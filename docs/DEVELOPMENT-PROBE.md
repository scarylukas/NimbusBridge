# Development probe — 2026-11-09

`tools/VirtualHIDProbe.swift` calls CoreHID directly, without the app's entitlement preflight. It uses an input-only eight-button gamepad descriptor and zero vendor/product IDs, and checks independent IOHIDManager enumeration if creation succeeds. It never claims a Sony identity, signs with invented entitlements, or changes SIP/system settings.

Build and run:

```sh
xcrun swiftc -module-cache-path /tmp/NimbusBridgeProbeCache -parse-as-library tools/VirtualHIDProbe.swift -o /tmp/NimbusBridgeVirtualHIDProbe
/tmp/NimbusBridgeVirtualHIDProbe
```

Observed output, both within the development tool sandbox and when executed outside it:

```text
Signed entitlement: nil
FAIL: HIDVirtualDevice initializer returned nil. No device created.
```

This proves the failure is not solely the application's preflight guard, nor solely the development tool's sandbox. The failable CoreHID initializer supplies no detailed error; absent entitlement is a plausible cause, not a fully isolated diagnosis. No entitlement-bearing provisioning profile was tested. Enumeration, receipt and game compatibility remain untested because creation failed.

The probe creates only a temporary device if permitted and exits after enumeration and neutral report submission. Run again after configuring approved signing/provisioning to compare results.

## Direct IOHIDUserDevice and signing audit

A second independent probe, `tools/IOHIDUserDeviceProbe.c`, uses the public SDK function `IOHIDUserDeviceCreateWithProperties`, without CoreHID or an application entitlement preflight:

```sh
xcrun clang -fblocks -Wall -Wextra -Werror tools/IOHIDUserDeviceProbe.c -framework IOKit -framework CoreFoundation -o /tmp/NimbusBridgeIOHIDProbe
/tmp/NimbusBridgeIOHIDProbe
```

Compilation passed. Execution both inside and outside the tool sandbox returned:

```text
FAIL: IOHIDUserDeviceCreateWithProperties returned NULL. No device created.
```

The local SDK header explicitly requires `com.apple.developer.hid.virtual.device`. OpenJoystickDriver's [signing guide](https://github.com/xsyetopz/OpenJoystickDriver/blob/main/docs/development/signing.md) independently documents that requirement on the host app, including a development profile containing the current Mac. Switching APIs therefore provides no demonstrated solution on this machine.

An out-of-sandbox, read-only signing audit found **one valid Apple Development identity**. The previous claim that this machine had no signing identity was based on sandbox-limited visibility and is corrected here. Nine installed profiles were decoded using `security cms`; none grants virtual HID, and none targets NimbusBridge. Certificate presence alone does not grant virtual HID creation.

Next signing steps:

1. In Apple Developer, inspect request 77LR6542FP (submitted November 1) and confirm it requests the host-app virtual HID capability for team 37ESJ57DQJ. The provided screenshot shows Submitted but does not identify the requested entitlement.
2. If it remains pending, follow up with Apple Developer Support using that request ID and explain: local macOS development, GameController Nimbus+ input, CoreHID generic virtual gamepad output, no kernel driver. Ask specifically about development access to `com.apple.developer.hid.virtual.device`.
3. Once granted, enable the capability on explicit App ID `de.scaryteam.NimbusBridge`, register this Mac as required for development, and generate a macOS development profile containing the capability and matching certificate. Do not edit the signed profile or reuse another app's grant.
4. Configure that profile and the matching entitlement on NimbusBridge, then run the probes and verify independent enumeration before claiming success. The existing application backend still requires a correctness review (enumeration verification, mapping/report consistency and forwarding lifecycle) before game testing.

No SIP, AMFI, profile, entitlement or system settings were changed during these tests.
