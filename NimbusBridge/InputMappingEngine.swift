import Foundation

struct MappingProfile: Codable, Equatable, Sendable {
    var name = "FS25 — Nimbus 1038:1420 experiment"
    var deadZone: Float = 0.12
    // FS25 SteelseriesNimbus.xml applies Y inversion; preserve raw signs by default.
    var invertedAxes: Set<String> = []
    // Virtual button -> physical button, using the labels printed on Nimbus+.
    var buttons: [String: String] = [
        "A": "A", "B": "B", "X": "X", "Y": "Y",
        "L1": "L1", "R1": "R1", "L2": "L2", "R2": "R2",
        "Menu": "Menu", "Options": "Options", "L3": "L3", "R3": "R3"
    ]

    static func load() -> Self {
        guard let data = UserDefaults.standard.data(forKey: "mappingProfile"),
              var value = try? JSONDecoder().decode(Self.self, from: data),
              value.deadZone.isFinite, (0...0.9).contains(value.deadZone) else { return Self() }
        value.buttons = migrateLegacyButtons(value.buttons)
        return value
    }

    private static func migrateLegacyButtons(_ buttons: [String: String]) -> [String: String] {
        let destinationNames = [
            "Cross": "A", "Circle": "B", "Square": "X", "Triangle": "Y", "Share": "Options"
        ]
        let physicalNames = [
            "Button A": "A", "Button B": "B", "Button X": "X", "Button Y": "Y",
            "Left Shoulder": "L1", "Right Shoulder": "R1",
            "Left Trigger": "L2", "Right Trigger": "R2",
            "Button Menu": "Menu", "Button Options": "Options",
            "Left Thumbstick Button": "L3", "Right Thumbstick Button": "R3"
        ]
        return Dictionary(uniqueKeysWithValues: buttons.map { destination, physical in
            (destinationNames[destination] ?? destination, physicalNames[physical] ?? physical)
        })
    }
    func save() throws { UserDefaults.standard.set(try JSONEncoder().encode(self), forKey: "mappingProfile") }
}

enum InputMappingEngine {
    static func axis(_ value: Float, deadZone: Float, inverted: Bool) -> Float {
        guard value.isFinite else { return 0 }
        let zone = min(0.9, max(0, deadZone))
        let magnitude = min(1, abs(value))
        guard magnitude > zone else { return 0 }
        return (magnitude - zone) / (1 - zone) * (value < 0 ? -1 : 1) * (inverted ? -1 : 1)
    }
    static func map(_ input: InputSnapshot, profile: MappingProfile) -> InputSnapshot {
        InputSnapshot(axes: input.axes.mapValues { $0 }.reduce(into: [:]) { result, item in
            result[item.key] = axis(item.value, deadZone: item.key.hasPrefix("D") ? 0 : profile.deadZone, inverted: profile.invertedAxes.contains(item.key))
        }, buttons: profile.buttons.mapValues { input.buttons[$0] ?? 0 })
    }
}
