import AppKit
import SwiftUI

enum PasteXWindowRole {
    case floating
    case panel
    case preferences
}

struct WindowConfigurator: NSViewRepresentable {
    var role: PasteXWindowRole

    func makeNSView(context: Context) -> ConfiguratorView {
        ConfiguratorView(role: role)
    }

    func updateNSView(_ nsView: ConfiguratorView, context: Context) {
        nsView.role = role
        nsView.configureIfPossible()
    }

    final class ConfiguratorView: NSView {
        var role: PasteXWindowRole
        private var didInitialConfigure = false
        private weak var configuredWindow: NSWindow?

        init(role: PasteXWindowRole) {
            self.role = role
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) {
            role = .floating
            super.init(coder: coder)
        }

        deinit {
            configuredWindow = nil
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            configureIfPossible()
        }

        func configureIfPossible() {
            guard let window else { return }

            window.hasShadow = true

            if configuredWindow !== window {
                configuredWindow = window
            }

            switch role {
            case .floating, .panel:
                window.styleMask.insert(.fullSizeContentView)
                window.titleVisibility = .hidden
                window.titlebarAppearsTransparent = true
                window.toolbar = nil
                window.titlebarSeparatorStyle = .none
                window.isMovableByWindowBackground = true
                window.backgroundColor = .clear
                window.isOpaque = false
                window.level = .floating
                window.collectionBehavior.insert(.fullScreenAuxiliary)
                window.standardWindowButton(.closeButton)?.isHidden = true
                window.standardWindowButton(.miniaturizeButton)?.isHidden = true
                window.standardWindowButton(.zoomButton)?.isHidden = true
            case .preferences:
                window.title = "PasteX Settings"
                window.titleVisibility = .visible
                window.titlebarAppearsTransparent = false
                window.isMovableByWindowBackground = false
                window.backgroundColor = .windowBackgroundColor
                window.isOpaque = true
                window.level = .normal
            }

            guard !didInitialConfigure else { return }
            didInitialConfigure = true
            window.center()
        }
    }
}
