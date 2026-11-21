import SwiftUI

struct ContentView: View {
    @Bindable var model: BridgeModel
    var body: some View {
        TabView {
            monitor.tabItem { Label("Monitor", systemImage: "gamecontroller") }
            mapping.tabItem { Label("Mapping", systemImage: "slider.horizontal.3") }
            FS25SetupView().tabItem { Label("FS25 Setup", systemImage: "gearshape") }
            diagnostics.tabItem { Label("Diagnostics", systemImage: "waveform.path.ecg") }
        }
        .padding().frame(minWidth: 820, minHeight: 620)
    }
    private var monitor: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("NimbusBridge").font(.largeTitle.bold())
                Text(model.discovery.details).textSelection(.enabled)
                HStack {
                    Label(model.discovery.selected == nil ? "Disconnected" : "Physical connected", systemImage: model.discovery.selected == nil ? "circle" : "checkmark.circle.fill")
                    Text("Input events: \(model.input.eventCount)")
                    if let date = model.input.lastEvent { Text("Last input: \(date.formatted(date: .omitted, time: .standard))") }
                }
                Button("Discover wireless controllers") { model.discovery.discover() }
                emulationControls
                ControllerDiagram(snapshot: model.input.snapshot)
                ControllerSignalDetails(
                    axes: model.input.snapshot.axes,
                    mappedAxes: model.mapped.axes,
                    buttons: model.input.snapshot.buttons
                )
            }.padding()
        }
    }

    private var emulationControls: some View {
        GroupBox("Emulation") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    if model.virtual.isStarting { ProgressView().controlSize(.small) }
                    Label(
                        model.virtual.status,
                        systemImage: model.virtual.created ? "checkmark.circle.fill" : "circle"
                    )
                    .font(.headline)
                    .foregroundStyle(model.virtual.created ? Color.green : Color.primary)
                }
                Text(model.inputStatus)
                if model.virtual.created {
                    Text("Reports forwarded: \(model.virtual.forwardedReports)")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Button("Start Emulation") { model.startEmulation() }
                        .buttonStyle(.borderedProminent)
                        .disabled(model.virtual.isActive)
                    Button("Stop Emulation") { model.stopEmulation() }
                        .disabled(!model.virtual.isActive)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    private func axisDisplayName(_ key: String) -> String {
        switch key {
        case "LX": return "Left stick X"
        case "LY": return "Left stick Y"
        case "RX": return "Right stick X"
        case "RY": return "Right stick Y"
        case "DX": return "D-pad X"
        case "DY": return "D-pad Y"
        default: return key
        }
    }

    private var mapping: some View {
        Form {
            TextField("Profile", text: $model.profile.name)
            HStack {
                Text("Stick dead zone")
                Slider(value: $model.profile.deadZone, in: 0...0.9)
                Text(model.profile.deadZone, format: .number.precision(.fractionLength(2)))
            }
            ForEach(["LX", "LY", "RX", "RY"], id: \.self) { key in
                Toggle("Invert \(key)", isOn: Binding(get: { model.profile.invertedAxes.contains(key) }, set: { value in
                    if value { model.profile.invertedAxes.insert(key) } else { model.profile.invertedAxes.remove(key) }
                }))
            }
            ForEach(model.profile.buttons.keys.sorted(), id: \.self) { key in
                Picker(key, selection: Binding(get: { model.profile.buttons[key] ?? "" }, set: { model.profile.buttons[key] = $0 })) {
                    Text("Unmapped").tag("")
                    ForEach(Set(model.input.snapshot.buttons.keys).union(model.profile.buttons.values).filter { !$0.isEmpty }.sorted(), id: \.self) { Text($0).tag($0) }
                }
            }
            Button("Save profile") { model.saveProfile() }
            Text("Saved mappings are applied to the live virtual controller. FS25 bindings still require in-game validation.").font(.caption)
        }.padding()
    }
    private var diagnostics: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(model.virtual.backend)
                Text(model.virtual.deviceName)
                Text(model.virtual.identity)
                Text(model.virtual.extensionStatus)
                Text("Elements: " + model.input.capabilities.joined(separator: ", "))
                Text("Reported analog buttons: " + model.input.analogButtons.joined(separator: ", "))
                Text(model.inputStatus)
                Divider()
                Text(model.log.entries.joined(separator: "\n")).font(.system(.caption, design: .monospaced))
            }.frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled).padding()
        }
    }
}

private struct ControllerDiagram: View {
    let snapshot: InputSnapshot

    var body: some View {
        GroupBox("Nimbus+ · live input") {
            VStack(spacing: 10) {
                HStack(spacing: 14) {
                    ShoulderIndicator(label: "L2", value: value("L2"))
                    ShoulderIndicator(label: "L1", value: value("L1"))
                    Spacer()
                    ShoulderIndicator(label: "R1", value: value("R1"))
                    ShoulderIndicator(label: "R2", value: value("R2"))
                }
                .padding(.horizontal, 34)

                ZStack {
                    RoundedRectangle(cornerRadius: 70)
                        .fill(.secondary.opacity(0.12))
                        .stroke(.secondary.opacity(0.35), lineWidth: 2)

                    StickIndicator(
                        label: "Left stick",
                        x: axis("LX"),
                        y: axis("LY"),
                        pressed: value("L3") > 0.5
                    )
                    .position(x: 155, y: 105)

                    DPadIndicator(
                        up: value("D-pad ↑") > 0.5,
                        down: value("D-pad ↓") > 0.5,
                        left: value("D-pad ←") > 0.5,
                        right: value("D-pad →") > 0.5
                    )
                    .position(x: 155, y: 220)

                    HStack(spacing: 20) {
                        SmallButtonIndicator(label: "Options", value: value("Options"))
                        SmallButtonIndicator(label: "Menu", value: value("Menu"))
                    }
                    .position(x: 300, y: 135)

                    StickIndicator(
                        label: "Right stick",
                        x: axis("RX"),
                        y: axis("RY"),
                        pressed: value("R3") > 0.5
                    )
                    .position(x: 360, y: 220)

                    FaceButtonsIndicator(
                        a: value("A") > 0.5,
                        b: value("B") > 0.5,
                        x: value("X") > 0.5,
                        y: value("Y") > 0.5
                    )
                    .position(x: 465, y: 105)
                }
                .frame(width: 600, height: 310)

                Text("Krzyżak jest pokazany jako cztery kierunki — bez technicznych osi X/Y.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    private func value(_ key: String) -> Float {
        snapshot.buttons[key] ?? 0
    }

    private func axis(_ key: String) -> Float {
        snapshot.axes[key] ?? 0
    }
}

private struct ShoulderIndicator: View {
    let label: String
    let value: Float

    var body: some View {
        VStack(spacing: 4) {
            Text(label).font(.headline)
            ProgressView(value: Double(value), total: 1)
                .frame(width: 80)
            Text(value, format: .number.precision(.fractionLength(2)))
                .font(.caption.monospacedDigit())
        }
        .padding(8)
        .background(value > 0.05 ? Color.green.opacity(0.25) : Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct StickIndicator: View {
    let label: String
    let x: Float
    let y: Float
    let pressed: Bool

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle().fill(.black.opacity(0.16))
                Circle()
                    .fill(pressed ? Color.green : Color.secondary)
                    .frame(width: 34, height: 34)
                    .offset(x: CGFloat(x) * 18, y: CGFloat(-y) * 18)
            }
            .frame(width: 76, height: 76)
            Text(label).font(.caption)
        }
    }
}

private struct DPadIndicator: View {
    let up: Bool
    let down: Bool
    let left: Bool
    let right: Bool

    var body: some View {
        ZStack {
            DirectionIndicator(symbol: "▲", active: up).offset(y: -29)
            DirectionIndicator(symbol: "▼", active: down).offset(y: 29)
            DirectionIndicator(symbol: "◀", active: left).offset(x: -29)
            DirectionIndicator(symbol: "▶", active: right).offset(x: 29)
            Circle().fill(.secondary.opacity(0.35)).frame(width: 28, height: 28)
        }
        .frame(width: 92, height: 92)
    }
}

private struct DirectionIndicator: View {
    let symbol: String
    let active: Bool

    var body: some View {
        Text(symbol)
            .font(.title3.bold())
            .foregroundStyle(active ? Color.white : Color.primary)
            .frame(width: 38, height: 38)
            .background(active ? Color.green : Color.secondary.opacity(0.25), in: RoundedRectangle(cornerRadius: 7))
    }
}

private struct FaceButtonsIndicator: View {
    let a: Bool
    let b: Bool
    let x: Bool
    let y: Bool

    var body: some View {
        ZStack {
            FaceButtonIndicator(label: "Y", active: y).offset(y: -34)
            FaceButtonIndicator(label: "A", active: a).offset(y: 34)
            FaceButtonIndicator(label: "X", active: x).offset(x: -34)
            FaceButtonIndicator(label: "B", active: b).offset(x: 34)
        }
        .frame(width: 116, height: 116)
    }
}

private struct FaceButtonIndicator: View {
    let label: String
    let active: Bool

    var body: some View {
        Text(label)
            .font(.headline)
            .foregroundStyle(active ? Color.white : Color.primary)
            .frame(width: 42, height: 42)
            .background(active ? Color.green : Color.secondary.opacity(0.25), in: Circle())
    }
}

private struct SmallButtonIndicator: View {
    let label: String
    let value: Float

    var body: some View {
        VStack(spacing: 3) {
            Circle()
                .fill(value > 0.5 ? Color.green : Color.secondary.opacity(0.35))
                .frame(width: 25, height: 25)
            Text(label).font(.caption2)
        }
    }
}

private struct ControllerSignalDetails: View {
    let axes: [String: Float]
    let mappedAxes: [String: Float]
    let buttons: [String: Float]

    private let stickAxes = ["LX", "LY", "RX", "RY"]
    private let buttonGroups = [
        ("Face buttons", ["A", "B", "X", "Y"]),
        ("Shoulders and triggers", ["L1", "R1", "L2", "R2"]),
        ("Stick and menu buttons", ["L3", "R3", "Options", "Menu"]),
        ("D-pad", ["D-pad ↑", "D-pad ↓", "D-pad ←", "D-pad →"])
    ]

    var body: some View {
        GroupBox("Signal details") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Analog sticks").font(.headline)
                ForEach(stickAxes, id: \.self) { key in
                    HStack {
                        Text(axisName(key)).frame(width: 110, alignment: .leading)
                        ProgressView(value: Double((axes[key] ?? 0) + 1), total: 2)
                        Text(String(format: "% .2f → % .2f", axes[key] ?? 0, mappedAxes[key] ?? 0))
                            .monospacedDigit()
                            .frame(width: 130)
                    }
                }

                ForEach(buttonGroups, id: \.0) { title, keys in
                    Divider()
                    Text(title).font(.headline)
                    HStack {
                        ForEach(keys, id: \.self) { key in
                            Text("\(key): \(buttons[key] ?? 0, specifier: "%.2f")")
                                .monospacedDigit()
                                .foregroundStyle((buttons[key] ?? 0) > 0.05 ? .green : .secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .padding(.vertical, 6)
        }
    }

    private func axisName(_ key: String) -> String {
        switch key {
        case "LX": return "Left stick X"
        case "LY": return "Left stick Y"
        case "RX": return "Right stick X"
        case "RY": return "Right stick Y"
        default: return key
        }
    }
}
