import SwiftUI

@main
struct NV2rayApp: App {
    @StateObject private var store = AppStore()

    var body: some Scene {
        MenuBarExtra {
            MenuPanel()
                .environmentObject(store)
                .frame(width: 360)
        } label: {
            Image(systemName: store.connectionState.iconName)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsRootView()
                .environmentObject(store)
                .frame(minWidth: 780, minHeight: 560)
        }
    }
}
