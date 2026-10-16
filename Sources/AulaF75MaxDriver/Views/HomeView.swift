import SwiftUI

/// The first page: is the keyboard connected, how much battery is left, and
/// shortcuts to the things people do most.
struct HomeView: View {
    @EnvironmentObject private var model: AppViewModel
    @Binding var selection: SidebarPage?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                summaryCard
                ProfileSwitcherRow()
                quickActions
            }
            .pageColumn()
        }
        .scrollBounceBehavior(.basedOnSize)
        .navigationTitle(SidebarPage.home.title)
    }

    private var summaryCard: some View {
        StageBackdrop {
            VStack(spacing: 16) {
                KeyboardStageView(settings: model.lastAppliedLighting ?? Self.idleLighting)
                    .frame(maxHeight: 360)

                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Aula F75 Max")
                            .font(.title2.weight(.semibold))
                        ConnectionRow(
                            isConnected: model.isWiredDevicePresent,
                            connectedText: L10n.text("USB cable connected"),
                            disconnectedText: L10n.text("USB cable not connected")
                        )
                        ConnectionRow(
                            isConnected: model.isDonglePresent,
                            connectedText: L10n.text("2.4G receiver connected"),
                            disconnectedText: L10n.text("2.4G receiver not connected")
                        )
                    }

                    Spacer(minLength: 12)

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(model.batteryPercent.map { "\($0)%" } ?? "--")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(model.batteryStatusColor)
                        Button {
                            model.queryBattery()
                        } label: {
                            Label(L10n.text("Refresh battery"), systemImage: "arrow.clockwise")
                        }
                        .controlSize(.small)
                        .disabled(model.isWorking || !model.isDonglePresent)
                    }
                }
            }
        }
    }

    /// Shown on the Home keyboard until lighting is applied in this session:
    /// a slow, dim white breath that reads as "idle".
    private static let idleLighting = LightingSettings(
        mode: 7, brightness: 2, speed: 2, direction: 0, colorful: false, red: 255, green: 255, blue: 255
    )

    private var quickActions: some View {
        HStack(alignment: .top, spacing: 12) {
            QuickActionTile(
                title: L10n.text("Screen clock"),
                caption: model.isWiredDevicePresent
                    ? L10n.text("Set the keyboard clock to this Mac's time")
                    : L10n.text("Needs the USB cable"),
                systemImage: "clock.arrow.circlepath"
            ) {
                Button(L10n.text("Sync Clock")) {
                    model.syncTime()
                }
                .disabled(model.isWorking || !model.isWiredDevicePresent)
            }

            QuickActionTile(
                title: SidebarPage.lighting.title,
                caption: L10n.text("Effects, colour and brightness"),
                systemImage: SidebarPage.lighting.systemImage
            ) {
                Button(L10n.text("Open Lighting")) {
                    selection = .lighting
                }
            }

            QuickActionTile(
                title: L10n.text("Screen image"),
                caption: L10n.text("Show a picture or GIF on the keyboard display"),
                systemImage: "photo"
            ) {
                Button(L10n.text("Open Screen")) {
                    selection = .screen
                }
            }
        }
    }
}

/// A coloured dot and a sentence saying whether one connection is up.
private struct ConnectionRow: View {
    let isConnected: Bool
    let connectedText: String
    let disconnectedText: String

    var body: some View {
        Label {
            Text(isConnected ? connectedText : disconnectedText)
                .foregroundStyle(.secondary)
        } icon: {
            Circle()
                .fill(isConnected ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
        }
        .font(.callout)
    }
}

/// One equal-width tile on the Home page: icon, title, caption, one button.
private struct QuickActionTile<Action: View>: View {
    let title: String
    let caption: String
    let systemImage: String
    @ViewBuilder let action: Action

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(.tint)
                Text(title)
                    .font(.headline)
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                action
            }
            .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
            .padding(6)
        }
    }
}
