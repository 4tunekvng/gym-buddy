import Foundation

/// Picks the right `PlanDay` for "today" from a `Plan`.
///
/// Strategy (the current plan week is searched first, then the others in
/// order, so each week's progression reaches the user):
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

    /// - Parameters:
    ///   - weekNumber: the plan week the user is in, from
    ///     `weekNumber(of:on:calendar:)`.
    ///   - weekdayMondayFirst: 1 = Monday, 7 = Sunday.
    public static func dayForToday(
        in plan: Plan?,
        weekNumber: Int,
        weekdayMondayFirst: Int
    ) -> PlanDay? {
        guard let plan else { return nil }
        let weekday = max(1, min(7, weekdayMondayFirst))
        let weeks = plan.weeks.filter { $0.weekNumber == weekNumber }
            + plan.weeks.filter { $0.weekNumber != weekNumber }
        for week in weeks {
            if let day = week.days.first(where: { !$0.isRestDay && $0.dayOfWeek == weekday }) {
                return day
            }
        }
        for week in weeks {
            if let day = week.days.first(where: { !$0.isRestDay }) {
                return day
            }
        }
        return nil
    }

    /// The 1-based plan week `date` falls in: week 1 is the seven days starting
    /// on the plan's creation day. Capped to the plan's last week, so a finished
    /// plan keeps showing its final targets instead of falling back to week 1.
    public static func weekNumber(
        of plan: Plan,
        on date: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        let start = calendar.startOfDay(for: plan.createdAt)
        let today = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: start, to: today).day ?? 0
        let lastWeek = plan.weeks.map(\.weekNumber).max() ?? 1
        return max(1, min(lastWeek, days / 7 + 1))
    }

    /// Convenience: convert `Calendar.current`'s weekday (1=Sunday) to our
    /// Monday-first format (1=Monday).
    public static func mondayFirstWeekday(from date: Date = Date(), calendar: Calendar = .current) -> Int {
        let weekdaySundayFirst = calendar.component(.weekday, from: date)
        return ((weekdaySundayFirst + 5) % 7) + 1
    }
}
