import AppKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class AppViewModel: ObservableObject {
    struct AppLanguage: Identifiable, Hashable {
        let code: String
        let flag: String
        let name: String

        var id: String { code }
    }

    private enum DeviceRefreshReason {
        case initial
        case hidEvent
        case manual
        case operationFinished
    }

    private struct DeviceEndpointSnapshot: Equatable {
        let wiredCount: Int
        let dongleCount: Int
    }

    @Published var endpoints: [HIDEndpointInfo] = []
    @Published var wirelessEndpoints: [HIDEndpointInfo] = []
    @Published var logLines: [String] = []
    @Published var isWorking = false
    @Published var selectedFile: URL? {
        didSet { refreshScreenPreview() }
    }
    @Published var slot = 1
    @Published var fitMode: ScreenFitMode = .contain {
        didSet { refreshScreenPreview() }
    }
    /// The selected image exactly as the keyboard screen will show it.
    @Published private(set) var screenPreviewFrames: [ScreenPreviewFrame] = []
    @Published private(set) var isPreparingScreenPreview = false
    private var screenPreviewTask: Task<Void, Never>?
    @Published var progress = DisplayUploadProgress(sentChunks: 0, totalChunks: 0)
    @Published var batteryPercent: Int?
    @Published var rgbMode = 11
    @Published var rgbBrightness = 5
    @Published var rgbSpeed = 3
    @Published var rgbDirection = 0
    @Published var rgbColor = Color.blue
    @Published var rgbColorful = true
    /// The lighting last sent successfully in this session, or nil if none
    /// was sent yet. Drives the "not applied" badge and the Revert button.
    @Published private(set) var lastAppliedLighting: LightingSettings?
    /// The lighting controls' values when the app started, so "has the user
    /// edited anything yet?" can be answered before anything is applied.
    private(set) var launchLighting: LightingSettings?
    @Published var keyResponseLevel = 1
    @Published var sleepTime = 1
    @Published var gameModeEnabled = false
    @Published var launchAtLoginEnabled = LaunchAtLogin.isEnabled
    @Published var selectedLanguageCode: String
    @Published var isInputMonitoring = false
    @Published var keymapTestPageIndex = 8
    @Published var keymapTestByteOffset = 0
    @Published var keymapTestLength = 32
    @Published var keymapTestValue = 0xcd

    private let batteryRefreshIntervalNanoseconds: UInt64 = 300_000_000_000
    private let batteryNotificationService = BatteryNotificationService.shared
    private var deviceMonitor: HIDDeviceMonitor?
    private var inputMonitor: HIDInputMonitor?
    private var batteryRefreshTask: Task<Void, Never>?
    private var lastEndpointSnapshot: DeviceEndpointSnapshot?

    let availableLanguages: [AppLanguage] = [
        AppLanguage(code: "system", flag: "🌐", name: "System default"),
        AppLanguage(code: "en", flag: "🇺🇸", name: "English"),
        AppLanguage(code: "ru", flag: "🇷🇺", name: "Русский"),
        AppLanguage(code: "es", flag: "🇪🇸", name: "Español"),
        AppLanguage(code: "uz", flag: "🇺🇿", name: "O'zbekcha"),
        AppLanguage(code: "kk", flag: "🇰🇿", name: "Қазақша"),
        AppLanguage(code: "pt", flag: "🇵🇹", name: "Português"),
        AppLanguage(code: "zh-Hans", flag: "🇨🇳", name: "简体中文")
    ]

    var sortedAvailableLanguages: [AppLanguage] {
        availableLanguages.sorted { lhs, rhs in
            if lhs.code == "system" { return true }
            if rhs.code == "system" { return false }
            return lhs.code < rhs.code
        }
    }

    init() {
        let storedCode = UserDefaults.standard.string(forKey: "app.language.code") ?? "system"
        selectedLanguageCode = L10n.configure(languageCode: storedCode)
        launchLighting = lightingSettings
    }

    var isWiredDevicePresent: Bool {
        !endpoints.isEmpty
    }

    var isDonglePresent: Bool {
        !wirelessEndpoints.isEmpty
    }

    var selectedLanguageName: String {
        if selectedLanguageCode == "system" {
            return L10n.text("System default")
        }
        return availableLanguages.first { $0.code == selectedLanguageCode }?.name ?? L10n.text("System default")
    }

    var selectedLanguageFlag: String {
        availableLanguages.first { $0.code == selectedLanguageCode }?.flag ?? "🌐"
    }

    var batteryStatusColor: Color {
        guard let percent = batteryPercent else {
            return isDonglePresent ? .orange : .secondary
        }
        if percent <= 20 {
            return .red
        }
        if percent <= 50 {
            return .orange
        }
        return .green
    }

    var isWiredControlPresent: Bool {
        endpoints.contains { $0.usagePage == AulaConstants.wiredCommandUsagePage }
    }

    var selectedFileName: String {
        selectedFile?.lastPathComponent ?? "No file selected"
    }

    func startMonitoring() {
        guard deviceMonitor == nil else { return }
        batteryNotificationService.requestAuthorization()
        refreshDeviceState(reason: .initial)

        let monitor = HIDDeviceMonitor()
        monitor.onDevicesChanged = { [weak self] in
            self?.refreshDeviceState(reason: .hidEvent)
        }
        monitor.start()
        deviceMonitor = monitor
    }

    func stopMonitoring() {
        deviceMonitor?.stop()
        deviceMonitor = nil
        inputMonitor?.stop()
        inputMonitor = nil
        isInputMonitoring = false
        stopBatteryRefreshTimer()
    }

    func toggleInputMonitoring() {
        if isInputMonitoring {
            inputMonitor?.stop()
            inputMonitor = nil
            isInputMonitoring = false
            appendLog(L10n.text("Input monitor stopped."))
            return
        }

        let monitor = HIDInputMonitor()
        monitor.onReport = { [weak self] report in
            guard let self else { return }
            self.appendLog(self.formatInputReport(report))
        }
        monitor.onOpenFailure = { [weak self] label, result in
            self?.appendLog(L10n.format("Input monitor: failed to open %@ (IOReturn 0x%08x).", L10n.text(label), UInt32(bitPattern: result)))
        }

        let (opened, total) = monitor.start()
        inputMonitor = monitor
        isInputMonitoring = true
        appendLog(L10n.format("Input monitor started: %d/%d interface(s) opened. Press keys or the knob to see raw reports below.", opened, total))
    }

    func setLanguage(_ languageCode: String) {
        guard selectedLanguageCode != languageCode else { return }
        selectedLanguageCode = L10n.configure(languageCode: languageCode)
    }

    func manualRefresh() {
        refreshDeviceState(reason: .manual)
    }

    func refresh() {
        manualRefresh()
    }

    /// Image types the keyboard screen upload accepts.
    static let screenImageTypes: [UTType] = [
        .png,
        .jpeg,
        .gif,
        .bmp,
        .tiff,
        UTType(filenameExtension: "webp") ?? .image
    ]

    func chooseFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = Self.screenImageTypes

        if panel.runModal() == .OK {
            selectedFile = panel.url
            appendLog(L10n.format("Selected %@.", panel.url?.lastPathComponent ?? L10n.text("image")))
        }
    }

    /// Selects an image dropped onto the Screen page, if it is a supported type.
    func selectImage(at url: URL) {
        let type = UTType(filenameExtension: url.pathExtension)
        guard let type, Self.screenImageTypes.contains(where: { type.conforms(to: $0) }) else {
            appendLog(L10n.format("%@ is not a supported image.", url.lastPathComponent))
            return
        }
        selectedFile = url
        appendLog(L10n.format("Selected %@.", url.lastPathComponent))
    }

    /// Re-encodes the selected image with the current fit mode, off the main
    /// thread, and decodes it back so the preview matches the upload exactly.
    func refreshScreenPreview() {
        screenPreviewTask?.cancel()
        guard let url = selectedFile else {
            screenPreviewFrames = []
            isPreparingScreenPreview = false
            return
        }

        let fit = fitMode
        isPreparingScreenPreview = true
        screenPreviewTask = Task { @MainActor [weak self] in
            let frames = await Task.detached(priority: .userInitiated) {
                do {
                    let stream = try DisplayEncoder.encodeImage(at: url, fitMode: fit)
                    return ScreenPreviewDecoder.frames(from: stream)
                } catch {
                    return [ScreenPreviewFrame]()
                }
            }.value
            // A newer preview may have cancelled this task while encoding.
            guard !Task.isCancelled else { return }
            self?.screenPreviewFrames = frames
            self?.isPreparingScreenPreview = false
        }
    }

    func syncTime() {
        runTask(startMessage: L10n.text("Syncing keyboard clock...")) {
            let device = try AulaDevice.connect()
            try device.syncTime()
            return L10n.text("Keyboard clock synced.")
        }
    }

    func dumpKeymap() {
        runTask(startMessage: L10n.text("Reading keymap pages (read-only, no write)...")) {
            let device = try AulaDevice.connect()
            let pages = try device.inspectKeymapPages()
            let lines = pages.enumerated().map { index, page in
                "  page \(index): \(page.map { String(format: "%02x", $0) }.joined(separator: " "))"
            }
            return L10n.format("Keymap dump (%d pages):\n%@", pages.count, lines.joined(separator: "\n"))
        }
    }

    func testKeymapByteWrite() {
        let pageIndex = keymapTestPageIndex
        let byteOffset = keymapTestByteOffset
        let length = max(1, keymapTestLength)
        let end = min(byteOffset + length, AulaConstants.commandLength)
        let value = UInt8(clamping: keymapTestValue)

        runTask(startMessage: L10n.format("Writing keymap page %d bytes %d-%d = 0x%02x (rest of all 9 pages zero)...", pageIndex, byteOffset, end - 1, value)) {
            var pages = (0..<9).map { _ in [UInt8](repeating: 0, count: AulaConstants.commandLength) }
            for i in byteOffset..<end {
                pages[pageIndex][i] = value
            }

            let device = try AulaDevice.connect()
            try device.writeKeymapPages(pages)
            return L10n.format("Wrote page %d bytes %d-%d = 0x%02x. Click the knob now and check the log above.", pageIndex, byteOffset, end - 1, value)
        }
    }

    func uploadSelectedImage() {
        guard let selectedFile else {
            appendLog(L10n.text("Select an image or GIF first."))
            return
        }

        let targetSlot = slot
        let targetFit = fitMode
        progress = DisplayUploadProgress(sentChunks: 0, totalChunks: 0)

        runTask(startMessage: L10n.format("Encoding %@...", selectedFile.lastPathComponent)) {
            let encoded = try DisplayEncoder.encodeImage(at: selectedFile, fitMode: targetFit)
            await MainActor.run {
                self.appendLog(L10n.format("Encoded %d frame(s), %d chunk(s).", encoded.frameCount, encoded.chunkCount))
                self.progress = DisplayUploadProgress(sentChunks: 0, totalChunks: encoded.chunkCount)
            }

            let device = try AulaDevice.connect()
            try device.uploadDisplayStream(encoded.data, slot: targetSlot) { progress in
                Task { @MainActor in
                    self.progress = progress
                }
            }
            return L10n.format("Uploaded %d frame(s) to slot %d.", encoded.frameCount, targetSlot)
        }
    }

    func factoryReset() {
        let alert = NSAlert()
        alert.messageText = L10n.text("Factory reset Aula F75 Max?")
        alert.informativeText = L10n.text("This clears display slots and resets keyboard configuration blocks used by the current CLI implementation.")
        alert.alertStyle = .warning
        alert.addButton(withTitle: L10n.text("Reset"))
        alert.addButton(withTitle: L10n.text("Cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else {
            appendLog(L10n.text("Factory reset cancelled."))
            return
        }

        runTask(startMessage: L10n.text("Starting factory reset...")) {
            let device = try AulaDevice.connect()
            try device.factoryReset { message in
                Task { @MainActor in
                    self.appendLog(message)
                }
            }
            return L10n.text("Factory reset complete.")
        }
    }

    func queryBattery() {
        requestBattery(logActivity: true)
    }

    /// The lighting controls' current values as one comparable value.
    var lightingSettings: LightingSettings {
        let packed = rgbColor.rgbInteger
        return LightingSettings(
            mode: rgbMode,
            brightness: rgbBrightness,
            speed: rgbSpeed,
            direction: rgbDirection,
            colorful: rgbColorful,
            red: (packed >> 16) & 0xff,
            green: (packed >> 8) & 0xff,
            blue: packed & 0xff
        )
    }

    /// True when the controls differ from what was last sent to the keyboard.
    var hasUnappliedLighting: Bool {
        lastAppliedLighting != lightingSettings
    }

    /// Puts saved lighting values (a profile, or Revert) into the controls.
    /// Sends nothing; call `applyRGB()` for that.
    func loadLighting(_ settings: LightingSettings) {
        rgbMode = settings.mode
        rgbBrightness = settings.brightness
        rgbSpeed = settings.speed
        rgbDirection = settings.direction
        rgbColorful = settings.colorful
        rgbColor = Color(
            .sRGB,
            red: Double(settings.red) / 255,
            green: Double(settings.green) / 255,
            blue: Double(settings.blue) / 255
        )
    }

    func applyRGB() {
        let applied = lightingSettings
        let mode = rgbMode
        let brightness = rgbBrightness
        let speed = rgbSpeed
        let direction = rgbDirection
        let colorful = rgbColorful
        let color = rgbColor.rgbInteger

        runTask(startMessage: L10n.text("Applying RGB lighting...")) {
            let device = try WirelessAulaDevice.connect()
            try device.applyRGB(
                mode: mode,
                brightness: brightness,
                speed: speed,
                direction: direction,
                colorful: colorful,
                color: color
            )
            await MainActor.run {
                self.lastAppliedLighting = applied
            }
            let colorText = colorful ? L10n.text("Colorful") : String(format: "#%06X", color)
            return L10n.format(
                "RGB set: %@ B%d S%d %@ %@.",
                WirelessAulaLabels.rgbModeTitle(mode),
                brightness,
                speed,
                WirelessAulaLabels.directionTitle(direction),
                colorText
            )
        }
    }

    func applyPerformance() {
        let level = keyResponseLevel
        let sleep = sleepTime
        runTask(startMessage: L10n.text("Applying performance settings...")) {
            let device = try WirelessAulaDevice.connect()
            try device.applyPerformance(level: level, sleepTime: sleep)
            return L10n.format(
                "Performance set: %@, sleep %@.",
                WirelessAulaLabels.keyResponseTitle(level),
                WirelessAulaLabels.sleepTitle(sleep)
            )
        }
    }

    func restoreCommandKey() {
        let level = keyResponseLevel
        let sleep = sleepTime
        runTask(startMessage: L10n.text("Restoring Command key / clearing lock...")) {
            let device = try WirelessAulaDevice.connect()
            try device.applyPerformance(level: level, sleepTime: sleep)
            return L10n.text("Command key restore sent; Fn layer unlocked.")
        }
    }

    func setGameMode(_ enabled: Bool) {
        let level = keyResponseLevel
        let sleep = sleepTime
        runTask(startMessage: L10n.format("Setting Game Mode %@...", enabled ? L10n.text("On") : L10n.text("Off"))) {
            let device = try WirelessAulaDevice.connect()
            try device.setGameMode(enabled: enabled, level: level, sleepTime: sleep)
            await MainActor.run {
                self.gameModeEnabled = enabled
            }
            return enabled ? L10n.text("Game Mode enabled.") : L10n.text("Game Mode disabled.")
        }
    }

    func toggleLaunchAtLogin() {
        do {
            let message = try LaunchAtLogin.setEnabled(!launchAtLoginEnabled)
            launchAtLoginEnabled = LaunchAtLogin.isEnabled
            appendLog(message)
        } catch {
            appendLog(L10n.format("Launch at Login error: %@.", error.localizedDescription))
        }
    }

    private func runTask(startMessage: String, operation: @escaping @Sendable () async throws -> String) {
        guard !isWorking else {
            appendLog(L10n.text("Another operation is already running."))
            return
        }

        isWorking = true
        appendLog(startMessage)

        Task.detached(priority: .userInitiated) {
            do {
                let message = try await operation()
                await MainActor.run {
                    self.appendLog(message)
                    self.isWorking = false
                    self.refreshDeviceState(reason: .operationFinished)
                }
            } catch {
                await MainActor.run {
                    self.appendLog(L10n.format("Error: %@.", error.localizedDescription))
                    self.isWorking = false
                    self.refreshDeviceState(reason: .operationFinished)
                }
            }
        }
    }

    private func refreshDeviceState(reason: DeviceRefreshReason) {
        let wasDonglePresent = isDonglePresent
        endpoints = AulaDevice.scanEndpoints()
        wirelessEndpoints = WirelessAulaDevice.scanEndpoints()
        launchAtLoginEnabled = LaunchAtLogin.isEnabled

        let snapshot = DeviceEndpointSnapshot(
            wiredCount: endpoints.count,
            dongleCount: wirelessEndpoints.count
        )
        let changed = snapshot != lastEndpointSnapshot
        let dongleAppeared = !wasDonglePresent && isDonglePresent
        let dongleDisappeared = wasDonglePresent && !isDonglePresent

        switch reason {
        case .initial:
            appendLog(L10n.format("Device monitor started. %@.", deviceStateSummary(snapshot)))
        case .manual:
            appendLog(L10n.format("Manual rescan complete. %@.", deviceStateSummary(snapshot)))
        case .hidEvent, .operationFinished:
            if changed {
                appendLog(L10n.format("Device status changed. %@.", deviceStateSummary(snapshot)))
            }
        }

        lastEndpointSnapshot = snapshot

        if dongleDisappeared {
            batteryPercent = nil
            stopBatteryRefreshTimer()
        }

        if isDonglePresent {
            startBatteryRefreshTimer()
            if reason != .operationFinished && (dongleAppeared || batteryPercent == nil) {
                requestBattery(logActivity: false)
            }
        }
    }

    private func deviceStateSummary(_ snapshot: DeviceEndpointSnapshot) -> String {
        let wired = snapshot.wiredCount == 0
            ? L10n.text("wired disconnected")
            : L10n.format("wired %d endpoint(s)", snapshot.wiredCount)
        let dongle = snapshot.dongleCount == 0
            ? L10n.text("2.4G disconnected")
            : L10n.format("2.4G %d endpoint(s)", snapshot.dongleCount)
        return L10n.format("%@, %@.", wired, dongle)
    }

    private func startBatteryRefreshTimer() {
        guard batteryRefreshTask == nil else { return }
        batteryRefreshTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: self?.batteryRefreshIntervalNanoseconds ?? 300_000_000_000)
                guard !Task.isCancelled, let self else { return }
                guard self.isDonglePresent else {
                    self.stopBatteryRefreshTimer()
                    return
                }
                guard !self.isWorking else { continue }
                self.requestBattery(logActivity: false)
            }
        }
    }

    private func stopBatteryRefreshTimer() {
        batteryRefreshTask?.cancel()
        batteryRefreshTask = nil
    }

    private func requestBattery(logActivity: Bool) {
        guard !isWorking else {
            if logActivity {
                appendLog(L10n.text("Another operation is already running."))
            }
            return
        }
        guard isDonglePresent else {
            batteryPercent = nil
            if logActivity {
                appendLog(L10n.text("Connect the 2.4G dongle before querying battery."))
            }
            return
        }

        isWorking = true
        if logActivity {
            appendLog(L10n.text("Querying keyboard battery..."))
        }

        Task.detached(priority: logActivity ? .userInitiated : .utility) {
            do {
                let device = try WirelessAulaDevice.connect()
                let percent = try device.queryBattery()
                await MainActor.run {
                    let previousPercent = self.batteryPercent
                    self.batteryPercent = percent
                    self.batteryNotificationService.handleBatteryUpdate(
                        previousPercent: previousPercent,
                        currentPercent: percent
                    )
                    if logActivity {
                        if let percent {
                            self.appendLog(L10n.format("Battery: %d%%.", percent))
                        } else {
                            self.appendLog(L10n.text("Battery query sent, but no percentage report was received."))
                        }
                    } else if let percent, let previousPercent, percent != previousPercent {
                        self.appendLog(L10n.format("Battery changed: %d%%.", percent))
                    }
                    self.isWorking = false
                    self.refreshDeviceState(reason: .operationFinished)
                }
            } catch {
                await MainActor.run {
                    if logActivity {
                        self.appendLog(L10n.format("Battery error: %@.", error.localizedDescription))
                    }
                    self.isWorking = false
                    self.refreshDeviceState(reason: .operationFinished)
                }
            }
        }
    }

    private func appendLog(_ message: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        logLines.append("[\(formatter.string(from: Date()))] \(message)")
        if logLines.count > 200 {
            logLines.removeFirst(logLines.count - 200)
        }
    }

    private func formatInputReport(_ report: HIDInputMonitor.Report) -> String {
        let limit = 32
        var hex = report.bytes.isEmpty
            ? "(empty)"
            : report.bytes.prefix(limit).map { String(format: "%02x", $0) }.joined(separator: " ")
        if report.bytes.count > limit {
            hex += " …(\(report.bytes.count)B)"
        }
        return L10n.format("Input: %@ rid=%d %@", L10n.text(report.deviceLabel), report.reportID, hex)
    }
}

private extension Color {
    var rgbInteger: Int {
        let nsColor = NSColor(self).usingColorSpace(.sRGB) ?? .blue
        let red = max(0, min(255, Int((nsColor.redComponent * 255.0).rounded())))
        let green = max(0, min(255, Int((nsColor.greenComponent * 255.0).rounded())))
        let blue = max(0, min(255, Int((nsColor.blueComponent * 255.0).rounded())))
        return (red << 16) | (green << 8) | blue
    }
}
