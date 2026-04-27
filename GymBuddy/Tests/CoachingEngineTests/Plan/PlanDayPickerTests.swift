import XCTest
@testable import CoachingEngine

final class PlanDayPickerTests: XCTestCase {

    private func makePlan(workoutWeekdays: Set<Int>) -> Plan {
        let weeks: [PlanWeek] = (1...4).map { weekNo in
            let days: [PlanDay] = (1...7).map { dow in
                PlanDay(
                    weekNumber: weekNo,
                    dayOfWeek: dow,
                    isRestDay: !workoutWeekdays.contains(dow),
                    exercises: workoutWeekdays.contains(dow) ? [
                        PlannedExercise(exerciseId: .pushUp, sets: [
                            PlannedSet(setNumber: 1, targetReps: 10)
                        ])
                    ] : []
                )
            }
            return PlanWeek(weekNumber: weekNo, days: days)
        }
        return Plan(weeks: weeks, rationale: "")
    }

    func testExactWeekdayMatchIsPreferred() {
        let plan = makePlan(workoutWeekdays: [1, 3, 5])
        // Today is Wednesday (3).
        let day = PlanDayPicker.dayForToday(in: plan, weekdayMondayFirst: 3)
        XCTAssertEqual(day?.dayOfWeek, 3)
    }

    func testFallsBackToFirstNonRestDayIfNoExactMatch() {
        let plan = makePlan(workoutWeekdays: [1, 3, 5])
        // Today is Tuesday (2) — not in the plan.
        let day = PlanDayPicker.dayForToday(in: plan, weekdayMondayFirst: 2)
        XCTAssertEqual(day?.dayOfWeek, 1, "Expected fallback to Monday since Tuesday is a rest day")
    }

    func testReturnsNilWhenPlanHasNoNonRestDays() {
        let plan = makePlan(workoutWeekdays: [])
        XCTAssertNil(PlanDayPicker.dayForToday(in: plan, weekdayMondayFirst: 3))
    }

    func testReturnsNilWhenPlanIsNil() {
        XCTAssertNil(PlanDayPicker.dayForToday(in: nil, weekdayMondayFirst: 3))
    }

    func testClampsOutOfRangeWeekdays() {
        let plan = makePlan(workoutWeekdays: [1])
        // weekdayMondayFirst=0 is invalid → clamp to 1. Should match day 1.
        XCTAssertEqual(
            PlanDayPicker.dayForToday(in: plan, weekdayMondayFirst: 0)?.dayOfWeek,
            1
        )
        // weekdayMondayFirst=99 is invalid → clamp to 7. No match, so fallback.
        XCTAssertEqual(
            PlanDayPicker.dayForToday(in: plan, weekdayMondayFirst: 99)?.dayOfWeek,
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
