import Foundation
import ServiceManagement

@MainActor
@Observable
final class SettingsViewModel {
    private(set) var launchAtLogin = false
    private(set) var error: String?

    var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }

    func refresh() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            error = nil
        } catch {
            self.error = "Konnte nicht geändert werden. Prüfe Systemeinstellungen › Allgemein › Anmeldeobjekte."
        }
        refresh()
    }
}
