import SwiftUI

/// The table: 3 columns, rows grow as the engine deals (12, 15, ...).
/// Sizes cards to fit both width and height, no scrolling.
/// Takes plain values so it renders local engines and remote snapshots alike.
///
/// When the hosting screen provides pile frames (measured in a "game"
/// coordinate space via `PileFramesKey`), matched cards fly to the done pile
/// and replacements fly in from the draw pile.
struct BoardGridView: View {
    let table: [Card]
    let selectedIDs: Set<Int>
    let mismatchIDs: Set<Int>
    let mismatchToken: Int
    let dealToken: Int
    var celebrationIDs: Set<Int> = []
    var hintedIDs: Set<Int> = []
    var collectedCount = 0
    var pileFrames = PileFrames()
    var isInteractive = true
    var onTap: (Card) -> Void

    init(
        engine: GameEngine,
        selectedIDsOverride: Set<Int>? = nil,
        hintedIDs: Set<Int> = [],
        pileFrames: PileFrames = PileFrames(),
        isInteractive: Bool = true,
        onTap: @escaping (Card) -> Void
    ) {
        self.table = engine.table
        self.selectedIDs = selectedIDsOverride ?? Set(engine.selection.map(\.id))
        self.mismatchIDs = engine.lastMismatch
        self.mismatchToken = engine.mismatchToken
        self.dealToken = engine.dealToken
        self.celebrationIDs = engine.celebrationIDs
        self.hintedIDs = hintedIDs
        self.collectedCount = engine.done.count
        self.pileFrames = pileFrames
        self.isInteractive = isInteractive
        self.onTap = onTap
    }

    init(
        table: [Card],
        selectedIDs: Set<Int>,
        mismatchIDs: Set<Int>,
        mismatchToken: Int,
        dealToken: Int = 0,
        celebrationIDs: Set<Int> = [],
        collectedCount: Int = 0,
        pileFrames: PileFrames = PileFrames(),
        isInteractive: Bool = true,
        onTap: @escaping (Card) -> Void
    ) {
        self.table = table
        self.selectedIDs = selectedIDs
        self.mismatchIDs = mismatchIDs
        self.mismatchToken = mismatchToken
        self.dealToken = dealToken
        self.celebrationIDs = celebrationIDs
        self.collectedCount = collectedCount
        self.pileFrames = pileFrames
        self.isInteractive = isInteractive
        self.onTap = onTap
    }

    private let gap: CGFloat = 10

    @State private var flights: [DepartureFlight] = []
    @State private var departureOrigins: [DepartureOrigin] = []
    @State private var playedOpeningDeal = false
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    /// The opening deal flips in generically; only later cards fly from the
    /// pile (its frame is not known during the very first layout anyway).
    @State private var pastInitialDeal = false

    private struct DepartureOrigin: Equatable {
        let card: Card
        let rect: CGRect
    }

    var body: some View {
        GeometryReader { proxy in
            let columns = 3
            let rows = max(1, Int(ceil(Double(table.count) / Double(columns))))
            let side = min(
                (proxy.size.width - CGFloat(columns - 1) * gap) / CGFloat(columns),
                (proxy.size.height - CGFloat(rows - 1) * gap) / CGFloat(rows)
            )
            let gridWidth = CGFloat(columns) * side + CGFloat(columns - 1) * gap
            let gridHeight = CGFloat(rows) * side + CGFloat(rows - 1) * gap
            let origin = CGPoint(
                x: (proxy.size.width - gridWidth) / 2,
                y: (proxy.size.height - gridHeight) / 2
            )
            let boardFrame = proxy.frame(in: .named("game"))
            let slotCenter: (Int) -> CGPoint = { index in
                CGPoint(
                    x: origin.x + CGFloat(index % columns) * (side + gap) + side / 2,
                    y: origin.y + CGFloat(index / columns) * (side + gap) + side / 2
                )
            }
            let toLocal: (CGRect) -> CGPoint = { rect in
                CGPoint(x: rect.midX - boardFrame.minX, y: rect.midY - boardFrame.minY)
            }
            let drawLocal = pileFrames.draw.map(toLocal)
            let doneLocal = pileFrames.done.map(toLocal)

            ZStack {
                VStack(spacing: gap) {
                    ForEach(0..<rows, id: \.self) { row in
                        HStack(spacing: gap) {
                            ForEach(0..<columns, id: \.self) { column in
                                let index = row * columns + column
                                if index < table.count {
                                    let card = table[index]
                                    let dealVector: CGSize? = (pastInitialDeal && drawLocal != nil)
                                        ? CGSize(
                                            width: drawLocal!.x - slotCenter(index).x,
                                            height: drawLocal!.y - slotCenter(index).y
                                        )
                                        : nil
                                    CardCell(
                                        card: card,
                                        index: index,
                                        isSelected: selectedIDs.contains(card.id),
                                        isHinted: hintedIDs.contains(card.id),
                                        isCelebrating: celebrationIDs.contains(card.id),
                                        isMismatched: mismatchIDs.contains(card.id),
                                        mismatchToken: mismatchToken,
                                        dealVector: dealVector
                                    )
                                    .frame(width: side, height: side)
                                    .onTapGesture {
                                        guard isInteractive else { return }
                                        if selectedIDs.contains(card.id) {
                                            GameAudio.shared.play(.cardDeselected)
                                        } else {
                                            GameAudio.shared.play(.cardSelected(step: selectedIDs.count + 1))
                                        }
                                        onTap(card)
                                    }
                                    .transition(.identity)
                                    .id(card.id)
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

                ForEach(flights) { flight in
                    FlightCardView(flight: flight)
                }
            }
            .onChange(of: celebrationIDs) { _, ids in
                guard !ids.isEmpty else { return }
                GameAudio.shared.play(.validSet)
                // Remember where the matched cards sit; by the time they move
                // to the done pile they are no longer on the table.
                departureOrigins = table.indices.compactMap { index in
                    guard ids.contains(table[index].id) else { return nil }
                    let center = slotCenter(index)
                    return DepartureOrigin(
                        card: table[index],
                        rect: CGRect(
                            x: center.x - side / 2,
                            y: center.y - side / 2,
                            width: side,
                            height: side
                        )
                    )
                }
            }
            .onChange(of: mismatchToken) { _, newToken in
                guard newToken > 0 else { return }
                GameAudio.shared.play(.mismatch)
            }
            .onChange(of: dealToken) { oldToken, newToken in
                guard newToken > oldToken else { return }
                GameAudio.shared.play(.deal)
            }
            .onChange(of: collectedCount) { oldCount, newCount in
                guard newCount > oldCount, let doneLocal, !departureOrigins.isEmpty else {
                    departureOrigins = []
                    return
                }
                let newFlights = departureOrigins.enumerated().map { offset, departure in
                    DepartureFlight(
                        card: departure.card,
                        from: departure.rect,
                        to: doneLocal,
                        delay: Double(offset) * 0.06
                    )
                }
                departureOrigins = []
                flights.append(contentsOf: newFlights)
                let flightIDs = Set(newFlights.map(\.id))
                Task {
                    try? await Task.sleep(for: .seconds(1.1))
                    flights.removeAll { flightIDs.contains($0.id) }
                }
            }
        }
        .sensoryFeedback(
            trigger: FeedbackTrigger(value: table, enabled: hapticsEnabled)
        ) { oldValue, newValue in
            guard newValue.enabled, oldValue.value != newValue.value else { return nil }
            return .impact(flexibility: .soft, intensity: 0.6)
        }
        .onAppear {
            if !table.isEmpty, !playedOpeningDeal {
                playedOpeningDeal = true
                GameAudio.shared.play(.deal)
            }
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                pastInitialDeal = true
            }
        }
    }
}

struct DepartureFlight: Identifiable {
    let id = UUID()
    let card: Card
    let from: CGRect
    let to: CGPoint
    let delay: Double
}

/// A matched card mid-air on its way to the done pile.
private struct FlightCardView: View {
    let flight: DepartureFlight

    @State private var arrived = false

    var body: some View {
        CardView(card: flight.card)
            .frame(width: flight.from.width, height: flight.from.height)
            .scaleEffect(arrived ? PileStack.cardSide / flight.from.width : 1)
            .opacity(arrived ? 0.6 : 1)
            .position(arrived ? flight.to : CGPoint(x: flight.from.midX, y: flight.from.midY))
            .onAppear {
                withAnimation(.easeInOut(duration: 0.45).delay(flight.delay)) {
                    arrived = true
                }
            }
            .allowsHitTesting(false)
            .zIndex(2)
    }
}

/// Brief toast explaining why the last trio failed, one line per broken
/// trait. Shows on every mismatch token bump, hides itself after a beat.
struct MismatchExplainer: View {
    let reasons: [String]
    let token: Int

    @State private var visibleToken = 0

    var body: some View {
        Group {
            if visibleToken == token, token > 0, !reasons.isEmpty {
                VStack(spacing: 3) {
                    Text("Not a set")
                        .font(.caption.bold())
                        .textCase(.uppercase)
                    ForEach(reasons, id: \.self) { reason in
                        Text(reason)
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .glassPanel(cornerRadius: 14)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.35), value: visibleToken)
        .onChange(of: token) { _, newToken in
            visibleToken = newToken
            Task {
                try? await Task.sleep(for: .seconds(5))
                if visibleToken == newToken {
                    visibleToken = -1
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// One slot on the board. New cards fly in from the draw pile (or flip in on
/// the opening deal); mismatched picks shake; matched picks glow while their
/// celebration runs.
private struct CardCell: View {
    let card: Card
    let index: Int
    let isSelected: Bool
    var isHinted = false
    var isCelebrating = false
    let isMismatched: Bool
    let mismatchToken: Int
    var dealVector: CGSize? = nil

    @State private var dealt = false
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    /// Local shake progress. Bumped by exactly 1 per mismatch this card is
    /// part of, so cards from earlier mismatches stay still.
    @State private var shakes: CGFloat = 0

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
            .scaleEffect(isCelebrating ? 1.10 : 1)
            .shadow(
                color: isCelebrating ? card.tint.color.opacity(0.7) : .clear,
                radius: isCelebrating ? 14 : 0
            )
            .zIndex(isCelebrating ? 1 : 0)
            .animation(.spring(duration: 0.35, bounce: 0.55), value: isCelebrating)
            .modifier(ShakeEffect(animatableData: shakes))
            .onChange(of: mismatchToken) { _, _ in
                guard isMismatched else { return }
                withAnimation(.linear(duration: 0.4)) {
                    shakes += 1
                }
            }
            .rotation3DEffect(
                .degrees(dealt ? 0 : 70),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.6
            )
            .scaleEffect(dealt ? 1 : (dealVector == nil ? 1 : 0.45))
            .offset(dealt ? .zero : (dealVector ?? CGSize(width: 0, height: -30)))
            .opacity(dealt ? 1 : (dealVector == nil ? 0 : 0.3))
            .onAppear {
                let delay = dealVector == nil
                    ? Double(index) * 0.06
                    : 0.12 + Double(index % 6) * 0.06
                withAnimation(.spring(duration: 0.55).delay(delay)) {
                    dealt = true
                }
            }
            .sensoryFeedback(
                trigger: FeedbackTrigger(value: isSelected, enabled: hapticsEnabled)
            ) { oldValue, newValue in
                guard newValue.enabled, !oldValue.value, newValue.value else { return nil }
                return .selection
            }
    }
}
