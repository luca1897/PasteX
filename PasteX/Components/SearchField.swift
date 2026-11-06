import SwiftUI

struct SearchField: View {
    @Binding var text: String
    var placeholder = "Search clipboard..."
    var shortcut: String? = "⌥⌘K"
    var autoFocus = false

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.secondary)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 16, weight: .regular))
                .focused($isFocused)

            if !text.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.14)) {
                        text = ""
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("Clear search")
            }

            if let shortcut {
                KeyboardShortcutBadge(shortcut)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
        .subtleControlBackground(cornerRadius: 12)
        .onAppear {
            guard autoFocus else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                isFocused = true
            }
        }
    }
}

#Preview {
    SearchField(text: .constant("Paste"))
        .padding()
        .frame(width: 420)
}
