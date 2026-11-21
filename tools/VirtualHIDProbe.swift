import CoreHID
import Foundation
import IOKit.hid
import Security

// Independent development probe: no entitlement injection or security changes.
// One input byte: eight buttons, neutral report 0x00.
@main struct VirtualHIDProbe {
    static func main() async {
        let task = SecTaskCreateFromSelf(nil)
        let entitlement = task.flatMap {
            SecTaskCopyValueForEntitlement($0, "com.apple.developer.hid.virtual.device" as CFString, nil)
        }
        print("Signed entitlement: \(String(describing: entitlement))")
        let descriptor = Data([
            0x05,0x01,0x09,0x05,0xA1,0x01,
            0x05,0x09,0x19,0x01,0x29,0x08,
            0x15,0x00,0x25,0x01,0x75,0x01,0x95,0x08,0x81,0x02,0xC0
        ])
        let serial = "NimbusBridge-probe-" + UUID().uuidString
        // Zero IDs are deliberate: this probe claims no vendor's identity.
        guard let device = HIDVirtualDevice(properties: .init(
            descriptor: descriptor, vendorID: 0, productID: 0,
            transport: .virtual, product: "NimbusBridge Development Probe",
            serialNumber: serial, uniqueID: serial
        )) else {
            print("FAIL: HIDVirtualDevice initializer returned nil. No device created.")
            return
        }
        let delegate = ProbeDelegate()
        await device.activate(delegate: delegate)
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, 0)
        IOHIDManagerSetDeviceMatching(manager, [kIOHIDSerialNumberKey: serial] as CFDictionary)
        var enumerated = false
        for _ in 0..<20 {
            if let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>, !devices.isEmpty {
                enumerated = true
                break
            }
            try? await Task.sleep(for: .milliseconds(100))
        }
        print("Independent IOHIDManager enumeration: \(enumerated)")
        guard enumerated else { print("FAIL: activation without verified enumeration"); return }
        do {
            try await device.dispatchInputReport(data: Data([0]), timestamp: .now)
            print("Neutral report submitted. Game compatibility and input receipt NOT verified.")
        } catch { print("FAIL: report submission: \(error)") }
        withExtendedLifetime(delegate) {}
        print("Probe exiting; temporary device released.")
    }
}
private final class ProbeDelegate: HIDVirtualDeviceDelegate {
    func hidVirtualDevice(_ device: HIDVirtualDevice, receivedSetReportRequestOfType type: HIDReportType, id: HIDReportID?, data: Data) async throws {
        throw NSError(domain: NSOSStatusErrorDomain, code: Int(kIOReturnUnsupported))
    }
    func hidVirtualDevice(_ device: HIDVirtualDevice, receivedGetReportRequestOfType type: HIDReportType, id: HIDReportID?, maxSize: Int) async throws -> Data {
        guard type == .input, id == nil, maxSize >= 1 else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(kIOReturnUnsupported))
        }
        return Data([0])
    }
}
