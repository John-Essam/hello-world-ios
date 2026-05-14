import CoreBluetooth
import Foundation

@MainActor
final class BLEScanViewModel: NSObject, ObservableObject {
    @Published private(set) var bluetoothState: CBManagerState = .unknown
    @Published private(set) var isScanning = false
    @Published private(set) var devices: [BLEScanDevice] = []
    @Published private(set) var logs: [ValidationLog] = []
    @Published private(set) var scanStatus: ValidationStatus = .notTested

    private var centralManager: CBCentralManager!

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

    private func appendLog(_ message: String) {
        logs.insert(ValidationLog(message: message), at: 0)
        if logs.count > 200 {
            logs.removeLast(logs.count - 200)
        }
    }
}

extension BLEScanViewModel: CBCentralManagerDelegate {
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
}
