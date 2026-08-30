import SwiftUI

/// EST's one button vocabulary. Every control the player taps outside a Form
/// uses this style, so the game reads as a game and not as a settings screen.
///
/// The style guide, in three rules:
///
/// 1. **One primary per screen.** The filled, glowing button is the action the
///    screen exists for. Everything else is secondary or quiet.
/// 2. **Tints come from the card palette**, never from the system accent. Blue
///    is solo and go, yellow is the alternate or bonus path, red is a duel or
///    a way out. A theme change restyles the buttons with the cards.
/// 3. **A row is one size.** Buttons stretch to equal widths, so no row ever
///    tapers or wraps its label.
///
/// Do not use `.bordered` or `.borderedProminent` in the game UI. Settings is
/// a Form and keeps native list rows on purpose.
struct GameButtonStyle: ButtonStyle {
    enum Role {
        /// The action the screen wants. Filled with the tint gradient, lit
        /// with a glow of its own color.
        case primary
        /// A real alternative on the same screen. Glass surface, tinted label.
        case secondary
        /// Exits, back steps, and asides. No surface, no glow.
        case quiet
    }

    enum Size {
        case large, medium, compact
        /// A fixed square for a lone glyph, and a label-width button for
        /// asides. Neither stretches to fill its row.
        case icon, inline

        var height: CGFloat {
            switch self {
            case .large: 58
            case .medium: 50
            case .compact: 46
            case .icon: 46
            case .inline: 38
            }
        }

        var fontSize: CGFloat {
            switch self {
            case .large: 18
            case .medium: 16
            case .compact: 14
            case .icon: 16
            case .inline: 14
            }
        }
    }

    var role: Role = .secondary
    var tint: Card.Tint = .blue
    var size: Size = .medium

    func makeBody(configuration: Configuration) -> some View {
        Surface(configuration: configuration, role: role, tint: tint, size: size)
    }

    /// A ButtonStyle cannot read the environment, so the body lives in a view
    /// that can: a disabled button has to look disabled.
    private struct Surface: View {
        let configuration: Configuration
        let role: Role
        let tint: Card.Tint
        let size: Size

        @Environment(\.isEnabled) private var isEnabled
        @AppStorage("hapticsEnabled") private var hapticsEnabled = true

        private var cornerRadius: CGFloat { size.height * 0.32 }
        private var shape: RoundedRectangle {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        }

        var body: some View {
            let pressed = configuration.isPressed
            configuration.label
                .font(.system(size: size.fontSize, weight: .bold, design: .rounded))
                .foregroundStyle(labelColor)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .padding(.horizontal, size == .icon ? 0 : 14)
                .modifier(SizeModifier(size: size))
                .background(background)
                .overlay {
                    if role != .primary {
                        shape.strokeBorder(
                            tint.color.opacity(role == .secondary ? 0.40 : 0.16),
                            lineWidth: 1.5
                        )
                    }
                }
                .contentShape(shape)
                .shadow(
                    color: role == .primary ? tint.color.opacity(pressed ? 0.25 : 0.5) : .clear,
                    radius: pressed ? 5 : 12,
                    y: pressed ? 2 : 5
                )
                .scaleEffect(pressed ? 0.96 : 1)
                .opacity(isEnabled ? 1 : 0.35)
                .animation(.spring(duration: 0.22), value: pressed)
                .sensoryFeedback(
                    trigger: FeedbackTrigger(value: pressed, enabled: hapticsEnabled)
                ) { oldValue, newValue in
                    guard newValue.enabled, !oldValue.value, newValue.value else { return nil }
                    return .impact(flexibility: .soft, intensity: 0.4)
                }
        }

        @ViewBuilder
        private var background: some View {
            switch role {
            case .primary:
                shape.fill(tint.gradient)
            case .secondary:
                Color.clear.glassPanel(cornerRadius: cornerRadius)
            case .quiet:
                shape.fill(tint.color.opacity(0.08))
            }
        }

        private var labelColor: Color {
            switch role {
            case .primary: .white
            case .secondary: tint.color
            case .quiet: .secondary
            }
        }
    }

    /// Every size but `.icon` stretches, so buttons in a row end up equal.
    private struct SizeModifier: ViewModifier {
        let size: Size

        func body(content: Content) -> some View {
            switch size {
            case .icon:
                content.frame(width: size.height, height: size.height)
            case .inline:
                content.frame(height: size.height)
            default:
                content.frame(maxWidth: .infinity).frame(height: size.height)
            }
        }
    }
}

extension ButtonStyle where Self == GameButtonStyle {
    static func game(
        _ role: GameButtonStyle.Role = .secondary,
        tint: Card.Tint = .blue,
        size: GameButtonStyle.Size = .medium
    ) -> GameButtonStyle {
        GameButtonStyle(role: role, tint: tint, size: size)
    }
}

#Preview {
    VStack(spacing: 12) {
        Button("Solo 81") {}
            .buttonStyle(.game(.primary, tint: .blue, size: .large))
        HStack(spacing: 12) {
            Button("Quick 27") {}
                .buttonStyle(.game(.secondary, tint: .yellow, size: .large))
            Button("Duel") {}
                .buttonStyle(.game(.secondary, tint: .red, size: .large))
        }
        HStack(spacing: 12) {
            Button("Rules") {}
                .buttonStyle(.game(.quiet, size: .compact))
            Button("Leaderboard") {}
                .buttonStyle(.game(.quiet, size: .compact))
            Button {} label: { Image(systemName: "gearshape") }
                .buttonStyle(.game(.quiet, size: .icon))
        }
        Button("Disabled") {}
            .buttonStyle(.game(.primary, size: .medium))
            .disabled(true)
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
