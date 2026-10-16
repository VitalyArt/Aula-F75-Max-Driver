import SwiftUI

@main
struct AulaF75MaxDriverApp: App {
    @StateObject private var model = AppViewModel()
    @StateObject private var profiles = LightingProfileStore()

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environmentObject(model)
                .environmentObject(profiles)
        }
        // The title bar is hidden so the sidebar runs under the window
        // buttons; each page draws its own large title instead.
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1040, height: 700)
        .windowResizability(.contentMinSize)
    }
}
