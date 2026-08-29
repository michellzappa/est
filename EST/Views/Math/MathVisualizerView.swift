import SwiftUI

/// A hands-on explanation of the four-trit structure behind EST.
struct MathVisualizerView: View {
    private enum Trait: Int, CaseIterable, Identifiable {
        case count, color, shape, fill

        var id: Int { rawValue }

        var label: String {
            switch self {
            case .count: "count"
            case .color: "color"
            case .shape: "shape"
            case .fill: "fill"
            }
        }

        /// Every value gets a themed accent, while the editor still shows
        /// the raw trit rather than the user-facing card value.
        func accent(for value: Int) -> Card.Tint {
            Card.Tint.allCases[value]
        }
    }

    /// This cap is a fixed, verified 20-card subset of the 81-card deck.
    /// Card.countSets(in:) is used again when the section renders.
    private static let pellegrinoCapIDs = [
        1, 3, 10, 13, 18, 21, 32, 34, 41, 44,
        49, 52, 54, 57, 59, 62, 64, 71, 72, 79
    ]

    @State private var editorTrits = [0, 0, 0, 0]
    @State private var forcePair: [Card] = {
        let trio = Card.randomValidSet()
        return Array(trio.prefix(2))
    }()
    @State private var gridSelection: [Int] = []

    private var editorCard: Card {
        Card(
            count: editorTrits[Trait.count.rawValue] + 1,
            tint: Card.Tint.allCases[editorTrits[Trait.color.rawValue]],
            symbol: Card.Symbol.allCases[editorTrits[Trait.shape.rawValue]],
            fill: Card.Fill.allCases[editorTrits[Trait.fill.rawValue]]
        )
    }

    private var completingCard: Card {
        Card.completing(forcePair[0], forcePair[1])
    }

    private var selectedGridCards: [Card] {
        gridSelection.map(Card.init(id:))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                intro

                sectionCard(
                    eyebrow: "01 / four trits",
                    title: "a card is four digits",
                    subtitle: "Tap a trait to cycle its value. The card and its base-3 id update together."
                ) {
                    editorSection
                }

                sectionCard(
                    eyebrow: "02 / the set rule",
                    title: "two cards force the third",
                    subtitle: "For every trait, the sum is zero modulo three. That leaves one possible third card."
                ) {
                    forceSection
                }

                sectionCard(
                    eyebrow: "03 / the whole space",
                    title: "all 81 at once",
                    subtitle: "The two trits on each axis make a 9 × 9 map of every card. Tap two cells to reveal the one they force."
                ) {
                    gridSection
                }

                sectionCard(
                    eyebrow: "stretch / cap set",
                    title: "the Pellegrino cap",
                    subtitle: "These 20 cards contain no set. Add any 21st card and a set must appear."
                ) {
                    capSection
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("The mathematics")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("cards are points. sets are lines.")
                .font(.title2.bold())
            Text("EST is the affine space AG(4,3): four coordinates, three values each, and 81 points in all.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
    }

    private var editorSection: some View {
        VStack(spacing: 14) {
            CardView(card: editorCard, isSelected: true)
                .frame(width: 176, height: 176)
                .frame(maxWidth: .infinity)
                .animation(.spring(duration: 0.3), value: editorCard)

            Text("base-3 id \(editorCard.id) / 0–80")
                .font(.caption.weight(.semibold).monospaced())
                .foregroundStyle(.secondary)

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 10
            ) {
                ForEach(Trait.allCases) { trait in
                    let value = editorTrits[trait.rawValue]
                    Button {
                        cycle(trait)
                    } label: {
                        VStack(spacing: 4) {
                            Text(trait.label)
                                .font(.caption.weight(.semibold))
                            Text(String(value))
                                .font(.title3.bold().monospacedDigit())
                            Text("tap to cycle")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .glassButtonSurface(
                        tint: trait.accent(for: value).color,
                        opacity: 0.12,
                        cornerRadius: 14
                    )
                    .accessibilityLabel("\(trait.label) trit \(value)")
                    .accessibilityHint("cycles from zero to two")
                }
            }
        }
    }

    private var forceSection: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                explanatoryCard(forcePair[0], label: "first")
                Image(systemName: "plus")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                explanatoryCard(forcePair[1], label: "second")
                Image(systemName: "equal")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                explanatoryCard(completingCard, label: "forced third", isThird: true)
            }
            .frame(maxWidth: .infinity)

            Text(Card.isValidSet(forcePair[0], forcePair[1], completingCard) ? "a set" : "not a set")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Card.Tint.blue.color)

            VStack(spacing: 8) {
                ForEach(Array(Card.audit(forcePair[0], forcePair[1], completingCard).enumerated()), id: \.element.id) { index, verdict in
                    HStack(spacing: 8) {
                        Text(verdict.label)
                            .font(.caption.weight(.semibold))
                            .frame(width: 48, alignment: .leading)

                        Text(outcomeName(for: verdict))
                            .font(.caption)

                        Spacer(minLength: 4)

                        Text("sum mod 3 = \(traitSum(at: index))")
                            .font(.caption2.monospaced())
                            .foregroundStyle(Card.Tint.blue.color)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .glassButtonSurface(
                        tint: verdict.isValid ? Card.Tint.blue.color : Card.Tint.red.color,
                        opacity: 0.10,
                        cornerRadius: 12
                    )
                }
            }

            Button {
                withAnimation(.spring(duration: 0.45)) {
                    let trio = Card.randomValidSet()
                    forcePair = Array(trio.prefix(2))
                }
            } label: {
                Label("shuffle the pair", systemImage: "shuffle")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.bordered)
        }
    }

    private var gridSection: some View {
        VStack(spacing: 14) {
            grid

            HStack(spacing: 10) {
                Button {
                    showRandomLine()
                } label: {
                    Label("show me a line", systemImage: "wand.and.stars")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    withAnimation(.spring(duration: 0.35)) {
                        gridSelection = []
                    }
                } label: {
                    Image(systemName: "xmark")
                        .frame(width: 20)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("clear line")
            }

            Text(gridInstruction)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var capSection: some View {
        let cards = Self.pellegrinoCapIDs.map(Card.init(id:))

        return VStack(spacing: 14) {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 5),
                spacing: 7
            ) {
                ForEach(cards) { card in
                    CardView(card: card)
                        .frame(maxWidth: .infinity)
                        .aspectRatio(1, contentMode: .fit)
                }
            }

            HStack {
                Label("20 cards", systemImage: "square.grid.3x3.fill")
                Spacer()
                Text("\(Card.countSets(in: cards)) sets")
                    .foregroundStyle(Card.Tint.blue.color)
            }
            .font(.subheadline.weight(.semibold))

            Text("Pellegrino proved that 20 is the largest cap in AG(4,3).")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func sectionCard<Content: View>(
        eyebrow: String,
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(eyebrow)
                    .font(.caption.weight(.bold).monospaced())
                    .foregroundStyle(Card.Tint.blue.color)
                Text(title)
                    .font(.title3.bold())
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            content()
        }
        .padding(16)
        .glassPanel(cornerRadius: 24)
    }

    private func explanatoryCard(_ card: Card, label: String, isThird: Bool = false) -> some View {
        VStack(spacing: 5) {
            CardView(card: card, isSelected: isThird)
                .frame(maxWidth: .infinity)
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(isThird ? Card.Tint.yellow.color : .secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private var grid: some View {
        GeometryReader { proxy in
            let side = proxy.size.width
            let gap: CGFloat = 3
            let cellSide = (side - gap * 8) / 9

            ZStack {
                VStack(spacing: gap) {
                    ForEach(0..<9, id: \.self) { row in
                        HStack(spacing: gap) {
                            ForEach(0..<9, id: \.self) { column in
                                let card = Card(id: row * 9 + column)
                                gridCell(card, row: row, column: column, side: cellSide)
                            }
                        }
                    }
                }

                if selectedGridCards.count > 1 {
                    TorusLineView(
                        points: selectedGridCards.map {
                            gridPoint(for: $0, cellSide: cellSide, gap: gap)
                        },
                        canvasSize: CGSize(width: side, height: side)
                    )
                    .allowsHitTesting(false)
                }
            }
            .frame(width: side, height: side)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
    }

    private func gridCell(_ card: Card, row: Int, column: Int, side: CGFloat) -> some View {
        let isSelected = gridSelection.contains(card.id)
        let isThird = gridSelection.count == 3 && gridSelection.last == card.id

        return Button {
            tapGrid(card)
        } label: {
            CardView(
                card: card,
                isSelected: isSelected,
                isDimmed: gridSelection.count == 3 && !isSelected
            )
            .overlay {
                if isThird {
                    RoundedRectangle(cornerRadius: side * 0.12, style: .continuous)
                        .stroke(Card.Tint.yellow.color, lineWidth: 2)
                        .padding(1)
                }
            }
        }
        .buttonStyle(.plain)
        .frame(width: side, height: side)
        .contentShape(Rectangle())
        .accessibilityLabel("card \(card.id), row \(row + 1), column \(column + 1)")
        .accessibilityHint("tap to choose this card")
    }

    private var gridInstruction: String {
        switch gridSelection.count {
        case 0: return "tap any two cells. the third card is unique."
        case 1: return "one selected. tap a second cell."
        default:
            let third = gridSelection[2]
            return "the third card is \(third). the line wraps at the edges."
        }
    }

    private func cycle(_ trait: Trait) {
        withAnimation(.spring(duration: 0.25)) {
            editorTrits[trait.rawValue] = (editorTrits[trait.rawValue] + 1) % 3
        }
    }

    private func outcomeName(for verdict: Card.TraitVerdict) -> String {
        switch verdict.outcome {
        case .allSame: "same"
        case .allDifferent: "all different"
        case .twoAndOne: "two and one"
        }
    }

    private func traitSum(at index: Int) -> Int {
        let cards = [forcePair[0], forcePair[1], completingCard]
        return cards.reduce(0) { partial, card in
            partial + card.trits[index]
        } % 3
    }

    private func tapGrid(_ card: Card) {
        withAnimation(.spring(duration: 0.4)) {
            switch gridSelection.count {
            case 0:
                gridSelection = [card.id]
            case 1:
                guard gridSelection[0] != card.id else { return }
                let first = Card(id: gridSelection[0])
                let third = Card.completing(first, card)
                gridSelection = [first.id, card.id, third.id]
            default:
                gridSelection = [card.id]
            }
        }
    }

    private func showRandomLine() {
        withAnimation(.spring(duration: 0.6)) {
            gridSelection = Card.randomValidSet().map(\.id)
        }
    }

    private func gridPoint(for card: Card, cellSide: CGFloat, gap: CGFloat) -> CGPoint {
        let row = card.id / 9
        let column = card.id % 9
        return CGPoint(
            x: cellSide / 2 + CGFloat(column) * (cellSide + gap),
            y: cellSide / 2 + CGFloat(row) * (cellSide + gap)
        )
    }
}

/// Draws each segment along the shortest route on a square torus. Copies of
/// the segment shifted by one canvas width/height make edge crossings appear
/// on the opposite edge as well.
private struct TorusLineView: View {
    let points: [CGPoint]
    let canvasSize: CGSize

    var body: some View {
        Canvas { context, size in
            guard points.count > 1 else { return }

            let tint = Card.Tint.blue.color
            let style = StrokeStyle(
                lineWidth: max(2, size.width * 0.012),
                lineCap: .round,
                lineJoin: .round
            )

            for pair in zip(points, points.dropFirst()) {
                drawWrappedSegment(
                    from: pair.0,
                    to: pair.1,
                    in: &context,
                    size: canvasSize,
                    style: style,
                    tint: tint
                )
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
    }

    private func drawWrappedSegment(
        from start: CGPoint,
        to end: CGPoint,
        in context: inout GraphicsContext,
        size: CGSize,
        style: StrokeStyle,
        tint: Color
    ) {
        var dx = end.x - start.x
        var dy = end.y - start.y

        if dx > size.width / 2 { dx -= size.width }
        if dx < -size.width / 2 { dx += size.width }
        if dy > size.height / 2 { dy -= size.height }
        if dy < -size.height / 2 { dy += size.height }

        let wrappedEnd = CGPoint(x: start.x + dx, y: start.y + dy)
        for xShift in -1...1 {
            for yShift in -1...1 {
                let offset = CGSize(
                    width: CGFloat(xShift) * size.width,
                    height: CGFloat(yShift) * size.height
                )
                var path = Path()
                path.move(to: CGPoint(x: start.x + offset.width, y: start.y + offset.height))
                path.addLine(to: CGPoint(x: wrappedEnd.x + offset.width, y: wrappedEnd.y + offset.height))
                context.stroke(path, with: .color(tint.opacity(0.82)), style: style)
            }
        }
    }
}

#Preview {
    NavigationStack {
        MathVisualizerView()
    }
}
