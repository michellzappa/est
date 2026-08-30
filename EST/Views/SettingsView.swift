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

                Section("Community Pulse") {
                    CommunityPulseView()
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

private struct CommunityPulseView: View {
    @State private var stats: ESTCommunityStats?
    @State private var isLoading = false

    var body: some View {
        Group {
            if let stats {
                statsContent(stats)
            } else if isLoading {
                HStack {
                    ProgressView()
                    Text("Loading community activity…")
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Community activity is unavailable", systemImage: "chart.xyaxis.line")
                    Text("Try again when you have a connection.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button("Try again") {
                        Task { await reload() }
                    }
                }
            }
        }
        .task {
            await reload()
        }
    }

    @ViewBuilder
    private func statsContent(_ stats: ESTCommunityStats) -> some View {
        if let latest = stats.latest {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(latest.inProgress ? "Week to date" : "Latest reported week")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(latest.period)
                        .font(.headline)
                }

                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        metric("Active devices", latest.reportingDevices)
                        metric("Games started", latest.activity.gamesStarted)
                    }
                    HStack(spacing: 10) {
                        metric("Games completed", latest.activity.gamesCompleted)
                        metric("Sets found", latest.activity.setsFound)
                    }
                }

                if latest.reportingDevices == nil {
                    Text("Results appear after at least \(stats.privacy.minimumGroupSize) devices report. Small groups stay withheld.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if !latest.modes.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Mode use")
                            .font(.subheadline.weight(.semibold))
                        ForEach(latest.modes) { mode in
                            HStack {
                                Text(modeName(mode.name))
                                Spacer()
                                Text(mode.percent.map { "\($0)%" } ?? "—")
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                            .font(.footnote)
                        }
                    }
                }

                recentWeeks(stats.weeklyActive, minimumGroupSize: stats.privacy.minimumGroupSize)

                Button {
                    Task { await reload() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(isLoading)
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Label("Community Pulse is getting started", systemImage: "chart.xyaxis.line")
                Text("Activity will appear after at least \(stats.privacy.minimumGroupSize) devices have reported.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button {
                    Task { await reload() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(isLoading)
            }
        }
    }

    private func metric(_ label: String, _ value: Int?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value.map { String($0) } ?? "—")
                .font(.title3.weight(.semibold))
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func recentWeeks(
        _ weeks: [ESTCommunityStats.WeeklyActive],
        minimumGroupSize: Int
    ) -> some View {
        if weeks.count > 1 {
            VStack(alignment: .leading, spacing: 6) {
                Text("Recent weeks")
                    .font(.subheadline.weight(.semibold))
                ForEach(weeks.suffix(8)) { week in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(week.period)
                            Spacer()
                            Text(week.count.map { "\($0) active devices" } ?? "Growing")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        if week.count == nil {
                            Text("Withheld until \(minimumGroupSize) devices report")
                                .foregroundStyle(.secondary)
                        } else {
                            Text("\(week.gamesStarted.map { String($0) } ?? "—") games started · \(week.gamesCompleted.map { String($0) } ?? "—") completed · \(week.setsFound.map { String($0) } ?? "—") sets")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.caption)
                }
            }
        }
    }

    private func modeName(_ name: String) -> String {
        switch name {
        case "full_solo": return "Full solo"
        case "quick_solo": return "Quick solo"
        case "local_duel": return "Local duel"
        case "network_duel": return "Network duel"
        default: return name.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    @MainActor
    private func reload() async {
        guard !isLoading else { return }
        isLoading = true
        defer {
            isLoading = false
        }
        guard let result = try? await ESTCommunityStatsClient.fetch() else { return }
        stats = result
    }
}
