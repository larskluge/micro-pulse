import Foundation

/// Byte-level protocol for the Pulse ring, reverse-engineered from BLE captures of
/// the official app. All commands are Write Requests to characteristic E3750002;
/// the ring replies via notifications on E3750003.
enum RingCommands {
    /// Auth / unlock + clock. Sent once per connection, right after notifications are
    /// enabled. Without it the ring rejects (and disconnects on) subsequent commands.
    static let handshake: [Data] = [
        "0550f133b792",       // auth / unlock (device key)
        "028c01",
        "010a",
        "014e",
        "0118",
        "072a202e160c067e",   // clock
    ].map(Data.init(hex:))

    /// Set the vibration interval. Encoding: `0e8403` + A(u32 LE) + B(u16 LE) + flag
    /// + pad, where A + B = interval in seconds. Fixed interval ⇒ A = seconds, B = 0.
    /// The two writes before it are the required per-set commit prefix.
    static func interval(minutes: Int) -> [Data] { interval(seconds: UInt32(max(1, minutes) * 60)) }

    /// Interval in raw seconds (used by the 10-second test button).
    static func interval(seconds: UInt32) -> [Data] {
        var value = Data([0x0e, 0x84, 0x03])
        withUnsafeBytes(of: seconds.littleEndian) { value.append(contentsOf: $0) }  // A
        value.append(contentsOf: [0x00, 0x00])                                       // B = 0
        value.append(0x01)                                                           // flag
        value.append(contentsOf: [0x00, 0x00, 0x00, 0x00, 0x00])                     // pad
        return [Data(hex: "06540000005802"), Data(hex: "09221c00000000000000"), value]
    }

    /// The vibration patterns the ring exposes, in the app's order. The 8 pattern
    /// bytes encode the rhythm (e.g. Knock Knock alternates short/long: 01 0b 01 0b…).
    static let vibrations: [(name: String, pattern: String)] = [
        ("Pulse", "5e5e000000000000"),
        ("Ohm", "6b5e000000000000"),
        ("Soft", "6464646400000000"),
        ("Prominent", "5656565656560000"),
        ("Purring Cat 1", "3737373737373737"),
        ("Purring Cat 2", "5858580000000000"),
        ("Knock Knock", "010b010b010b010b"),
    ]

    /// Set (and preview) a vibration pattern: define → commit → play.
    static func vibration(pattern hex: String) -> [Data] {
        let p = Data(hex: hex)
        return [Data(hex: "0b880300") + p, Data(hex: "06540000000000"), Data(hex: "0922") + p]
    }
}

extension Data {
    /// Build a `Data` from a hex string like "0e8403". Traps on invalid input —
    /// all call sites here pass compile-time-constant, known-good hex.
    init(hex: String) {
        var bytes = [UInt8]()
        bytes.reserveCapacity(hex.count / 2)
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            bytes.append(UInt8(hex[index..<next], radix: 16)!)
            index = next
        }
        self = Data(bytes)
    }

    var hexString: String { map { String(format: "%02x", $0) }.joined() }
}
