import SwiftUI

/// The app's name never settles: the three letters keep shuffling through
/// permutations of S, E, T (skipping the one spelling that names the
/// original game).
struct VaryingTitleView: View {
    var fontSize: CGFloat = 72
    /// Fired on every letter shuffle so companions (the title screen's demo
    /// cards) can cycle on the same beat.
    var onCycle: (() -> Void)? = nil

    private static let permutations = ["EST", "TSE", "STE", "ETS", "TES"]
    @State private var index = 0

    var body: some View {
        HStack(spacing: fontSize * 0.06) {
            ForEach(Array(Self.permutations[index]), id: \.self) { letter in
                Text(String(letter))
                    .font(.system(size: fontSize, weight: .black, design: .rounded))
                    .foregroundStyle(color(for: letter))
            }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(7.2))
                withAnimation(.spring(duration: 0.7)) {
                    index = (index + 1) % Self.permutations.count
                }
                onCycle?()
            }
        }
    }

    private func color(for letter: Character) -> Color {
        switch letter {
        case "E": Card.Tint.red.color
        case "S": Card.Tint.blue.color
        default: Card.Tint.yellow.color
        }
    }
}

struct TitleView: View {
    var onSolo: () -> Void
    var onQuickSolo: () -> Void
    var onParty: (Int) -> Void
    var onOnlineParty: () -> Void

    @State private var showRules = false
    @State private var showPlayStyle = false
    @State private var showSettings = false
    @State private var demoCards = Card.randomValidSet()

    var body: some View {
        GeometryReader { proxy in
            let supportsFourPlayerMode = PartySession.supportsFourPlayerMode(in: proxy.size)

            VStack(spacing: 16) {
            Spacer()

            VaryingTitleView {
                withAnimation(.spring(duration: 0.7)) {
                    demoCards = Card.randomValidSet()
                }
            }
            Text("A game of card patterns")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("81 cards. Every combination. Find three where\nevery trait is all the same or all different.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            demoRow
                .padding(.vertical, 16)

            Spacer()

            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Button(action: onSolo) {
                        Label("Solo 81", systemImage: "timer")
                    }
                    .buttonStyle(.game(.primary, tint: .blue, size: .large))

                    Button(action: onQuickSolo) {
                        Label("Quick 27", systemImage: "bolt.fill")
                    }
                    .buttonStyle(.game(.secondary, tint: .yellow, size: .large))
                }

                if supportsFourPlayerMode {
                    HStack(spacing: 12) {
                        Button {
                            onParty(PartySession.minimumPlayerCount)
                        } label: {
                            Label("Duel, one phone", systemImage: "person.2.fill")
                        }
                        .buttonStyle(.game(.secondary, tint: .red, size: .large))

                        Button {
                            onParty(PartySession.maximumPlayerCount)
                        } label: {
                                Label(
                                "\(PartySession.maximumPlayerCount) players, \(PartySession.fourPlayerDeviceLabel)",
                                systemImage: "person.3.fill"
                            )
                        }
                        .buttonStyle(.game(.secondary, tint: .yellow, size: .large))
                    }
                } else {
                    Button {
                        onParty(PartySession.minimumPlayerCount)
                    } label: {
                        Label("Duel, one phone", systemImage: "person.2.fill")
                    }
                    .buttonStyle(.game(.secondary, tint: .red))
                }

                Button(action: onOnlineParty) {
                    Label(
                        supportsFourPlayerMode ? "Party, online or nearby" : "Duel, online or nearby",
                        systemImage: "antenna.radiowaves.left.and.right"
                    )
                }
                .buttonStyle(.game(.secondary, tint: .red))
                .disabled(!GameCenterManager.shared.isAuthenticated)

                Button {
                    showPlayStyle = true
                } label: {
                    Label("Your play style", systemImage: "chart.bar.xaxis")
                }
                .buttonStyle(.game(.quiet, tint: .blue, size: .compact))

                HStack(spacing: 12) {
                    Button {
                        showRules = true
                    } label: {
                        Label("Rules", systemImage: "questionmark.circle")
                    }
                    .buttonStyle(.game(.quiet, size: .compact))

                    Button {
                        GameCenterManager.shared.showLeaderboard()
                    } label: {
                        Label("Leaderboard", systemImage: "trophy")
                    }
                    .buttonStyle(.game(.quiet, size: .compact))
                    .disabled(!GameCenterManager.shared.isAuthenticated)

                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .buttonStyle(.game(.quiet, size: .icon))
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
            }
        }
        .background(Appearance.shared.gameBackground)
        .sheet(isPresented: $showRules) {
            RulesView()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showPlayStyle) {
            PlayStyleView()
        }
    }

    /// Always a valid EST, re-rolled on the same beat as the name shuffle.
    private var demoRow: some View {
        HStack(spacing: 12) {
            // Keep each physical position stable. The cards are shuffled as a
            // set, but the animation belongs to each of these three slots.
            ForEach(0..<3, id: \.self) { index in
                DemoCardSlot(card: demoCards[index])
            }
        }
        .frame(height: 84)
    }
}

private struct DemoCardSlot: View {
    let card: Card

    @State private var displayedCard: Card
    @State private var angle: Double = 0

    init(card: Card) {
        self.card = card
        _displayedCard = State(initialValue: card)
    }

    var body: some View {
        ZStack {
            CardView(card: displayedCard)
                .rotation3DEffect(
                    .degrees(angle),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.65
                )

            if edgeOpacity > 0 {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Appearance.shared.theme.cardBorder)
                    .frame(width: 2, height: 84)
                    .opacity(edgeOpacity)
            }
        }
            .task(id: card.id) {
                guard displayedCard.id != card.id else { return }
                await flip(to: card)
            }
    }

    private var edgeOpacity: Double {
        let distanceFromFace = abs(angle)
        guard distanceFromFace > 72 else { return 0 }
        return min(1, (distanceFromFace - 72) / 18)
    }

    @MainActor
    private func flip(to newCard: Card) async {
        withAnimation(.easeInOut(duration: 0.32)) {
            angle = 90
        }

        try? await Task.sleep(for: .seconds(0.32))
        guard !Task.isCancelled else { return }

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            displayedCard = newCard
            angle = -90
        }

        withAnimation(.easeInOut(duration: 0.32)) {
            angle = 0
        }
    }
}

struct RulesView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showTutorial = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    intro

                    rulesSection(
                        "Learn the rule",
                        "Start here if you are new to EST."
                    ) {
                        Button {
                            showTutorial = true
                        } label: {
                            Label("Walk me through it", systemImage: "graduationcap")
                        }
                        .buttonStyle(.game(.primary, tint: .blue, size: .large))

                        NavigationLink {
                            MathVisualizerView()
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "function")
                                    .font(.title3)
                                    .frame(width: 28)
                                    .foregroundStyle(Card.Tint.blue.color)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("The mathematics")
                                        .font(.subheadline.weight(.semibold))
                                    Text("Cards are points. Sets are lines. Explore the four-trit structure.")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(12)
                            .glassButtonSurface(
                                tint: Card.Tint.blue.color,
                                opacity: 0.10,
                                cornerRadius: 14
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    rulesSection(
                        "Choose a mode",
                        "Pick a game and start playing."
                    ) {
                        ruleRow(
                            "timer",
                            "Solo 81",
                            "Clear all 81 cards against the clock. Your best time can go to Game Center."
                        )
                        ruleRow(
                            "bolt.fill",
                            "Quick 27",
                            "Play the 27 solid cards for a shorter, faster round."
                        )
                        ruleRow(
                            "person.2.fill",
                            "Duel",
                            "Play pass-around on one phone, or live across phones over Game Center."
                        )
                    }

                    rulesSection(
                        "How the game works",
                        "The same rule applies in every mode."
                    ) {
                        ruleRow(
                            "square.grid.3x3.fill",
                            "The deck",
                            "81 cards cover every combination of count, color, shape, and fill. Each trait has three values."
                        )
                        ruleRow(
                            "checkmark.circle",
                            "A valid set",
                            "Three cards work when every trait is either the same on all three or different on all three. Two and one never works."
                        )
                        ruleRow(
                            "rectangle.3.group",
                            "The table",
                            "Start with 12 cards. Tap three that form a set. If none exists, three more cards appear automatically."
                        )
                        ruleRow(
                            "hand.tap",
                            "In a duel",
                            "Buzz first, then tap the three cards within \(Int(PartySession.claimWindow)) seconds. A miss costs a point and a short lockout."
                        )
                    }

                    rulesSection(
                        "About EST",
                        "A free game built around the structure of its deck."
                    ) {
                        Text("EST is a free, open-source iPhone game inspired by SET, the card game Marsha Falco created in 1974. It has its own name, artwork, and code, and is not affiliated with or endorsed by SET's makers. SET is a registered trademark of Cannei, LLC.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 28)
            }
            .background(Appearance.shared.gameBackground.ignoresSafeArea())
            .navigationTitle("How to play")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .fullScreenCover(isPresented: $showTutorial) {
                TutorialView { showTutorial = false }
            }
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Learn the rule, then play it")
                .font(.title2.bold())
            Text("A quick guide to the game, its modes, and the idea underneath all 81 cards.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
    }

    private func rulesSection<Content: View>(
        _ title: String,
        _ subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.title3.bold())
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            content()
        }
        .padding(16)
        .glassPanel(cornerRadius: 22)
    }

    private func ruleRow(_ icon: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .frame(width: 28)
                .foregroundStyle(Card.Tint.blue.color)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(text)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
