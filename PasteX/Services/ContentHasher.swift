import CryptoKit
import Foundation

enum ContentHasher {
    static func hash(type: ClipboardItemType, content: String, payloadData: Data?) -> String {
        var hasher = SHA256()
        hasher.update(data: Data(type.rawValue.utf8))
        hasher.update(data: Data([0x1F]))
        hasher.update(data: Data(content.utf8))

        if let payloadData {
            hasher.update(data: Data([0x1E]))
            hasher.update(data: payloadData)
        }

        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }

}
