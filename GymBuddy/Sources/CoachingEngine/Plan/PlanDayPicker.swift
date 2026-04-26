import Foundation

/// Picks the right `PlanDay` for "today" from a `Plan`.
///
/// Strategy:
///   1. Exact match: the first non-rest day whose `dayOfWeek` equals today's
///      weekday (1=Monday).
///   2. Fallback: the first non-rest day in any week, so a new user who starts
///      mid-week still sees something actionable.
///   3. Nil when the plan has no non-rest days at all (every day is rest).
///
/// Lives in the domain layer so both the iOS view layer and the CLI / tests
/// can share the same logic. Weekday input is explicit (1-based, Monday=1)
/// so tests don't have to monkey with `Calendar.current`.
public enum PlanDayPicker {

    /// - Parameter weekdayMondayFirst: 1 = Monday, 7 = Sunday.
    public static func dayForToday(in plan: Plan?, weekdayMondayFirst: Int) -> PlanDay? {
        guard let plan else { return nil }
        let weekday = max(1, min(7, weekdayMondayFirst))
        for week in plan.weeks {
            if let day = week.days.first(where: { !$0.isRestDay && $0.dayOfWeek == weekday }) {
                return day
            }
        }
        for week in plan.weeks {
            if let day = week.days.first(where: { !$0.isRestDay }) {
                return day
            }
        }
        return nil
    }

    /// Convenience: convert `Calendar.current`'s weekday (1=Sunday) to our
    /// Monday-first format (1=Monday).
    public static func mondayFirstWeekday(from date: Date = Date(), calendar: Calendar = .current) -> Int {
        let weekdaySundayFirst = calendar.component(.weekday, from: date)
        return ((weekdaySundayFirst + 5) % 7) + 1
    }
}
