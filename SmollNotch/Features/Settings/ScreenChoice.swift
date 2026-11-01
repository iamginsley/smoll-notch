import Foundation

/// Which screens show an island.
enum ScreenChoice: String, CaseIterable, Identifiable {
    /// The built-in display with the notch, or the main display when it is closed or absent.
    case builtIn
    /// The display with the menu bar.
    case main
    case all

    var id: Self { self }

    var title: String {
        switch self {
        case .builtIn: "Bildschirm mit Notch"
        case .main: "Hauptbildschirm"
        case .all: "Alle Bildschirme"
        }
    }

    static var current: ScreenChoice {
        UserDefaults.standard.string(forKey: SettingsKey.screens).flatMap(ScreenChoice.init) ?? .builtIn
    }

    /// Indices of the screens to use. `hasNotch` is in `NSScreen.screens` order, where index 0 holds the menu bar.
    func screenIndices(hasNotch: [Bool]) -> [Int] {
        guard !hasNotch.isEmpty else { return [] }
        switch self {
        case .builtIn:
            return hasNotch.firstIndex(of: true).map { [$0] } ?? [0]
        case .main:
            return [0]
        case .all:
            return Array(hasNotch.indices)
        }
    }
}
