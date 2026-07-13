import CoreBluetooth
import Foundation

/// Connects to the Pulse ring over the phone's existing bond, runs the unlock
/// handshake once, and sends interval / vibration commands as sequential writes.
final class RingController: NSObject, ObservableObject {
    enum Status: String {
        case bluetoothOff = "Bluetooth is off"
        case searching = "Searching for ring…"
        case connecting = "Connecting…"
        case preparing = "Preparing…"
        case ready = "Ready"
        case disconnected = "Disconnected"
    }

    @Published private(set) var status: Status = .disconnected
    @Published private(set) var lastMessage = ""
    @Published private(set) var lastReply = ""

    var isReady: Bool { status == .ready }

    private let serviceUUID = CBUUID(string: "E3750001-EA37-4DB0-8A7B-003F177D7BA3")
    private let writeUUID = CBUUID(string: "E3750002-EA37-4DB0-8A7B-003F177D7BA3")
    private let notifyUUID = CBUUID(string: "E3750003-EA37-4DB0-8A7B-003F177D7BA3")

    private var central: CBCentralManager!
    private var ring: CBPeripheral?
    private var writeChar: CBCharacteristic?

    private var queue: [Data] = []
    private var writing = false
    private var awaitingReady = false

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: nil)  // callbacks on main queue
    }

    // MARK: - Public actions

    func setInterval(minutes: Int) {
        guard isReady else { return }
        enqueue(RingCommands.interval(minutes: minutes))
        lastMessage = "Interval → every \(minutes) min"
    }

    func setVibration(name: String, pattern: String) {
        guard isReady else { return }
        enqueue(RingCommands.vibration(pattern: pattern))
        lastMessage = "Vibration → \(name)"
    }

    func reconnect() {
        guard central.state == .poweredOn, ring == nil else { return }
        startScan()
    }

    // MARK: - Write queue (sequential, with response)

    private func enqueue(_ commands: [Data]) {
        queue.append(contentsOf: commands)
        pump()
    }

    private func pump() {
        guard !writing, let ring, let writeChar, !queue.isEmpty else { return }
        writing = true
        ring.writeValue(queue.removeFirst(), for: writeChar, type: .withResponse)
    }

    private func startScan() {
        status = .searching
        central.scanForPeripherals(withServices: nil, options: nil)
    }

    private func reset() {
        ring = nil
        writeChar = nil
        queue.removeAll()
        writing = false
        awaitingReady = false
    }
}

// MARK: - CBCentralManagerDelegate

extension RingController: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn: startScan()
        case .poweredOff: status = .bluetoothOff
        default: status = .disconnected
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = peripheral.name ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? ""
        let services = (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID]) ?? []
        guard name == "Ring" || services.contains(serviceUUID) else { return }
        central.stopScan()
        ring = peripheral
        peripheral.delegate = self
        status = .connecting
        central.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        status = .preparing
        peripheral.discoverServices([serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        reset()
        status = .disconnected
        startScan()
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        reset()
        status = .disconnected
        startScan()
    }
}

// MARK: - CBPeripheralDelegate

extension RingController: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil, let service = peripheral.services?.first(where: { $0.uuid == serviceUUID }) else {
            lastReply = error.map { "Discover failed: \($0.localizedDescription)" } ?? "Ring service not found"
            return
        }
        peripheral.discoverCharacteristics([writeUUID, notifyUUID], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for characteristic in service.characteristics ?? [] {
            switch characteristic.uuid {
            case writeUUID: writeChar = characteristic
            case notifyUUID: peripheral.setNotifyValue(true, for: characteristic)
            default: break
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        // Notifications on → run the unlock handshake, then mark ready when it drains.
        awaitingReady = true
        enqueue(RingCommands.handshake)
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        writing = false
        if let error {
            lastReply = "Write failed: \(error.localizedDescription)"
        }
        if queue.isEmpty && awaitingReady {
            awaitingReady = false
            status = .ready
        }
        pump()
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let value = characteristic.value { lastReply = "ring: \(value.hexString)" }
    }
}
