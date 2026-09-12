# Pulse ring Bluetooth protocol

[README](../README.md) · [Command encoding](../Sources/Commands.swift) · [Connection handling](../Sources/RingController.swift)

Consolidated from the July 12–13, 2026 capture research in `cli` commit
`0f9eac3` and MicroPulse's implementation. Observations concern the tested ring;
no new hardware tests were run. Device identifiers and raw captures are omitted.

## Connection and handshake

Service: `E3750001-EA37-4DB0-8A7B-003F177D7BA3`.

| Role | Characteristic UUID | Captured ATT handle |
|---|---|---|
| Command; write with response | `E3750002-EA37-4DB0-8A7B-003F177D7BA3` | `0x0014` |
| Reply; notifications | `E3750003-EA37-4DB0-8A7B-003F177D7BA3` | `0x0016` |

MicroPulse enables notifications, then sends these six writes sequentially:

```text
0550f133b792       # auth/session
028c01
010a
014e
0118
072a202e160c067e   # apparent clock command
```

The captured auth command arrived unprompted; a static/device key is an inference.
Auth and clock bytes are replayed as fixed constants; portability to other rings
or bonds is unverified. Captured CCCD writes were `0x0017 ← 0100` and
`0x000d ← 0200`; CoreBluetooth uses UUIDs and manages notification subscription.
The separate Secure DFU service (`FE59`, Buttonless DFU `8EC90003-…`) is unrelated.

## Interval

Before **every** interval write, send `06540000005802`, then
`09221c00000000000000`. Without both prefixes, observed acknowledgements did not
mean the setting applied; a confirmation buzz accompanied successful application.

The 15-byte payload is `0e8403` + A (uint32 little-endian) + B (uint16
little-endian) + `01` + five zero bytes. Captured presets satisfy A+B = seconds.
B as a jitter half-window is an interpretation, not verified timing behavior.
For fixed intervals, MicroPulse sets A=seconds and B=0.

| Official preset | Minutes | A | B | Captured payload |
|---|---:|---:|---:|---|
| 3×/hour | 20 | 840 | 360 | `0e8403 48030000 6801 01 0000000000` |
| 2×/hour | 30 | 1440 | 360 | `0e8403 a0050000 6801 01 0000000000` |
| 1×/hour | 60 | 2400 | 1200 | `0e8403 60090000 b004 01 0000000000` |
| Once/2 hours | 120 | 5400 | 1800 | `0e8403 18150000 0807 01 0000000000` |

Fixed examples: 3 minutes = `0e8403 b4000000 0000 01 0000000000`;
7 minutes = `0e8403 a4010000 0000 01 0000000000`.
Replies `022300` then `03850003` were observed after setting; these are
acknowledgements, **not interval read-back**.

## Vibration patterns

Send `0b880300<pattern>` (define), `06540000000000` (commit), then
`0922<pattern>` (play/preview). Each pattern is eight bytes:

| Pattern | Bytes |
|---|---|
| Pulse | `5e5e000000000000` |
| Ohm | `6b5e000000000000` |
| Soft | `6464646400000000` |
| Prominent | `5656565656560000` |
| Purring Cat 1 | `3737373737373737` |
| Purring Cat 2 | `5858580000000000` |
| Knock Knock | `010b010b010b010b` |

Alternating bytes suggest pulse durations; units and full semantics are unknown.
MicroPulse reuses the captured patterns unchanged.

## Observations and limits

- The phone's existing bond worked; Mac connections failed even with phone
  Bluetooth off. Moving the bond and replaying commands from a Mac was not verified.
- Force-quit the official Pulse app: its reconnects can steal the ring connection.
- Fixed 1-, 3-, and 7-minute intervals worked. Ten seconds was rejected; one minute
  is the smallest confirmed value, not a proven minimum. Exact limits are unknown.
- The interval persisted while the phone stayed disconnected. Whether reopening
  the official app overwrites it remains untested.
- MicroPulse marks Ready when handshake write callbacks drain, including callbacks
  reporting errors. It displays reply bytes without decoding setting confirmation;
  Ready and successful writes alone do not establish that a setting applied.

The earlier Mac controller, tests, configuration, and capture decoder are retired;
this reference preserves the decoded findings rather than that implementation.
