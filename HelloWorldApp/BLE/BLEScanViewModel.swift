import CoreBluetooth
import Foundation

@MainActor
final class BLEFoundationViewModel: NSObject, ObservableObject {
    @Published private(set) var bluetoothState: CBManagerState = .unknown
    @Published private(set) var isScanning = false
    @Published private(set) var devices: [BLEScanDevice] = []
    @Published private(set) var logs: [ValidationLog] = []
    @Published private(set) var scanStatus: ValidationStatus = .notTested
    @Published private(set) var connectStatus: ValidationStatus = .notTested
    @Published private(set) var connectionState: BLEConnectionState = .disconnected
    @Published private(set) var connectedDeviceID: UUID?

    private var centralManager: CBCentralManager!
    private var peripheralByID: [UUID: CBPeripheral] = [:]
    private var connectedPeripheral: CBPeripheral?

    private let serviceUUIDs: [CBUUID] = [
        CBUUID(string: "54430011-0153-3236-FFFF-FFFFFFFBFFFF"),
        CBUUID(string: "54430011-0153-3239-FFFF-FFFFFFF7FFFF")
    ]

    override init() {
        super.init()
        centralManager = CBCentralManager(
            delegate: self,
            queue: nil,
            options: [CBCentralManagerOptionShowPowerAlertKey: true]
        )
    }

    func toggleScan() {
        if isScanning {
            stopScan()
        } else {
            startScan()
        }
    }

    private func startScan() {
        guard centralManager.state == .poweredOn else {
            appendLog("SCAN failed: bluetoothState=\(centralManager.state.rawValue)")
            scanStatus = .failed
            return
        }

        devices.removeAll()
        let options: [String: Any] = [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        centralManager.scanForPeripherals(withServices: serviceUUIDs, options: options)
        isScanning = true
        appendLog("SCAN start: services=\(serviceUUIDs.map(\\.uuidString).joined(separator: \",\"))")
    }

    private func stopScan() {
        centralManager.stopScan()
        isScanning = false
        appendLog("SCAN stop")
    }

    func connect(peripheralID: UUID) {
        guard let peripheral = peripheralByID[peripheralID] else {
            appendLog("CONNECT failed: peripheral not found id=\(peripheralID.uuidString)")
            connectStatus = .failed
            return
        }
        connectionState = .connecting
        appendLog("CONNECT request: id=\(peripheralID.uuidString) name=\(peripheral.name ?? "NoName")")
        centralManager.connect(peripheral, options: nil)
    }

    func disconnect() {
        guard let connectedPeripheral else {
            appendLog("DISCONNECT ignored: no connected peripheral")
            return
        }
        appendLog("DISCONNECT request: id=\(connectedPeripheral.identifier.uuidString)")
        centralManager.cancelPeripheralConnection(connectedPeripheral)
    }

    private func appendLog(_ message: String) {
        logs.insert(ValidationLog(message: message), at: 0)
        if logs.count > 200 {
            logs.removeLast(logs.count - 200)
        }
    }
}

extension BLEFoundationViewModel: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            bluetoothState = central.state
            appendLog("BLE state update: \(central.state.rawValue)")
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        Task { @MainActor in
            let name = (advertisementData[CBAdvertisementDataLocalNameKey] as? String)
                ?? peripheral.name
                ?? "NoName"
            let id = peripheral.identifier
            let rssi = RSSI.intValue

            if let index = devices.firstIndex(where: { $0.peripheralID == id }) {
                devices[index].name = name
                devices[index].rssi = rssi
                devices[index].discoverCount += 1
                devices[index].lastSeen = Date()
            } else {
                peripheralByID[id] = peripheral
                devices.append(
                    BLEScanDevice(
                        peripheralID: id,
                        name: name,
                        rssi: rssi,
                        discoverCount: 1,
                        lastSeen: Date()
                    )
                )
            }

            devices.sort { $0.rssi > $1.rssi }
            appendLog("SCAN didDiscover: name=\(name) id=\(id.uuidString) rssi=\(rssi)")
            scanStatus = .passed
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            connectedPeripheral = peripheral
            connectedDeviceID = peripheral.identifier
            connectionState = .connected
            connectStatus = .passed
            appendLog("CONNECT success: id=\(peripheral.identifier.uuidString) name=\(peripheral.name ?? "NoName")")
            peripheral.delegate = self
            peripheral.discoverServices(nil)
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: (any Error)?
    ) {
        Task { @MainActor in
            connectedPeripheral = nil
            connectedDeviceID = nil
            connectionState = .disconnected
            connectStatus = .failed
            appendLog("CONNECT failed: id=\(peripheral.identifier.uuidString) error=\(String(describing: error))")
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: (any Error)?
    ) {
        Task { @MainActor in
            connectedPeripheral = nil
            connectedDeviceID = nil
            connectionState = .disconnected
            appendLog("DISCONNECT callback: id=\(peripheral.identifier.uuidString) error=\(String(describing: error))")
        }
    }
}

extension BLEFoundationViewModel: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: (any Error)?) {
        Task { @MainActor in
            appendLog(
                "SERVICES discovered: id=\(peripheral.identifier.uuidString) count=\(peripheral.services?.count ?? 0) error=\(String(describing: error))"
            )
        }
    }
}
