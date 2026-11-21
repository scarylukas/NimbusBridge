import Foundation

import Testing
@testable import NimbusBridge

@MainActor
struct NimbusBridgeTests {
    @Test func deadZoneAndInversion() {
        #expect(InputMappingEngine.axis(0.1, deadZone: 0.12, inverted: false) == 0)
        #expect(abs(InputMappingEngine.axis(0.56, deadZone: 0.12, inverted: false) - 0.5) < 0.0001)
        #expect(InputMappingEngine.axis(1, deadZone: 0.12, inverted: true) == -1)
        #expect(InputMappingEngine.axis(.nan, deadZone: 0.12, inverted: false) == 0)
    }
    @Test func neutralAndMissingControls() {
        let output = InputMappingEngine.map(InputSnapshot(axes: ["LX": 0, "DY": 1], buttons: ["A": 1, "L2": 0.75]), profile: MappingProfile())
        #expect(output.axes["LX"] == 0)
        #expect(output.axes["DY"] == 1)
        #expect(output.buttons["A"] == 1)
        #expect(output.buttons["L2"] == 0.75)
        #expect(output.buttons["L3"] == 0)
    }
    @Test func profileRoundTrip() throws {
        var profile = MappingProfile()
        profile.deadZone = 0.25
        profile.buttons["Options"] = "A"
        #expect(try JSONDecoder().decode(MappingProfile.self, from: JSONEncoder().encode(profile)) == profile)
    }
    @Test func nimbusReportMatchesFS25Buttons() {
        // Physical 0...7 from installed SteelseriesNimbus.xml, PS at physical 12.
        let names = ["A", "B", "X", "Y", "L1", "R1", "L2", "R2", "Options", "Menu", "L3", "R3", "Home"]
        for (index, name) in names.enumerated() {
            let report = Array(VirtualGamepadReport.encode(InputSnapshot(buttons: [name: 1])))
            #expect(report.count == 10)
            #expect(report[6] == 15) // neutral hat
            #expect(UInt16(report[7]) | UInt16(report[8]) << 8 == UInt16(1) << index)
        }
    }
    @Test func nimbusAxisAndNeutralEncoding() {
        let report = Array(VirtualGamepadReport.encode(InputSnapshot(axes: ["LX": -1, "LY": 1, "RX": 0.5, "RY": -.infinity])))
        #expect(report == [129, 127, 64, 0, 129, 129, 15, 0, 0, 0])
        #expect(MappingProfile().invertedAxes.isEmpty)
        #expect(Array(VirtualGamepadReport.encode(InputSnapshot())) == [0, 0, 0, 0, 129, 129, 15, 0, 0, 0])
        // FS25 physical axis names X,Y,Z,RX match descriptor usages 30,31,32,33.
        let descriptor = Array(VirtualGamepadReport.descriptor)
        #expect(descriptor[8...15].elementsEqual([0x09, 0x30, 0x09, 0x31, 0x09, 0x32, 0x09, 0x33]))
    }

    @Test func nimbusTriggersPreserveTravel() {
        let report = Array(VirtualGamepadReport.encode(InputSnapshot(buttons: ["L2": 0.5, "R2": 1])))
        #expect(report[4] == 0)
        #expect(report[5] == 127)
        #expect(report[7] == 1 << 7)
    }

    @Test func nimbusDpadSendsHatAndNavigationButtons() {
        let cases: [(x: Float, y: Float, hat: UInt8, buttons: [UInt8])] = [
            (0, 1, 0, [0, 0x20, 0]), (0, -1, 4, [0, 0x40, 0]),
            (-1, 0, 6, [0, 0x80, 0]), (1, 0, 2, [0, 0, 1]),
            (1, 1, 1, [0, 0x20, 1])
        ]
        for direction in cases {
            let report = Array(VirtualGamepadReport.encode(InputSnapshot(axes: ["DX": direction.x, "DY": direction.y])))
            #expect(report[6] == direction.hat)
            #expect(Array(report[7...9]) == direction.buttons)
        }
    }

    @Test func fs25SetupPreservesControlsAndCanRunTwice() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let bindings = folder.appending(path: "inputBinding.xml")
        let original = Data("""
        <inputBinding>
            <actionBinding action="MENU_AXIS_UP_DOWN">
                <binding device="KB_MOUSE_DEFAULT" input="KEY_up" axisComponent="+" />
            </actionBinding>
            <actionBinding action="MENU_AXIS_LEFT_RIGHT"/>
            <actionBinding action="AXIS_RUN">
                <binding device="another-controller" input="AXIS_11" />
            </actionBinding>
            <devices>
                <device id="0_03000000381000002014000001000000" name="SteelSeries Nimbus (NimbusBridge experiment)"/>
            </devices>
        </inputBinding>
        """.utf8)
        try original.write(to: bindings)
        let profile = Data("<deviceMapping/>".utf8)

        let setup = try FS25Configuration.apply(to: folder, profile: profile)
        let backup = try #require(setup.backupFolder)
        #expect(try Data(contentsOf: backup.appending(path: "inputBinding.xml")) == original)
        #expect(try Data(contentsOf: folder.appending(path: "inputDevicesManual/SteelseriesNimbus.xml")) == profile)
        let updated = try Data(contentsOf: bindings)
        let root = try #require(try XMLDocument(data: updated).rootElement())
        let actions = root.elements(forName: "actionBinding")
        #expect(actions.map { $0.elements(forName: "binding").count } == [5, 4, 1])
        #expect(actions[2].elements(forName: "binding").first?.attribute(forName: "device")?.stringValue == "another-controller")
        #expect(try FS25Configuration.apply(to: folder, profile: profile).backupFolder == nil)
        #expect(try Data(contentsOf: bindings) == updated)
    }
}
