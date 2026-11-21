# FS25 Nimbus identity experiment

Target changed to the game's existing Nimbus profile. DS4 is not the active experiment.

Installed definition inspected: `/Applications/Farming Simulator 2025.app/Contents/Resources/shared/inputDevices/SteelseriesNimbus.xml`.

- VID `1038`, PID `1420`; product keyword `nimbus` constrained to vendor `1038`.
- Backend list: `rawInput;directInput;macosXSdl`.
- Axes: X → LS-X, Y → LS-Y with scale -1, Z → RS-X, RX → RS-Y with scale -1.
- Buttons at physical indices 0–7: A, B, X, Y, LB, RB, LT, RT. PS at index 12.

The virtual profile uses those IDs, a Nimbus name, X/Y/Z/RX HID usages and button bits matching the documented indices. A hat carries D-pad. The stock game profile treats triggers as buttons and omits Options and Menu. The virtual report also carries proportional L2/R2 on RY/RZ. For FS25 on macOS, copy [SteelseriesNimbus.xml](../NimbusBridge/SteelseriesNimbus.xml) to the game's `inputDevicesManual` directory and restart FS25 with emulation already running. The manual profile maps the two trigger axes and Options/Menu at indices 8–9. Check recognition and assignments in the game.

Default mapping preserves GameController Y signs because the FS25 Nimbus profile performs the Y inversion. Existing saved user inversion settings are preserved: turn off LY/RY inversion in Mapping and Save for this baseline test.

This descriptor is a minimal coherent HID layout based on the game's mapping, not a byte-exact hardware Nimbus descriptor. macOS/SDL may translate controls before FS25 sees them, so descriptor ordering and IDs do not prove correct game mappings.

## Acceptance

1. Create the virtual device under approved signing and independently enumerate VID/PID and controls. The app now waits for independent IOHIDManager enumeration before displaying enumerated status.
2. Start FS25 and inspect log.txt: actual exposed VID/PID, category, axis/button counts and selected mapping if logged. Determine whether macosXSdl is the actual consumer path.
3. Test each stick axis separately: sign, center, full range and which game action responds.
4. Test A/B/X/Y, LB/RB/LT/RT one at a time; verify actions and labels against the default gamepad bindings.
5. Test D-pad, additional buttons, simultaneous controls, neutral after release and disconnect. Check duplicate physical-controller input.
6. Record recognition separately from mapping correctness. A wrong mapping remains a failure even if the name/category looks right.

## macOS validation — 2026-11-21

The Apple Development signature and embedded profile both contain `com.apple.developer.hid.virtual.device` for `de.scaryteam.NimbusBridge`. With App Sandbox enabled, CoreHID creation failed and the macOS log reported `IOServiceOpen: 0xe00002e2` (`kIOReturnNotPermitted`).

An isolated Debug build with `ENABLE_APP_SANDBOX=NO` created the controller. Both the app's IOHIDManager check and `hidutil list` confirmed the virtual `1038:1420` device. The app forwarded its initial neutral report. FS25 recognition and mappings still need in-game testing.

FS25 subsequently recognized the virtual Nimbus profile, but assigned input to the physical Nimbus+ as well. Start Emulation now requires exclusive access to the physical Bluetooth Nimbus+ and reads its HID elements directly. Start emulation before launching FS25 so the virtual controller is ready during discovery. The virtual device has a fixed serial number so the game can retain bindings across launches. FS25 may still list the physical controller, so test which device actually generates bindings.

To reproduce the local diagnostic build:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project NimbusBridge.xcodeproj -scheme NimbusBridge -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath /tmp/NimbusBridge-HID-Dev \
  ENABLE_APP_SANDBOX=NO -allowProvisioningUpdates build
```
