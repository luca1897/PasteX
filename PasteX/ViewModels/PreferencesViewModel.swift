import Foundation

enum PreferencesSection: String, CaseIterable, Identifiable {
    case general = "General"
    case history = "History"
    case pinned = "Pinned"
    case shortcuts = "Shortcuts"
    case advanced = "Advanced"
    case about = "About"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .general:
            return "gearshape"
        case .history:
            return "clock"
        case .pinned:
            return "pin"
        case .shortcuts:
            return "command"
        case .advanced:
            return "slider.horizontal.3"
        case .about:
            return "info.circle"
        }
    }
}

enum ShortcutAction: String, CaseIterable, Identifiable {
    case clipboardWindow
    case compactSearch
    case previewPanel
    case settings
    case copySelectedItem
    case togglePin

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clipboardWindow:
            return "Clipboard Window"
        case .compactSearch:
            return "Compact Search"
        case .previewPanel:
            return "Preview Panel"
        case .settings:
            return "PasteX Settings"
        case .copySelectedItem:
            return "Copy Selected Item"
        case .togglePin:
            return "Pin or Unpin"
        }
    }

    var subtitle: String {
        switch self {
        case .clipboardWindow:
            return "Open the floating clipboard history"
        case .compactSearch:
            return "Open the quick launcher overlay"
        case .previewPanel:
            return "Open the selected item preview"
        case .settings:
            return "Open preferences"
        case .copySelectedItem:
            return "Copy the highlighted clipboard item"
        case .togglePin:
            return "Toggle the selected item"
        }
    }

    var isEditable: Bool {
        self == .clipboardWindow || self == .compactSearch
    }
}

struct ShortcutSetting: Identifiable, Equatable {
    let id: ShortcutAction
    var title: String
    var subtitle: String
    var keys: String
    var isEditable: Bool
}

struct CapturePreferences: Equatable {
    var includeImages: Bool
    var includeFiles: Bool
    var ignoreSensitiveContent: Bool
}

@MainActor
final class PreferencesViewModel: ObservableObject {
    @Published var selectedSection: PreferencesSection = .general
    @Published var recordingShortcutID: ShortcutAction?
    @Published var shortcutStatusMessage: String?
    @Published private(set) var launchAtLoginStatusMessage: String?

    @Published var launchAtLogin: Bool {
        didSet {
            guard !isSynchronizingLaunchAtLogin else {
                save(launchAtLogin, for: Keys.launchAtLogin)
                return
            }

            updateLaunchAtLoginRegistration()
        }
    }

    @Published var showInMenuBar: Bool {
        didSet { save(showInMenuBar, for: Keys.showInMenuBar) }
    }

    @Published var preferInlinePreview: Bool {
        didSet { save(preferInlinePreview, for: Keys.preferInlinePreview) }
    }

    @Published var clipboardDisplayMode: ClipboardDisplayMode {
        didSet {
            save(clipboardDisplayMode.rawValue, for: Keys.clipboardDisplayMode)
            onClipboardDisplayModeChanged?(clipboardDisplayMode)
        }
    }

    @Published var historyLimit: Int {
        didSet {
            let clampedValue = historyLimit.clamped(to: 50...2_000)
            guard clampedValue == historyLimit else {
                historyLimit = clampedValue
                return
            }
            save(historyLimit, for: Keys.historyLimit)
            notifyHistoryPolicyChanged()
        }
    }

    @Published var ignoreSensitiveContent: Bool {
        didSet {
            save(ignoreSensitiveContent, for: Keys.ignoreSensitiveContent)
            notifyCaptureSettingsChanged()
        }
    }

    @Published var retention: String {
        didSet {
            save(retention, for: Keys.retention)
            notifyHistoryPolicyChanged()
        }
    }

    @Published var maxItems: Int {
        didSet {
            let clampedValue = maxItems.clamped(to: 100...3_000)
            guard clampedValue == maxItems else {
                maxItems = clampedValue
                return
            }
            save(maxItems, for: Keys.maxItems)
            notifyHistoryPolicyChanged()
        }
    }

    @Published var includeImages: Bool {
        didSet {
            save(includeImages, for: Keys.includeImages)
            notifyCaptureSettingsChanged()
        }
    }

    @Published var includeFiles: Bool {
        didSet {
            save(includeFiles, for: Keys.includeFiles)
            notifyCaptureSettingsChanged()
        }
    }

    @Published var keepPinnedWhenClearing: Bool {
        didSet { save(keepPinnedWhenClearing, for: Keys.keepPinnedWhenClearing) }
    }

    @Published var showPinnedFirst: Bool {
        didSet { save(showPinnedFirst, for: Keys.showPinnedFirst) }
    }

    @Published var pinnedLimit: Int {
        didSet {
            let clampedValue = pinnedLimit.clamped(to: 10...200)
            guard clampedValue == pinnedLimit else {
                pinnedLimit = clampedValue
                return
            }
            save(pinnedLimit, for: Keys.pinnedLimit)
        }
    }

    @Published var reduceMotion: Bool {
        didSet { save(reduceMotion, for: Keys.reduceMotion) }
    }

    @Published private(set) var hasSeenEmptyStateOnboarding: Bool {
        didSet { save(hasSeenEmptyStateOnboarding, for: Keys.hasSeenEmptyStateOnboarding) }
    }

    @Published var clipboardShortcut: GlobalShortcut {
        didSet {
            save(clipboardShortcut, for: Keys.clipboardShortcut)
            notifyGlobalShortcutsChanged()
        }
    }

    @Published var compactSearchShortcut: GlobalShortcut {
        didSet {
            save(compactSearchShortcut, for: Keys.compactSearchShortcut)
            notifyGlobalShortcutsChanged()
        }
    }

    var onCaptureSettingsChanged: ((CapturePreferences) -> Void)?
    var onGlobalShortcutsChanged: (() -> Void)?
    var onHistoryPolicyChanged: (() -> Void)?
    var onClipboardDisplayModeChanged: ((ClipboardDisplayMode) -> Void)?
    var onClearHistory: ((Bool) -> Void)?

    let retentionOptions = ["24 hours", "7 days", "30 days", "90 days", "Forever"]

    private let defaults: UserDefaults
    private var isSynchronizingLaunchAtLogin = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let storedLaunchAtLogin = defaults.bool(for: Keys.launchAtLogin, default: false)
        launchAtLogin = storedLaunchAtLogin
        showInMenuBar = defaults.bool(for: Keys.showInMenuBar, default: true)
        preferInlinePreview = defaults.bool(for: Keys.preferInlinePreview, default: false)
        clipboardDisplayMode = ClipboardDisplayMode(rawValue: defaults.string(for: Keys.clipboardDisplayMode, default: ClipboardDisplayMode.list.rawValue)) ?? .list
        historyLimit = defaults.integer(for: Keys.historyLimit, default: 500)
        ignoreSensitiveContent = defaults.bool(for: Keys.ignoreSensitiveContent, default: true)
        retention = defaults.string(for: Keys.retention, default: "30 days")
        maxItems = defaults.integer(for: Keys.maxItems, default: 500)
        includeImages = defaults.bool(for: Keys.includeImages, default: true)
        includeFiles = defaults.bool(for: Keys.includeFiles, default: false)
        keepPinnedWhenClearing = defaults.bool(for: Keys.keepPinnedWhenClearing, default: true)
        showPinnedFirst = defaults.bool(for: Keys.showPinnedFirst, default: true)
        pinnedLimit = defaults.integer(for: Keys.pinnedLimit, default: 50)
        reduceMotion = defaults.bool(for: Keys.reduceMotion, default: false)
        hasSeenEmptyStateOnboarding = defaults.bool(for: Keys.hasSeenEmptyStateOnboarding, default: false)
        clipboardShortcut = defaults.shortcut(for: Keys.clipboardShortcut, default: .clipboardWindowDefault)
        compactSearchShortcut = defaults.shortcut(for: Keys.compactSearchShortcut, default: .compactSearchDefault)

        synchronizeLaunchAtLoginWithSystem(storedPreference: storedLaunchAtLogin)
    }

    var shouldShowEmptyStateOnboarding: Bool {
        !hasSeenEmptyStateOnboarding
    }

    var capturePreferences: CapturePreferences {
        CapturePreferences(
            includeImages: includeImages,
            includeFiles: includeFiles,
            ignoreSensitiveContent: ignoreSensitiveContent
        )
    }

    var retentionCutoffDate: Date? {
        switch retention {
        case "24 hours":
            return Calendar.current.date(byAdding: .hour, value: -24, to: Date())
        case "7 days":
            return Calendar.current.date(byAdding: .day, value: -7, to: Date())
        case "30 days":
            return Calendar.current.date(byAdding: .day, value: -30, to: Date())
        case "90 days":
            return Calendar.current.date(byAdding: .day, value: -90, to: Date())
        default:
            return nil
        }
    }

    var shortcuts: [ShortcutSetting] {
        [
            ShortcutSetting(
                id: .clipboardWindow,
                title: ShortcutAction.clipboardWindow.title,
                subtitle: ShortcutAction.clipboardWindow.subtitle,
                keys: clipboardShortcut.displayText,
                isEditable: true
            ),
            ShortcutSetting(
                id: .compactSearch,
                title: ShortcutAction.compactSearch.title,
                subtitle: ShortcutAction.compactSearch.subtitle,
                keys: compactSearchShortcut.displayText,
                isEditable: true
            ),
            ShortcutSetting(
                id: .previewPanel,
                title: ShortcutAction.previewPanel.title,
                subtitle: ShortcutAction.previewPanel.subtitle,
                keys: "Space",
                isEditable: false
            ),
            ShortcutSetting(
                id: .settings,
                title: ShortcutAction.settings.title,
                subtitle: ShortcutAction.settings.subtitle,
                keys: "⌘,",
                isEditable: false
            ),
            ShortcutSetting(
                id: .copySelectedItem,
                title: ShortcutAction.copySelectedItem.title,
                subtitle: ShortcutAction.copySelectedItem.subtitle,
                keys: "↩",
                isEditable: false
            ),
            ShortcutSetting(
                id: .togglePin,
                title: ShortcutAction.togglePin.title,
                subtitle: ShortcutAction.togglePin.subtitle,
                keys: "⌘P",
                isEditable: false
            )
        ]
    }

    func shortcut(for action: ShortcutAction) -> GlobalShortcut? {
        switch action {
        case .clipboardWindow:
            return clipboardShortcut
        case .compactSearch:
            return compactSearchShortcut
        default:
            return nil
        }
    }

    func startRecordingShortcut(_ action: ShortcutAction) {
        guard action.isEditable else { return }
        shortcutStatusMessage = "Press a shortcut for \(action.title). Esc cancels."
        recordingShortcutID = action
    }

    func cancelRecordingShortcut() {
        recordingShortcutID = nil
        shortcutStatusMessage = nil
    }

    func updateShortcut(_ shortcut: GlobalShortcut, for action: ShortcutAction) {
        guard action.isEditable else { return }

        if let conflictingAction = conflictingAction(for: shortcut, excluding: action) {
            shortcutStatusMessage = "\(shortcut.displayText) is already assigned to \(conflictingAction.title)."
            recordingShortcutID = nil
            return
        }

        switch action {
        case .clipboardWindow:
            clipboardShortcut = shortcut
        case .compactSearch:
            compactSearchShortcut = shortcut
        default:
            break
        }

        shortcutStatusMessage = "\(action.title) shortcut set to \(shortcut.displayText)."
        recordingShortcutID = nil
    }

    func resetGlobalShortcuts() {
        clipboardShortcut = .clipboardWindowDefault
        compactSearchShortcut = .compactSearchDefault
        shortcutStatusMessage = "Shortcuts reset to defaults."
    }

    func updateHotKeyRegistrationStatus(_ registrations: [GlobalHotKeyRegistration]) {
        let failures = registrations.filter { !$0.succeeded }

        guard !failures.isEmpty else {
            if shortcutStatusMessage?.contains("failed") == true {
                shortcutStatusMessage = nil
            }
            return
        }

        shortcutStatusMessage = failures
            .map { "\($0.shortcut.displayText) for \($0.action.title) failed to register. It may be used by another app." }
            .joined(separator: " ")
    }

    func clearHistory(keepingPinned: Bool) {
        onClearHistory?(keepingPinned)
    }

    func refreshLaunchAtLoginStatus() {
        let manager = LaunchAtLoginManager.shared
        setLaunchAtLoginState(manager.isEnabled)
        launchAtLoginStatusMessage = manager.statusMessage()
    }

    func markEmptyStateOnboardingSeen() {
        hasSeenEmptyStateOnboarding = true
    }

    private func synchronizeLaunchAtLoginWithSystem(storedPreference: Bool) {
        let manager = LaunchAtLoginManager.shared

        // Migrate the old preference, which only stored the toggle and never registered anything.
        if storedPreference && !manager.isEnabled {
            do {
                try manager.enable()
            } catch {
                setLaunchAtLoginState(false)
                launchAtLoginStatusMessage = manager.statusMessage(for: error)
                return
            }
        }

        refreshLaunchAtLoginStatus()
    }

    private func updateLaunchAtLoginRegistration() {
        let manager = LaunchAtLoginManager.shared

        do {
            if launchAtLogin {
                try manager.enable()
            } else {
                try manager.disable()
            }

            setLaunchAtLoginState(manager.isEnabled)
            launchAtLoginStatusMessage = manager.statusMessage()
        } catch {
            setLaunchAtLoginState(manager.isEnabled)
            launchAtLoginStatusMessage = manager.statusMessage(for: error)
        }
    }

    private func setLaunchAtLoginState(_ enabled: Bool) {
        guard launchAtLogin != enabled else {
            save(enabled, for: Keys.launchAtLogin)
            return
        }

        isSynchronizingLaunchAtLogin = true
        launchAtLogin = enabled
        isSynchronizingLaunchAtLogin = false
    }

    private func conflictingAction(for shortcut: GlobalShortcut, excluding action: ShortcutAction) -> ShortcutAction? {
        if action != .clipboardWindow, clipboardShortcut == shortcut {
            return .clipboardWindow
        }

        if action != .compactSearch, compactSearchShortcut == shortcut {
            return .compactSearch
        }

        return nil
    }

    private func notifyCaptureSettingsChanged() {
        onCaptureSettingsChanged?(capturePreferences)
    }

    private func notifyGlobalShortcutsChanged() {
        onGlobalShortcutsChanged?()
    }

    private func notifyHistoryPolicyChanged() {
        onHistoryPolicyChanged?()
    }


    private func save<T>(_ value: T, for key: String) {
        defaults.set(value, forKey: key)
    }

    private func save(_ shortcut: GlobalShortcut, for key: String) {
        guard let data = try? JSONEncoder().encode(shortcut) else { return }
        defaults.set(data, forKey: key)
    }
}

private enum Keys {
    static let launchAtLogin = "preferences.launchAtLogin"
    static let showInMenuBar = "preferences.showInMenuBar"
    static let preferInlinePreview = "preferences.preferInlinePreview"
    static let clipboardDisplayMode = "preferences.clipboardDisplayMode"
    static let historyLimit = "preferences.historyLimit"
    static let ignoreSensitiveContent = "preferences.ignoreSensitiveContent"
    static let retention = "preferences.retention"
    static let maxItems = "preferences.maxItems"
    static let includeImages = "preferences.includeImages"
    static let includeFiles = "preferences.includeFiles"
    static let keepPinnedWhenClearing = "preferences.keepPinnedWhenClearing"
    static let showPinnedFirst = "preferences.showPinnedFirst"
    static let pinnedLimit = "preferences.pinnedLimit"
    static let reduceMotion = "preferences.reduceMotion"
    static let clipboardShortcut = "preferences.shortcuts.clipboardWindow"
    static let compactSearchShortcut = "preferences.shortcuts.compactSearch"
    static let hasSeenEmptyStateOnboarding = "preferences.onboarding.emptyStateSeen"
}

private extension UserDefaults {
    func bool(for key: String, default defaultValue: Bool) -> Bool {
        object(forKey: key) as? Bool ?? defaultValue
    }

    func integer(for key: String, default defaultValue: Int) -> Int {
        object(forKey: key) as? Int ?? defaultValue
    }

    func string(for key: String, default defaultValue: String) -> String {
        string(forKey: key) ?? defaultValue
    }

    func shortcut(for key: String, default defaultValue: GlobalShortcut) -> GlobalShortcut {
        guard
            let data = data(forKey: key),
            let shortcut = try? JSONDecoder().decode(GlobalShortcut.self, from: data)
        else {
            return defaultValue
        }

        return shortcut
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
