import SwiftUI

struct KeyboardShortcutBadge: View {
    private let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .frame(height: 22)
            .background(.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(.primary.opacity(0.06), lineWidth: 1)
            }
    }
}

#Preview {
    HStack {
        KeyboardShortcutBadge("⌥⌘K")
        KeyboardShortcutBadge("⇧⌘V")
        KeyboardShortcutBadge("↩")
    }
    .padding()
}
