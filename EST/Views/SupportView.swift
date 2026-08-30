import SwiftUI

/// The optional patronage screen. It deliberately explains that the purchase
/// changes nothing about gameplay, so it cannot be mistaken for a paywall.
struct SupportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(SupportStore.self) private var store
    @State private var showThankYou = false

    private var isWorking: Bool {
        store.isLoading || store.isPurchasing || store.isRestoring
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    supporterMark

                    VStack(spacing: 8) {
                        Text(store.isSupporter ? "Thank you for supporting EST" : "Support EST")
                            .font(.title2.weight(.bold))
                            .multilineTextAlignment(.center)

                        Text("EST is free and open source. If you enjoy playing it, a one-time gift helps keep it independent and ad-free.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        reasonRow("gift", "Keeps every mode free")
                        reasonRow("sparkles", "Helps pay for maintenance")
                        reasonRow("nosign", "Keeps ads out of the game")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .glassPanel(cornerRadius: 20)

                    perksPanel

                    Text("This purchase unlocks no gameplay. Every player gets the same game.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    if let message = store.message {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    if store.isSupporter {
                        VStack(spacing: 12) {
                            Label("You're an EST supporter", systemImage: "checkmark.seal.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Card.Tint.blue.color)

                            Button {
                                Appearance.shared.theme = .supporter
                            } label: {
                                Label("Use supporter finish", systemImage: "paintpalette")
                            }
                            .buttonStyle(.game(.secondary, tint: .yellow, size: .medium))
                        }
                    } else {
                        Button {
                            Task {
                                if await store.purchase() {
                                    showThankYou = true
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                if store.isPurchasing {
                                    ProgressView()
                                        .tint(.white)
                                }
                                Text("Support EST")
                                if let product = store.product {
                                    Text("·")
                                    Text(product.displayPrice)
                                }
                            }
                        }
                        .buttonStyle(.game(.primary, tint: .red, size: .large))
                        .disabled(isWorking || store.product == nil)
                    }

                    Button {
                        Task { await store.restore() }
                    } label: {
                        HStack(spacing: 8) {
                            if store.isRestoring {
                                ProgressView()
                            }
                            Text("Restore purchase")
                        }
                    }
                    .buttonStyle(.game(.quiet, size: .compact))
                    .disabled(isWorking)

                    Text("One-time gift. No subscription.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(24)
            }
            .navigationTitle("Support EST")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .disabled(isWorking)
                }
            }
        }
        .task {
            await store.start()
        }
        .sheet(isPresented: $showThankYou) {
            SupportThankYouView {
                Appearance.shared.theme = .supporter
            }
        }
    }

    private var perksPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Supporter perks")
                .font(.headline)

            perkRow("checkmark.seal.fill", "A permanent supporter mark in EST")
            perkRow("paintpalette.fill", "An optional cosmetic finish for cards and the table")
            perkRow("testtube.2", "Early TestFlight access when new builds are available")

            Text("TestFlight invites and public thanks are handled manually and are always opt-in.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                openURL(Self.publicThanksURL)
            } label: {
                Label("Ask to be listed in public thanks", systemImage: "person.crop.circle.badge.plus")
            }
            .buttonStyle(.game(.quiet, size: .compact))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .glassPanel(cornerRadius: 20)
    }

    private var supporterMark: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Card.Tint.red.color, Card.Tint.yellow.color, Card.Tint.blue.color],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Image(systemName: "heart.fill")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: 88, height: 88)
        .shadow(color: Card.Tint.red.color.opacity(0.28), radius: 16, y: 8)
        .accessibilityHidden(true)
    }

    private func reasonRow(_ icon: String, _ text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.primary)
    }

    private func perkRow(_ icon: String, _ text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.primary)
    }

    private static let publicThanksURL = URL(string: "https://github.com/michellzappa/est/issues/new?title=Public%20supporter%20thanks")!
}

private struct SupportThankYouView: View {
    @Environment(\.dismiss) private var dismiss
    var onUseFinish: () -> Void

    var body: some View {
        ZStack {
            Appearance.shared.gameBackground
                .ignoresSafeArea()
            ConfettiView()
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 58, weight: .bold))
                    .foregroundStyle(Card.Tint.yellow.color)

                Text("Thank you")
                    .font(.largeTitle.weight(.bold))

                Text("You’re helping keep EST free, open source, and independent.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                Text("Every mode stays free for everyone.")
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.center)

                Button {
                    onUseFinish()
                    dismiss()
                } label: {
                    Label("Try supporter finish", systemImage: "paintpalette")
                }
                .buttonStyle(.game(.secondary, tint: .yellow, size: .large))

                Button("Done") { dismiss() }
                    .buttonStyle(.game(.primary, tint: .blue, size: .large))
            }
            .padding(28)
            .frame(maxWidth: 440)
            .glassPanel(cornerRadius: 28)
            .padding(24)
        }
    }
}

#Preview {
    SupportView()
        .environment(SupportStore())
}
