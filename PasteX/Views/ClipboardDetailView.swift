import AppKit
import Carbon.HIToolbox
import SwiftUI

struct ClipboardDetailView: View {
    @ObservedObject var viewModel: ClipboardViewModel
    var isEmbedded = false
    @State private var copied = false

    var body: some View {
        detailBody
            .background {
                if !isEmbedded {
                    DetailKeyboardMonitor { event in
                        handleKeyDown(event)
                    }
                }
            }
            .onAppear {
                if !isEmbedded {
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
    }

    @ViewBuilder
    private var detailBody: some View {
        Group {
            if let item = viewModel.selectedItem {
                content(for: item)
            } else {
                emptyState
            }
        }
        .modifier(DetailChromeModifier(isEmbedded: isEmbedded))
    }

    private struct DetailChromeModifier: ViewModifier {
        var isEmbedded: Bool

        func body(content: Content) -> some View {
            if isEmbedded {
                content
                    .background(Color.clear)
            } else {
                content
                    .glassPanel(cornerRadius: 20, material: .regularMaterial)
                    .overlay(alignment: .topLeading) {
                        WindowCloseButton()
                            .padding(.top, 16)
                            .padding(.leading, 18)
                    }
                    .ignoresSafeArea()
            }
        }
    }

    private func content(for item: ClipboardItem) -> some View {
        VStack(spacing: 0) {
            header(for: item)

            Divider()
                .opacity(0.58)

            let quickActions = quickActions(for: item)
            if !quickActions.isEmpty {
                QuickActionStrip(actions: quickActions)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)

                Divider()
                    .opacity(0.45)
            }

            previewArea(for: item)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(22)

            Divider()
                .opacity(0.58)

            footer(for: item)
        }
    }

    private func header(for item: ClipboardItem) -> some View {
        HStack(spacing: 12) {
            IconBadge(type: item.type, size: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.type.displayName)
                    .font(.system(size: 15, weight: .semibold))

                Text(item.dateTimeString)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                viewModel.togglePin(item)
            } label: {
                Image(systemName: item.isPinned ? "pin.fill" : "pin")
            }
            .help(item.isPinned ? "Unpin item" : "Pin item")

            Menu {
                Button("Copy") {
                    copy(item)
                }
                Button(item.isPinned ? "Unpin" : "Pin") {
                    viewModel.togglePin(item)
                }
                Divider()
                Button("Delete", role: .destructive) {
                    viewModel.delete(item)
                }
            } label: {
                Image(systemName: "ellipsis")
            }
            .menuStyle(.button)
            .menuIndicator(.hidden)
            .help("More")
        }
        .buttonStyle(.borderless)
        .font(.system(size: 16, weight: .medium))
        .padding(.leading, isEmbedded ? 22 : 46)
        .padding(.trailing, 22)
        .frame(height: 78)
    }

    @ViewBuilder
    private func previewArea(for item: ClipboardItem) -> some View {
        switch item.type {
        case .code:
            CodePreview(text: item.content)
        case .json:
            CodePreview(text: formattedJSON(from: item.content) ?? item.content, languageLabel: "JSON")
        case .url:
            URLPreview(item: item)
        case .image:
            ImagePreview(item: item)
        case .color:
            ColorPreview(item: item, copyValue: copyString)
        case .email:
            PlainTextPreview(text: item.content, title: item.title, copyValue: copyString)
        case .file:
            PlainTextPreview(text: item.content, title: item.title, copyValue: copyString)
        case .text:
            PlainTextPreview(text: item.content, title: item.title, copyValue: copyString)
        }
    }

    private func footer(for item: ClipboardItem) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                Text("Source")
                    .font(.system(size: 13, weight: .semibold))

                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 6, height: 6)

                    Text(item.sourceApp)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                copy(item)
            } label: {
                Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                    .labelStyle(.iconOnly)
                    .frame(width: 34, height: 28)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .help("Copy item")

            KeyboardShortcutBadge("↩")
        }
        .padding(.horizontal, 22)
        .frame(height: 90)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            AppIconMark(size: 54)
            Text("Select an item")
                .font(.system(size: 17, weight: .semibold))
            Text("The preview panel updates as you move through clipboard history.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func copy(_ item: ClipboardItem) {
        viewModel.copyToPasteboard(item)
        showCopiedState()
    }

    private func copyString(_ value: String) {
        viewModel.copyStringToPasteboard(value)
        showCopiedState()
    }

    private func showCopiedState() {
        withAnimation(.spring(response: 0.22, dampingFraction: 0.8)) {
            copied = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeInOut(duration: 0.18)) {
                copied = false
            }
        }
    }

    private func quickActions(for item: ClipboardItem) -> [DetailQuickAction] {
        switch item.type {
        case .url:
            guard let url = normalizedURL(from: item.content) else { return [] }
            return [
                DetailQuickAction(id: "open-url", title: "Open URL", symbolName: "arrow.up.forward.app") {
                    NSWorkspace.shared.open(url)
                },
                DetailQuickAction(id: "copy-url", title: "Copy URL", symbolName: "link") {
                    copyString(url.absoluteString)
                }
            ]
        case .color:
            guard let color = SmartClipboardDetector.primaryColorCandidate(in: item.content) else { return [] }
            var actions = [
                DetailQuickAction(id: "copy-hex", title: "Copy HEX", symbolName: "number") {
                    copyString(color.hexRGB)
                },
                DetailQuickAction(id: "copy-rgb", title: "Copy RGB", symbolName: "slider.horizontal.3") {
                    copyString(color.rgbString)
                }
            ]

            if color.alpha < 1 {
                actions.append(
                    DetailQuickAction(id: "copy-rgba", title: "Copy RGBA", symbolName: "circle.lefthalf.filled") {
                        copyString(color.rgbaString)
                    }
                )
            }

            return actions
        case .json:
            guard let formattedJSON = formattedJSON(from: item.content) else { return [] }
            return [
                DetailQuickAction(id: "copy-formatted-json", title: "Format JSON", symbolName: "curlybraces") {
                    copyString(formattedJSON)
                }
            ]
        case .email:
            let parts = emailParts(from: item.content)
            var actions: [DetailQuickAction] = []

            if let subject = parts.subject {
                actions.append(
                    DetailQuickAction(id: "copy-subject", title: "Copy Subject", symbolName: "text.quote") {
                        copyString(subject)
                    }
                )
            }

            if let body = parts.body {
                actions.append(
                    DetailQuickAction(id: "copy-body", title: "Copy Body", symbolName: "doc.text") {
                        copyString(body)
                    }
                )
            }

            return actions
        case .code, .image, .file, .text:
            return []
        }
    }

    private func normalizedURL(from text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if let url = URL(string: trimmed), url.scheme != nil {
            return url
        }

        return URL(string: "https://\(trimmed)")
    }

    private func formattedJSON(from text: String) -> String? {
        guard
            let data = text.data(using: .utf8),
            let object = try? JSONSerialization.jsonObject(with: data),
            JSONSerialization.isValidJSONObject(object),
            let formattedData = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
            let formatted = String(data: formattedData, encoding: .utf8)
        else {
            return nil
        }

        return formatted
    }

    private func emailParts(from text: String) -> (subject: String?, body: String?) {
        let lines = text.components(separatedBy: .newlines)
        let subjectLine = lines.first { line in
            line.range(of: #"^\s*subject\s*:"#, options: [.regularExpression, .caseInsensitive]) != nil
        }

        let subject = subjectLine?
            .replacingOccurrences(of: #"^\s*subject\s*:\s*"#, with: "", options: [.regularExpression, .caseInsensitive])
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty

        let bodyLines = lines.filter { line in
            line.range(of: #"^\s*subject\s*:"#, options: [.regularExpression, .caseInsensitive]) == nil
        }
        let body = bodyLines.joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty

        return (subject, body)
    }

    private func handleKeyDown(_ event: NSEvent) -> Bool {
        switch Int(event.keyCode) {
        case kVK_Escape:
            event.window?.close()
            return true
        case kVK_Return, kVK_ANSI_KeypadEnter:
            if let item = viewModel.selectedItem {
                copy(item)
            }
            return true
        default:
            return false
        }
    }
}

private struct DetailQuickAction: Identifiable {
    let id: String
    let title: String
    let symbolName: String
    let action: () -> Void
}

private struct QuickActionStrip: View {
    var actions: [DetailQuickAction]
    @State private var copiedActionID: String?

    var body: some View {
        HStack(spacing: 8) {
            ForEach(actions) { action in
                Button {
                    action.action()
                    markCopied(action.id)
                } label: {
                    Label(copiedActionID == action.id ? "Done" : action.title, systemImage: copiedActionID == action.id ? "checkmark" : action.symbolName)
                        .font(.system(size: 12, weight: .semibold))
                        .labelStyle(.titleAndIcon)
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                }
                .buttonStyle(.plain)
                .background(.primary.opacity(0.045), in: Capsule())
                .help(action.title)
            }

            Spacer(minLength: 0)
        }
    }

    private func markCopied(_ id: String) {
        withAnimation(.spring(response: 0.22, dampingFraction: 0.84)) {
            copiedActionID = id
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            withAnimation(.easeInOut(duration: 0.16)) {
                if copiedActionID == id {
                    copiedActionID = nil
                }
            }
        }
    }
}

private struct DetailKeyboardMonitor: NSViewRepresentable {
    var handle: (NSEvent) -> Bool

    func makeNSView(context: Context) -> MonitorView {
        let view = MonitorView()
        view.handle = handle
        return view
    }

    func updateNSView(_ nsView: MonitorView, context: Context) {
        nsView.handle = handle
    }

    final class MonitorView: NSView {
        var handle: ((NSEvent) -> Bool)?
        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            installMonitorIfNeeded()
        }

        deinit {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }

        private func installMonitorIfNeeded() {
            guard monitor == nil else { return }

            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard
                    let self,
                    let window,
                    event.window === window,
                    window.isKeyWindow
                else {
                    return event
                }

                return self.handle?(event) == true ? nil : event
            }
        }
    }
}

private struct CodePreview: View {
    var text: String
    var languageLabel = "TS"

    private var highlightedText: AttributedString {
        SyntaxHighlighter.highlight(
            text,
            language: languageLabel.caseInsensitiveCompare("JSON") == .orderedSame ? .json : .code
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(languageLabel)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)

                Spacer()

                Image(systemName: "curlybraces")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .frame(height: 34)

            Divider()
                .opacity(0.55)

            ScrollView {
                Text(highlightedText)
                    .font(.system(size: 13.5, weight: .regular, design: .monospaced))
                    .lineSpacing(5)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }
        }
        .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.primary.opacity(0.07), lineWidth: 1)
        }
    }
}

private enum SyntaxHighlighter {
    enum Language {
        case code
        case json
    }

    private static let keywords: Set<String> = [
        "actor", "as", "async", "await", "break", "case", "catch", "class", "const", "continue",
        "default", "defer", "do", "else", "enum", "export", "extension", "false", "final",
        "for", "func", "function", "guard", "if", "import", "in", "interface", "let", "nil",
        "private", "protocol", "public", "return", "self", "static", "struct", "switch",
        "throws", "true", "try", "type", "typealias", "var", "while"
    ]

    private static let jsonLiterals: Set<String> = ["true", "false", "null"]

    static func highlight(_ source: String, language: Language) -> AttributedString {
        var result = AttributedString()
        var index = source.startIndex

        while index < source.endIndex {
            let character = source[index]

            if language == .code, character == "/", let next = Self.character(after: index, in: source) {
                if next == "/" {
                    append(comment(from: index, in: source, index: &index), color: Palette.comment, to: &result)
                    continue
                }

                if next == "*" {
                    append(blockComment(from: index, in: source, index: &index), color: Palette.comment, to: &result)
                    continue
                }
            }

            if isQuote(character) {
                let token = quotedString(from: index, in: source, index: &index)
                let color = language == .json && isJSONKey(after: index, in: source) ? Palette.jsonKey : Palette.string
                append(token, color: color, to: &result)
                continue
            }

            if isNumberStart(character, at: index, in: source) {
                append(number(from: index, in: source, index: &index), color: Palette.number, to: &result)
                continue
            }

            if isIdentifierStart(character) {
                let identifier = identifier(from: index, in: source, index: &index)
                append(identifier, color: color(for: identifier, language: language), to: &result)
                continue
            }

            if isSymbol(character) {
                append(String(character), color: Palette.symbol, to: &result)
            } else {
                append(String(character), color: Palette.plain, to: &result)
            }

            index = source.index(after: index)
        }

        return result
    }

    private static func append(_ string: String, color: Color, to result: inout AttributedString) {
        var segment = AttributedString(string)
        segment.foregroundColor = color
        result.append(segment)
    }

    private static func comment(from start: String.Index, in source: String, index: inout String.Index) -> String {
        index = source.index(start, offsetBy: 2, limitedBy: source.endIndex) ?? source.endIndex

        while index < source.endIndex, !source[index].isNewline {
            index = source.index(after: index)
        }

        return String(source[start..<index])
    }

    private static func blockComment(from start: String.Index, in source: String, index: inout String.Index) -> String {
        index = source.index(start, offsetBy: 2, limitedBy: source.endIndex) ?? source.endIndex

        while index < source.endIndex {
            if source[index] == "*", character(after: index, in: source) == "/" {
                index = source.index(after: source.index(after: index))
                break
            }

            index = source.index(after: index)
        }

        return String(source[start..<index])
    }

    private static func quotedString(from start: String.Index, in source: String, index: inout String.Index) -> String {
        let quote = source[start]
        index = source.index(after: start)
        var isEscaped = false

        while index < source.endIndex {
            let character = source[index]
            index = source.index(after: index)

            if isEscaped {
                isEscaped = false
                continue
            }

            if character == "\\" {
                isEscaped = true
            } else if character == quote {
                break
            }
        }

        return String(source[start..<index])
    }

    private static func number(from start: String.Index, in source: String, index: inout String.Index) -> String {
        index = source.index(after: start)

        while index < source.endIndex, isNumberContinuation(source[index]) {
            index = source.index(after: index)
        }

        return String(source[start..<index])
    }

    private static func identifier(from start: String.Index, in source: String, index: inout String.Index) -> String {
        index = source.index(after: start)

        while index < source.endIndex, isIdentifierContinuation(source[index]) {
            index = source.index(after: index)
        }

        return String(source[start..<index])
    }

    private static func color(for identifier: String, language: Language) -> Color {
        if language == .json, jsonLiterals.contains(identifier) {
            return Palette.keyword
        }

        if identifier.hasPrefix("@") {
            return Palette.attribute
        }

        if keywords.contains(identifier) {
            return Palette.keyword
        }

        if startsWithUppercase(identifier) {
            return Palette.type
        }

        return Palette.plain
    }

    private static func character(after index: String.Index, in source: String) -> Character? {
        let nextIndex = source.index(after: index)
        return nextIndex < source.endIndex ? source[nextIndex] : nil
    }

    private static func isJSONKey(after index: String.Index, in source: String) -> Bool {
        var cursor = index

        while cursor < source.endIndex {
            let character = source[cursor]

            if character.isWhitespace {
                cursor = source.index(after: cursor)
                continue
            }

            return character == ":"
        }

        return false
    }

    private static func isQuote(_ character: Character) -> Bool {
        character == "\"" || character == "'" || character == "`"
    }

    private static func isNumberStart(_ character: Character, at index: String.Index, in source: String) -> Bool {
        character.isNumber || (character == "-" && Self.character(after: index, in: source)?.isNumber == true)
    }

    private static func isNumberContinuation(_ character: Character) -> Bool {
        character.isNumber || character == "." || character == "_" || character == "x" || character == "X"
            || character == "e" || character == "E" || character == "-" || character == "+"
            || ("abcdefABCDEF").contains(character)
    }

    private static func isIdentifierStart(_ character: Character) -> Bool {
        character.isLetter || character == "_" || character == "$" || character == "@"
    }

    private static func isIdentifierContinuation(_ character: Character) -> Bool {
        isIdentifierStart(character) || character.isNumber
    }

    private static func isSymbol(_ character: Character) -> Bool {
        "{}[]().,:;<>+-=*/!&|?".contains(character)
    }

    private static func startsWithUppercase(_ identifier: String) -> Bool {
        guard let scalar = identifier.first?.unicodeScalars.first else { return false }
        return CharacterSet.uppercaseLetters.contains(scalar)
    }

    private enum Palette {
        static let plain = Color.primary.opacity(0.9)
        static let keyword = Color(red: 0.72, green: 0.28, blue: 0.80)
        static let string = Color(red: 0.22, green: 0.55, blue: 0.34)
        static let number = Color(red: 0.84, green: 0.42, blue: 0.16)
        static let comment = Color.secondary.opacity(0.76)
        static let type = Color(red: 0.18, green: 0.44, blue: 0.82)
        static let attribute = Color(red: 0.88, green: 0.48, blue: 0.20)
        static let jsonKey = Color(red: 0.24, green: 0.45, blue: 0.88)
        static let symbol = Color.secondary.opacity(0.86)
    }
}

private struct PlainTextPreview: View {
    var text: String
    var title: String
    var copyValue: (String) -> Void
    private var utilities: [SmartClipboardUtility] {
        SmartClipboardDetector.detectUtilities(in: text)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)

                if !utilities.isEmpty {
                    SmartUtilityPanel(utilities: utilities, copyValue: copyValue)
                }

                Text(text)
                    .font(.system(size: 15))
                    .lineSpacing(6)
                    .foregroundStyle(.primary.opacity(0.88))
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
        }
        .background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.primary.opacity(0.06), lineWidth: 1)
        }
    }
}

private struct ColorPreview: View {
    var item: ClipboardItem
    var copyValue: (String) -> Void
    @State private var copiedValue: String?

    private var colors: [SmartColor] {
        SmartClipboardDetector.detectColors(in: item.content)
    }

    private var primaryColor: SmartColor? {
        colors.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let primaryColor {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(primaryColor.color)
                    .overlay(alignment: .bottomLeading) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(primaryColor.hexRGB)
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                            Text(primaryColor.source)
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .opacity(0.82)
                        }
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.38), radius: 7, x: 0, y: 2)
                        .padding(20)
                    }
                    .frame(height: 176)

                VStack(spacing: 8) {
                    ColorValueRow(label: "HEX", value: primaryColor.hexRGB, copiedValue: $copiedValue, copyValue: copyValue)

                    if primaryColor.alpha < 1 {
                        ColorValueRow(label: "HEXA", value: primaryColor.hexRGBA, copiedValue: $copiedValue, copyValue: copyValue)
                    }

                    ColorValueRow(label: "RGB", value: primaryColor.rgbString, copiedValue: $copiedValue, copyValue: copyValue)
                    ColorValueRow(label: "RGBA", value: primaryColor.rgbaString, copiedValue: $copiedValue, copyValue: copyValue)
                }

                if colors.count > 1 {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Detected colors")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 10)], spacing: 10) {
                            ForEach(colors.prefix(8)) { color in
                                Button {
                                    copy(color.hexRGB)
                                } label: {
                                    HStack(spacing: 7) {
                                        Circle()
                                            .fill(color.color)
                                            .frame(width: 14, height: 14)

                                        Text(color.hexRGB)
                                            .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                                            .lineLimit(1)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                Spacer(minLength: 0)
            } else {
                PlainTextPreview(text: item.content, title: item.title, copyValue: copyValue)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func copy(_ value: String) {
        copyValue(value)

        withAnimation(.spring(response: 0.22, dampingFraction: 0.82)) {
            copiedValue = value
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            withAnimation(.easeInOut(duration: 0.16)) {
                copiedValue = nil
            }
        }
    }
}

private struct ColorValueRow: View {
    var label: String
    var value: String
    @Binding var copiedValue: String?
    var copyValue: (String) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .leading)

            Text(value)
                .font(.system(size: 13.5, weight: .medium, design: .monospaced))
                .textSelection(.enabled)

            Spacer()

            Button {
                copy(value)
            } label: {
                Image(systemName: copiedValue == value ? "checkmark" : "doc.on.doc")
                    .frame(width: 26, height: 24)
            }
            .buttonStyle(.borderless)
            .help("Copy \(label)")
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func copy(_ value: String) {
        copyValue(value)

        withAnimation(.spring(response: 0.22, dampingFraction: 0.82)) {
            copiedValue = value
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            withAnimation(.easeInOut(duration: 0.16)) {
                copiedValue = nil
            }
        }
    }
}

private struct SmartUtilityPanel: View {
    var utilities: [SmartClipboardUtility]
    var copyValue: (String) -> Void
    @State private var copiedValue: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Smart utilities")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            ForEach(utilities) { utility in
                Button {
                    copy(utility.value)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: utility.symbolName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 18)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(utility.title)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.primary)

                            Text(utility.value)
                                .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }

                        Spacer()

                        Text(copiedValue == utility.value ? "Copied" : utility.detail)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func copy(_ value: String) {
        copyValue(value)

        withAnimation(.spring(response: 0.22, dampingFraction: 0.82)) {
            copiedValue = value
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            withAnimation(.easeInOut(duration: 0.16)) {
                copiedValue = nil
            }
        }
    }
}

private struct URLPreview: View {
    var item: ClipboardItem

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.20, green: 0.42, blue: 0.84),
                                Color(red: 0.20, green: 0.62, blue: 0.72)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Image(systemName: "safari")
                    .font(.system(size: 44, weight: .regular))
                    .foregroundStyle(.white.opacity(0.92))
            }
            .frame(height: 150)

            VStack(alignment: .leading, spacing: 7) {
                Text(item.subtitle ?? "Web Link")
                    .font(.system(size: 18, weight: .semibold))

                Text(item.content)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .textSelection(.enabled)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct ImagePreview: View {
    var item: ClipboardItem

    var body: some View {
        VStack(spacing: 14) {
            if let data = item.payloadData, let image = NSImage(data: data) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(.primary.opacity(0.08), lineWidth: 1)
                    }
            } else {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.10, green: 0.24, blue: 0.46),
                                Color(red: 0.18, green: 0.55, blue: 0.52),
                                Color(red: 0.92, green: 0.70, blue: 0.42)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(alignment: .bottomLeading) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(item.title)
                                .font(.system(size: 18, weight: .semibold))
                            Text(item.subtitle ?? "Image")
                                .font(.system(size: 13))
                                .opacity(0.82)
                        }
                        .foregroundStyle(.white)
                        .padding(18)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    }
            }
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

#Preview {
    ClipboardDetailView(viewModel: ClipboardViewModel(preferences: PreferencesViewModel()))
        .frame(width: 460, height: 560)
}
