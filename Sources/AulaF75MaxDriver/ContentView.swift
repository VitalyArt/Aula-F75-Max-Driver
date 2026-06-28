import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppViewModel

    private let pageWidth: CGFloat = 1120
    private let windowWidth: CGFloat = 1216
    private let titleBarContentInset: CGFloat = 54

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    connectionOverview
                    mainGrid
                    logPanel
                }
                .frame(maxWidth: pageWidth, alignment: .leading)
                .padding(.horizontal, 28)
                .padding(.top, titleBarContentInset)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.visible)
        }
        .frame(minWidth: windowWidth, maxWidth: windowWidth, minHeight: 760)
        .onAppear {
            model.startMonitoring()
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.text("Aula F75 Max Driver"))
                    .font(.custom("Avenir Next Condensed", size: 46).weight(.heavy))
                    .foregroundStyle(.white)

                Text(L10n.text("One focused control surface for USB screen tasks and 2.4G keyboard settings."))
                    .font(.custom("Avenir Next", size: 15))
                    .foregroundStyle(.white.opacity(0.68))
            }

            Spacer()

            StatusPill(
                title: model.isWorking ? "Working" : "Ready",
                systemImage: model.isWorking ? "hourglass" : "checkmark.circle.fill",
                color: model.isWorking ? .orange : .green
            )
        }
    }

    private var connectionOverview: some View {
        HStack(spacing: 14) {
            StatusCard(
                title: L10n.text("Wired USB"),
                value: model.isWiredDevicePresent ? L10n.format("%d endpoint(s)", model.endpoints.count) : L10n.text("Not connected"),
                detail: model.isWiredDevicePresent ? L10n.text("Required for clock sync and display upload.") : L10n.text("Connect the keyboard by USB-C."),
                systemImage: "cable.connector",
                color: model.isWiredDevicePresent ? .green : .orange
            )

            StatusCard(
                title: L10n.text("2.4G Dongle"),
                value: model.isDonglePresent ? L10n.format("%d endpoint(s)", model.wirelessEndpoints.count) : L10n.text("Not connected"),
                detail: model.isDonglePresent ? L10n.text("Required for battery, RGB and performance.") : L10n.text("Plug in the 2.4G receiver."),
                systemImage: "antenna.radiowaves.left.and.right",
                color: model.isDonglePresent ? .green : .orange
            )

            StatusCard(
                title: L10n.text("Battery"),
                value: model.batteryPercent.map { L10n.format("%d%%", $0) } ?? L10n.text("Unknown"),
                detail: model.isDonglePresent ? L10n.text("Query over the 2.4G dongle.") : L10n.text("Battery is unavailable without the dongle."),
                systemImage: "battery.75percent",
                color: model.batteryStatusColor
            )
        }
    }

    private var mainGrid: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(spacing: 18) {
                wiredPanel
                endpointsPanel
            }
            .frame(width: 548)

            VStack(spacing: 18) {
                wirelessPanel
                systemPanel
            }
            .frame(width: 548)
        }
    }

    private var wiredPanel: some View {
        Panel(
            title: L10n.text("USB Screen Workflow"),
            subtitle: model.isWiredDevicePresent ? L10n.text("Ready for wired operations") : L10n.text("Connect USB-C before running these actions"),
            systemImage: "display"
        ) {
            VStack(alignment: .leading, spacing: 16) {
                ActionHeader(
                    title: L10n.text("Keyboard clock"),
                    detail: L10n.text("Sync the screen clock to local macOS time."),
                    systemImage: "clock.arrow.circlepath"
                )

                Button {
                    model.syncTime()
                } label: {
                    Label(L10n.text("Sync Clock"), systemImage: "clock.arrow.circlepath")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(model.isWorking || !model.isWiredDevicePresent)

                SectionDivider()

                ActionHeader(
                    title: L10n.text("Screen upload"),
                    detail: L10n.text("Prepare a PNG, JPEG, GIF, BMP, TIFF or WebP for the 128 x 128 keyboard display."),
                    systemImage: "photo.on.rectangle"
                )

                HStack(spacing: 10) {
                    Button {
                        model.chooseFile()
                    } label: {
                        Label(L10n.text("Choose File"), systemImage: "folder")
                    }
                    .disabled(model.isWorking || !model.isWiredDevicePresent)

                    Text(model.selectedFileName)
                        .font(.callout)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(model.selectedFile == nil ? .white.opacity(0.45) : .white.opacity(0.78))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                }

                HStack(spacing: 16) {
                    Stepper("\(L10n.text("Slot")) \(model.slot)", value: $model.slot, in: 1...255)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Picker(L10n.text("Fit"), selection: $model.fitMode) {
                        ForEach(ScreenFitMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 230)
                }
                .foregroundStyle(.white.opacity(0.88))

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                        Text(L10n.text("Upload progress"))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.52))
                        Spacer()
                        Text(uploadProgressText)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.white.opacity(0.62))
                    }

                    ProgressView(value: model.progress.fraction)
                        .tint(.orange)
                }

                Button {
                    model.uploadSelectedImage()
                } label: {
                    Label(L10n.text("Upload to Keyboard Screen"), systemImage: "display.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(model.isWorking || model.selectedFile == nil || !model.isWiredDevicePresent)

                SectionDivider()

                VStack(alignment: .leading, spacing: 10) {
                    ActionHeader(
                        title: L10n.text("Factory reset"),
                        detail: L10n.text("Clears display slots and configuration blocks touched by this app."),
                        systemImage: "exclamationmark.triangle"
                    )

                    Button(role: .destructive) {
                        model.factoryReset()
                    } label: {
                        Label(L10n.text("Factory Reset Keyboard"), systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(model.isWorking || !model.isWiredDevicePresent)
                }
            }
        }
    }

    private var wirelessPanel: some View {
        Panel(
            title: L10n.text("2.4G Keyboard Control"),
            subtitle: model.isDonglePresent ? L10n.text("Ready for wireless commands") : L10n.text("Plug in the USB receiver before applying settings"),
            systemImage: "keyboard"
        ) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.text("Battery"))
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(model.isDonglePresent ? L10n.text("Read from the receiver endpoint.") : L10n.text("Unavailable until the 2.4G dongle is connected."))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.55))
                    }

                    Spacer()

                    Text(model.batteryPercent.map { "\($0)%" } ?? "--")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(model.batteryStatusColor)

                    Button {
                        model.queryBattery()
                    } label: {
                        Label(L10n.text("Query"), systemImage: "arrow.clockwise")
                    }
                    .disabled(model.isWorking || !model.isDonglePresent)
                }

                SectionDivider()

                ActionHeader(
                    title: L10n.text("RGB lighting"),
                    detail: L10n.text("Preview intent in the controls, then send the full lighting profile to the keyboard."),
                    systemImage: "sparkles"
                )

                VStack(alignment: .leading, spacing: 12) {
                    Picker(L10n.text("Mode"), selection: $model.rgbMode) {
                        ForEach(WirelessAulaLabels.rgbModes) { mode in
                            Text(mode.title).tag(mode.id)
                        }
                    }
                    .id("mode-\(model.selectedLanguageCode)")

                    HStack(spacing: 14) {
                        Stepper("\(L10n.text("Brightness")) \(model.rgbBrightness)", value: $model.rgbBrightness, in: 1...5)
                        Stepper("\(L10n.text("Speed")) \(model.rgbSpeed)", value: $model.rgbSpeed, in: 1...5)
                    }

                    Picker(L10n.text("Direction"), selection: $model.rgbDirection) {
                        ForEach(0...3, id: \.self) { value in
                            Text(WirelessAulaLabels.directionTitle(value)).tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                    .id("direction-\(model.selectedLanguageCode)")

                    HStack(spacing: 14) {
                        Toggle(L10n.text("Colorful animation"), isOn: $model.rgbColorful)
                        ColorPicker(L10n.text("Fixed color"), selection: $model.rgbColor)
                            .disabled(model.rgbColorful)
                    }
                }
                .foregroundStyle(.white.opacity(0.88))
                .disabled(model.isWorking || !model.isDonglePresent)

                Button {
                    model.applyRGB()
                } label: {
                    Label(L10n.text("Apply RGB Profile"), systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(model.isWorking || !model.isDonglePresent)

                SectionDivider()

                ActionHeader(
                    title: L10n.text("Performance"),
                    detail: L10n.text("Tune latency, sleep behavior and game lockout commands."),
                    systemImage: "speedometer"
                )

                VStack(alignment: .leading, spacing: 12) {
                    Picker(L10n.text("Response"), selection: $model.keyResponseLevel) {
                        ForEach(1...5, id: \.self) { value in
                            Text(WirelessAulaLabels.keyResponseTitle(value)).tag(value)
                        }
                    }
                    .id("response-\(model.selectedLanguageCode)")

                    Picker(L10n.text("Sleep"), selection: $model.sleepTime) {
                        ForEach(0...3, id: \.self) { value in
                            Text(WirelessAulaLabels.sleepTitle(value)).tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                    .id("sleep-\(model.selectedLanguageCode)")
                }
                .foregroundStyle(.white.opacity(0.88))
                .disabled(model.isWorking || !model.isDonglePresent)

                HStack(spacing: 10) {
                    Button {
                        model.applyPerformance()
                    } label: {
                        Label(L10n.text("Apply"), systemImage: "checkmark")
                            .frame(maxWidth: .infinity)
                    }

                    Button {
                        model.restoreCommandKey()
                    } label: {
                        Label(L10n.text("Restore Command"), systemImage: "command")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(model.isWorking || !model.isDonglePresent)

                Button {
                    model.setGameMode(!model.gameModeEnabled)
                } label: {
                    Label(
                        model.gameModeEnabled ? L10n.text("Disable Game Mode") : L10n.text("Enable Game Mode"),
                        systemImage: model.gameModeEnabled ? "lock.open" : "gamecontroller"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(model.gameModeEnabled ? .green : .orange)
                .disabled(model.isWorking || !model.isDonglePresent)
            }
        }
    }

    private var endpointsPanel: some View {
        Panel(
            title: L10n.text("Detected HID Endpoints"),
            subtitle: L10n.text("Diagnostic view for permissions and transport troubleshooting"),
            systemImage: "point.3.connected.trianglepath.dotted"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    Text(L10n.text("Status updates automatically on USB plug and unplug events."))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))

                    Spacer()

                    Button {
                        model.manualRefresh()
                    } label: {
                        Label(L10n.text("Rescan"), systemImage: "arrow.clockwise")
                    }
                    .controlSize(.small)
                    .disabled(model.isWorking)
                    .help(L10n.text("Manual fallback if macOS HID events or permissions lag behind."))
                }

                EndpointGroup(
                    title: L10n.text("Wired USB"),
                    emptyTitle: L10n.text("No wired 0C45:800A endpoints visible."),
                    emptyDetail: L10n.text("Screen upload and time sync need wired mode. macOS may require Input Monitoring for raw HID reports."),
                    endpoints: model.endpoints
                )

                EndpointGroup(
                    title: L10n.text("2.4G Receiver"),
                    emptyTitle: L10n.text("No 05AC:024F receiver endpoints visible."),
                    emptyDetail: L10n.text("Battery, RGB and performance commands need the USB dongle."),
                    endpoints: model.wirelessEndpoints
                )
            }
        }
    }

    private var systemPanel: some View {
        Panel(
            title: L10n.text("App Settings"),
            subtitle: L10n.text("Local macOS behavior, independent of keyboard transport"),
            systemImage: "gearshape"
        ) {
            VStack(alignment: .leading, spacing: 14) {
                LanguageSelector(
                    languages: model.sortedAvailableLanguages,
                    selectedCode: model.selectedLanguageCode,
                    selectedFlag: model.selectedLanguageFlag,
                    selectedName: model.selectedLanguageName,
                    selectLanguage: model.setLanguage
                )
                .zIndex(2)

                SectionDivider()
                    .zIndex(0)

                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: "power")
                        .font(.title3)
                        .foregroundStyle(.orange)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(L10n.text("Launch at Login"))
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(L10n.text("Starts the app after macOS sign-in. This does not require the keyboard or dongle."))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.55))
                    }

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { model.launchAtLoginEnabled },
                        set: { _ in model.toggleLaunchAtLogin() }
                    ))
                    .labelsHidden()
                    .disabled(model.isWorking)
                }
                .zIndex(0)

                if model.isWorking {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text(L10n.text("A device command is running. Settings are locked until it finishes."))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.58))
                    }
                }
            }
        }
    }

    private var logPanel: some View {
        Panel(
            title: L10n.text("Operation Log"),
            subtitle: model.isWorking ? L10n.text("Latest command is still running") : L10n.text("Idle"),
            systemImage: "terminal"
        ) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(model.logLines.enumerated()), id: \.offset) { index, line in
                            Text(line)
                                .id(index)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.78))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        if model.logLines.isEmpty {
                            Text(L10n.text("No log entries yet."))
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.45))
                        }
                    }
                    .padding(12)
                }
                .frame(height: 150)
                .background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 14))
                .onChange(of: model.logLines.count) { _, newValue in
                    proxy.scrollTo(max(newValue - 1, 0), anchor: .bottom)
                }
            }
        }
        .frame(maxWidth: pageWidth, alignment: .leading)
    }

    private var uploadProgressText: String {
        guard model.progress.totalChunks > 0 else {
            return L10n.text("0%")
        }
        return L10n.format("%d%%  %d/%d", Int((model.progress.fraction * 100).rounded()), model.progress.sentChunks, model.progress.totalChunks)
    }
}

private struct AppBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.03, green: 0.05, blue: 0.06),
                    Color(red: 0.07, green: 0.11, blue: 0.12),
                    Color(red: 0.14, green: 0.10, blue: 0.04)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(.orange.opacity(0.18))
                .frame(width: 420, height: 420)
                .blur(radius: 80)
                .offset(x: -430, y: -260)

            Circle()
                .fill(.teal.opacity(0.14))
                .frame(width: 520, height: 520)
                .blur(radius: 100)
                .offset(x: 460, y: 180)
        }
        .ignoresSafeArea()
    }
}

private struct StatusPill: View {
    let title: String
    let systemImage: String
    let color: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
            .foregroundStyle(color)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(color.opacity(0.14), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(color.opacity(0.35), lineWidth: 1)
            )
    }
}

private struct StatusCard: View {
    let title: String
    let value: String
    let detail: String
    let systemImage: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 34, height: 34)
                .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.55))
                    .textCase(.uppercase)

                Text(value)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 116, alignment: .topLeading)
        .background(.white.opacity(0.075), in: RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
    }
}

private struct Panel<Content: View>: View {
    let title: String
    let subtitle: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(.orange)
                    .frame(width: 32, height: 32)
                    .background(.orange.opacity(0.13), in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.custom("Avenir Next", size: 18).weight(.bold))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                }

                Spacer()
            }

            content
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.white.opacity(0.08))
                .shadow(color: .black.opacity(0.25), radius: 24, x: 0, y: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
    }
}

private struct ActionHeader: View {
    let title: String
    let detail: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(.orange)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct EndpointGroup: View {
    let title: String
    let emptyTitle: String
    let emptyDetail: String
    let endpoints: [HIDEndpointInfo]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text(L10n.format("%d", endpoints.count))
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.white.opacity(0.58))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.white.opacity(0.08), in: Capsule())
            }

            if endpoints.isEmpty {
                EmptyEndpointState(title: emptyTitle, detail: emptyDetail)
            } else {
                VStack(spacing: 8) {
                    ForEach(endpoints) { endpoint in
                        EndpointRow(endpoint: endpoint)
                    }
                }
            }
        }
    }
}

private struct EmptyEndpointState: View {
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.circle")
                .font(.title3)
                .foregroundStyle(.orange)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.82))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(.orange.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct EndpointRow: View {
    let endpoint: HIDEndpointInfo

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(endpoint.role)
                    .foregroundStyle(.white)
                    .font(.headline)
                Text(endpoint.summary)
                    .foregroundStyle(.white.opacity(0.62))
                    .font(.caption)
                    .lineLimit(2)
                Text(L10n.format("%@ via %@", endpoint.product, endpoint.transport))
                    .foregroundStyle(.white.opacity(0.48))
                    .font(.caption2)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(12)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
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

    private var iconColor: Color {
        endpoint.role.contains("display") || endpoint.role.contains("raw") ? .orange : .teal
    }
}

private struct LanguageSelector: View {
    let languages: [AppViewModel.AppLanguage]
    let selectedCode: String
    let selectedFlag: String
    let selectedName: String
    let selectLanguage: (String) -> Void
    @State private var isLanguagePickerPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                isLanguagePickerPresented.toggle()
            } label: {
                HStack(alignment: .center, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.orange.opacity(0.13))
                        Text(selectedFlag)
                            .font(.title3)
                    }
                    .frame(width: 34, height: 34)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(.orange.opacity(0.24), lineWidth: 1)
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.text("Language"))
                            .font(.headline)
                            .foregroundStyle(.white)

                        Text(selectedName)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .foregroundStyle(.white.opacity(0.92))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(1)

                    ZStack {
                        Circle()
                            .fill(.orange.opacity(isLanguagePickerPresented ? 0.22 : 0.12))
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(.orange.opacity(0.9))
                            .rotationEffect(.degrees(isLanguagePickerPresented ? 180 : 0))
                    }
                    .frame(width: 32, height: 32)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.white.opacity(0.12), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .contentShape(RoundedRectangle(cornerRadius: 12))

            if isLanguagePickerPresented {
                languagePicker
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .zIndex(isLanguagePickerPresented ? 10 : 0)
        .animation(.easeInOut(duration: 0.16), value: isLanguagePickerPresented)
    }

    private var languagePicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(languages) { language in
                Button {
                    selectLanguage(language.code)
                    isLanguagePickerPresented = false
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: selectedCode == language.code ? "checkmark.circle.fill" : "circle")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(selectedCode == language.code ? .orange : .white.opacity(0.22))
                            .frame(width: 16)
                        Text(language.flag)
                            .font(.body)
                        Text(language.code == "system" ? L10n.text(language.name) : language.name)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.92))
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .background(
                        selectedCode == language.code ? .orange.opacity(0.12) : .white.opacity(0.04),
                        in: RoundedRectangle(cornerRadius: 8)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 18, y: 10)
    }
}

private struct SectionDivider: View {
    var body: some View {
        Divider()
            .overlay(.white.opacity(0.18))
    }
}
