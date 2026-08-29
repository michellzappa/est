import SwiftUI

/// Where the draw and done piles sit on screen, measured in the "game"
/// coordinate space. The board uses these to fly cards to and from the piles.
struct PileFrames: Equatable {
    var draw: CGRect?
    var done: CGRect?
}

struct PileFramesKey: PreferenceKey {
    static var defaultValue = PileFrames()

    static func reduce(value: inout PileFrames, nextValue: () -> PileFrames) {
        let next = nextValue()
        if let draw = next.draw { value.draw = draw }
        if let done = next.done { value.done = done }
    }
}

/// Bottom bar: the remaining deck on the left, the done pile on the right.
/// Both drawn as physical stacks, with counts.
struct PilesView: View {
    let deckCount: Int
    let doneCount: Int
    let doneTop: Card?
    var setsOnTable: Int?
    var totalCards = 81

    init(engine: GameEngine) {
        deckCount = engine.deck.count
        doneCount = engine.done.count
        doneTop = engine.done.last
        setsOnTable = Card.countSets(in: engine.table)
        totalCards = engine.totalCards
    }

    init(
        deckCount: Int,
        doneCount: Int,
        doneTop: Card?,
        setsOnTable: Int? = nil,
        totalCards: Int = 81
    ) {
        self.deckCount = deckCount
        self.doneCount = doneCount
        self.doneTop = doneTop
        self.setsOnTable = setsOnTable
        self.totalCards = totalCards
    }

    var body: some View {
        HStack(spacing: 14) {
            PileStack(
                label: "pile",
                count: deckCount,
                topFace: nil
            )
            .background(
                GeometryReader { geo in
                    Color.clear.preference(
                        key: PileFramesKey.self,
                        value: PileFrames(draw: geo.frame(in: .named("game")), done: nil)
                    )
                }
            )
            DeckProgressBar(
                deckCount: deckCount,
                doneCount: doneCount,
                setsOnTable: setsOnTable,
                totalCards: totalCards
            )
            .frame(maxWidth: .infinity)
            PileStack(
                label: "done",
                count: doneCount,
                topFace: doneTop
            )
            .background(
                GeometryReader { geo in
                    Color.clear.preference(
                        key: PileFramesKey.self,
                        value: PileFrames(draw: nil, done: geo.frame(in: .named("game")))
                    )
                }
            )
        }
    }
}

/// The linear read on where the game stands: cards flow left to right —
/// colored = done, faint = on the table, empty track = still in the deck.
struct DeckProgressBar: View {
    let deckCount: Int
    let doneCount: Int
    var setsOnTable: Int?
    var totalCards = 81

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { proxy in
                let width = proxy.size.width
                let doneFraction = CGFloat(doneCount) / CGFloat(totalCards)
                let inPlayFraction = CGFloat(totalCards - deckCount) / CGFloat(totalCards)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                    Capsule()
                        .fill(Color.primary.opacity(0.15))
                        .frame(width: max(deckCount < totalCards ? 10 : 0, width * inPlayFraction))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Card.Tint.red.color,
                                    Card.Tint.blue.color,
                                    Card.Tint.yellow.color,
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .mask(alignment: .leading) {
                            Capsule()
                                .frame(width: doneCount > 0 ? max(10, width * doneFraction) : 0)
                        }
                }
            }
            .frame(height: 10)
            .animation(.spring(duration: 0.5), value: doneCount)
            .animation(.spring(duration: 0.5), value: deckCount)

            Text("\(doneCount / 3) of \(totalCards / 3)" + (setsOnTable.map { " · \($0) in view" } ?? ""))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }
}

/// A small stack of cards with a count badge. `topFace == nil` renders card
/// backs (the draw pile); otherwise the last collected card shows on top.
struct PileStack: View {
    static let cardSide: CGFloat = 52

    let label: String
    let count: Int
    let topFace: Card?

    private var side: CGFloat { Self.cardSide }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                if count == 0 {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(
                            Color.primary.opacity(0.2),
                            style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])
                        )
                        .frame(width: side, height: side)
                } else {
                    ForEach(0..<min(count, 5), id: \.self) { layer in
                        stackLayer(layer: layer)
                            .offset(
                                x: CGFloat(layer) * -1.5,
                                y: CGFloat(layer) * -1.5
                            )
                    }
                }
            }
            .frame(width: side + 8, height: side + 8)
            .animation(.spring(duration: 0.35), value: count)

            Text("\(count)")
                .font(.headline.monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
        }
    }

    @ViewBuilder
    private func stackLayer(layer: Int) -> some View {
        let isTop = layer == min(count, 5) - 1
        if isTop, let topFace {
            CardView(card: topFace)
                .frame(width: side, height: side)
        } else if isTop {
            CardBackView()
                .frame(width: side, height: side)
        } else {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
                )
                .frame(width: side, height: side)
        }
    }
}

/// Card back: neutral tile with the three elementary shapes as a motif.
/// Follows the system color scheme so it never reads as the "wrong mode".
struct CardBackView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { proxy in
            let side = proxy.size.width
            let backColors = colorScheme == .dark
                ? [Color(white: 0.16), Color(white: 0.28)]
                : [Color(white: 0.85), Color(white: 0.95)]
            ZStack {
                RoundedRectangle(cornerRadius: side * 0.12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: backColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                HStack(spacing: side * 0.06) {
                    SymbolView(symbol: .circle, fill: .outline, tint: .red)
                    SymbolView(symbol: .square, fill: .outline, tint: .blue)
                    SymbolView(symbol: .triangle, fill: .outline, tint: .yellow)
                }
                .frame(width: side * 0.62)
                RoundedRectangle(cornerRadius: side * 0.12, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
