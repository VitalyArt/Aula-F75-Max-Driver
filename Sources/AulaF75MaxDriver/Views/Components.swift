import AppKit
import SwiftUI

// Small views shared by more than one page.

/// Which piece of hardware a group of controls needs.
enum DeviceRequirement {
    case usbCable
    case receiver
}

/// Explains why controls are disabled when their device is missing.
/// Renders nothing while the device is connected.
struct DeviceRequirementNote: View {
    @EnvironmentObject private var model: AppViewModel
    private let requirement: DeviceRequirement

    init(_ requirement: DeviceRequirement) {
        self.requirement = requirement
    }

    var body: some View {
        if !isDevicePresent {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.callout)
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private var isDevicePresent: Bool {
        switch requirement {
        case .usbCable: return model.isWiredDevicePresent
        case .receiver: return model.isDonglePresent
        }
    }

    private var message: String {
        switch requirement {
        case .usbCable: return L10n.text("Connect the keyboard with a USB-C cable to use these controls.")
        case .receiver: return L10n.text("Plug in the 2.4G receiver to use these controls.")
        }
    }
}

/// A floating pill at the bottom of every page showing the latest result, so
/// users see whether an action worked without opening the Activity Log.
/// Clicking it opens the log.
struct StatusBar: View {
    @EnvironmentObject private var model: AppViewModel
    @Binding var selection: SidebarPage?

    var body: some View {
        Button {
            selection = .activityLog
        } label: {
            HStack(spacing: 8) {
                if model.isWorking {
                    ProgressView()
                        .controlSize(.small)
                    Text(L10n.text("Working…"))
                } else {
                    Image(systemName: "text.alignleft")
                    Text(model.logLines.last ?? L10n.text("No activity yet"))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .frame(maxWidth: 640)
            .background(.regularMaterial, in: Capsule())
            .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(L10n.text("Open Activity Log"))
    }
}

/// The operation log as one selectable block of monospaced text that
/// scrolls to the newest line. Callers decide its height.
struct LogTextView: View {
    let lines: [String]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Group {
                    if lines.isEmpty {
                        Text(L10n.text("No log entries yet."))
                            .foregroundStyle(.secondary)
                    } else {
                        Text(lines.joined(separator: "\n"))
                            .textSelection(.enabled)
                            .lineSpacing(4)
                    }
                }
                .font(.system(.caption, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .id("logContent")
            }
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
            .onChange(of: lines.count) { _, _ in
                proxy.scrollTo("logContent", anchor: .bottom)
            }
            .onAppear {
                proxy.scrollTo("logContent", anchor: .bottom)
            }
        }
    }
}

/// A titled list of detected HID endpoints, or an explanation when none are visible.
struct EndpointGroup: View {
    let title: String
    let emptyTitle: String
    let emptyDetail: String
    let endpoints: [HIDEndpointInfo]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Text("\(endpoints.count)")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }

            if endpoints.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text(emptyTitle)
                        .font(.callout.weight(.semibold))
                    Text(emptyDetail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                ForEach(endpoints) { endpoint in
                    EndpointRow(endpoint: endpoint)
                }
            }
        }
    }
}

struct EndpointRow: View {
    let endpoint: HIDEndpointInfo

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: iconName)
                .foregroundStyle(.tint)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(endpoint.role)
                    .font(.callout.weight(.semibold))
                Text(endpoint.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text(L10n.format("%@ via %@", endpoint.product, endpoint.transport))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
    }

    private var iconName: String {
        if endpoint.role.contains("display") {
            return "display"
        }
        if endpoint.role.contains("2.4G") {
            return "antenna.radiowaves.left.and.right"
        }
        return "cable.connector"
    }
}

/// Tracks whether the app's window can actually be seen. Animations use it to
/// stop drawing while the window is minimised, hidden or fully covered, which
/// `onDisappear` does not report.
private struct WindowVisibilityModifier: ViewModifier {
    @Binding var isVisible: Bool

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.didChangeOcclusionStateNotification)) { notification in
                guard let window = notification.object as? NSWindow, window.isVisible || window.isMiniaturized else { return }
                isVisible = window.occlusionState.contains(.visible)
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didHideNotification)) { _ in
                isVisible = false
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didUnhideNotification)) { _ in
                isVisible = true
            }
    }
}

extension View {
    /// Keeps `isVisible` false while the app window cannot be seen.
    func trackingWindowVisibility(_ isVisible: Binding<Bool>) -> some View {
        modifier(WindowVisibilityModifier(isVisible: isVisible))
    }
}

// MARK: - Page layout

/// Shared page geometry so every page lines up with the large page title:
/// the same left inset, the same maximum width, and room at the bottom for
/// the floating status pill.
enum PageLayout {
    static let horizontalInset: CGFloat = 28
    static let maxContentWidth: CGFloat = 1400
    static let bottomClearance: CGFloat = 16
}

extension View {
    /// For scrolling pages built from stacks (Home, Lighting, Screen).
    func pageColumn() -> some View {
        self
            .padding(.horizontal, PageLayout.horizontalInset)
            .padding(.top, 8)
            .padding(.bottom, PageLayout.bottomClearance)
            .frame(maxWidth: PageLayout.maxContentWidth + PageLayout.horizontalInset * 2, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Cards as soft filled panels with no outline. The system GroupBox draws a
/// light border that looks like stray lines on a dark window.
struct CardGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            configuration.label
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            configuration.content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Responsive building blocks

/// Lays its children side by side when the page is wide enough, and stacks
/// them when it is narrow. It measures its own width, so it reacts live as
/// the window is resized.
struct ResponsiveColumns<Content: View>: View {
    /// Below this width the columns stack vertically.
    var breakpoint: CGFloat = 760
    var spacing: CGFloat = 16
    @ViewBuilder let content: Content

    @State private var width: CGFloat = 0

    var body: some View {
        let layout = width >= breakpoint
            ? AnyLayout(HStackLayout(alignment: .top, spacing: spacing))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: spacing))

        layout {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { newWidth in
            width = newWidth
        }
    }
}

/// One setting inside a card: title (and optional explanation) on the left,
/// its control on the right. Replaces grouped `Form` rows, which cap their
/// width and leave wide windows half empty.
struct CardRow<Control: View>: View {
    let title: String
    var detail: String? = nil
    @ViewBuilder let control: Control

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 12)
            control
        }
        .padding(.vertical, 4)
    }
}

/// A card footer line in secondary text.
struct CardFootnote: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
