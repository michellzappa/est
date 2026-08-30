import SwiftUI
import Observation

/// User-facing look settings, persisted in UserDefaults. Card tint colors
/// flow through the active theme (`Card.Tint.color` delegates here), so a
/// theme change restyles cards, confetti, the title, and the progress bar
/// at once.
@Observable
final class Appearance {
    static let shared = Appearance()

    enum FillStyle: Int, CaseIterable {
        case shaded, pinstriped

        var name: String {
            switch self {
            case .shaded: "Shaded"
            case .pinstriped: "Pinstriped"
            }
        }
    }

    enum Theme: Int, CaseIterable {
        case primary, orchard, dusk, supporter

        var name: String {
            switch self {
            case .primary: "Primary"
            case .orchard: "Orchard"
            case .dusk: "Dusk"
            case .supporter: "Supporter"
            }
        }

        func color(for tint: Card.Tint) -> Color {
            switch (self, tint) {
            case (.primary, .red): Color(red: 0.87, green: 0.32, blue: 0.28)
            case (.primary, .blue): Color(red: 0.24, green: 0.43, blue: 0.92)
            case (.primary, .yellow): Color(red: 0.94, green: 0.66, blue: 0.20)
            case (.orchard, .red): Color(red: 0.55, green: 0.33, blue: 0.83)
            case (.orchard, .blue): Color(red: 0.13, green: 0.62, blue: 0.39)
            case (.orchard, .yellow): Color(red: 0.93, green: 0.47, blue: 0.15)
            case (.dusk, .red): Color(red: 0.87, green: 0.33, blue: 0.46)
            case (.dusk, .blue): Color(red: 0.12, green: 0.55, blue: 0.58)
            case (.dusk, .yellow): Color(red: 0.82, green: 0.60, blue: 0.16)
            case (.supporter, .red): Color(red: 0.78, green: 0.27, blue: 0.28)
            case (.supporter, .blue): Color(red: 0.16, green: 0.43, blue: 0.58)
            case (.supporter, .yellow): Color(red: 0.82, green: 0.55, blue: 0.18)
            }
        }

        func highlight(for tint: Card.Tint) -> Color {
            switch (self, tint) {
            case (.primary, .red): Color(red: 0.96, green: 0.47, blue: 0.41)
            case (.primary, .blue): Color(red: 0.44, green: 0.60, blue: 0.98)
            case (.primary, .yellow): Color(red: 0.99, green: 0.79, blue: 0.38)
            case (.orchard, .red): Color(red: 0.68, green: 0.48, blue: 0.93)
            case (.orchard, .blue): Color(red: 0.30, green: 0.76, blue: 0.53)
            case (.orchard, .yellow): Color(red: 0.98, green: 0.62, blue: 0.31)
            case (.dusk, .red): Color(red: 0.96, green: 0.50, blue: 0.61)
            case (.dusk, .blue): Color(red: 0.29, green: 0.70, blue: 0.73)
            case (.dusk, .yellow): Color(red: 0.93, green: 0.74, blue: 0.34)
            case (.supporter, .red): Color(red: 0.93, green: 0.43, blue: 0.40)
            case (.supporter, .blue): Color(red: 0.36, green: 0.63, blue: 0.76)
            case (.supporter, .yellow): Color(red: 0.96, green: 0.74, blue: 0.34)
            }
        }

        /// Soft semantic accents are for feedback, never for card identity.
        /// They stay readable beside the themed card tints without using the
        /// saturated system `Color.green`/`Color.red` defaults.
        var successColor: Color {
            switch self {
            case .primary: Color(red: 0.28, green: 0.64, blue: 0.40)
            case .orchard: Color(red: 0.30, green: 0.66, blue: 0.45)
            case .dusk: Color(red: 0.34, green: 0.70, blue: 0.64)
            case .supporter: Color(red: 0.30, green: 0.62, blue: 0.55)
            }
        }

        /// The fourth player's identity accent. It is deliberately separate
        /// from `successColor`: that color is reserved for game feedback,
        /// while this one must remain distinct from the three card tints.
        var fourthPlayerColor: Color {
            switch self {
            case .primary: Color(red: 0.61, green: 0.34, blue: 0.78)
            case .orchard: Color(red: 0.82, green: 0.28, blue: 0.48)
            case .dusk: Color(red: 0.61, green: 0.38, blue: 0.80)
            case .supporter: Color(red: 0.61, green: 0.34, blue: 0.60)
            }
        }

        var errorColor: Color {
            switch self {
            case .primary: Color(red: 0.78, green: 0.36, blue: 0.34)
            case .orchard: Color(red: 0.78, green: 0.39, blue: 0.43)
            case .dusk: Color(red: 0.80, green: 0.40, blue: 0.49)
            case .supporter: Color(red: 0.72, green: 0.31, blue: 0.32)
            }
        }

        /// The supporter finish adds a warm paper-and-metal feel without
        /// changing card identity or giving its owner a gameplay advantage.
        var cardSurface: Color {
            switch self {
            case .supporter: Color(red: 0.96, green: 0.94, blue: 0.88)
            default: Color(.secondarySystemGroupedBackground)
            }
        }

        var cardBorder: Color {
            switch self {
            case .supporter: Color(red: 0.68, green: 0.47, blue: 0.16).opacity(0.55)
            default: Color.primary.opacity(0.12)
            }
        }
    }

    var fillStyle: FillStyle {
        didSet { UserDefaults.standard.set(fillStyle.rawValue, forKey: "appearance.fillStyle") }
    }

    var theme: Theme {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: "appearance.theme") }
    }

    /// Player identity follows the card palette so a theme changes both in
    /// lockstep. The fourth slot uses the theme's implicit fourth player hue.
    func playerColor(for slot: Int) -> Color {
        switch slot {
        case 0: Card.Tint.red.color
        case 1: Card.Tint.blue.color
        case 2: Card.Tint.yellow.color
        default: theme.fourthPlayerColor
        }
    }

    /// Use these for UI feedback, not for card or player identity.
    var successColor: Color { theme.successColor }
    var errorColor: Color { theme.errorColor }

    /// The supporter finish is a small, global surface treatment so the
    /// cosmetic feels coherent across the title, tutorial, and game boards.
    var gameBackground: Color {
        switch theme {
        case .supporter: Color(red: 0.93, green: 0.91, blue: 0.85)
        default: Color(.systemGroupedBackground)
        }
    }

    private init() {
        // New installs get pinstriped. An explicit choice still wins, so a
        // player who picked shaded keeps it.
        let storedFill = UserDefaults.standard.object(forKey: "appearance.fillStyle") as? Int
        fillStyle = storedFill.flatMap(FillStyle.init(rawValue:)) ?? .pinstriped
        theme = Theme(rawValue: UserDefaults.standard.integer(forKey: "appearance.theme")) ?? .primary
    }
}
