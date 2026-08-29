import SwiftUI

/// Bottom bar: the remaining deck on the left, the done pile on the right.
/// Both drawn as physical stacks, with counts.
struct PilesView: View {
    let deckCount: Int
    let doneCount: Int
    let doneTop: Card?

    init(engine: GameEngine) {
        deckCount = engine.deck.count
        doneCount = engine.done.count
        doneTop = engine.done.last
    }

    init(deckCount: Int, doneCount: Int, doneTop: Card?) {
        self.deckCount = deckCount
        self.doneCount = doneCount
        self.doneTop = doneTop
    }

    var body: some View {
        HStack {
            PileStack(
                label: "pile",
                count: deckCount,
                topFace: nil
            )
            Spacer()
            PileStack(
                label: "done",
                count: doneCount,
                topFace: doneTop
            )
        }
    }
}

/// A small stack of cards with a count badge. `topFace == nil` renders card
/// backs (the draw pile); otherwise the last collected card shows on top.
struct PileStack: View {
    let label: String
    let count: Int
    let topFace: Card?

    private let side: CGFloat = 52

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

/// Card back: dark tile with the three elementary shapes as a motif.
struct CardBackView: View {
    var body: some View {
        GeometryReader { proxy in
            let side = proxy.size.width
            ZStack {
                RoundedRectangle(cornerRadius: side * 0.12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.16), Color(white: 0.28)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                HStack(spacing: side * 0.06) {
                    SymbolView(symbol: .circle, fill: .outline, color: Card.Tint.red.color)
                    SymbolView(symbol: .square, fill: .outline, color: Card.Tint.blue.color)
                    SymbolView(symbol: .triangle, fill: .outline, color: Card.Tint.yellow.color)
                }
                .frame(width: side * 0.62)
                RoundedRectangle(cornerRadius: side * 0.12, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
