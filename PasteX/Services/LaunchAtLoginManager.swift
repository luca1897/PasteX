import Foundation
import ServiceManagement

@MainActor
final class LaunchAtLoginManager {
    static let shared = LaunchAtLoginManager()

    private let service = SMAppService.mainApp

    private init() {}

    var status: SMAppService.Status {
        service.status
    }

    var isEnabled: Bool {
        status == .enabled
    }

    func enable() throws {
        guard status != .enabled else { return }
        try service.register()
    }

    func disable() throws {
        guard status != .notRegistered else { return }
        try service.unregister()
    }

    func statusMessage(for error: Error? = nil) -> String? {
        if let error {
            let nsError = error as NSError

            if nsError.code == Int(kSMErrorInvalidSignature) {
                return "Launch at login requires a signed app. Set a Team in Xcode and run the app again."
            }

            if nsError.code == Int(kSMErrorLaunchDeniedByUser) {
                return "macOS denied this login item. Enable PasteX in System Settings > General > Login Items."
            }

            return "Could not update Launch at login: \(nsError.localizedDescription)"
        }

        switch status {
        case .enabled, .notRegistered:
            return nil
        case .requiresApproval:
            return "Enable PasteX in System Settings > General > Login Items."
        case .notFound:
            return "PasteX must be installed as an app before it can launch at login."
        @unknown default:
            return "The Launch at login status is unavailable."
        }
    }
}
