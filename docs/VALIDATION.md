# Validation checklist

## Evidence from this development session

- Xcode Debug build: succeeded, code signing disabled for build validation.
- Xcode unit tests: 3 passed (dead zone/inversion/NaN; neutral/missing controls/button mapping; Codable profile round trip).
- IORegistry: Nimbus+ Bluetooth VID 13 PID 0 and USB VID 4152 PID 5154 present.
- Actual physical control movement, virtual creation, report forwarding and FS25 behavior: unverified.

## Manual monitor validation

1. Run NimbusBridge in Xcode. Pair Nimbus+ via Bluetooth. Confirm connection independently in System Information; a USB entry is insufficient.
2. Move both sticks through full range and release. Check X/Y signs and center values. Test all D-pad directions and diagonals.
3. Test A/B/X/Y, shoulders, triggers, menu, options, home and stick clicks where exposed. Record element names and analog flags from Diagnostics. Slowly squeeze each trigger to establish whether values are continuous or binary; do not infer from DS4 behavior.
4. Confirm input count and last event advance on actual events, not merely connection. Save dead zone/inversion/button changes, check mapped preview and relaunch to check persistence.
5. Disconnect while controls are held: connection and snapshot must reset. Reconnect and verify input resumes. Check menu bar status.

## Backend gate — not yet available

6. Obtain approved virtual HID entitlement and matching signing/provisioning. Implement generic descriptor/report encoder and CoreHID lifecycle, with an independent HIDDeviceManager or IOHIDManager observer installed before creation. Match a session-unique identity; wait with timeout. Never call creation successful solely because initialization returned an object.
7. Verify descriptor/report byte lengths and ranges with unit tests. Confirm report submission errors are surfaced. Read values independently through IOHIDManager; a submitted-report counter is not receipt evidence. Stop/disconnect must send neutral state then destroy the device; verify disappearance. Serialize forwarding and bound pending input to prevent backlog/stale states.
8. Implement a coherent DS4 protocol only after generic functionality is established, if required. Test feature/output requests rather than just spoofing Sony identifiers.

## FS25 acceptance — requires interactive gameplay

9. Start output before FS25. Locate FS25's user-data `log.txt` (commonly under `~/Library/Application Support/FarmingSimulator2025/`; confirm the actual path locally). Save a before/after copy. Record device name, VID/PID, axes and buttons. Log enumeration alone is not proof of control.
10. Use FS25 controller settings to bind only the virtual device and clear physical Nimbus bindings if supported. Test steering, camera, throttle/brake, menus, face buttons, triggers and diagonals in a safe saved game. Verify no doubled movement/actions, stuck controls or lost neutral state.
11. Test disconnect/reconnect, stopping output and relaunching FS25. Record OS/app/game versions, signing identity/profile, descriptor hash, report samples and observed failures. Mark compatible only after actual gameplay passes.
