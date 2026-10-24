import SwiftUI

@main
struct AulaF75MaxDriverApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model = AppViewModel()
    @StateObject private var profiles = LightingProfileStore()

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .safeAreaInset(edge: .top, spacing: 0) { UpdateBanner() }
                .task { UpdateStore.shared.checkIfDue() }
                .onChange(of: scenePhase) { _, phase in if phase == .active { UpdateStore.shared.checkIfDue() } }
                .environmentObject(model)
                .environmentObject(profiles)
        }
        // The title bar is hidden so the sidebar runs under the window
        // buttons; each page draws its own large title instead.
        .commands {
            CommandGroup(after: .appInfo) {
                Button(L10n.text("Check for Updates…")) { UpdateStore.shared.check() }
            }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1040, height: 700)
        .windowResizability(.contentMinSize)
    }
}
