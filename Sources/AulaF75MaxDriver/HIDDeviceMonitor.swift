import Foundation
import IOKit.hid

@MainActor
final class HIDDeviceMonitor {
    var onDevicesChanged: (() -> Void)?

    private let manager: IOHIDManager
    private var debounceTask: Task<Void, Never>?
    private var isStarted = false

    init() {
        manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
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

        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(
            manager,
            { context, _, _, _ in
                HIDDeviceMonitor.notifyDeviceChange(context)
            },
            context
        )
        IOHIDManagerRegisterDeviceRemovalCallback(
            manager,
            { context, _, _, _ in
                HIDDeviceMonitor.notifyDeviceChange(context)
            },
            context
        )
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    }

    func stop() {
        guard isStarted else {
            debounceTask?.cancel()
            debounceTask = nil
            return
        }
        debounceTask?.cancel()
        debounceTask = nil
        IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        isStarted = false
    }

    private static func notifyDeviceChange(_ context: UnsafeMutableRawPointer?) {
        guard let context else { return }
        Task { @MainActor in
            let monitor = Unmanaged<HIDDeviceMonitor>.fromOpaque(context).takeUnretainedValue()
            monitor.scheduleDebouncedNotification()
        }
    }

    private func scheduleDebouncedNotification() {
        debounceTask?.cancel()
        debounceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            self?.onDevicesChanged?()
        }
    }
}
