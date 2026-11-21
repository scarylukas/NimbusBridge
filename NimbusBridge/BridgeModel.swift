import Foundation
import Observation

@MainActor @Observable
final class BridgeModel {
    let log: DiagnosticLog
    let input: ControllerInputService
    let discovery: ControllerDiscoveryService
    let virtual = VirtualControllerService()
    private let exclusive = ExclusiveNimbusInput()
    private(set) var inputStatus = "Shared monitoring"
    var profile: MappingProfile = .load()
    var mapped = InputSnapshot()
    init() {
        let log = DiagnosticLog(), input = ControllerInputService()
        self.log = log; self.input = input
        self.discovery = ControllerDiscoveryService(input: input, log: log)
        input.onInput = { [weak self] snapshot in
            guard let self else { return }
            mapped = InputMappingEngine.map(snapshot, profile: profile)
            virtual.forward(mapped, log: log)
        }
        exclusive.onInput = { [weak input] snapshot in input?.publishExclusive(snapshot) }
        exclusive.onDisconnect = { [weak self] in self?.stopEmulation() }
        virtual.onStartFailure = { [weak self] in self?.releaseExclusiveInput() }
        log.write("[INFO] Input monitoring initialized; CoreHID virtual output ready")
    }

    func startEmulation() {
        guard !exclusive.isActive else { return }
        guard exclusive.start(log: log) else {
            inputStatus = "Exclusive input unavailable. See Diagnostics."
            return
        }
        input.usesExclusiveInput = true
        inputStatus = "Exclusive Nimbus+ input"
        input.publishExclusive(InputSnapshot())
        virtual.start(log: log)
    }

    func stopEmulation() {
        virtual.stop(log: log)
        releaseExclusiveInput()
    }

    private func releaseExclusiveInput() {
        exclusive.stop()
        input.usesExclusiveInput = false
        input.attach(discovery.selected)
        inputStatus = "Shared monitoring"
    }
    func saveProfile() {
        do {
            try profile.save()
            mapped = InputMappingEngine.map(input.snapshot, profile: profile)
            log.write("[INFO] Mapping profile saved")
        } catch { log.write("[ERROR] Profile save: \(error.localizedDescription)") }
    }
}
