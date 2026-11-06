import AppKit
import Foundation
import SwiftUI

struct ClipboardSection: Identifiable {
    let id: String
    let title: String
    let items: [ClipboardItem]
}

@MainActor
final class ClipboardViewModel: ObservableObject {
    @Published var items: [ClipboardItem]
    @Published var searchText = ""
    @Published var selectedItemID: ClipboardItem.ID?
    @Published var lastErrorMessage: String?
    @Published private(set) var displayMode: ClipboardDisplayMode
    @Published private(set) var showFirstRunOnboarding: Bool

    private let database: ClipboardDatabase
    private let pasteboardMonitor: PasteboardMonitor
    private let preferences: PreferencesViewModel

    init(
        database: ClipboardDatabase = .shared,
        pasteboardMonitor: PasteboardMonitor? = nil,
        preferences: PreferencesViewModel
    ) {
        self.database = database
        self.pasteboardMonitor = pasteboardMonitor ?? .shared
        self.preferences = preferences
        items = []
        displayMode = preferences.clipboardDisplayMode
        showFirstRunOnboarding = preferences.shouldShowEmptyStateOnboarding

        if showFirstRunOnboarding {
            preferences.markEmptyStateOnboardingSeen()
        }

        self.pasteboardMonitor.updateConfiguration(preferences.capturePreferences)

        preferences.onCaptureSettingsChanged = { [weak pasteboardMonitor = self.pasteboardMonitor] preferences in
            Task { @MainActor in
                pasteboardMonitor?.updateConfiguration(preferences)
            }
        }
        preferences.onHistoryPolicyChanged = { [weak self] in
            Task { @MainActor in
                await self?.applyHistoryPolicy()
            }
        }
        preferences.onClipboardDisplayModeChanged = { [weak self] displayMode in
            Task { @MainActor in
                self?.displayMode = displayMode
            }
        }

        self.pasteboardMonitor.onCapture = { [weak self] capture in
            Task { @MainActor in
                await self?.storeCapture(capture)
            }
        }

        Task {
            await reloadItems()
            self.pasteboardMonitor.start()
        }
    }

    var selectedItem: ClipboardItem? {
        guard let selectedItemID else { return filteredItems.first ?? items.first }
        return items.first(where: { $0.id == selectedItemID }) ?? filteredItems.first ?? items.first
    }

    var filteredItems: [ClipboardItem] {
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return items }

        return items.filter { item in
            item.title.localizedCaseInsensitiveContains(trimmedQuery)
                || item.preview.localizedCaseInsensitiveContains(trimmedQuery)
                || item.content.localizedCaseInsensitiveContains(trimmedQuery)
                || item.sourceApp.localizedCaseInsensitiveContains(trimmedQuery)
                || item.type.displayName.localizedCaseInsensitiveContains(trimmedQuery)
        }
    }

    var pinnedItems: [ClipboardItem] {
        filteredItems.filter(\.isPinned)
    }

    var sections: [ClipboardSection] {
        let unpinned = filteredItems.filter { !$0.isPinned }
        let calendar = Calendar.current

        return [
            ClipboardSection(id: "pinned", title: "Pinned", items: pinnedItems),
            ClipboardSection(
                id: "today",
                title: "Today",
                items: unpinned.filter { calendar.isDateInToday($0.createdAt) }
            ),
            ClipboardSection(
                id: "yesterday",
                title: "Yesterday",
                items: unpinned.filter { calendar.isDateInYesterday($0.createdAt) }
            ),
            ClipboardSection(
                id: "earlier",
                title: "Earlier",
                items: unpinned.filter {
                    !calendar.isDateInToday($0.createdAt) && !calendar.isDateInYesterday($0.createdAt)
                }
            )
        ]
        .filter { !$0.items.isEmpty }
    }

    var itemCountDescription: String {
        "\(items.count) items"
    }

    var compactSearchShortcutDisplay: String {
        preferences.compactSearchShortcut.displayText
    }

    var clipboardShortcutDisplay: String {
        preferences.clipboardShortcut.displayText
    }

    var compactSearchShortcut: GlobalShortcut {
        preferences.compactSearchShortcut
    }

    var clipboardShortcut: GlobalShortcut {
        preferences.clipboardShortcut
    }

    var preferredClipboardWindowLayout: ClipboardWindowLayout {
        preferences.preferInlinePreview ? .inlinePreview : .compact
    }

    var selectedItemIndex: Int? {
        guard let selectedItemID else { return nil }
        return navigableItems.firstIndex { $0.id == selectedItemID }
    }

    func shortcutNumber(for item: ClipboardItem) -> Int? {
        guard let index = items.prefix(9).firstIndex(where: { $0.id == item.id }) else { return nil }
        return items.distance(from: items.startIndex, to: index) + 1
    }

    private var navigableItems: [ClipboardItem] {
        sections.flatMap(\.items)
    }

    func select(_ item: ClipboardItem) {
        withAnimation(.spring(response: 0.26, dampingFraction: 0.86)) {
            selectedItemID = item.id
        }

        Task { @MainActor in
            await loadPayloadForSelectedItemIfNeeded(item)
        }
    }

    func setPreferredClipboardWindowLayout(_ layout: ClipboardWindowLayout) {
        preferences.preferInlinePreview = layout == .inlinePreview
    }

    func setDisplayMode(_ displayMode: ClipboardDisplayMode) {
        guard self.displayMode != displayMode else { return }
        self.displayMode = displayMode
        preferences.clipboardDisplayMode = displayMode
    }

    func toggleDisplayMode() {
        setDisplayMode(displayMode == .list ? .board : .list)
    }

    func togglePin(_ item: ClipboardItem) {
        Task {
            do {
                try await database.togglePin(id: item.id)
                await reloadItems(preferredSelectionID: item.id)
            } catch {
                lastErrorMessage = error.localizedDescription
            }
        }
    }

    func toggleSelectedPin() {
        guard let selectedItem else { return }
        togglePin(selectedItem)
    }

    func delete(_ item: ClipboardItem) {
        Task {
            do {
                try await database.delete(id: item.id)
                await reloadItems(preferredSelectionID: selectedItemID == item.id ? nil : selectedItemID)
            } catch {
                lastErrorMessage = error.localizedDescription
            }
        }
    }

    func deleteSelectedItem() {
        guard let selectedItem else { return }
        delete(selectedItem)
    }

    func copyToPasteboard(_ item: ClipboardItem) {
        Task { @MainActor in
            do {
                let itemToCopy = try await itemWithPayloadIfNeeded(item)
                writeToPasteboard(itemToCopy)
            } catch {
                lastErrorMessage = error.localizedDescription
            }
        }
    }

    private func writeToPasteboard(_ item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        if item.type == .image, let payloadData = item.payloadData, let image = NSImage(data: payloadData) {
            pasteboard.writeObjects([image])
        } else {
            pasteboard.setString(item.content, forType: .string)
        }

        pasteboardMonitor.markSelfCopy(
            type: item.type,
            content: item.content,
            payloadData: item.payloadData
        )
    }

    func copyStringToPasteboard(_ value: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(value, forType: .string)

        pasteboardMonitor.markSelfCopy(type: .text, content: value, payloadData: nil)
    }

    @discardableResult
    func copySelectedToPasteboard() -> ClipboardItem? {
        guard let selectedItem else { return nil }
        copyToPasteboard(selectedItem)
        return selectedItem
    }

    @discardableResult
    func copyRecentItemToPasteboard(number: Int) -> ClipboardItem? {
        guard (1...9).contains(number), items.indices.contains(number - 1) else { return nil }

        let item = items[number - 1]
        select(item)
        copyToPasteboard(item)
        return item
    }

    func selectNextItem() {
        let items = navigableItems
        guard !items.isEmpty else { return }

        let nextIndex: Int
        if let selectedItemIndex {
            nextIndex = min(selectedItemIndex + 1, items.count - 1)
        } else {
            nextIndex = 0
        }

        select(items[nextIndex])
    }

    func selectPreviousItem() {
        let items = navigableItems
        guard !items.isEmpty else { return }

        let previousIndex: Int
        if let selectedItemIndex {
            previousIndex = max(selectedItemIndex - 1, 0)
        } else {
            previousIndex = 0
        }

        select(items[previousIndex])
    }

    func confirmAndClearHistory() {
        // Defer until the menu bar menu has finished dismissing before presenting AppKit UI.
        DispatchQueue.main.async { [weak self] in
            self?.presentClearHistoryConfirmation()
        }
    }

    func clearHistory(keepingPinned: Bool) {
        Task {
            do {
                try await database.clearHistory(keepingPinned: keepingPinned)
                await reloadItems(preferredSelectionID: selectedItemID)
            } catch {
                lastErrorMessage = error.localizedDescription
            }
        }
    }

    func seedDemoData() {
        Task {
            do {
                try await database.clearHistory(keepingPinned: false)

                for item in MockClipboardData.items() {
                    let capture = ClipboardCapture(
                        type: item.type,
                        title: item.title,
                        subtitle: item.subtitle,
                        preview: item.preview,
                        content: item.content,
                        payloadData: item.payloadData,
                        sourceApp: item.sourceApp,
                        createdAt: item.createdAt
                    )
                    _ = try await database.upsertCapture(capture)
                }

                try await pruneHistory()
                await reloadItems()
            } catch {
                lastErrorMessage = error.localizedDescription
            }
        }
    }

    func suggestions(for query: String) -> [ClipboardItem] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = items.sorted {
            if $0.isPinned != $1.isPinned {
                return $0.isPinned && !$1.isPinned
            }
            return $0.createdAt > $1.createdAt
        }

        guard !trimmedQuery.isEmpty else {
            return Array(source.prefix(3))
        }

        return Array(source.filter { item in
            item.title.localizedCaseInsensitiveContains(trimmedQuery)
                || item.preview.localizedCaseInsensitiveContains(trimmedQuery)
                || item.sourceApp.localizedCaseInsensitiveContains(trimmedQuery)
        }.prefix(4))
    }

    private func storeCapture(_ capture: ClipboardCapture) async {
        do {
            let item = try await database.upsertCapture(capture)
            try await pruneHistory()
            await reloadItems(preferredSelectionID: item.id)
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func pruneHistory() async throws {
        try await database.prune(
            maxItems: min(preferences.maxItems, preferences.historyLimit),
            retentionCutoff: preferences.retentionCutoffDate,
            keepingPinned: preferences.keepPinnedWhenClearing
        )
    }

    private func presentClearHistoryConfirmation() {
        guard !items.isEmpty else { return }

        let pinnedCount = items.lazy.filter(\.isPinned).count
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Clear Clipboard History?"
        NSApp.activate(ignoringOtherApps: true)

        if pinnedCount > 0 {
            alert.informativeText = pinnedCount == 1
                ? "There is 1 pinned item. Do you want to keep it or delete it too?"
                : "There are \(pinnedCount) pinned items. Do you want to keep them or delete them too?"

            alert.addButton(withTitle: "Keep Pinned")
            let deleteAllButton = alert.addButton(withTitle: "Delete All")
            deleteAllButton.hasDestructiveAction = true
            alert.addButton(withTitle: "Cancel")

            switch alert.runModal() {
            case .alertFirstButtonReturn:
                clearHistory(keepingPinned: true)
            case .alertSecondButtonReturn:
                clearHistory(keepingPinned: false)
            default:
                break
            }
        } else {
            alert.informativeText = "This will permanently remove all clipboard items."
            let clearButton = alert.addButton(withTitle: "Clear History")
            clearButton.hasDestructiveAction = true
            alert.addButton(withTitle: "Cancel")

            if alert.runModal() == .alertFirstButtonReturn {
                clearHistory(keepingPinned: false)
            }
        }
    }

    private func applyHistoryPolicy() async {
        do {
            try await pruneHistory()
            await reloadItems(preferredSelectionID: selectedItemID)
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func reloadItems(preferredSelectionID: ClipboardItem.ID? = nil) async {
        do {
            let loadedItems = try await database.fetchItems()

            withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                items = loadedItems

                if let preferredSelectionID, loadedItems.contains(where: { $0.id == preferredSelectionID }) {
                    selectedItemID = preferredSelectionID
                } else if let selectedItemID, loadedItems.contains(where: { $0.id == selectedItemID }) {
                    self.selectedItemID = selectedItemID
                } else {
                    selectedItemID = loadedItems.first?.id
                }
            }
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func loadPayloadForSelectedItemIfNeeded(_ item: ClipboardItem) async {
        do {
            let loadedItem = try await itemWithPayloadIfNeeded(item)
            guard selectedItemID == item.id else { return }
            replaceLoadedPayloadItem(loadedItem)
        } catch {
            guard selectedItemID == item.id else { return }
            lastErrorMessage = error.localizedDescription
        }
    }

    private func itemWithPayloadIfNeeded(_ item: ClipboardItem) async throws -> ClipboardItem {
        guard item.type == .image, item.payloadData == nil else { return item }
        return try await database.fetchItem(id: item.id)
    }

    private func replaceLoadedPayloadItem(_ loadedItem: ClipboardItem) {
        guard loadedItem.payloadData != nil else {
            releaseLoadedPayloads(except: loadedItem.id)
            return
        }

        items = items.map { item in
            if item.id == loadedItem.id {
                return loadedItem
            }

            var lightweightItem = item
            lightweightItem.payloadData = nil
            return lightweightItem
        }
    }

    private func releaseLoadedPayloads(except retainedItemID: ClipboardItem.ID? = nil) {
        items = items.map { item in
            guard item.id != retainedItemID, item.payloadData != nil else { return item }

            var lightweightItem = item
            lightweightItem.payloadData = nil
            return lightweightItem
        }
    }
}
