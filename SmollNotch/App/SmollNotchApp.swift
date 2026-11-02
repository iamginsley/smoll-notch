import SwiftUI

@main
struct SmollNotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Smoll Notch", image: "MenuBarIcon") {
            SettingsLink { Text("Einstellungen …") }
                .keyboardShortcut(",")
            Divider()
            Button("Smoll Notch beenden") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }

        Settings {
            SettingsView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: NotchViewModel?
    /// One island per shown screen, keyed by display ID.
    private var controllers: [CGDirectDisplayID: NotchWindowController] = [:]
    private var observers: [NSObjectProtocol] = []
    private var screenChoice = ScreenChoice.current

    func applicationDidFinishLaunching(_ notification: Notification) {
        SettingsKey.registerDefaults()
        screenChoice = ScreenChoice.current
        let model = Self.makeModel()
        self.model = model
        updateScreens()
        model.start()

        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateScreens() }
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, ScreenChoice.current != self.screenChoice else { return }
                self.screenChoice = ScreenChoice.current
                self.updateScreens()
            }
        })
    }

    func applicationWillTerminate(_ notification: Notification) {
        model?.stop()
    }

    /// Adds, moves and removes islands so they match the connected screens and the setting.
    private func updateScreens() {
        guard let model else { return }
        let screens = NSScreen.screens
        let chosen = screenChoice
            .screenIndices(hasNotch: screens.map { $0.safeAreaInsets.top > 0 })
            .map { screens[$0] }
        let wanted = Dictionary(chosen.compactMap { screen in screen.displayID.map { ($0, screen) } },
                                uniquingKeysWith: { first, _ in first })

        for (id, controller) in controllers where wanted[id] == nil {
            controller.close()
            controllers[id] = nil
        }
        for (id, screen) in wanted {
            if let controller = controllers[id] {
                controller.update(screen: screen)
            } else {
                let controller = NotchWindowController(model: model, screen: screen, forceExpanded: LaunchFlags.expanded)
                controller.show()
                controllers[id] = controller
            }
        }
    }

    private static func makeModel() -> NotchViewModel {
        #if DEBUG
        if LaunchFlags.demo {
            return NotchViewModel(source: DemoNowPlayingSource(), favorites: DemoFavoriteService())
        }
        #endif
        return NotchViewModel(source: NowPlayingService(), favorites: MusicFavoriteService())
    }
}

private extension NSScreen {
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }
}

/// Launch arguments for screenshots and UI tests. Only honored in Debug builds.
enum LaunchFlags {
    #if DEBUG
    static let demo = ProcessInfo.processInfo.arguments.contains("-SmollNotchDemo")
    static let expanded = ProcessInfo.processInfo.arguments.contains("-SmollNotchExpanded")
    #else
    static let demo = false
    static let expanded = false
    #endif
}
