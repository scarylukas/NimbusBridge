# Backend decision — 2026-11-01

Environment inspected: arm64, macOS 27.2 build 26B123, Xcode 27.2 build 27B52, Swift 6.4.2. The shell selects Command Line Tools; explicit DEVELOPER_DIR selects the installed Xcode. SDK CoreHID.swiftinterface confirms HIDVirtualDevice, activate(delegate:), dispatchInputReport and HIDDeviceManager device notifications.

## Decision

Prefer CoreHID HIDVirtualDevice for the first generic HID prototype, contingent on approved signing and provisioning. It avoids a separate DriverKit installation and has a Swift concurrency interface. This is a backend selection, not a working backend. No approved virtual-HID provisioning profile was supplied, and the project intentionally claims no restricted entitlement. Current VirtualControllerService is a truthful blocker/preflight service. Generic descriptor, report encoding, enumeration and input readback remain future work.

[Apple virtual HID entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.hid.virtual.device) authorizes virtual HID creation. Adding an entitlement file alone does not grant the capability. Obtain Apple's approval and a matching development/distribution provisioning profile before enabling it. Do not use ad-hoc signing or SIP changes as an entitlement workaround. Keep monitoring independently runnable.

[CoreHID HIDVirtualDevice](https://developer.apple.com/documentation/corehid/hidvirtualdevice) is the modern API. [IOHIDUserDevice](https://developer.apple.com/documentation/iokit/iohiduserdevice) is the older C alternative; choosing it does not establish a way around access controls. Both still require real system enumeration and consumer tests.

[DriverKit](https://developer.apple.com/documentation/driverkit) supports Apple Silicon. HIDDriverKit is the alternative if a user-space virtual device cannot satisfy the game. That path requires an independently signed/provisioned driver system extension, appropriate approved DriverKit/HID entitlements, host system-extension installation entitlement and user approval. Host user-client access must name the driver if used. No extension is currently bundled. Scope exact entitlements to the eventual driver design rather than adding broad claims now.

[OpenJoystickDriver](https://github.com/xsyetopz/OpenJoystickDriver) documents CoreHID on recent macOS and multiple controller personas. This is evidence for investigating user-space gamepads, not evidence NimbusBridge works. Do not copy descriptors or source without reviewing its license. [PadLink](https://padlink.nimets.com/) describes its own notarized DriverKit DS4 implementation. Its product claims do not establish entitlement availability for this project or a reusable open-source DS4 backend. [Karabiner VirtualHIDDevice](https://github.com/pqrs-org/Karabiner-DriverKit-VirtualHIDDevice) illustrates DriverKit packaging but targets keyboard/pointing devices, not drop-in gamepads.

## DS4 and compatibility risks

A Sony VID/PID is insufficient. DS4 consumers may require exact report IDs, sizes, feature replies, transport behavior and initialization beyond basic controls. Do not publish a Sony identity with an unrelated generic descriptor. A generic gamepad should use an appropriate development identity, explicit generic name, four stick axes, hat, buttons and separate triggers. Its acceptance by FS25 remains unknown. Apple's controller stack may filter virtual devices; HID enumeration alone is not GameController or game compatibility evidence.

The monitor reads Nimbus names and extended profiles through GameController, not raw USB. GameController does not expose authoritative transport/VID/PID. System IORegistry inspection on this machine showed both Nimbus+ USB 1038:1422 and Bluetooth 000D:0000; no input events have been manually validated. USB presence does not prove gameplay input.

The sandbox is retained for Phase 2. Reassess backend sandbox requirements with the approved provisioning profile and actual creation error; do not silently remove sandboxing or security protections. No system files, physical device suppression, firmware, or game executable changes are proposed.

## Duplicate input

Monitoring uses GameController. During emulation, NimbusBridge opens the single Bluetooth Nimbus+ gamepad with IOKit's exclusive-open option, reads it directly, and forwards the mapped values to the virtual controller. Stopping emulation, unplugging or disconnecting the gamepad, or failure to start virtual output releases the exclusive open. The physical device may still appear in device lists. Validate that FS25 receives controls from the virtual pad and that physical-pad bindings do not fire.
