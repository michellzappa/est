import SwiftUI

/// Liquid Glass surfaces on iOS 26, graceful material/color fallbacks below.
/// Deployment target is 17.0, so everything goes through availability checks.
extension View {
    @ViewBuilder
    func glassPanel(cornerRadius: CGFloat = 24) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            self.background(
                .regularMaterial,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
        }
    }

    /// Tinted, press-responsive glass for the buzz buttons.
    @ViewBuilder
    func glassButtonSurface(tint: Color, opacity: Double, cornerRadius: CGFloat = 16) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(
                .regular.tint(tint.opacity(opacity)).interactive(),
                in: .rect(cornerRadius: cornerRadius)
            )
        } else {
            self.background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(tint.opacity(opacity))
            )
        }
    }
}
