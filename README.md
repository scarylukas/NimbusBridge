# NimbusBridge

NimbusBridge reads a SteelSeries Nimbus+ over Bluetooth on macOS and forwards its controls to a virtual gamepad for Farming Simulator 25.

NimbusBridge is in alpha and requires macOS 27 or later. The virtual controller has been created on a development Mac and recognized by FS25. Gameplay mappings and exclusive input still need end-to-end validation.

## Use with FS25

1. Pair Nimbus+ in macOS Bluetooth settings and open NimbusBridge.
2. With the game closed, select **FS25 Setup → Configure FS25** and choose the `FarmingSimulator2025` folder containing `inputBinding.xml`.
3. Select **Start Emulation**, wait for **Emulation active**, then open FS25. If setup says the virtual controller has yet to be detected, open the game once with emulation running, close it, and run setup again.
4. Close the NimbusBridge window to keep emulation running from the macOS menu bar. The menu bar icon opens the window or stops emulation.

Setup installs the device profile and adds missing menu navigation bindings for the virtual controller. It backs up changed configuration in `NimbusBridge Backups` under the selected game folder. **Show Instructions** provides manual setup steps and lets you save the device profile.

## Development

Open `NimbusBridge.xcodeproj` in Xcode 27.2. Select your development team and a bundle identifier covered by your provisioning profile. Emulation requires an Apple Development signature and a provisioning profile that grants `com.apple.developer.hid.virtual.device`. The local signed HID test uses a Debug build with App Sandbox disabled for that build.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project NimbusBridge.xcodeproj -scheme NimbusBridge -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath /tmp/NimbusBridgeBuild \
  ENABLE_APP_SANDBOX=NO -only-testing:NimbusBridgeTests test
```

See [FS25 mapping and validation](docs/FS25-NIMBUS-EXPERIMENT.md).

NimbusBridge is licensed under the [MIT License](LICENSE).
