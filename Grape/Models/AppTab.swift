import Foundation

enum AppSection: String, CaseIterable, Identifiable {
    case home
    case tasks
    case calendar
    case chat
    case expenses

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "Home"
        case .tasks: return "Tasks"
        case .calendar: return "Schedule"
        case .chat: return "Chat"
        case .expenses: return "Wallet"
        }
    }

    var assetName: String {
        switch self {
        case .home: return "AppIcon"
        case .tasks: return "Task"
        case .calendar: return "Timetable"
        case .chat: return "Communication"
        case .expenses: return "Expense"
        }
    }
}
