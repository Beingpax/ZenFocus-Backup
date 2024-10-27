import Foundation

enum TimePeriod: String, CaseIterable {
    case day = "Today"
    case yesterday = "Yesterday"
    case week = "This Week"
    case month = "This Month"
    case year = "This Year"
    case allTime = "All Time"
    
    func dateRange() -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .day:
            let start = calendar.startOfDay(for: now)
            let end = calendar.date(byAdding: .day, value: 1, to: start)!
            return (start, end)
        case .yesterday:
            let start = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now))!
            let end = calendar.date(byAdding: .day, value: 1, to: start)!
            return (start, end)
        case .week:
            let weekday = calendar.component(.weekday, from: now)
            let weekdayOffset = (weekday + 7 - calendar.firstWeekday) % 7
            let weekStart = calendar.date(byAdding: .day, value: -weekdayOffset, to: calendar.startOfDay(for: now))!
            let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart)!
            return (weekStart, weekEnd)
        case .month:
            let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart)!
            return (monthStart, monthEnd)
        case .year:
            let yearStart = calendar.date(from: calendar.dateComponents([.year], from: now))!
            let yearEnd = calendar.date(byAdding: DateComponents(year: 1, day: -1), to: yearStart)!
            return (yearStart, yearEnd)
        case .allTime:
            return (Date.distantPast, Date.distantFuture)
        }
    }
}