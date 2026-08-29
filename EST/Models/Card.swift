import SwiftUI

/// One card in the 81-card deck. Four attributes, three values each: 3^4 = 81.
struct Card: Identifiable, Hashable {
    enum Symbol: Int, CaseIterable {
        case circle, square, triangle

        var name: String {
            switch self {
            case .circle: "circle"
            case .square: "square"
            case .triangle: "triangle"
            }
        }
    }

    enum Tint: Int, CaseIterable {
        case red, blue, yellow

        /// Themed via Appearance: a theme change restyles everything that
        /// draws with tint colors.
        var color: Color {
            Appearance.shared.theme.color(for: self)
        }

        /// Lighter sibling used as the top of the solid-fill gradient.
        var highlight: Color {
            Appearance.shared.theme.highlight(for: self)
        }

        var gradient: LinearGradient {
            LinearGradient(
                colors: [highlight, color],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        var name: String {
            switch self {
            case .red: "red"
            case .blue: "blue"
            case .yellow: "yellow"
            }
        }
    }

    enum Fill: Int, CaseIterable {
        // Raw values are load-bearing (card id math); only names may change.
        case solid, outline, translucent

        var name: String {
            switch self {
            case .solid: "solid"
            case .outline: "outline"
            case .translucent: Appearance.shared.fillStyle == .pinstriped ? "striped" : "shaded"
            }
        }
    }

    /// 1, 2, or 3 symbols on the card.
    let count: Int
    let tint: Tint
    let symbol: Symbol
    let fill: Fill

    var id: Int {
        (count - 1) * 27 + tint.rawValue * 9 + symbol.rawValue * 3 + fill.rawValue
    }

    init(count: Int, tint: Tint, symbol: Symbol, fill: Fill) {
        self.count = count
        self.tint = tint
        self.symbol = symbol
        self.fill = fill
    }

    /// Inverse of `id`, used to decode cards off the wire (0...80).
    init(id: Int) {
        self.count = id / 27 + 1
        self.tint = Tint(rawValue: (id % 27) / 9)!
        self.symbol = Symbol(rawValue: (id % 9) / 3)!
        self.fill = Fill(rawValue: id % 3)!
    }

    /// Attribute values as trits (0...2), used by the set math.
    var trits: [Int] {
        [count - 1, tint.rawValue, symbol.rawValue, fill.rawValue]
    }

    static var fullDeck: [Card] {
        var deck: [Card] = []
        for count in 1...3 {
            for tint in Tint.allCases {
                for symbol in Symbol.allCases {
                    for fill in Fill.allCases {
                        deck.append(Card(count: count, tint: tint, symbol: symbol, fill: fill))
                    }
                }
            }
        }
        return deck
    }

    /// Three cards form a valid set when, for every attribute, the values are
    /// all equal or all different. Equivalent: each trit sum is 0 mod 3.
    static func isValidSet(_ a: Card, _ b: Card, _ c: Card) -> Bool {
        for i in 0..<4 where (a.trits[i] + b.trits[i] + c.trits[i]) % 3 != 0 {
            return false
        }
        return true
    }

    /// The unique third card that completes a set with `a` and `b`.
    /// For each trit: c = (2 * (a + b)) mod 3 gives "same if same, the
    /// remaining value if different".
    static func completing(_ a: Card, _ b: Card) -> Card {
        let t = (0..<4).map { (2 * (a.trits[$0] + b.trits[$0])) % 3 }
        return Card(
            count: t[0] + 1,
            tint: Tint(rawValue: t[1])!,
            symbol: Symbol(rawValue: t[2])!,
            fill: Fill(rawValue: t[3])!
        )
    }

    /// A random valid set, shuffled. Two random distinct cards plus their
    /// unique completion always form one.
    static func randomValidSet() -> [Card] {
        let deck = fullDeck
        let a = deck.randomElement()!
        var b = deck.randomElement()!
        while b == a {
            b = deck.randomElement()!
        }
        return [a, b, completing(a, b)].shuffled()
    }

    /// Why three cards fail, one line per broken trait. A trait breaks only
    /// as a two-and-one split, so each line reads "pair vs odd one out".
    static func violationDescriptions(_ a: Card, _ b: Card, _ c: Card) -> [String] {
        var lines: [String] = []
        func check(_ label: String, _ values: [String]) {
            guard Set(values).count == 2 else { return }
            let pair = values.first { v in values.filter { $0 == v }.count == 2 }!
            let odd = values.first { $0 != pair }!
            lines.append("\(label): \(pair), \(pair) vs \(odd)")
        }
        check("count", [a, b, c].map { String($0.count) })
        check("color", [a, b, c].map(\.tint.name))
        check("shape", [a, b, c].map(\.symbol.name))
        check("fill", [a, b, c].map(\.fill.name))
        return lines
    }

    /// How many valid sets `cards` contain. Each set is met once per pair,
    /// so divide by 3.
    static func countSets(in cards: [Card]) -> Int {
        let present = Set(cards)
        var found = 0
        for i in cards.indices {
            for j in cards.indices where j > i {
                let third = completing(cards[i], cards[j])
                if third != cards[i], third != cards[j], present.contains(third) {
                    found += 1
                }
            }
        }
        return found / 3
    }

    /// First set found among `cards`, or nil. O(n^2) via the completion trick.
    static func findSet(in cards: [Card]) -> [Card]? {
        let present = Set(cards)
        for i in cards.indices {
            for j in cards.indices where j > i {
                let third = completing(cards[i], cards[j])
                if third != cards[i], third != cards[j], present.contains(third) {
                    return [cards[i], cards[j], third]
                }
            }
        }
        return nil
    }
}
