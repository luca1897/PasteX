import SwiftUI

struct IconBadge: View {
    var type: ClipboardItemType
    var size: CGFloat = 42

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(type.tint.opacity(type == .text ? 0.05 : 0.16))

            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .stroke(.primary.opacity(0.09), lineWidth: 1)

            Image(systemName: type.symbolName)
                .font(.system(size: size * 0.43, weight: .medium))
                .foregroundStyle(type == .text ? .primary : type.tint)
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    HStack {
        ForEach(ClipboardItemType.allCases) { type in
            IconBadge(type: type)
        }
    }
    .padding()
}
