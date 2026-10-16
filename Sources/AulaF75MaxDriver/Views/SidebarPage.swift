import Foundation

/// One row in the sidebar. The sidebar list and the detail `switch` in
/// `ContentView` are both driven by this enum, so adding a page means adding
/// a case here and a view for it.
enum SidebarPage: String, CaseIterable, Identifiable, Hashable {
    case home
    case lighting
    case screen
    case performance
    case settings
    case diagnostics
    case activityLog

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return L10n.text("Home")
        case .lighting: return L10n.text("Lighting")
        case .screen: return L10n.text("Screen")
        case .performance: return L10n.text("Performance")
        case .settings: return L10n.text("Settings")
        case .diagnostics: return L10n.text("Diagnostics")
        case .activityLog: return L10n.text("Activity Log")
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "house"
        case .lighting: return "sparkles"
        case .screen: return "display"
        case .performance: return "speedometer"
        case .settings: return "gearshape"
        case .diagnostics: return "stethoscope"
        case .activityLog: return "list.bullet.rectangle"
        }
    }

    /// Advanced pages hold research and troubleshooting tools that everyday
    /// users never need, so the sidebar lists them in a separate group.
    var isAdvanced: Bool {
        self == .diagnostics || self == .activityLog
    }

    static var mainPages: [SidebarPage] {
        allCases.filter { !$0.isAdvanced }
    }

    static var advancedPages: [SidebarPage] {
        allCases.filter { $0.isAdvanced }
    }
}
