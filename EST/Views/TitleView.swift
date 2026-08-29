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
                try? await Task.sleep(for: .seconds(2.4))
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
    @State private var showSettings = false
    @State private var demoCards = Card.randomValidSet()

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            VaryingTitleView {
                withAnimation(.spring(duration: 0.7)) {
                    demoCards = Card.randomValidSet()
                }
            }
            Text("81 cards. every combination. find three\nwhere each trait is all same or all different.")
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
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button(action: onQuickSolo) {
                        Label("Quick 27", systemImage: "bolt.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }

                Button {
                    onParty(2)
                } label: {
                    Label("Duel, one phone", systemImage: "person.2.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button(action: onOnlineParty) {
                    Label("Duel, online or nearby", systemImage: "antenna.radiowaves.left.and.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(!GameCenterManager.shared.isAuthenticated)

                HStack(spacing: 12) {
                    Button {
                        showRules = true
                    } label: {
                        Label("Rules", systemImage: "questionmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        GameCenterManager.shared.showLeaderboard()
                    } label: {
                        Label("Leaderboard", systemImage: "trophy")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!GameCenterManager.shared.isAuthenticated)

                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .frame(maxWidth: 44)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $showRules) {
            RulesView()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .onAppear {
            GameCenterManager.shared.setAccessPointVisible(true)
        }
        .onDisappear {
            GameCenterManager.shared.setAccessPointVisible(false)
        }
    }

    /// Always a valid EST, re-rolled on the same beat as the name shuffle.
    private var demoRow: some View {
        HStack(spacing: 12) {
            ForEach(demoCards) { card in
                CardView(card: card)
                    .transition(.scale(scale: 0.7).combined(with: .opacity))
                    .id(card.id)
            }
        }
        .frame(height: 84)
    }
}

struct RulesView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ruleBlock(
                        "The deck",
                        "81 cards: every combination of four traits. Count (1, 2, 3), color (red, blue, yellow), shape (circle, square, triangle), and fill (solid, translucent, outline)."
                    )
                    ruleBlock(
                        "A valid set",
                        "Three cards where each of the four traits is either the same on all three cards or different on all three. One trait two-and-one? Not a set."
                    )
                    ruleBlock(
                        "The table",
                        "12 cards face up. If no set exists among them, 3 more are dealt automatically. Find one, tap its three cards, and replacements are dealt."
                    )
                    ruleBlock(
                        "Solo",
                        "Clear the whole deck as fast as you can. Your time goes to the Game Center leaderboard."
                    )
                    ruleBlock(
                        "Party",
                        "Pass-around play on one phone, or across phones over Game Center. See a set? Hit your button first and you get \(Int(PartySession.claimWindow)) seconds to tap the three cards. Miss or time out: lose a point and sit out briefly."
                    )
                    ruleBlock(
                        "About",
                        "EST is free and open source, made in the spirit of SET, the card game Marsha Falco invented in 1974. We love the original and give copies away often. If you have never played it, buy one. EST is not affiliated with, sponsored by, or endorsed by SET's makers. SET is a registered trademark of Cannei, LLC."
                    )
                }
                .padding()
            }
            .navigationTitle("How to play")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func ruleBlock(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
