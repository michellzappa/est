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
        case primary, orchard, dusk

        var name: String {
            switch self {
            case .primary: "Primary"
            case .orchard: "Orchard"
            case .dusk: "Dusk"
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
            }
        }
    }

    var fillStyle: FillStyle {
        didSet { UserDefaults.standard.set(fillStyle.rawValue, forKey: "appearance.fillStyle") }
    }

    var theme: Theme {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: "appearance.theme") }
    }

    private init() {
        fillStyle = FillStyle(rawValue: UserDefaults.standard.integer(forKey: "appearance.fillStyle")) ?? .shaded
        theme = Theme(rawValue: UserDefaults.standard.integer(forKey: "appearance.theme")) ?? .primary
    }
}
