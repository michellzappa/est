import SwiftUI

/// The table: 3 columns, rows grow as the engine deals (12, 15, ...).
/// Sizes cards to fit both width and height, no scrolling.
/// Takes plain values so it renders local engines and remote snapshots alike.
struct BoardGridView: View {
    let table: [Card]
    let selectedIDs: Set<Int>
    let mismatchIDs: Set<Int>
    let mismatchToken: Int
    var hintedIDs: Set<Int> = []
    var isInteractive = true
    var onTap: (Card) -> Void

    init(
        engine: GameEngine,
        hintedIDs: Set<Int> = [],
        isInteractive: Bool = true,
        onTap: @escaping (Card) -> Void
    ) {
        self.table = engine.table
        self.selectedIDs = Set(engine.selection.map(\.id))
        self.mismatchIDs = engine.lastMismatch
        self.mismatchToken = engine.mismatchToken
        self.hintedIDs = hintedIDs
        self.isInteractive = isInteractive
        self.onTap = onTap
    }

    init(
        table: [Card],
        selectedIDs: Set<Int>,
        mismatchIDs: Set<Int>,
        mismatchToken: Int,
        isInteractive: Bool = true,
        onTap: @escaping (Card) -> Void
    ) {
        self.table = table
        self.selectedIDs = selectedIDs
        self.mismatchIDs = mismatchIDs
        self.mismatchToken = mismatchToken
        self.isInteractive = isInteractive
        self.onTap = onTap
    }

    private let gap: CGFloat = 10

    var body: some View {
        GeometryReader { proxy in
            let columns = 3
            let rows = max(1, Int(ceil(Double(table.count) / Double(columns))))
            let side = min(
                (proxy.size.width - CGFloat(columns - 1) * gap) / CGFloat(columns),
                (proxy.size.height - CGFloat(rows - 1) * gap) / CGFloat(rows)
            )

            VStack(spacing: gap) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: gap) {
                        ForEach(0..<columns, id: \.self) { column in
                            let index = row * columns + column
                            if index < table.count {
                                let card = table[index]
                                CardCell(
                                    card: card,
                                    index: index,
                                    isSelected: selectedIDs.contains(card.id),
                                    isHinted: hintedIDs.contains(card.id),
                                    wiggle: mismatchIDs.contains(card.id) ? mismatchToken : 0
                                )
                                .frame(width: side, height: side)
                                .onTapGesture {
                                    guard isInteractive else { return }
                                    onTap(card)
                                }
                            } else {
                                Color.clear.frame(width: side, height: side)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.spring(duration: 0.4), value: table)
            .animation(.spring(duration: 0.25), value: selectedIDs)
        }
    }
}

/// One slot on the board. New cards flip in with a 3D deal animation,
/// staggered by position; mismatched picks shake.
private struct CardCell: View {
    let card: Card
    let index: Int
    let isSelected: Bool
    var isHinted = false
    let wiggle: Int

    @State private var dealt = false

    var body: some View {
        CardView(card: card, isSelected: isSelected)
            .overlay {
                if isHinted {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            Color.orange,
                            style: StrokeStyle(lineWidth: 3, dash: [7, 5])
                        )
                }
            }
            .modifier(ShakeEffect(animatableData: CGFloat(wiggle)))
            .animation(.linear(duration: 0.35), value: wiggle)
            .rotation3DEffect(
                .degrees(dealt ? 0 : 80),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.6
            )
            .offset(y: dealt ? 0 : -30)
            .opacity(dealt ? 1 : 0)
            .onAppear {
                withAnimation(.spring(duration: 0.5).delay(Double(index) * 0.06)) {
                    dealt = true
                }
            }
            .id(card.id)
            .transition(.asymmetric(
                insertion: .identity,
                removal: .scale(scale: 0.4).combined(with: .opacity)
            ))
            .sensoryFeedback(.selection, trigger: isSelected)
    }
}
