import SwiftUI

/// Troubleshooting and protocol-research tools. Not needed for everyday use,
/// which is why this page sits in the sidebar's Advanced group. Most of these
/// tools report only to the log, so the page shows the log too.
struct DiagnosticsView: View {
    @EnvironmentObject private var model: AppViewModel
    @State private var isConfirmingByteWrite = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ResponsiveColumns(breakpoint: 860) {
                    connectionsCard
                    keymapCard
                }
                logCard
            }
            .pageColumn()
        }
        .scrollBounceBehavior(.basedOnSize)
        .navigationTitle(SidebarPage.diagnostics.title)
        .confirmationDialog(
            L10n.text("Write to the keyboard?"),
            isPresented: $isConfirmingByteWrite
        ) {
            Button(L10n.text("Write"), role: .destructive) {
                model.testKeymapByteWrite()
            }
            Button(L10n.text("Cancel"), role: .cancel) {}
        } message: {
            Text(L10n.text("This changes keymap data on the keyboard. Factory Reset can undo it."))
        }
    }

    private var connectionsCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Button {
                        model.manualRefresh()
                    } label: {
                        Label(L10n.text("Rescan"), systemImage: "arrow.clockwise")
                    }
                    .help(L10n.text("Manual fallback if macOS HID events or permissions lag behind."))

                    Button {
                        model.toggleInputMonitoring()
                    } label: {
                        Label(
                            model.isInputMonitoring ? L10n.text("Stop Input Monitor") : L10n.text("Start Input Monitor"),
                            systemImage: model.isInputMonitoring ? "stop.circle" : "waveform.path"
                        )
                    }
                    .tint(model.isInputMonitoring ? .red : nil)
                    .help(L10n.text("Logs raw HID input reports (key presses, knob clicks) to the log below."))
                }
                .disabled(model.isWorking)

                EndpointGroup(
                    title: L10n.text("Wired USB"),
                    emptyTitle: L10n.text("No wired 0C45:800A endpoints visible."),
                    emptyDetail: L10n.text("Screen upload and time sync need wired mode. macOS may require Input Monitoring for raw HID reports."),
                    endpoints: model.endpoints
                )
                Divider()
                EndpointGroup(
                    title: L10n.text("2.4G Receiver"),
                    emptyTitle: L10n.text("No 05AC:024F receiver endpoints visible."),
                    emptyDetail: L10n.text("Battery, RGB and performance commands need the USB dongle."),
                    endpoints: model.wirelessEndpoints
                )
                CardFootnote(L10n.text("Status updates automatically on USB plug and unplug events."))
            }
        } label: {
            Label(L10n.text("Connections"), systemImage: "cable.connector")
        }
    }

    private var keymapCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                DeviceRequirementNote(.usbCable)
                CardFootnote(L10n.text("For protocol research. Not needed for normal use. The test write sets one byte in one page and zeros the rest of all 9 pages."))

                CardRow(title: L10n.text("Keymap inspector")) {
                    Button {
                        model.dumpKeymap()
                    } label: {
                        Label(L10n.text("Dump Keymap Pages"), systemImage: "arrow.down.doc")
                    }
                }
                Divider()
                CardRow(title: L10n.text("Page")) {
                    Stepper("\(model.keymapTestPageIndex)", value: $model.keymapTestPageIndex, in: 0...8)
                }
                CardRow(title: L10n.text("Byte")) {
                    Stepper("\(model.keymapTestByteOffset)", value: $model.keymapTestByteOffset, in: 0...63)
                }
                CardRow(title: L10n.text("Length")) {
                    Stepper("\(model.keymapTestLength)", value: $model.keymapTestLength, in: 1...64)
                }
                CardRow(title: L10n.text("Value")) {
                    Stepper(String(format: "0x%02X", model.keymapTestValue), value: $model.keymapTestValue, in: 0...255)
                }
                HStack {
                    Spacer()
                    Button(role: .destructive) {
                        isConfirmingByteWrite = true
                    } label: {
                        Label(L10n.text("Write Test Byte…"), systemImage: "pencil.and.outline")
                    }
                }
            }
            .disabled(model.isWorking || !model.isWiredDevicePresent)
        } label: {
            Label(L10n.text("Keymap Research"), systemImage: "doc.text.magnifyingglass")
        }
    }

    private var logCard: some View {
        GroupBox {
            LogTextView(lines: model.logLines)
                .frame(height: 200)
        } label: {
            Label(SidebarPage.activityLog.title, systemImage: SidebarPage.activityLog.systemImage)
        }
    }
}
