import SwiftUI

struct GlassPanel<Content: View>: View {
    var cornerRadius: CGFloat = 24
    var material: Material = .regularMaterial
    @ViewBuilder var content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content
            .background(material, in: shape)
            .clipShape(shape)
            .contentShape(shape)
    }
}

extension View {
    func glassPanel(cornerRadius: CGFloat = 24, material: Material = .regularMaterial) -> some View {
        GlassPanel(cornerRadius: cornerRadius, material: material) {
            self
        }
    }

    func subtleControlBackground(cornerRadius: CGFloat = 12) -> some View {
        background(.thinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.primary.opacity(0.08), lineWidth: 1)
            }
    }
}
