import Foundation

struct ClipboardItem: Identifiable, Equatable {
    let id: UUID
    let type: ClipboardItemType
    var title: String
    var subtitle: String?
    var preview: String
    var content: String
    var payloadData: Data?
    var sourceApp: String
    var createdAt: Date
    var isPinned: Bool

    init(
        id: UUID = UUID(),
        type: ClipboardItemType,
        title: String,
        subtitle: String? = nil,
        preview: String,
        content: String,
        payloadData: Data? = nil,
        sourceApp: String,
        createdAt: Date,
        isPinned: Bool = false
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.subtitle = subtitle
        self.preview = preview
        self.content = content
        self.payloadData = payloadData
        self.sourceApp = sourceApp
        self.createdAt = createdAt
        self.isPinned = isPinned
    }
}

extension ClipboardItem {
    var contentHash: String {
        ContentHasher.hash(type: type, content: content, payloadData: payloadData)
    }


    var timeString: String {
        Self.timeFormatter.string(from: createdAt)
    }

    var dateTimeString: String {
        Self.dateTimeFormatter.string(from: createdAt)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
