import SwiftUI

@main
struct NimbusBridgeApp: App {
    @Environment(\.openWindow) private var openWindow
    @NSApplicationDelegateAdaptor(BridgeApplicationDelegate.self) private var appDelegate
    @State private var model = BridgeModel()

    var body: some Scene {
        Window("NimbusBridge", id: "main") {
            ContentView(model: model)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Close Window") { NSApp.mainWindow?.performClose(nil) }
                    .keyboardShortcut("w")
            }
        }

        MenuBarExtra {
            Button("Open NimbusBridge") {
                NSApp.setActivationPolicy(.regular)
                openWindow(id: "main")
                NSApp.activate()
            }
            Text(model.virtual.status)
            Divider()
            Button("Start Emulation") { model.startEmulation() }
                .disabled(model.virtual.isActive)
            Button("Stop Emulation") { model.stopEmulation() }
                .disabled(!model.virtual.isActive)
            Divider()
            Button("Quit NimbusBridge") {
                model.stopEmulation()
                NSApp.terminate(nil)
            }
        } label: {
            Label("NimbusBridge", systemImage: model.virtual.created ? "gamecontroller.fill" : "gamecontroller")
        }
    }
}

private final class BridgeApplicationDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NotificationCenter.default.addObserver(
            self, selector: #selector(windowWillClose(_:)), name: NSWindow.willCloseNotification, object: nil
        )
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    @objc private func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window.identifier?.rawValue == "main" else { return }
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
