import SwiftUI

enum SettingsKey {
    static let hideWhenPaused = "hideWhenPaused"
}

struct SettingsView: View {
    @State private var model = SettingsViewModel()
    @AppStorage(SettingsKey.hideWhenPaused) private var hideWhenPaused = false

    var body: some View {
        Form {
            Section {
                Toggle("Beim Anmelden starten", isOn: Binding(
                    get: { model.launchAtLogin },
                    set: { model.setLaunchAtLogin($0) }
                ))
                Toggle("Bei Pause ausblenden", isOn: $hideWhenPaused)
            } footer: {
                if let error = model.error {
                    Text(error).foregroundStyle(.red)
                }
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
