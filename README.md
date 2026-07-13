# micro-pulse

A tiny SwiftUI iPhone app to control a **Pulse mindfulness ring** over Bluetooth —
set an arbitrary **vibration interval** and pick a **vibration pattern** — bypassing
the official app's fixed presets. It talks to the ring using the phone's existing
bond, so no unpairing is needed.

Built because the official Pulse app only offers four interval presets (20/30/60/120
min) and no way to choose intervals like 1, 3, or 7 minutes.

## Build & run

Requires Xcode and a personal Apple ID (free) or paid developer account. From the
project directory:

```sh
xcodegen generate           # regenerates MicroPulse.xcodeproj from project.yml
open MicroPulse.xcodeproj
```

In Xcode:
1. Select the **MicroPulse** target → **Signing & Capabilities** → set **Team** to
   your Apple ID (adds a personal signing certificate automatically).
2. Plug in your iPhone (or use a paired wireless device) and pick it as the run
   destination.
3. **Run** (⌘R). First launch: on the iPhone, trust the developer profile under
   *Settings → General → VPN & Device Management*.
4. Grant the Bluetooth permission prompt.

> Free Apple ID signing expires after 7 days — just re-run from Xcode to refresh.
> The `.xcodeproj` is generated (git-ignored); edit `project.yml` and re-run
> `xcodegen` to change build settings.

## Using it

Launch the app near the ring. It scans, connects, runs the unlock handshake, and
shows **Ready**. Then tap an interval preset (or set a custom value) or a vibration
pattern — each fires the full command sequence in a fraction of a second, and the
ring reacts immediately.

1 minute works; 10 seconds is rejected.

**Keep the official Pulse app force-quit** while using this — otherwise iOS may
reconnect the ring to it and steal the single BLE connection.

## Protocol (reverse-engineered)

All commands are Write Requests to characteristic `E3750002-EA37-4DB0-8A7B-003F177D7BA3`
under service `E3750001-…`; the ring replies with notifications on `E3750003-…`.

**Per connection**, once, after enabling notifications — unlock handshake:
`0550f133b792`, `028c01`, `010a`, `014e`, `0118`, `072a202e160c067e`.

**Interval** (`0e8403` + A·u32le + B·u16le + flag + pad, where A+B = seconds;
fixed interval ⇒ A=seconds, B=0), preceded by the commit prefix:
```
06540000005802
09221c00000000000000
0e8403<seconds·u32le>0000010000000000
```

**Vibration pattern** (define → commit → play):
```
0b880300<pattern>
06540000000000
0922<pattern>
```

| Pattern | 8 bytes |
|---|---|
| Pulse | `5e5e000000000000` |
| Ohm | `6b5e000000000000` |
| Soft | `6464646400000000` |
| Prominent | `5656565656560000` |
| Purring Cat 1 | `3737373737373737` |
| Purring Cat 2 | `5858580000000000` |
| Knock Knock | `010b010b010b010b` |

## Layout

```
project.yml               xcodegen spec (source of truth for the Xcode project)
Sources/
  MicroPulseApp.swift      @main entry
  ContentView.swift        UI: status + interval/vibration buttons
  RingController.swift     CoreBluetooth: connect, handshake, sequential write queue
  Commands.swift           the byte-level protocol
```
