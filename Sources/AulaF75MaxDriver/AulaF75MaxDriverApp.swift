import AppKit
import SwiftUI

@main
struct AulaF75MaxDriverApp: App {
    @StateObject private var model = AppViewModel()

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environmentObject(model)
                .background(WindowAppearanceConfigurator(refreshToken: model.selectedLanguageCode))
        }
        .windowResizability(.contentSize)
    }
}

private final class WindowAppearanceView: NSView {
    var configureWindow: ((NSWindow?) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        configureWindow?(window)
    }
}

private struct WindowAppearanceConfigurator: NSViewRepresentable {
    let refreshToken: String

    func makeNSView(context: Context) -> WindowAppearanceView {
        let view = WindowAppearanceView(frame: .zero)
        view.configureWindow = { window in
            Self.configureRepeatedly(window: window)
        }
        Self.configureRepeatedly(window: view.window)
        return view
    }

    func updateNSView(_ nsView: WindowAppearanceView, context: Context) {
        _ = refreshToken
        Self.configureRepeatedly(window: nsView.window)
    }

    @MainActor
    private static func configureRepeatedly(window: NSWindow?) {
        configure(window: window)

        DispatchQueue.main.async {
            configure(window: window)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(80)) {
            configure(window: window)
        }
    }

    @MainActor
    private static func configure(window: NSWindow?) {
        guard let window else { return }

        window.styleMask.insert(.fullSizeContentView)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .visible
        window.backgroundColor = NSColor(red: 0.03, green: 0.05, blue: 0.06, alpha: 1)
    }
}
