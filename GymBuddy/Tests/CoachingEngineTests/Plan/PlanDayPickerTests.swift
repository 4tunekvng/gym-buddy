import XCTest
@testable import CoachingEngine

final class PlanDayPickerTests: XCTestCase {

    private func makePlan(
        workoutWeekdays: Set<Int>,
        createdAt: Date = Date()
    ) -> Plan {
        let weeks: [PlanWeek] = (1...4).map { weekNo in
            let days: [PlanDay] = (1...7).map { dow in
                PlanDay(
                    weekNumber: weekNo,
                    dayOfWeek: dow,
                    isRestDay: !workoutWeekdays.contains(dow),
                    exercises: workoutWeekdays.contains(dow) ? [
                        PlannedExercise(exerciseId: .pushUp, sets: [
                            // Reps rise one per week, like PlanGenerator.
                            PlannedSet(setNumber: 1, targetReps: 9 + weekNo)
                        ])
                    ] : []
                )
            }
            return PlanWeek(weekNumber: weekNo, days: days)
        }
        return Plan(createdAt: createdAt, weeks: weeks, rationale: "")
    }

    func testExactWeekdayMatchIsPreferred() {
        let plan = makePlan(workoutWeekdays: [1, 3, 5])
        // Today is Wednesday (3).
        let day = PlanDayPicker.dayForToday(
            in: plan, weekNumber: 1, weekdayMondayFirst: 3, hasTrained: false
        )
        XCTAssertEqual(day?.dayOfWeek, 3)
    }

    func testRestDayIsRestOnceTheUserHasTrained() {
        let plan = makePlan(workoutWeekdays: [1, 3, 5])

        // Today is Tuesday (2), a rest day.
        let day = PlanDayPicker.dayForToday(
            in: plan, weekNumber: 1, weekdayMondayFirst: 2, hasTrained: true
        )

        XCTAssertNil(day)
    }

    func testNewUserOnARestDayGetsTheFirstWorkout() {
        let plan = makePlan(workoutWeekdays: [1, 3, 5])
        // Today is Tuesday (2) — not in the plan.
        let day = PlanDayPicker.dayForToday(
            in: plan, weekNumber: 1, weekdayMondayFirst: 2, hasTrained: false
        )
        XCTAssertEqual(day?.dayOfWeek, 1, "Expected fallback to Monday since Tuesday is a rest day")
    }

    func testPicksTheCurrentWeeksDaySoProgressionReachesTheUser() {
        let plan = makePlan(workoutWeekdays: [1, 3, 5])

        let day = PlanDayPicker.dayForToday(
            in: plan, weekNumber: 3, weekdayMondayFirst: 3, hasTrained: false
        )

        XCTAssertEqual(day?.weekNumber, 3)
        XCTAssertEqual(day?.exercises.first?.sets.first?.targetReps, 12)
    }

    func testFallbackAlsoStaysInTheCurrentWeek() {
        let plan = makePlan(workoutWeekdays: [1, 3, 5])

        let day = PlanDayPicker.dayForToday(
            in: plan, weekNumber: 2, weekdayMondayFirst: 2, hasTrained: false
        )

        XCTAssertEqual(day?.weekNumber, 2)
        XCTAssertEqual(day?.dayOfWeek, 1)
    }

    func testWeekNumberCountsSevenDayBlocksFromPlanCreation() throws {
        let cal = try utcCalendar()
        let created = try day(2026, 4, 15, cal)  // a Wednesday
        let plan = makePlan(workoutWeekdays: [1], createdAt: created)

        let sameDay = PlanDayPicker.weekNumber(
            of: plan, on: created, calendar: cal
        )
        let day6 = try PlanDayPicker.weekNumber(
            of: plan, on: day(2026, 4, 21, cal), calendar: cal
        )
        let day7 = try PlanDayPicker.weekNumber(
            of: plan, on: day(2026, 4, 22, cal), calendar: cal
        )
        let day15 = try PlanDayPicker.weekNumber(
            of: plan, on: day(2026, 4, 30, cal), calendar: cal
        )

        XCTAssertEqual(sameDay, 1)
        XCTAssertEqual(day6, 1)
        XCTAssertEqual(day7, 2)
        XCTAssertEqual(day15, 3)
    }

    func testWeekNumberCapsAtTheLastWeekAndNeverDropsBelowOne() throws {
        let cal = try utcCalendar()
        let created = try day(2026, 4, 15, cal)
        let plan = makePlan(workoutWeekdays: [1], createdAt: created)

        let longAfter = try PlanDayPicker.weekNumber(
            of: plan, on: day(2026, 9, 1, cal), calendar: cal
        )
        let before = try PlanDayPicker.weekNumber(
            of: plan, on: day(2026, 4, 1, cal), calendar: cal
        )

        XCTAssertEqual(longAfter, 4)
        XCTAssertEqual(before, 1)
    }

    private func utcCalendar() throws -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = try XCTUnwrap(TimeZone(identifier: "UTC"))
        return cal
    }

    private func day(_ y: Int, _ m: Int, _ d: Int, _ cal: Calendar) throws -> Date {
        let comps = DateComponents(year: y, month: m, day: d, hour: 9)
        return try XCTUnwrap(cal.date(from: comps))
    }

    func testReturnsNilWhenPlanHasNoNonRestDays() {
        let plan = makePlan(workoutWeekdays: [])
        XCTAssertNil(PlanDayPicker.dayForToday(
            in: plan, weekNumber: 1, weekdayMondayFirst: 3, hasTrained: false
        ))
    }

    func testReturnsNilWhenPlanIsNil() {
        XCTAssertNil(PlanDayPicker.dayForToday(
            in: nil, weekNumber: 1, weekdayMondayFirst: 3, hasTrained: false
        ))
    }

    func testClampsOutOfRangeWeekdays() {
        let plan = makePlan(workoutWeekdays: [1])
        // weekdayMondayFirst=0 is invalid → clamp to 1. Should match day 1.
        XCTAssertEqual(
            PlanDayPicker.dayForToday(
                in: plan, weekNumber: 1, weekdayMondayFirst: 0, hasTrained: false
            )?.dayOfWeek,
            1
        )
        // weekdayMondayFirst=99 is invalid → clamp to 7. No match, so fallback.
        XCTAssertEqual(
            PlanDayPicker.dayForToday(
                in: plan, weekNumber: 1, weekdayMondayFirst: 99, hasTrained: false
            )?.dayOfWeek,
            1
        )
    }

    func testMondayFirstConversionFromCalendarWeekday() throws {
        // Calendar .weekday: 1=Sunday, 2=Monday, …, 7=Saturday.
        // Our Monday-first: 1=Monday, 2=Tuesday, …, 7=Sunday.
        //
        // We can't force `Date()` directly, but we CAN build a Date for a
        // known weekday and verify the conversion.
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = try XCTUnwrap(TimeZone(identifier: "UTC"))

        // 2026-04-13 is a Monday (weekday = 2 in Calendar's Sunday-first).
        var comps = DateComponents()
        comps.year = 2026; comps.month = 4; comps.day = 13
        let monday = try XCTUnwrap(cal.date(from: comps))
        XCTAssertEqual(PlanDayPicker.mondayFirstWeekday(from: monday, calendar: cal), 1)

        comps.day = 14
        let tuesday = try XCTUnwrap(cal.date(from: comps))
        XCTAssertEqual(PlanDayPicker.mondayFirstWeekday(from: tuesday, calendar: cal), 2)

        comps.day = 19
        let sunday = try XCTUnwrap(cal.date(from: comps))
        XCTAssertEqual(PlanDayPicker.mondayFirstWeekday(from: sunday, calendar: cal), 7)
    }
}
