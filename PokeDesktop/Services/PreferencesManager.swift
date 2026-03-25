import Foundation

class PreferencesManager: ObservableObject {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.readAloudEnabled = defaults.object(forKey: "readAloudEnabled") as? Bool ?? true
        self.autoLaunchEnabled = defaults.object(forKey: "autoLaunchEnabled") as? Bool ?? true
    }

    var pokeHandleId: Int64? {
        get { defaults.object(forKey: "pokeHandleId") as? Int64 }
        set { defaults.set(newValue, forKey: "pokeHandleId") }
    }

    var lastSeenRowId: Int64 {
        get { defaults.object(forKey: "lastSeenRowId") as? Int64 ?? 0 }
        set { defaults.set(newValue, forKey: "lastSeenRowId") }
    }

    @Published var readAloudEnabled: Bool = true {
        didSet { defaults.set(readAloudEnabled, forKey: "readAloudEnabled") }
    }

    @Published var autoLaunchEnabled: Bool = true {
        didSet { defaults.set(autoLaunchEnabled, forKey: "autoLaunchEnabled") }
    }

    var globalHotkey: String {
        get { defaults.string(forKey: "globalHotkey") ?? "⌘⇧P" }
        set { defaults.set(newValue, forKey: "globalHotkey") }
    }

    var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: "hasCompletedOnboarding") }
        set { defaults.set(newValue, forKey: "hasCompletedOnboarding") }
    }

    var pokeHandleIdentifier: String? {
        get { defaults.string(forKey: "pokeHandleIdentifier") }
        set { defaults.set(newValue, forKey: "pokeHandleIdentifier") }
    }

    var pokeChatId: Int64? {
        get { defaults.object(forKey: "pokeChatId") as? Int64 }
        set { defaults.set(newValue, forKey: "pokeChatId") }
    }
}
