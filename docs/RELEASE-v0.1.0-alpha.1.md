# NimbusBridge v0.1.0-alpha.1

First source prerelease of NimbusBridge, a macOS bridge from a Bluetooth SteelSeries Nimbus+ to a virtual gamepad for Farming Simulator 25.

- Monitor controller input and customize button mappings, stick inversion and dead zones.
- Create a virtual Nimbus controller and keep emulation running from the menu bar.
- Install the FS25 device profile and add missing controller menu bindings. Setup backs up configuration files before updating them.

## Requirements

- macOS 27 or later and Xcode 27.2.
- For virtual controller output, build with an Apple Development signature and a matching provisioning profile granting `com.apple.developer.hid.virtual.device`. The validated development build used `ENABLE_APP_SANDBOX=NO`.

This is a source release. The virtual device was enumerated on a development Mac and recognized by FS25. Gameplay mappings and exclusive access to the physical controller still require end-to-end testing.
