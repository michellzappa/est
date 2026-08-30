import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SupportStore.self) private var supportStore
    @Bindable private var appearance = Appearance.shared
    @AppStorage("soundEffectsEnabled") private var soundEffectsEnabled = true
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("immersiveGameMode") private var immersiveGameMode = true
    @AppStorage(ESTTelemetry.enabledKey) private var telemetryEnabled = true
    @State private var showSupport = false
    @State private var showTelemetryPreview = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Fill") {
                    Picker("Fill style", selection: $appearance.fillStyle) {
                        ForEach(Appearance.FillStyle.allCases, id: \.self) { style in
                            Text(style.name).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)

                    HStack(spacing: 12) {
                        CardView(card: Card(count: 1, tint: .red, symbol: .circle, fill: .translucent))
                        CardView(card: Card(count: 2, tint: .blue, symbol: .square, fill: .translucent))
                        CardView(card: Card(count: 3, tint: .yellow, symbol: .triangle, fill: .translucent))
                    }
                    .frame(height: 72)
                    .frame(maxWidth: .infinity)
                }

                Section("Colors") {
                    ForEach(Appearance.Theme.allCases, id: \.self) { theme in
                        Button {
                            if theme == .supporter && !supportStore.isSupporter {
                                showSupport = true
                            } else {
                                appearance.theme = theme
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Text(theme.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                ForEach(Card.Tint.allCases, id: \.self) { tint in
                                    Circle()
                                        .fill(theme.color(for: tint))
                                        .frame(width: 16, height: 16)
                                }
                                Image(systemName: theme == .supporter && !supportStore.isSupporter ? "lock.fill" : "checkmark")
                                    .font(.footnote.bold())
                                    .foregroundStyle(theme == .supporter && !supportStore.isSupporter ? .secondary : .primary)
                                    .opacity((theme == .supporter && !supportStore.isSupporter) || appearance.theme == theme ? 1 : 0)
                            }
                        }
                    }
                }

                Section("Feedback") {
                    Toggle("Sound effects", isOn: $soundEffectsEnabled)
                    Toggle("Haptics", isOn: $hapticsEnabled)
                }

                Section("Game") {
                    Toggle("Immersive game mode", isOn: $immersiveGameMode)
                    Text("Hides the iPhone status bar and Game Center button while playing.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Privacy") {
                    Toggle("Share anonymous diagnostics", isOn: $telemetryEnabled)
                        .onChange(of: telemetryEnabled) { _, enabled in
                            ESTTelemetry.setEnabled(enabled)
                        }

                    DisclosureGroup("What is shared") {
                        Text("When enabled, EST sends at most one aggregate batch per week containing the app version, iOS major version, coarse mode activity, and a few feature settings.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text("EST never sends your name, Game Center ID, cards, scores, exact times, or gameplay events. Turning this off deletes pending diagnostics and stops new collection.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Link(destination: ESTTelemetry.sourceURL) {
                            Label("Read the telemetry code", systemImage: "chevron.left.forwardslash.chevron.right")
                        }
                        Link(destination: ESTTelemetry.privacyURL) {
                            Label("Read the privacy policy", systemImage: "hand.raised")
                        }
                        Button {
                            showTelemetryPreview = true
                        } label: {
                            Label("Preview this week's batch", systemImage: "doc.text.magnifyingglass")
                        }
                        .disabled(!telemetryEnabled)
                    }
                }

                Section(
                    content: {
                        Button {
                            showSupport = true
                        } label: {
                            HStack {
                                Label("Support EST", systemImage: "heart")
                                Spacer()
                                if supportStore.isSupporter {
                                    Text("Supporter")
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(Card.Tint.blue.color)
                                }
                            }
                        }
                    },
                    header: {
                        Text("Support")
                    },
                    footer: {
                        Text("EST is free and open source. Support is optional and unlocks no gameplay; it adds only supporter thanks and cosmetics.")
                    }
                )

                Section("About") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("EST")
                            .font(.headline)
                        Text("A free, open-source iPhone game by Michell Zappa at Centaur Labs, inspired by SET.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)

                    if supportStore.isSupporter {
                        Label("EST Supporter", systemImage: "checkmark.seal.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Card.Tint.blue.color)
                    }

                    Link(destination: Self.sourceCodeURL) {
                        Label("Source code", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                }

                Section {
                } footer: {
                    Text("EST \(Self.marketingVersion) (build \(Self.buildNumber))")
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showSupport) {
                SupportView()
            }
            .sheet(isPresented: $showTelemetryPreview) {
                TelemetryPreviewView()
            }
            .onChange(of: soundEffectsEnabled) { _, enabled in
                GameAudio.shared.setEnabled(enabled)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private static let sourceCodeURL = URL(string: "https://github.com/michellzappa/est")!

    private static var marketingVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    private static var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }
}

private struct TelemetryPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var preview: ESTTelemetryBatch?

    var body: some View {
        NavigationStack {
            Group {
                if let preview {
                    ScrollView {
                        Text(encoded(preview))
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                } else {
                    ProgressView("Building preview…")
                }
            }
            .navigationTitle("Telemetry preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                preview = await TelemetryCoordinator.shared.preview()
            }
        }
    }

    private func encoded(_ batch: ESTTelemetryBatch) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(batch),
              let value = String(data: data, encoding: .utf8)
        else { return "Preview unavailable." }
        return value
    }
}
