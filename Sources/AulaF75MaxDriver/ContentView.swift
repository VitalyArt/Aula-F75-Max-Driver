import AppKit
import SwiftUI

/// The app window: a translucent sidebar of pages on the left, the selected
/// page on the right with a large title, and a floating status pill.
///
/// This is a custom two-column layout rather than `NavigationSplitView`.
/// The system split view draws a light divider and a line under the title bar
/// that cannot be restyled; laying the columns out ourselves gives a clean,
/// line-free window like premium peripheral apps.
struct ContentView: View {
    @EnvironmentObject private var model: AppViewModel
    @State private var selection: SidebarPage? = .home
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let sidebarWidth: CGFloat = 220

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: sidebarWidth)
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(minWidth: 820, minHeight: 560)
        .groupBoxStyle(CardGroupBoxStyle())
        .background { pageShortcuts }
        .onAppear {
            model.startMonitoring()
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            // Room for the window's close/minimise/zoom buttons.
            Color.clear.frame(height: 40)

            sidebarHeader

            List(selection: $selection) {
                Section {
                    ForEach(SidebarPage.mainPages) { page in
                        sidebarRow(page)
                    }
                }

                Section(L10n.text("Advanced")) {
                    ForEach(SidebarPage.advancedPages) { page in
                        sidebarRow(page)
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            // L10n strings are not observable, so a language change would not
            // redraw these labels on its own; a new id forces a redraw.
            .id(model.selectedLanguageCode)

            sidebarFooter
        }
        .background(SidebarMaterial().ignoresSafeArea())
    }

    private func sidebarRow(_ page: SidebarPage) -> some View {
        Label(page.title, systemImage: page.systemImage)
            .tag(page)
    }

    private var sidebarHeader: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 1) {
                Text("Aula F75 Max")
                    .font(.headline)
                Text(L10n.text("Keyboard Control"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 8)
    }

    private var sidebarFooter: some View {
        HStack(spacing: 6) {
            if model.isWorking {
                ProgressView()
                    .controlSize(.small)
                Text(L10n.text("Working…"))
            } else {
                Circle()
                    .fill(.green)
                    .frame(width: 7, height: 7)
                Text(L10n.text("Ready"))
            }
            Spacer(minLength: 0)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    /// Invisible buttons that give ⌘1…⌘8 to the sidebar pages in order.
    private var pageShortcuts: some View {
        ZStack {
            ForEach(Array(SidebarPage.allCases.enumerated()), id: \.element) { index, page in
                Button("") { selection = page }
                    .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
            }
        }
        .opacity(0)
        .accessibilityHidden(true)
    }

    // MARK: - Detail

    private var currentPage: SidebarPage {
        selection ?? .home
    }

    private var detail: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(currentPage.title)
                .font(.system(size: 26, weight: .bold))
                .padding(.horizontal, 28)
                .padding(.bottom, 6)
                .frame(height: 56, alignment: .bottomLeading)
                .accessibilityAddTraits(.isHeader)

            page(for: currentPage)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        // A new id per page and language gives each page switch a fresh
        // view, which the transition fades in.
        .id("\(model.selectedLanguageCode)-\(currentPage.rawValue)")
        .transition(.opacity)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: selection)
        // The pill takes real space at the bottom (rather than floating over
        // the page), so a page that fits never needs a scrollbar.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            StatusBar(selection: $selection)
                .padding(.top, 6)
                .padding(.bottom, 12)
                .padding(.horizontal, 28)
        }
    }

    @ViewBuilder
    private func page(for page: SidebarPage) -> some View {
        switch page {
        case .home: HomeView(selection: $selection)
        case .lighting: LightingView()
        case .screen: ScreenView()
        case .performance: PerformanceView()
        case .settings: SettingsView()
        case .diagnostics: DiagnosticsView()
        case .activityLog: ActivityLogView()
        case .guide: KeyboardGuideView()
        }
    }
}

/// The translucent macOS sidebar material (the blurred desktop shows through).
private struct SidebarMaterial: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .sidebar
        view.blendingMode = .behindWindow
        view.state = .followsWindowActiveState
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
