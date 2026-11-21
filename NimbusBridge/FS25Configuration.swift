import Foundation

enum FS25Configuration {
    enum BindingResult {
        case configured
        case gameMustDetectController
    }

    struct Result {
        let bindingResult: BindingResult
        let backupFolder: URL?
    }

    enum ConfigurationError: LocalizedError {
        case missingProfile, invalidFolder, invalidBindings, ambiguousDevice, filesChanged

        var errorDescription: String? {
            switch self {
            case .missingProfile: "The device profile is missing from the app."
            case .invalidFolder: "Choose the FarmingSimulator2025 folder that contains inputBinding.xml."
            case .invalidBindings: "The FS25 input bindings could not be read."
            case .ambiguousDevice: "FS25 has multiple matching NimbusBridge devices in its bindings."
            case .filesChanged: "FS25 configuration changed during setup. Close the game and try again."
            }
        }
    }

    static func profileURL() throws -> URL {
        guard let url = Bundle.main.url(forResource: "SteelseriesNimbus", withExtension: "xml") else {
            throw ConfigurationError.missingProfile
        }
        return url
    }

    static func apply(to folder: URL, profile: Data) throws -> Result {
        let files = FileManager.default
        let bindingsURL = folder.appending(path: "inputBinding.xml")
        let profileFolder = folder.appending(path: "inputDevicesManual", directoryHint: .isDirectory)
        let profileURL = profileFolder.appending(path: "SteelseriesNimbus.xml")
        guard files.fileExists(atPath: bindingsURL.path) else { throw ConfigurationError.invalidFolder }

        let originalBindings = try Data(contentsOf: bindingsURL)
        let originalProfile = files.fileExists(atPath: profileURL.path) ? try Data(contentsOf: profileURL) : nil
        let (bindings, bindingResult) = try navigationBindings(in: originalBindings)
        let profileChanged = originalProfile != profile
        guard profileChanged || bindings != originalBindings else {
            return Result(bindingResult: bindingResult, backupFolder: nil)
        }

        let backup = folder.appending(path: "NimbusBridge Backups", directoryHint: .isDirectory)
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try files.createDirectory(at: backup, withIntermediateDirectories: true)
        try originalBindings.write(to: backup.appending(path: "inputBinding.xml"), options: .atomic)
        if let originalProfile {
            try originalProfile.write(to: backup.appending(path: "SteelseriesNimbus.xml"), options: .atomic)
        }
        let latestProfile = files.fileExists(atPath: profileURL.path) ? try Data(contentsOf: profileURL) : nil
        guard try Data(contentsOf: bindingsURL) == originalBindings, latestProfile == originalProfile else {
            throw ConfigurationError.filesChanged
        }

        if profileChanged {
            try files.createDirectory(at: profileFolder, withIntermediateDirectories: true)
            try profile.write(to: profileURL, options: .atomic)
        }
        do {
            if bindings != originalBindings {
                try bindings.write(to: bindingsURL, options: .atomic)
            }
        } catch {
            if profileChanged {
                if let originalProfile {
                    try originalProfile.write(to: profileURL, options: .atomic)
                } else {
                    try files.removeItem(at: profileURL)
                }
            }
            throw error
        }
        return Result(bindingResult: bindingResult, backupFolder: backup)
    }

    private static func navigationBindings(in data: Data) throws -> (Data, BindingResult) {
        let document = try XMLDocument(data: data, options: [.nodePreserveAll, .nodeLoadExternalEntitiesNever])
        guard let root = document.rootElement(), let devices = root.elements(forName: "devices").first else {
            throw ConfigurationError.invalidBindings
        }
        let matches = devices.elements(forName: "device").compactMap { element -> String? in
            guard let id = element.attribute(forName: "id")?.stringValue,
                  id.lowercased().contains("3810000020140000"),
                  let name = element.attribute(forName: "name")?.stringValue,
                  name.localizedCaseInsensitiveContains("NimbusBridge") else { return nil }
            return id
        }
        guard !matches.isEmpty else { return (data, .gameMustDetectController) }
        guard matches.count == 1, let id = matches.first else { throw ConfigurationError.ambiguousDevice }

        let navigation = [
            ("MENU_AXIS_UP_DOWN", [("AXIS_2-", "+", "1"), ("AXIS_2+", "-", "1"), ("BUTTON_17", "+", "2"), ("BUTTON_19", "-", "2")]),
            ("MENU_AXIS_LEFT_RIGHT", [("AXIS_1+", "+", "1"), ("AXIS_1-", "-", "1"), ("BUTTON_18", "+", "2"), ("BUTTON_20", "-", "2")])
        ]
        var changed = false
        for (action, bindings) in navigation {
            guard let section = root.elements(forName: "actionBinding").first(where: {
                $0.attribute(forName: "action")?.stringValue == action
            }) else { throw ConfigurationError.invalidBindings }

            for (input, direction, index) in bindings {
                let exists = section.elements(forName: "binding").contains {
                    $0.attribute(forName: "device")?.stringValue == id &&
                    $0.attribute(forName: "input")?.stringValue == input &&
                    $0.attribute(forName: "axisComponent")?.stringValue == direction
                }
                guard !exists else { continue }
                let binding = XMLElement(name: "binding")
                for (name, value) in [("device", id), ("input", input), ("axisComponent", direction),
                                      ("neutralInput", "0"), ("index", index)] {
                    binding.addAttribute(XMLNode.attribute(withName: name, stringValue: value) as! XMLNode)
                }
                let insertion = section.children?.last?.kind == .text ? section.childCount - 1 : section.childCount
                section.insertChild(XMLNode.text(withStringValue: "\n        ") as! XMLNode, at: insertion)
                section.insertChild(binding, at: insertion + 1)
                changed = true
            }
        }
        return (changed ? document.xmlData(options: [.nodeCompactEmptyElement]) : data, .configured)
    }
}
