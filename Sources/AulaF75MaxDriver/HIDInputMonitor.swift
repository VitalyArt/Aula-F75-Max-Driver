import Foundation
import IOKit.hid

@MainActor
final class HIDInputMonitor {
    struct Report: Sendable {
        let deviceLabel: String
        let reportID: Int
        let bytes: [UInt8]
    }

    var onReport: ((Report) -> Void)?
    var onOpenFailure: ((String, IOReturn) -> Void)?

    private var openedDevices: [OpenedInputDevice] = []
    private(set) var isActive = false

    @discardableResult
    func start() -> (opened: Int, total: Int) {
        guard !isActive else { return (openedDevices.count, openedDevices.count) }
        isActive = true

        let candidates = Self.matchingDevices()
        for device in candidates {
            let label = Self.label(for: device)
            let result = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
            guard result == kIOReturnSuccess else {
                onOpenFailure?(label, result)
                continue
            }

            let bufferSize = max(Self.intProperty(device, kIOHIDMaxInputReportSizeKey), 64)
            let opened = OpenedInputDevice(device: device, label: label, bufferSize: bufferSize, monitor: self)
            opened.register()
            openedDevices.append(opened)
        }

        return (openedDevices.count, candidates.count)
    }

    func stop() {
        guard isActive else { return }
        for opened in openedDevices {
            opened.close()
        }
        openedDevices.removeAll()
        isActive = false
    }

    fileprivate func deliver(_ report: Report) {
        onReport?(report)
    }

    private static func matchingDevices() -> [IOHIDDevice] {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let matching: [[String: Any]] = [
            [
                kIOHIDVendorIDKey: AulaConstants.wiredVendorID,
                kIOHIDProductIDKey: AulaConstants.wiredProductID
            ],
            [
                kIOHIDVendorIDKey: AulaConstants.dongleVendorID,
                kIOHIDProductIDKey: AulaConstants.dongleProductID
            ]
        ]
        IOHIDManagerSetDeviceMatchingMultiple(manager, matching as CFArray)
        _ = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        defer {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        }

        guard let deviceSet = IOHIDManagerCopyDevices(manager) else {
            return []
        }
        let count = CFSetGetCount(deviceSet)
        var rawValues = [UnsafeRawPointer?](repeating: nil, count: count)
        CFSetGetValues(deviceSet, &rawValues)
        return rawValues.compactMap { value in
            guard let value else { return nil }
            return Unmanaged<IOHIDDevice>.fromOpaque(value).retain().takeRetainedValue()
        }
        .sorted {
            if usagePage($0) != usagePage($1) { return usagePage($0) < usagePage($1) }
            return usage($0) < usage($1)
        }
    }

    private static func label(for device: IOHIDDevice) -> String {
        let vendorID = intProperty(device, kIOHIDVendorIDKey)
        let productID = intProperty(device, kIOHIDProductIDKey)
        let page = usagePage(device)
        let use = usage(device)

        if vendorID == AulaConstants.dongleVendorID && productID == AulaConstants.dongleProductID {
            if page == AulaConstants.wirelessCommandUsagePage { return "2.4G command" }
            if page == AulaConstants.wirelessRawUsagePage { return "2.4G raw" }
        }
        if page == AulaConstants.wiredCommandUsagePage { return "Wired command" }
        if page == AulaConstants.wiredRawUsagePage { return "Wired display" }
        if page == 0x0001 && use == 0x0006 { return "Keyboard" }
        if page == 0x000c { return "Media" }
        return "HID 0x\(String(page, radix: 16))/0x\(String(use, radix: 16))"
    }

    private static func intProperty(_ device: IOHIDDevice, _ key: String) -> Int {
        guard let value = IOHIDDeviceGetProperty(device, key as CFString) else {
            return 0
        }
        if CFGetTypeID(value) == CFNumberGetTypeID() {
            return (value as! NSNumber).intValue
        }
        return 0
    }

    private static func usagePage(_ device: IOHIDDevice) -> Int {
        let primary = intProperty(device, kIOHIDPrimaryUsagePageKey)
        return primary != 0 ? primary : intProperty(device, kIOHIDDeviceUsagePageKey)
    }

    private static func usage(_ device: IOHIDDevice) -> Int {
        let primary = intProperty(device, kIOHIDPrimaryUsageKey)
        return primary != 0 ? primary : intProperty(device, kIOHIDDeviceUsageKey)
    }
}

private final class OpenedInputDevice {
    let device: IOHIDDevice
    let label: String
    weak var monitor: HIDInputMonitor?
    private var buffer: [UInt8]

    init(device: IOHIDDevice, label: String, bufferSize: Int, monitor: HIDInputMonitor) {
        self.device = device
        self.label = label
        self.monitor = monitor
        self.buffer = [UInt8](repeating: 0, count: bufferSize)
    }

    func register() {
        let context = Unmanaged.passUnretained(self).toOpaque()
        buffer.withUnsafeMutableBufferPointer { pointer in
            IOHIDDeviceRegisterInputReportCallback(
                device,
                pointer.baseAddress!,
                pointer.count,
                { context, result, _, _, reportID, report, reportLength in
                    guard result == kIOReturnSuccess, let context, reportLength > 0 else {
                        return
                    }
                    let bytes = Array(UnsafeBufferPointer(start: report, count: reportLength))
                    OpenedInputDevice.handleReport(context: context, reportID: Int(reportID), bytes: bytes)
                },
                context
            )
        }
        IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
    }

    func close() {
        IOHIDDeviceUnscheduleFromRunLoop(device, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
    }

    private static func handleReport(context: UnsafeMutableRawPointer, reportID: Int, bytes: [UInt8]) {
        let opened = Unmanaged<OpenedInputDevice>.fromOpaque(context).takeUnretainedValue()
        let label = opened.label
        let monitor = opened.monitor
        Task { @MainActor in
            monitor?.deliver(HIDInputMonitor.Report(deviceLabel: label, reportID: reportID, bytes: bytes))
        }
    }
}
