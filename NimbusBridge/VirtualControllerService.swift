import CoreHID
import Foundation
import Observation
import Security
import IOKit.hid

private final class VirtualGamepadDelegate: HIDVirtualDeviceDelegate {
    func hidVirtualDevice(
        _ device: HIDVirtualDevice,
        receivedSetReportRequestOfType type: HIDReportType,
        id: HIDReportID?,
        data: Data
    ) async throws {
        // This controller has input reports only. Output reports are intentionally ignored.
    }

    func hidVirtualDevice(
        _ device: HIDVirtualDevice,
        receivedGetReportRequestOfType type: HIDReportType,
        id: HIDReportID?,
        maxSize: Int
    ) async throws -> Data {
        Data(VirtualGamepadReport.encode(InputSnapshot()).prefix(maxSize))
    }
}

enum VirtualGamepadReport {
    // Keep the original stick and button indices used by FS25.
    // Ry and Rz carry proportional L2/R2 for the manual device profile.
    static let descriptor = Data([
        0x05, 0x01,       // Usage Page (Generic Desktop)
        0x09, 0x05,       // Usage (Game Pad)
        0xA1, 0x01,       // Collection (Application)
        0x05, 0x01,
        0x09, 0x30,       // X
        0x09, 0x31,       // Y
        0x09, 0x32,       // Z (right stick X)
        0x09, 0x33,       // Rx (right stick Y)
        0x15, 0x81,       // Logical Minimum (-127)
        0x25, 0x7F,       // Logical Maximum (127)
        0x75, 0x08,       // Report Size (8)
        0x95, 0x04,       // Report Count (4)
        0x81, 0x02,       // Input (Data, Variable, Absolute)
        0x09, 0x34,       // Ry (L2)
        0x09, 0x35,       // Rz (R2)
        0x95, 0x02,
        0x81, 0x02,
        0x09, 0x39,       // Usage (Hat Switch)
        0x15, 0x00,
        0x25, 0x07,
        0x35, 0x00,
        0x46, 0x3B, 0x01, // Physical Maximum (315)
        0x65, 0x14,       // Unit (degrees)
        0x75, 0x04,
        0x95, 0x01,
        0x81, 0x42,       // Input (Data, Variable, Absolute, Null State)
        0x65, 0x00,
        0x75, 0x04,
        0x95, 0x01,
        0x81, 0x01,       // Input (Constant)
        0x05, 0x09,       // Usage Page (Button)
        0x19, 0x01,
        0x29, 0x11,
        0x15, 0x00,
        0x25, 0x01,
        0x75, 0x01,
        0x95, 0x11,
        0x81, 0x02,
        0x75, 0x07,
        0x95, 0x01,
        0x81, 0x01,
        0xC0
    ])

    nonisolated private static let buttonOrder = [
        "A", "B", "X", "Y",
        "L1", "R1", "L2", "R2",
        "Options", "Menu", "L3", "R3", "Home"
    ]

    nonisolated static func encode(_ snapshot: InputSnapshot) -> Data {
        let axisKeys = ["LX", "LY", "RX", "RY"]
        var bytes = axisKeys.map { key -> UInt8 in
            let raw = snapshot.axes[key] ?? 0
            let value = raw.isFinite ? min(1, max(-1, raw)) : 0
            return UInt8(bitPattern: Int8((value * 127).rounded()))
        }
        for trigger in ["L2", "R2"] {
            let raw = snapshot.buttons[trigger] ?? 0
            let value = raw.isFinite ? min(1, max(0, raw)) : 0
            bytes.append(UInt8(bitPattern: Int8(((2 * value - 1) * 127).rounded())))
        }

        bytes.append(hat(x: snapshot.axes["DX"] ?? 0, y: snapshot.axes["DY"] ?? 0))

        var buttons: UInt32 = 0
        for (index, name) in buttonOrder.enumerated() where (snapshot.buttons[name] ?? 0) > 0.5 {
            buttons |= UInt32(1) << index
        }
        // FS25's menu bindings use four buttons. Keep the hat for existing bindings.
        let horizontal = snapshot.axes["DX"] ?? 0
        let vertical = snapshot.axes["DY"] ?? 0
        let directions = [vertical > 0.5, vertical < -0.5, horizontal < -0.5, horizontal > 0.5]
        for (index, pressed) in directions.enumerated() where pressed {
            buttons |= UInt32(1) << (buttonOrder.count + index)
        }
        bytes.append(UInt8(truncatingIfNeeded: buttons))
        bytes.append(UInt8(truncatingIfNeeded: buttons >> 8))
        bytes.append(UInt8(truncatingIfNeeded: buttons >> 16))
        return Data(bytes)
    }

    nonisolated private static func hat(x: Float, y: Float) -> UInt8 {
        let horizontal = x > 0.5 ? 1 : (x < -0.5 ? -1 : 0)
        let vertical = y > 0.5 ? 1 : (y < -0.5 ? -1 : 0)
        switch (horizontal, vertical) {
        case (0, 1): return 0
        case (1, 1): return 1
        case (1, 0): return 2
        case (1, -1): return 3
        case (0, -1): return 4
        case (-1, -1): return 5
        case (-1, 0): return 6
        case (-1, 1): return 7
        default: return 0x0F
        }
    }
}

@MainActor @Observable
final class VirtualControllerService {
    private(set) var status = "Stopped"
    private(set) var isStarting = false
    private(set) var created = false
    private(set) var forwardedReports = 0
    var onStartFailure: (() -> Void)?

    let backend = "CoreHID HIDVirtualDevice"
    let deviceName = "SteelSeries Nimbus (NimbusBridge experiment)"
    let identity = "Experimental FS25 Nimbus profile · VID 0x1038 · PID 0x1420"
    let extensionStatus = "No DriverKit extension required"

    private var device: HIDVirtualDevice?
    private var delegate: VirtualGamepadDelegate?
    private var generation = 0
    var isActive: Bool { isStarting || created }

    func start(log: DiagnosticLog) {
        guard !isActive else { return }
        guard hasVirtualDeviceEntitlement else {
            status = "Blocked — signed virtual HID entitlement is absent"
            log.write("[ERROR] \(status)")
            onStartFailure?()
            return
        }

        isStarting = true
        status = "Starting…"
        forwardedReports = 0
        generation += 1
        let currentGeneration = generation
        Task {
            let serial = "de.scaryteam.NimbusBridge.virtual-gamepad"
            let properties = HIDVirtualDevice.Properties(
                descriptor: VirtualGamepadReport.descriptor,
                vendorID: 0x1038,
                productID: 0x1420,
                transport: .virtual,
                product: deviceName,
                manufacturer: "NimbusBridge",
                modelNumber: "FS25-Nimbus-Mapping-Experiment",
                versionNumber: 1,
                serialNumber: serial,
                uniqueID: "de.scaryteam.NimbusBridge.virtual-gamepad",
                locationID: nil,
                localizationCode: nil,
                extraProperties: nil
            )
            guard let newDevice = HIDVirtualDevice(properties: properties) else {
                isStarting = false
                status = "Failed — CoreHID rejected the virtual device properties"
                log.write("[ERROR] \(status)")
                onStartFailure?()
                return
            }

            let newDelegate = VirtualGamepadDelegate()
            await newDevice.activate(delegate: newDelegate)
            guard generation == currentGeneration else { return }
            device = newDevice
            delegate = newDelegate
            // Verify through an independent consumer; activation alone is not enumeration.
            let manager = IOHIDManagerCreate(kCFAllocatorDefault, 0)
            IOHIDManagerSetDeviceMatching(manager, [kIOHIDSerialNumberKey: serial] as CFDictionary)
            for _ in 0..<20 {
                guard generation == currentGeneration else { return }
                if let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>, !devices.isEmpty {
                    created = true
                    isStarting = false
                    status = "Emulation active"
                    log.write("[INFO] IOHIDManager enumerated experimental Nimbus 1038:1420; FS25 acceptance unverified")
                    forward(InputSnapshot(), log: log)
                    return
                }
                try? await Task.sleep(for: .milliseconds(100))
            }
            guard generation == currentGeneration else { return }
            device = nil
            delegate = nil
            isStarting = false
            status = "Failed — no independent HID enumeration within 2 seconds"
            log.write("[ERROR] \(status)")
            onStartFailure?()
        }
    }

    func forward(_ snapshot: InputSnapshot, log: DiagnosticLog) {
        guard let device else { return }
        let report = VirtualGamepadReport.encode(snapshot)
        let currentGeneration = generation
        Task {
            guard generation == currentGeneration else { return }
            do {
                try await device.dispatchInputReport(data: report, timestamp: .now)
                guard generation == currentGeneration else { return }
                forwardedReports += 1
            } catch {
                guard generation == currentGeneration else { return }
                status = "Report failed — \(error.localizedDescription)"
                log.write("[ERROR] Virtual HID report: \(error.localizedDescription)")
            }
        }
    }

    func stop(log: DiagnosticLog) {
        generation += 1
        device = nil
        delegate = nil
        isStarting = false
        created = false
        status = "Stopped"
        log.write("[INFO] Emulation stopped")
    }

    private var hasVirtualDeviceEntitlement: Bool {
        let task = SecTaskCreateFromSelf(nil)
        return task.flatMap {
            SecTaskCopyValueForEntitlement(
                $0,
                "com.apple.developer.hid.virtual.device" as CFString,
                nil
            )
        } as? Bool ?? false
    }
}
