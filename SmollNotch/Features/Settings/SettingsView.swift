import SwiftUI

enum SettingsKey {
    static let hideWhenPaused = "hideWhenPaused"
    static let peekOnTrackChange = "peekOnTrackChange"
    static let screens = "screens"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            peekOnTrackChange: true,
            screens: ScreenChoice.builtIn.rawValue,
        ])
    }
}

struct SettingsView: View {
    @State private var model = SettingsViewModel()
    @AppStorage(SettingsKey.hideWhenPaused) private var hideWhenPaused = false
    @AppStorage(SettingsKey.peekOnTrackChange) private var peekOnTrackChange = true
    @AppStorage(SettingsKey.screens) private var screens = ScreenChoice.builtIn

    var body: some View {
        Form {
            Section {
                Toggle("Beim Anmelden starten", isOn: Binding(
                    get: { model.launchAtLogin },
                    set: { model.setLaunchAtLogin($0) }
                ))
                Toggle("Bei Pause ausblenden", isOn: $hideWhenPaused)
                Toggle("Bei Songwechsel kurz anzeigen", isOn: $peekOnTrackChange)
            } footer: {
                if let error = model.error {
                    Text(error).foregroundStyle(.red)
                }
            }

            Section {
                Picker("Anzeigen auf", selection: $screens) {
                    ForEach(ScreenChoice.allCases) { choice in
                        Text(choice.title).tag(choice)
                    }
                }
            } footer: {
                Text("Auf Bildschirmen ohne Notch schwebt die Insel als Pille oben in der Mitte.")
                    .foregroundStyle(.secondary)
            }

            Section("Gesten auf der geöffneten Insel") {
                LabeledContent("Mit zwei Fingern nach links oder rechts wischen", value: "Nächster oder vorheriger Titel")
            }

            Section {
                LabeledContent("Version", value: model.version)
                Link("Datenschutz", destination: URL(string: "https://iamginsley.github.io/smoll-notch/datenschutz")!)
            } footer: {
                Text("Smoll Notch liest nur, was dein Mac unter „Läuft gerade“ anzeigt. Nichts verlässt deinen Mac.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear(perform: model.refresh)
    }
}

#Preview {
    SettingsView()
}
