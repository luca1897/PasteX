import SwiftUI

enum ClipboardItemType: String, CaseIterable, Codable, Identifiable {
    case text
    case url
    case code
    case image
    case json
    case email
    case color
    case file

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .text:
            return "Text"
        case .url:
            return "URL"
        case .code:
            return "Code"
        case .image:
            return "Image"
        case .json:
            return "JSON"
        case .email:
            return "Email"
        case .color:
            return "Color"
        case .file:
            return "File"
        }
    }

    var symbolName: String {
        switch self {
        case .text:
            return "text.alignleft"
        case .url:
            return "globe"
        case .code:
            return "chevron.left.forwardslash.chevron.right"
        case .image:
            return "photo"
        case .json:
            return "curlybraces"
        case .email:
            return "envelope"
        case .color:
            return "eyedropper.halffull"
        case .file:
            return "doc"
        }
    }

    var tint: Color {
        switch self {
        case .text:
            return .primary
        case .url:
            return Color(red: 0.16, green: 0.45, blue: 0.86)
        case .code:
            return Color(red: 0.42, green: 0.45, blue: 0.92)
        case .image:
            return Color(red: 0.12, green: 0.58, blue: 0.48)
        case .json:
            return Color(red: 0.54, green: 0.36, blue: 0.82)
        case .email:
            return Color(red: 0.87, green: 0.46, blue: 0.24)
        case .color:
            return Color(red: 0.24, green: 0.52, blue: 0.95)
        case .file:
            return Color(red: 0.48, green: 0.54, blue: 0.62)
        }
    }
}
