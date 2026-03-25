import SwiftUI
import ServiceManagement

struct PreferencesView: View {
    @ObservedObject var prefs: PreferencesManager

    var body: some View {
        Form {
            Section("Voice") {
                Toggle("Read replies aloud", isOn: $prefs.readAloudEnabled)
            }

            Section("Startup") {
                Toggle("Launch at login", isOn: Binding(
                    get: { prefs.autoLaunchEnabled },
                    set: { newValue in
                        prefs.autoLaunchEnabled = newValue
                        if newValue {
                            try? SMAppService.mainApp.register()
                        } else {
                            try? SMAppService.mainApp.unregister()
                        }
                    }
                ))
            }

            Section("Hotkey") {
                Text("Global shortcut: ⌘⇧P")
                    .foregroundColor(.secondary)
                Text("Custom hotkeys coming in a future update.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 350, height: 250)
    }
}
