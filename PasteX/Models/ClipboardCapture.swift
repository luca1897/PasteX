import Foundation

struct ClipboardCaptureMetadata: Equatable {
    var bundleIdentifier: String?
    var pasteboardChangeCount: Int?
    var mimeType: String?
    var language: String?
    var imagePixelWidth: Int?
    var imagePixelHeight: Int?
    var byteSize: Int?
    var sizeLabel: String?
    var primaryName: String?
    var fileCount: Int?
    var fileNames: [String]?
}

struct ClipboardCapture {
    let type: ClipboardItemType
    let title: String
    let subtitle: String?
    let preview: String
    let content: String
    let payloadData: Data?
    let sourceApp: String
    let createdAt: Date
    var metadata = ClipboardCaptureMetadata()

    var contentHash: String {
        ContentHasher.hash(type: type, content: content, payloadData: payloadData)
    }
}
