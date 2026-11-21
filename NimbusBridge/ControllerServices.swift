import Foundation
import GameController
import Observation
import OSLog

@MainActor @Observable
final class DiagnosticLog {
    private(set) var entries: [String] = []
    private let logger = Logger(subsystem: "de.scaryteam.NimbusBridge", category: "controller")
    func write(_ message: String) {
        let line = "\(Date().formatted(date: .omitted, time: .standard)) \(message)"
        entries.append(line)
        if entries.count > 500 { entries.removeFirst(entries.count - 500) }
        logger.info("\(message, privacy: .public)")
    }
}

struct InputSnapshot: Sendable {
    var axes: [String: Float] = [:]
    var buttons: [String: Float] = [:]
}

@MainActor @Observable
final class ControllerInputService {
    private(set) var snapshot = InputSnapshot()
    private(set) var eventCount = 0
    private(set) var lastEvent: Date?
    private(set) var capabilities: [String] = []
    private(set) var analogButtons: [String] = []
    private var gamepad: GCExtendedGamepad?
    var usesExclusiveInput = false
    var onInput: ((InputSnapshot) -> Void)?
    func attach(_ controller: GCController?) {
        guard !usesExclusiveInput else { return }
        gamepad?.valueChangedHandler = nil
        gamepad?.dpad.valueChangedHandler = nil
        gamepad = controller?.extendedGamepad
        snapshot = InputSnapshot(); eventCount = 0; lastEvent = nil
        capabilities = []; analogButtons = []
        guard let gamepad else { onInput?(snapshot); return }
        capabilities = [
            "Left stick X", "Left stick Y", "Right stick X", "Right stick Y",
            "D-pad ↑", "D-pad ↓", "D-pad ←", "D-pad →", "A", "B", "X", "Y",
            "L1", "R1", "L2", "R2", "Menu", "Options", "L3", "R3"
        ]
        analogButtons = [
            ("A", gamepad.buttonA), ("B", gamepad.buttonB),
            ("X", gamepad.buttonX), ("Y", gamepad.buttonY),
            ("L1", gamepad.leftShoulder), ("R1", gamepad.rightShoulder),
            ("L2", gamepad.leftTrigger), ("R2", gamepad.rightTrigger)
        ].filter { $0.1.isAnalog }.map(\.0)
        read(gamepad, event: false)
        gamepad.valueChangedHandler = { [weak self] pad, element in
            // Some MFi controllers don't forward every D-pad direction through
            // the profile-wide callback. The D-pad has a dedicated handler below.
            guard element !== pad.dpad else { return }
            MainActor.assumeIsolated { self?.read(pad, event: true) }
        }
        gamepad.dpad.valueChangedHandler = { [weak self, weak gamepad] _, _, _ in
            guard let gamepad else { return }
            MainActor.assumeIsolated { self?.read(gamepad, event: true) }
        }
    }
    private func read(_ pad: GCExtendedGamepad, event: Bool) {
        guard !usesExclusiveInput else { return }
        var buttons: [String: Float] = [
            "A": pad.buttonA.value,
            "B": pad.buttonB.value,
            "X": pad.buttonX.value,
            "Y": pad.buttonY.value,
            "L1": pad.leftShoulder.value,
            "R1": pad.rightShoulder.value,
            "L2": pad.leftTrigger.value,
            "R2": pad.rightTrigger.value,
            "D-pad ↑": pad.dpad.up.value,
            "D-pad ↓": pad.dpad.down.value,
            "D-pad ←": pad.dpad.left.value,
            "D-pad →": pad.dpad.right.value,
            "Menu": pad.buttonMenu.value
        ]
        buttons["Options"] = pad.buttonOptions?.value ?? 0
        buttons["L3"] = pad.leftThumbstickButton?.value ?? 0
        buttons["R3"] = pad.rightThumbstickButton?.value ?? 0

        snapshot = InputSnapshot(axes: [
            "LX": pad.leftThumbstick.xAxis.value, "LY": pad.leftThumbstick.yAxis.value,
            "RX": pad.rightThumbstick.xAxis.value, "RY": pad.rightThumbstick.yAxis.value,
            "DX": pad.dpad.right.value - pad.dpad.left.value,
            "DY": pad.dpad.up.value - pad.dpad.down.value
        ], buttons: buttons)
        if event { eventCount += 1; lastEvent = Date() }
        onInput?(snapshot)
    }

    func publishExclusive(_ snapshot: InputSnapshot) {
        self.snapshot = snapshot
        eventCount += 1
        lastEvent = Date()
        onInput?(snapshot)
    }
}

@MainActor @Observable
final class ControllerDiscoveryService {
    private(set) var selected: GCController?
    private(set) var candidates: [GCController] = []
    private(set) var details = "No Nimbus controller detected"
    private let input: ControllerInputService
    private let log: DiagnosticLog
    private var observers: [NSObjectProtocol] = []
    init(input: ControllerInputService, log: DiagnosticLog) {
        self.input = input; self.log = log
        for name in [Notification.Name.GCControllerDidConnect, .GCControllerDidDisconnect] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            })
        }
        refresh()
    }
    func refresh() {
        candidates = GCController.controllers().filter {
            ($0.vendorName ?? "").localizedCaseInsensitiveContains("nimbus") &&
            !($0.vendorName ?? "").localizedCaseInsensitiveContains("nimbusbridge") && $0.extendedGamepad != nil
        }
        let next = candidates.first
        guard selected !== next else { return }
        selected?.extendedGamepad?.valueChangedHandler = nil
        selected = next
        next?.handlerQueue = .main
        input.attach(next)
        if let next {
            details = "\(next.vendorName ?? "Nimbus") • \(next.productCategory) • Extended gamepad\nTransport is not exposed by GameController; verify Bluetooth in System Information."
            log.write("[INFO] Nimbus selected: \(details)")
        } else {
            details = "No Nimbus controller detected"
            log.write("[INFO] Nimbus disconnected; input reset")
        }
    }
    func discover() {
        GCController.startWirelessControllerDiscovery(completionHandler: nil)
        log.write("[INFO] Wireless discovery requested")
    }
}
