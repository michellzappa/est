import SwiftUI

/// One card in the 81-card deck. Four attributes, three values each: 3^4 = 81.
struct Card: Identifiable, Hashable {
    enum Symbol: Int, CaseIterable {
        case circle, square, triangle
    }

    enum Tint: Int, CaseIterable {
        case red, blue, yellow

        var color: Color {
            switch self {
            case .red: Color(red: 0.86, green: 0.18, blue: 0.16)
            case .blue: Color(red: 0.08, green: 0.36, blue: 0.87)
            case .yellow: Color(red: 0.95, green: 0.71, blue: 0.00)
            }
        }
    }

    enum Fill: Int, CaseIterable {
        case solid, outline, striped
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

    /// Three cards form an EST when, for every attribute, the values are
    /// all equal or all different. Equivalent: each trit sum is 0 mod 3.
    static func isEST(_ a: Card, _ b: Card, _ c: Card) -> Bool {
        for i in 0..<4 where (a.trits[i] + b.trits[i] + c.trits[i]) % 3 != 0 {
            return false
        }
        return true
    }

    /// The unique third card that completes an EST with `a` and `b`.
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

    /// First EST found among `cards`, or nil. O(n^2) via the completion trick.
    static func findEST(in cards: [Card]) -> [Card]? {
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
