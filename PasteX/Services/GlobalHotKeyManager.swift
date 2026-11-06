import AppKit
import Carbon.HIToolbox
import Foundation

enum GlobalHotKeyAction: String, CaseIterable, Codable, Identifiable {
    case clipboardWindow
    case compactSearch

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clipboardWindow:
            return "Clipboard Window"
        case .compactSearch:
            return "Compact Search"
        }
    }

    var hotKeyID: UInt32 {
        switch self {
        case .clipboardWindow:
            return 1
        case .compactSearch:
            return 2
        }
    }

    var defaultShortcut: GlobalShortcut {
        switch self {
        case .clipboardWindow:
            return .clipboardWindowDefault
        case .compactSearch:
            return .compactSearchDefault
        }
    }
}

struct GlobalShortcut: Codable, Equatable, Hashable {
    var keyCode: UInt32
    var modifiers: UInt32
    var keyLabel: String

    static let clipboardWindowDefault = GlobalShortcut(
        keyCode: UInt32(kVK_ANSI_V),
        modifiers: UInt32(cmdKey | shiftKey),
        keyLabel: "V"
    )

    static let compactSearchDefault = GlobalShortcut(
        keyCode: UInt32(kVK_ANSI_K),
        modifiers: UInt32(cmdKey | optionKey),
        keyLabel: "K"
    )

    var displayText: String {
        var text = ""

        if modifiers & UInt32(controlKey) != 0 {
            text += "⌃"
        }

        if modifiers & UInt32(optionKey) != 0 {
            text += "⌥"
        }

        if modifiers & UInt32(shiftKey) != 0 {
            text += "⇧"
        }

        if modifiers & UInt32(cmdKey) != 0 {
            text += "⌘"
        }

        return text + keyLabel
    }

    var hasSystemModifier: Bool {
        let systemModifiers = UInt32(cmdKey | controlKey | optionKey)
        return modifiers & systemModifiers != 0
    }

    init(keyCode: UInt32, modifiers: UInt32, keyLabel: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.keyLabel = keyLabel
    }

    init?(event: NSEvent) {
        guard let keyLabel = Self.keyLabel(for: event), !keyLabel.isEmpty else { return nil }

        let modifiers = Self.carbonModifiers(from: event.modifierFlags)
        let shortcut = GlobalShortcut(
            keyCode: UInt32(event.keyCode),
            modifiers: modifiers,
            keyLabel: keyLabel
        )

        guard shortcut.hasSystemModifier else { return nil }
        self = shortcut
    }

    private static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        let normalizedFlags = flags.intersection(.deviceIndependentFlagsMask)
        var carbonModifiers: UInt32 = 0

        if normalizedFlags.contains(.command) {
            carbonModifiers |= UInt32(cmdKey)
        }

        if normalizedFlags.contains(.shift) {
            carbonModifiers |= UInt32(shiftKey)
        }

        if normalizedFlags.contains(.option) {
            carbonModifiers |= UInt32(optionKey)
        }

        if normalizedFlags.contains(.control) {
            carbonModifiers |= UInt32(controlKey)
        }

        return carbonModifiers
    }

    private static func keyLabel(for event: NSEvent) -> String? {
        switch Int(event.keyCode) {
        case kVK_Space:
            return "Space"
        case kVK_Return, kVK_ANSI_KeypadEnter:
            return "↩"
        case kVK_Delete:
            return "⌫"
        case kVK_Escape:
            return nil
        default:
            guard let character = event.charactersIgnoringModifiers?.trimmingCharacters(in: .whitespacesAndNewlines).first else {
                return nil
            }

            return String(character).uppercased()
        }
    }
}

struct GlobalHotKeyRegistration {
    let action: GlobalHotKeyAction
    let shortcut: GlobalShortcut
    let status: OSStatus

    var succeeded: Bool {
        status == noErr
    }
}

final class GlobalHotKeyManager {
    static let shared = GlobalHotKeyManager()

    private static let signature: OSType = 0x50535458 // "PSTX"

    private var hotKeyRefs: [UInt32: EventHotKeyRef] = [:]
    private var eventHandlerRef: EventHandlerRef?
    private var actions: [UInt32: () -> Void] = [:]

    private init() {}

    @discardableResult
    func registerShortcuts(
        clipboardShortcut: GlobalShortcut,
        searchShortcut: GlobalShortcut,
        openClipboard: @escaping () -> Void,
        openSearch: @escaping () -> Void
    ) -> [GlobalHotKeyRegistration] {
        actions = [
            GlobalHotKeyAction.clipboardWindow.hotKeyID: openClipboard,
            GlobalHotKeyAction.compactSearch.hotKeyID: openSearch
        ]

        installEventHandlerIfNeeded()

        return [
            registerHotKey(action: .clipboardWindow, shortcut: clipboardShortcut),
            registerHotKey(action: .compactSearch, shortcut: searchShortcut)
        ]
    }

    private func installEventHandlerIfNeeded() {
        guard eventHandlerRef == nil else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, eventRef, _ in
                guard let eventRef else { return noErr }

                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    eventRef,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                guard
                    status == noErr,
                    hotKeyID.signature == GlobalHotKeyManager.signature
                else {
                    return noErr
                }

                DispatchQueue.main.async {
                    GlobalHotKeyManager.shared.handleHotKey(id: hotKeyID.id)
                }

                return noErr
            },
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )

        if status != noErr {
            NSLog("PasteX failed to install global hotkey handler: \(status)")
        }
    }

    private func registerHotKey(action: GlobalHotKeyAction, shortcut: GlobalShortcut) -> GlobalHotKeyRegistration {
        let id = action.hotKeyID

        if let hotKeyRef = hotKeyRefs[id] {
            UnregisterEventHotKey(hotKeyRef)
            hotKeyRefs[id] = nil
        }

        let hotKeyID = EventHotKeyID(
            signature: Self.signature,
            id: id
        )

        var hotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status == noErr, let hotKeyRef {
            hotKeyRefs[id] = hotKeyRef
        } else {
            NSLog("PasteX failed to register global hotkey \(shortcut.displayText): \(status)")
        }

        return GlobalHotKeyRegistration(action: action, shortcut: shortcut, status: status)
    }

    private func handleHotKey(id: UInt32) {
        actions[id]?()
    }

    deinit {
        for hotKeyRef in hotKeyRefs.values {
            UnregisterEventHotKey(hotKeyRef)
        }

        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }
}
