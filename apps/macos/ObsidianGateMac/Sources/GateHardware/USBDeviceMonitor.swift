import Foundation
import IOKit
import IOKit.usb

public struct USBDevice: Equatable {
    public let vendorID: Int
    public let productID: Int
    public let productName: String?
    public let serialNumber: String?

    /// Stable enough for diagnostics only; do not use as an authentication credential.
    public var diagnosticDescription: String {
        let name = productName ?? "USB device"
        return String(format: "%@ (VID:%04X PID:%04X)", name, vendorID, productID)
    }
}

public final class USBDeviceMonitor {
    public typealias Handler = (USBDevice, Bool) -> Void // true = connected, false = disconnected

    private let handler: Handler
    private let allowedVendorIDs: Set<Int>?
    private var notificationPort: IONotificationPortRef?
    private var addedIterator: io_iterator_t = 0
    private var removedIterator: io_iterator_t = 0

    public init(allowedVendorIDs: Set<Int>? = nil, handler: @escaping Handler) {
        self.allowedVendorIDs = allowedVendorIDs
        self.handler = handler
    }

    deinit { stop() }

    public func start() throws {
        guard notificationPort == nil else { return }
        guard let port = IONotificationPortCreate(kIOMainPortDefault) else {
            throw USBMonitorError.cannotCreateNotificationPort
        }
        notificationPort = port
        if let source = IONotificationPortGetRunLoopSource(port)?.takeUnretainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        }

        let context = Unmanaged.passUnretained(self).toOpaque()
        let matching = IOServiceMatching(kIOUSBHostDeviceClassName)
        let addStatus = IOServiceAddMatchingNotification(
            port, kIOFirstMatchNotification, matching, Self.notificationCallback,
            context, &addedIterator
        )
        guard addStatus == KERN_SUCCESS else {
            stop()
            throw USBMonitorError.registrationFailed(addStatus)
        }
        drain(addedIterator, connected: true)

        let removalMatching = IOServiceMatching(kIOUSBHostDeviceClassName)
        let removeStatus = IOServiceAddMatchingNotification(
            port, kIOTerminatedNotification, removalMatching, Self.notificationCallback,
            context, &removedIterator
        )
        guard removeStatus == KERN_SUCCESS else {
            stop()
            throw USBMonitorError.registrationFailed(removeStatus)
        }
        drain(removedIterator, connected: false)
    }

    public func stop() {
        if addedIterator != 0 { IOObjectRelease(addedIterator); addedIterator = 0 }
        if removedIterator != 0 { IOObjectRelease(removedIterator); removedIterator = 0 }
        if let port = notificationPort {
            if let source = IONotificationPortGetRunLoopSource(port)?.takeUnretainedValue() {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
            }
            IONotificationPortDestroy(port)
            notificationPort = nil
        }
    }

    private static let notificationCallback: IOServiceMatchingCallback = { context, iterator in
        guard let context else { return }
        let monitor = Unmanaged<USBDeviceMonitor>.fromOpaque(context).takeUnretainedValue()
        monitor.drain(iterator, connected: iterator == monitor.addedIterator)
    }

    private func drain(_ iterator: io_iterator_t, connected: Bool) {
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            guard let device = Self.readDevice(service),
                  allowedVendorIDs == nil || allowedVendorIDs!.contains(device.vendorID) else { continue }
            handler(device, connected)
        }
    }

    private static func readDevice(_ service: io_service_t) -> USBDevice? {
        func number(_ key: String) -> Int? {
            guard let value = IORegistryEntryCreateCFProperty(
                service, key as CFString, kCFAllocatorDefault, 0
            )?.takeRetainedValue() as? NSNumber else { return nil }
            return value.intValue
        }
        guard let vendor = number("idVendor"), let product = number("idProduct") else { return nil }
        let name = IORegistryEntryCreateCFProperty(
            service, "USB Product Name" as CFString, kCFAllocatorDefault, 0
        )?.takeRetainedValue() as? String
        let serial = IORegistryEntryCreateCFProperty(
            service, "USB Serial Number" as CFString, kCFAllocatorDefault, 0
        )?.takeRetainedValue() as? String
        return USBDevice(vendorID: vendor, productID: product, productName: name, serialNumber: serial)
    }
}

public enum USBMonitorError: Error {
    case cannotCreateNotificationPort
    case registrationFailed(kern_return_t)
}
