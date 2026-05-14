import CoreBluetooth
import Foundation
import TCBleComminucation

@MainActor
final class BLEFoundationViewModel: NSObject, ObservableObject {
    @Published private(set) var bluetoothState: CBManagerState = .unknown
    @Published private(set) var isScanning = false
    @Published private(set) var devices: [BLEScanDevice] = []
    @Published private(set) var logs: [ValidationLog] = []
    @Published private(set) var scanStatus: ValidationStatus = .notTested
    @Published private(set) var connectStatus: ValidationStatus = .notTested
    @Published private(set) var bindStatus: ValidationStatus = .notTested
    @Published private(set) var unbindStatus: ValidationStatus = .notTested
    @Published private(set) var connectionState: BLEConnectionState = .disconnected
    @Published private(set) var connectedDeviceID: UUID?

    private var centralManager: CBCentralManager!
    private var peripheralByID: [UUID: CBPeripheral] = [:]
    private var connectedPeripheral: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?
    private var notifyCharacteristic: CBCharacteristic?
    private var pendingTcb02Action: TCB02Action?

    private let serviceUUIDs: [CBUUID] = [
        CBUUID(string: "54430011-0153-3236-FFFF-FFFFFFFBFFFF"),
        CBUUID(string: "54430011-0153-3239-FFFF-FFFFFFF7FFFF")
    ]
    private let validatorUserID: UInt32 = 0x272b

    private enum TCB02Action {
        case bind
        case unbind
    }

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

    func bindScooter() {
        guard writeCharacteristic != nil else {
            appendLog("BIND failed: write characteristic not ready")
            bindStatus = .failed
            return
        }
        do {
            let payload = try TCB02Command.writeConnect(on: true, userID: validatorUserID)
            pendingTcb02Action = .bind
            appendLog("TX SDK TCB02Command.writeConnect(on:true,userID:\(validatorUserID)) bytes=\(payload.hexString)")
            send(payload)
        } catch {
            appendLog("BIND sdk error: \(error)")
            bindStatus = .failed
            pendingTcb02Action = nil
        }
    }

    func unbindScooter() {
        guard writeCharacteristic != nil else {
            appendLog("UNBIND failed: write characteristic not ready")
            unbindStatus = .failed
            return
        }
        do {
            let payload = try TCB02Command.readUnbind()
            pendingTcb02Action = .unbind
            appendLog("TX SDK TCB02Command.readUnbind() bytes=\(payload.hexString)")
            send(payload)
        } catch {
            appendLog("UNBIND sdk error: \(error)")
            unbindStatus = .failed
            pendingTcb02Action = nil
        }
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
            writeCharacteristic = nil
            notifyCharacteristic = nil
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
            writeCharacteristic = nil
            notifyCharacteristic = nil
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
            writeCharacteristic = nil
            notifyCharacteristic = nil
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
            peripheral.services?.forEach { service in
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: (any Error)?
    ) {
        Task { @MainActor in
            appendLog(
                "CHAR discovered: service=\(service.uuid.uuidString) count=\(service.characteristics?.count ?? 0) error=\(String(describing: error))"
            )
            service.characteristics?.forEach { characteristic in
                if serviceUUIDs.contains(service.uuid) {
                    if characteristic.uuid == CBUUID(string: TCBConstant.uuidWrite),
                       characteristic.properties.contains(.writeWithoutResponse) {
                        writeCharacteristic = characteristic
                        appendLog("CHAR ready write=\(characteristic.uuid.uuidString)")
                    } else if characteristic.uuid == CBUUID(string: TCBConstant.uuidNotify),
                              characteristic.properties.contains(.notify) {
                        notifyCharacteristic = characteristic
                        appendLog("CHAR ready notify=\(characteristic.uuid.uuidString)")
                        peripheral.setNotifyValue(true, for: characteristic)
                    }
                }
            }
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error: (any Error)?
    ) {
        Task { @MainActor in
            appendLog(
                "NOTIFY state: char=\(characteristic.uuid.uuidString) isNotifying=\(characteristic.isNotifying) error=\(String(describing: error))"
            )
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: (any Error)?
    ) {
        Task { @MainActor in
            let data = characteristic.value ?? Data()
            appendLog("RX callback: char=\(characteristic.uuid.uuidString) bytes=\(data.hexString) error=\(String(describing: error))")
            let model = TCBManager.convertToModel(data: data)
            appendLog("SDK parsed model: \(type(of: model))")
            if let bindModel = model as? TCB02Model {
                if pendingTcb02Action == .bind {
                    bindStatus = .passed
                } else if pendingTcb02Action == .unbind {
                    unbindStatus = .passed
                }
                pendingTcb02Action = nil
                appendLog(
                    "SDK parsed TCB02Model: bluetoothStatus=\(bindModel.bluetoothStatus) lockStatus=\(bindModel.lockStatus) boundId=\(bindModel.boundId)"
                )
            }
        }
    }

    private func send(_ data: Data) {
        guard let connectedPeripheral, let writeCharacteristic else {
            appendLog("TX skipped: connection/characteristic not ready")
            return
        }
        connectedPeripheral.writeValue(data, for: writeCharacteristic, type: .withoutResponse)
    }
}

private extension Data {
    var hexString: String {
        map { String(format: "%02X", $0) }.joined()
    }
}
        }
    }
}
