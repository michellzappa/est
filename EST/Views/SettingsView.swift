import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable private var appearance = Appearance.shared

    var body: some View {
        NavigationStack {
            Form {
                Section("Third fill") {
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
                            appearance.theme = theme
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
                                Image(systemName: "checkmark")
                                    .font(.footnote.bold())
                                    .opacity(appearance.theme == theme ? 1 : 0)
                            }
                        }
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
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private static var marketingVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    private static var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }
}
