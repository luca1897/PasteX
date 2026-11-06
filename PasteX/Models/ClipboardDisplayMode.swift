import Foundation

enum ClipboardDisplayMode: String, CaseIterable, Identifiable {
    case list
    case board

    var id: String { rawValue }

    var title: String {
        switch self {
        case .list:
            return "List"
        case .board:
            return "Board"
        }
    }

    var symbolName: String {
        switch self {
        case .list:
            return "list.bullet"
        case .board:
            return "square.grid.2x2"
        }
    }
}
