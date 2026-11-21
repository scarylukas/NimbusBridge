> Superseded: user selected the built-in Nimbus profile. See FS25-NIMBUS-EXPERIMENT.md. DS4 is not the active implementation target.

# FS25 DS4 identity and mapping experiment

Evidence: installed FS25 `SonyPlaystation4Controller_Mac.xml`, read on 2026-11-09. No game files changed. This is a consumer mapping definition, not a DS4 HID descriptor or proof that a virtual device will be accepted.

Backend: `macosXSdl`. Name keywords: `wireless`, `controller`; vendor `054C`.

Product identities declared by the game:
- VID `054C`, PID `05C4`
- VID `054C`, PID `09CC`

## Expected buttons after the macOS/SDL backend

| Control | Physical index | FS25 logical index |
|---|---:|---:|
| Square | 2 | 0 |
| Cross | 0 | 1 |
| Circle | 1 | 2 |
| Triangle | 3 | 3 |
| L1 | 9 | 4 |
| R1 | 10 | 5 |
| SET | 4 | 8 |
| Options | 6 | 9 |
| LS | 7 | 10 |
| RS | 8 | 11 |
| PS | 5 | 12 |
| Touch | 15 | 13 |
| DP-Up | 11 | 16 |
| DP-Down | 12 | 18 |
| DP-Left | 13 | 19 |
| DP-Right | 14 | 17 |

## Expected axes after the macOS/SDL backend

| Control | Physical axis | Logical index | Scale | Offset |
|---|---|---:|---:|---:|
| LS-X | X | 0 | 1 | 0 |
| LS-Y | Y | 1 | 1 | 0 |
| RS-X | RX | 2 | 1 | 0 |
| LT | Z | 11 | -1 | 0 |
| RT | RZ | 10 | -1 | 0 |
| RS-Y | RY | 3 | 1 | 0 |

## Experiment acceptance

1. Publish a coherent DS4 device and reports; test one declared PID at a time. Sony IDs alone do not reproduce the HID contract or the macOS/SDL translation.
2. Independently enumerate the device; record actual VID/PID, name, transport and controls. Confirm which backend FS25 uses for this instance from runtime evidence.
3. Start FS25 after creation and inspect its log: category, loaded mapping if reported, axes and buttons. Identity matching and functional mapping are separate outcomes.
4. Test each control above in isolation, then diagonals and simultaneous inputs. Record actual physical index, sign, range and neutral. Pay particular attention to shoulder indices 9/10, Options index 6, D-pad buttons 11–14, and trigger axes Z/RZ with negative scale.
5. Check in-game default actions, duplicate physical Nimbus input, release/neutral and reconnect behavior. No compatibility claim before gameplay passes.

Current generic NimbusBridge descriptor is not a DS4 profile: it exposes four axes, a hat and twelve buttons; triggers are buttons, not Z/RZ axes. Its button order is also different. Changing only VID/PID cannot establish correct mapping and could select an incompatible DS4 decoding path.

The installed SteelseriesNimbus.xml targets 1038:1420 (and name matching constrained to vendor 1038), whereas the reported Bluetooth Nimbus+ identity is 000D:0000 at IORegistry level and 0000:0000 in the earlier FS25 log. This is a concrete identity mismatch worth recording; it does not alone prove how FS25 chooses a fallback profile.

Runtime gate remains: both CoreHID and public IOHIDUserDevice creation probes failed without the virtual-HID entitlement. This document establishes test expectations, not a bypass or a successful experiment.
