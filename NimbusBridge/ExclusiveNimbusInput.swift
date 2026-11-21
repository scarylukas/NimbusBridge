import Foundation
import IOKit.hid

@MainActor
final class ExclusiveNimbusInput {
    private var device: IOHIDDevice?
    private var snapshot = InputSnapshot()
    var onInput: ((InputSnapshot) -> Void)?
    var onDisconnect: (() -> Void)?

    var isActive: Bool { device != nil }

    func start(log: DiagnosticLog) -> Bool {
        guard device == nil else { return true }
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, 0)
        IOHIDManagerSetDeviceMatching(manager, [
            kIOHIDProductKey: "Nimbus+",
            kIOHIDTransportKey: "Bluetooth",
            kIOHIDDeviceUsagePageKey: 1,
            kIOHIDDeviceUsageKey: 5
        ] as CFDictionary)
        guard let matches = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>,
              matches.count == 1, let physical = matches.first else {
            log.write("[ERROR] Connect exactly one Bluetooth Nimbus+ for exclusive input")
            return false
        }
        let result = IOHIDDeviceOpen(physical, IOOptionBits(kIOHIDOptionsTypeSeizeDevice))
        guard result == kIOReturnSuccess else {
            log.write("[ERROR] Exclusive Nimbus+ open failed: 0x\(String(UInt32(bitPattern: result), radix: 16))")
            return false
        }

        device = physical
        snapshot = InputSnapshot()
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDDeviceRegisterInputValueCallback(physical, { context, result, _, value in
            guard result == kIOReturnSuccess, let context else { return }
            MainActor.assumeIsolated {
                Unmanaged<ExclusiveNimbusInput>.fromOpaque(context).takeUnretainedValue().receive(value)
            }
        }, context)
        IOHIDDeviceRegisterRemovalCallback(physical, { context, _, _ in
            guard let context else { return }
            MainActor.assumeIsolated {
                Unmanaged<ExclusiveNimbusInput>.fromOpaque(context).takeUnretainedValue().onDisconnect?()
            }
        }, context)
        IOHIDDeviceScheduleWithRunLoop(physical, CFRunLoopGetMain(), RunLoop.Mode.common.rawValue as CFString)
        log.write("[INFO] Physical Nimbus+ opened exclusively")
        return true
    }

    func stop() {
        guard let device else { return }
        self.device = nil
        IOHIDDeviceUnscheduleFromRunLoop(device, CFRunLoopGetMain(), RunLoop.Mode.common.rawValue as CFString)
        IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeSeizeDevice))
        snapshot = InputSnapshot()
    }

    private static let buttons: [UInt32: String] = [
        1: "A", 2: "B", 3: "X", 4: "Y", 5: "L1", 6: "R1",
        7: "L2", 8: "R2", 9: "L3", 10: "R3"
    ]
    private static let stickAxes: [UInt32: (name: String, sign: Float)] = [
        0x30: ("LX", 1), 0x31: ("LY", -1), 0x32: ("RX", 1), 0x35: ("RY", -1)
    ]
    private static let directions: [UInt32: String] = [
        0x90: "D-pad ↑", 0x91: "D-pad ↓", 0x92: "D-pad →", 0x93: "D-pad ←"
    ]
    private static let menuButtons: [UInt32: String] = [
        0x223: "Home", 0x209: "Options", 0x204: "Menu"
    ]

    private func receive(_ value: IOHIDValue) {
        guard isActive else { return }
        let element = IOHIDValueGetElement(value)
        let page = IOHIDElementGetUsagePage(element)
        let usage = IOHIDElementGetUsage(element)
        let raw = Float(IOHIDValueGetIntegerValue(value))
        let minValue = Float(IOHIDElementGetLogicalMin(element))
        let range = Float(IOHIDElementGetLogicalMax(element)) - minValue
        guard range > 0 else { return }
        let normalized = min(1, max(0, (raw - minValue) / range))

        switch page {
        case 1:
            if let axis = Self.stickAxes[usage] {
                snapshot.axes[axis.name] = (normalized * 2 - 1) * axis.sign
            } else if let direction = Self.directions[usage] {
                snapshot.buttons[direction] = normalized
                snapshot.axes["DX"] = (snapshot.buttons["D-pad →"] ?? 0) - (snapshot.buttons["D-pad ←"] ?? 0)
                snapshot.axes["DY"] = (snapshot.buttons["D-pad ↑"] ?? 0) - (snapshot.buttons["D-pad ↓"] ?? 0)
            } else {
                return
            }
        case 9:
            guard let button = Self.buttons[usage] else { return }
            snapshot.buttons[button] = normalized
        case 12:
            guard let button = Self.menuButtons[usage] else { return }
            snapshot.buttons[button] = normalized
        default:
            return
        }
        onInput?(snapshot)
    }
}
