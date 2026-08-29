import SwiftUI

/// The app's name never settles: the three letters keep shuffling through
/// permutations of S, E, T (skipping the one spelling that names the
/// original game).
struct VaryingTitleView: View {
    var fontSize: CGFloat = 72

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
    var onParty: (Int) -> Void
    var onOnlineParty: () -> Void

    @State private var showRules = false

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            VaryingTitleView()
            Text("81 cards. every combination. find three\nwhere each trait is all same or all different.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            demoRow
                .padding(.vertical, 16)

            Spacer()

            VStack(spacing: 12) {
                Button(action: onSolo) {
                    Label("Solo — race the deck", systemImage: "timer")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                HStack(spacing: 12) {
                    ForEach(2...4, id: \.self) { count in
                        Button {
                            onParty(count)
                        } label: {
                            Label("\(count)", systemImage: "person.\(count).fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                }

                Button(action: onOnlineParty) {
                    Label("Play with friends — online or nearby", systemImage: "antenna.radiowaves.left.and.right")
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
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $showRules) {
            RulesView()
        }
        .onAppear {
            GameCenterManager.shared.setAccessPointVisible(true)
        }
        .onDisappear {
            GameCenterManager.shared.setAccessPointVisible(false)
        }
    }

    /// A valid EST as a standing example: all traits different on every axis.
    private var demoRow: some View {
        HStack(spacing: 12) {
            CardView(card: Card(count: 1, tint: .red, symbol: .circle, fill: .solid))
            CardView(card: Card(count: 2, tint: .blue, symbol: .square, fill: .striped))
            CardView(card: Card(count: 3, tint: .yellow, symbol: .triangle, fill: .outline))
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
                        "81 cards: every combination of four traits — count (1, 2, 3), color (red, blue, yellow), shape (circle, square, triangle), and fill (solid, striped, outline)."
                    )
                    ruleBlock(
                        "A valid EST",
                        "Three cards where each of the four traits is either the same on all three cards or different on all three. One trait two-and-one? Not an EST."
                    )
                    ruleBlock(
                        "The table",
                        "12 cards face up. If no EST exists among them, 3 more are dealt automatically. Find one, tap its three cards, and replacements are dealt."
                    )
                    ruleBlock(
                        "Solo",
                        "Clear the whole deck as fast as you can. Your time goes to the Game Center leaderboard."
                    )
                    ruleBlock(
                        "Party",
                        "Pass-around play on one phone. See an EST? Hit your button first — you get \(Int(PartySession.claimWindow)) seconds to tap the three cards. Miss or time out: lose a point and sit out briefly."
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
