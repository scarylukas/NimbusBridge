import SwiftUI
import UniformTypeIdentifiers

struct FS25SetupView: View {
    @State private var status = ""
    @State private var backupFolder: URL?
    @State private var showInstructions = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Farming Simulator 25").font(.title.bold())
                Text("Install the Nimbus device profile and add menu navigation to your existing FS25 controls.")
                HStack {
                    Button("Configure FS25…", action: configure)
                        .buttonStyle(.borderedProminent)
                    Button(showInstructions ? "Hide Instructions" : "Show Instructions") {
                        showInstructions.toggle()
                    }
                }
                if !status.isEmpty { Text(status).textSelection(.enabled) }
                if let backupFolder {
                    Button("Show Backup in Finder") {
                        NSWorkspace.shared.open(backupFolder)
                    }
                }
                if showInstructions {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("1. Close FS25 and locate its FarmingSimulator2025 folder. It contains inputBinding.xml.")
                        Text("2. Save SteelseriesNimbus.xml in the inputDevicesManual subfolder.")
                        Text("3. Start emulation, then open FS25 once so it registers the virtual Nimbus. Quit FS25 before running setup again to add the menu bindings.")
                        Text("For manual editing, back up inputBinding.xml. In MENU_AXIS_UP_DOWN, add the virtual Nimbus device to AXIS_2− / AXIS_2+ and BUTTON_17 / BUTTON_19. In MENU_AXIS_LEFT_RIGHT, add it to AXIS_1+ / AXIS_1− and BUTTON_18 / BUTTON_20. Use the device ID listed next to SteelSeries Nimbus (NimbusBridge experiment).")
                        Button("Save Device Profile…", action: exportProfile)
                    }
                    .textSelection(.enabled)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
    }

    private func configure() {
        guard !NSWorkspace.shared.runningApplications.contains(where: {
            $0.bundleIdentifier?.hasPrefix("com.giants-software.fs25") == true
        }) else {
            status = "Close FS25 to save its current controls, then run setup again."
            return
        }
        let panel = NSOpenPanel()
        panel.title = "Choose the FarmingSimulator2025 Folder"
        panel.message = "Select the folder that contains inputBinding.xml."
        panel.prompt = "Configure FS25"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        let library = URL.libraryDirectory
        let candidates = [
            library.appending(path: "Containers/com.giants-software.fs25/Data/Library/Application Support/FarmingSimulator2025"),
            library.appending(path: "Application Support/FarmingSimulator2025")
        ]
        panel.directoryURL = candidates.first { FileManager.default.fileExists(atPath: $0.path) }
            ?? library.appending(path: "Application Support")
        guard panel.runModal() == .OK, let folder = panel.url else { return }
        backupFolder = nil
        let scoped = folder.startAccessingSecurityScopedResource()
        defer { if scoped { folder.stopAccessingSecurityScopedResource() } }
        do {
            let result = try FS25Configuration.apply(to: folder, profile: Data(contentsOf: FS25Configuration.profileURL()))
            backupFolder = result.backupFolder
            switch result.bindingResult {
            case .configured:
                status = "FS25 is configured. Start emulation before opening the game."
            case .gameMustDetectController:
                status = "Device profile installed. Start emulation, open FS25 once, then close it and run setup again to add menu navigation."
            }
        } catch {
            status = "Setup could not finish. \(error.localizedDescription)"
            showInstructions = true
        }
    }

    private func exportProfile() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "SteelseriesNimbus.xml"
        panel.allowedContentTypes = [.xml]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try Data(contentsOf: FS25Configuration.profileURL()).write(to: url, options: .atomic)
            status = "Device profile saved."
        } catch {
            status = "Could not save the profile. \(error.localizedDescription)"
        }
    }
}
