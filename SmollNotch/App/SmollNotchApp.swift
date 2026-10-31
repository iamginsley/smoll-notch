import SwiftUI

@main
struct SmollNotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Smoll Notch", systemImage: "music.note") {
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
    private var windowController: NotchWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let model = NotchViewModel(source: Self.makeSource(), forceExpanded: LaunchFlags.expanded)
        let windowController = NotchWindowController(model: model)
        windowController.show()
        model.start()
        self.model = model
        self.windowController = windowController
    }

    func applicationWillTerminate(_ notification: Notification) {
        model?.stop()
    }

    private static func makeSource() -> NowPlayingSource {
        #if DEBUG
        if LaunchFlags.demo { return DemoNowPlayingSource() }
        #endif
        return NowPlayingService()
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
