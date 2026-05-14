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
    @Published private(set) var heartbeatStatus: ValidationStatus = .notTested
    @Published private(set) var notifyStatus: ValidationStatus = .notTested
    @Published private(set) var isNotifying = false
    @Published private(set) var heartbeatCount = 0
    @Published private(set) var scanCallbackCount = 0
    @Published private(set) var lastHeartbeat: HeartbeatSnapshot?
    @Published private(set) var connectionState: BLEConnectionState = .disconnected
    @Published private(set) var connectedDeviceID: UUID?
    @Published private(set) var connectingDeviceID: UUID?
    @Published private(set) var hasScanAttempted = false
    @Published private(set) var lastScanError: String?
    @Published private(set) var scanFilterLabel = "All BLE Services"
    @Published private(set) var runtimeEnvironment = "Device"

    private var centralManager: CBCentralManager!
    private var peripheralByID: [UUID: CBPeripheral] = [:]
    private var connectedPeripheral: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?
    private var notifyCharacteristic: CBCharacteristic?
    private var pendingTcb02Action: TCB02Action?
    private var scanSessionID = UUID()

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
        #if targetEnvironment(simulator)
        runtimeEnvironment = "Simulator"
        #else
        runtimeEnvironment = "Device"
        #endif
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
        hasScanAttempted = true
        guard centralManager.state == .poweredOn else {
            let stateText = bluetoothStateLabel
            lastScanError = "BLE state is \(stateText)"
            appendLog(.error, "SCAN failed: bluetoothState=\(stateText)")
            scanStatus = .failed
            return
        }

        lastScanError = nil
        devices.removeAll()
        scanCallbackCount = 0
        scanFilterLabel = "All BLE Services"
        scanSessionID = UUID()
        let options: [String: Any] = [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        centralManager.scanForPeripherals(withServices: nil, options: options)
        isScanning = true
        appendLog(.scan, "SCAN API started: services=nil (all peripherals)")
        appendLog(.scan, "Vendor reference service UUIDs: \(serviceUUIDs.map(\.uuidString).joined(separator: ","))")
        appendLog(.scan, "Authorization=\(bluetoothAuthorizationLabel) plistKeysPresent=\(hasBluetoothUsageDescriptions) runtime=\(runtimeEnvironment)")
        if !hasBluetoothUsageDescriptions {
            appendLog(.error, "Info.plist BLE usage keys missing; iOS may suppress permission prompts/results.")
        }
        scheduleScanDiagnostics(for: scanSessionID)
    }

    private func stopScan() {
        centralManager.stopScan()
        isScanning = false
        appendLog(.scan, "SCAN stopped")
    }

    func connect(peripheralID: UUID) {
        guard let peripheral = peripheralByID[peripheralID] else {
            appendLog(.error, "CONNECT failed: peripheral not found id=\(peripheralID.uuidString)")
            connectStatus = .failed
            return
        }
        connectingDeviceID = peripheralID
        connectionState = .connecting
        appendLog(.connect, "CONNECT request: id=\(peripheralID.uuidString) name=\(peripheral.name ?? "NoName")")
        centralManager.connect(peripheral, options: nil)
    }

    func disconnect() {
        guard let connectedPeripheral else {
            appendLog(.connect, "DISCONNECT ignored: no connected peripheral")
            return
        }
        appendLog(.connect, "DISCONNECT request: id=\(connectedPeripheral.identifier.uuidString)")
        centralManager.cancelPeripheralConnection(connectedPeripheral)
    }

    func bindScooter() {
        guard writeCharacteristic != nil else {
            appendLog(.error, "BIND failed: write characteristic not ready")
            bindStatus = .failed
            return
        }
        do {
            let payload = try TCB02Command.writeConnect(on: true, userID: validatorUserID)
            pendingTcb02Action = .bind
            appendLog(.tx, "TX SDK TCB02Command.writeConnect(on:true,userID:\(validatorUserID)) bytes=\(payload.hexString)")
            send(payload)
        } catch {
            appendLog(.error, "BIND sdk error: \(error)")
            bindStatus = .failed
            pendingTcb02Action = nil
        }
    }

    func unbindScooter() {
        guard writeCharacteristic != nil else {
            appendLog(.error, "UNBIND failed: write characteristic not ready")
            unbindStatus = .failed
            return
        }
        do {
            let payload = try TCB02Command.readUnbind()
            pendingTcb02Action = .unbind
            appendLog(.tx, "TX SDK TCB02Command.readUnbind() bytes=\(payload.hexString)")
            send(payload)
        } catch {
            appendLog(.error, "UNBIND sdk error: \(error)")
            unbindStatus = .failed
            pendingTcb02Action = nil
        }
    }

    private func appendLog(_ category: ValidationLogCategory, _ message: String) {
        logs.insert(ValidationLog(category: category, message: message), at: 0)
        if logs.count > 200 {
            logs.removeLast(logs.count - 200)
        }
    }

    private func scheduleScanDiagnostics(for sessionID: UUID) {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(8))
            guard sessionID == scanSessionID, isScanning else { return }
            if scanCallbackCount == 0 {
                appendLog(.error, "SCAN diagnostics: no scan callbacks received after 8s")
                appendLog(.error, "Possible causes: no BLE advertisements nearby, scooter not advertising now, or iOS radio/environment constraints")
            } else if devices.isEmpty {
                appendLog(.error, "SCAN diagnostics: callbacks received but device list is empty (possible UI/filtering issue)")
            } else {
                appendLog(.scan, "SCAN diagnostics: callbacks=\(scanCallbackCount), devices=\(devices.count)")
            }
        }
    }

    var bluetoothStateLabel: String {
        switch bluetoothState {
        case .unknown: return "Unknown"
        case .resetting: return "Resetting"
        case .unsupported: return "Unsupported"
        case .unauthorized: return "Unauthorized"
        case .poweredOff: return "Powered Off"
        case .poweredOn: return "Powered On"
        @unknown default: return "Unknown"
        }
    }

    var scanStatusLabel: String {
        if connectionState == .connected {
            return "Connected"
        }
        if bluetoothState == .poweredOff {
            return "Bluetooth OFF"
        }
        if bluetoothState == .unauthorized {
            return "Permissions missing"
        }
        if bluetoothState == .unsupported {
            return "Failed"
        }
        if scanStatus == .failed {
            return "Failed"
        }
        if isScanning {
            return devices.isEmpty ? "Scanning..." : "Devices found: \(devices.count)"
        }
        if hasScanAttempted && devices.isEmpty {
            return "No devices found"
        }
        if !devices.isEmpty {
            return "Devices found: \(devices.count)"
        }
        return "Ready to scan"
    }

    var scanStateLabel: String {
        if connectionState == .connected {
            return "Connected"
        }
        if connectionState == .connecting {
            return "Connecting"
        }
        if isScanning {
            return devices.isEmpty ? "Scanning" : "Devices Found"
        }
        return "Idle"
    }

    var bluetoothAuthorizationLabel: String {
        switch CBManager.authorization {
        case .allowedAlways: return "Allowed"
        case .denied: return "Denied"
        case .restricted: return "Restricted"
        case .notDetermined: return "Not Determined"
        @unknown default: return "Unknown"
        }
    }

    var hasBluetoothUsageDescriptions: Bool {
        let always = Bundle.main.object(forInfoDictionaryKey: "NSBluetoothAlwaysUsageDescription") as? String
        let peripheral = Bundle.main.object(forInfoDictionaryKey: "NSBluetoothPeripheralUsageDescription") as? String
        return !(always?.isEmpty ?? true) && !(peripheral?.isEmpty ?? true)
    }

    func connectionLabel(for deviceID: UUID) -> String {
        if connectedDeviceID == deviceID {
            return "Connected"
        }
        if connectingDeviceID == deviceID {
            return "Connecting"
        }
        return "Not Connected"
    }

    var connectedDevice: BLEScanDevice? {
        guard let connectedDeviceID else { return nil }
        return devices.first(where: { $0.peripheralID == connectedDeviceID })
    }
}

extension BLEFoundationViewModel: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            bluetoothState = central.state
            appendLog(.scan, "BLE state update: \(bluetoothStateLabel)")
            if central.state == .unauthorized {
                appendLog(.error, "Permissions missing: Bluetooth authorization is denied/restricted")
            } else if central.state == .poweredOff {
                appendLog(.error, "Bluetooth is powered off")
            } else if central.state == .poweredOn {
                appendLog(.scan, "Bluetooth powered on: scan ready")
            }
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
            let advServiceUUIDs = (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID]) ?? []
            let advOverflowUUIDs = (advertisementData[CBAdvertisementDataOverflowServiceUUIDsKey] as? [CBUUID]) ?? []
            let connectable = (advertisementData[CBAdvertisementDataIsConnectable] as? NSNumber)?.boolValue
            scanCallbackCount += 1

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
            appendLog(
                .scan,
                "SCAN callback triggered: name=\(name) id=\(id.uuidString) rssi=\(rssi) connectable=\(String(describing: connectable)) advServices=\(advServiceUUIDs.map(\.uuidString)) overflowServices=\(advOverflowUUIDs.map(\.uuidString))"
            )
            appendLog(.scan, "Device discovered: name=\(name), rssi=\(rssi), identifier=\(id.uuidString)")
            scanStatus = .passed
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            connectedPeripheral = peripheral
            connectedDeviceID = peripheral.identifier
            connectingDeviceID = nil
            connectionState = .connected
            connectStatus = .passed
            appendLog(.connect, "CONNECT success: id=\(peripheral.identifier.uuidString) name=\(peripheral.name ?? "NoName")")
            peripheral.delegate = self
            writeCharacteristic = nil
            notifyCharacteristic = nil
            notifyStatus = .notTested
            isNotifying = false
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
            connectingDeviceID = nil
            connectionState = .disconnected
            connectStatus = .failed
            writeCharacteristic = nil
            notifyCharacteristic = nil
            notifyStatus = .failed
            isNotifying = false
            appendLog(.error, "CONNECT failed: id=\(peripheral.identifier.uuidString) error=\(String(describing: error))")
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
            connectingDeviceID = nil
            connectionState = .disconnected
            writeCharacteristic = nil
            notifyCharacteristic = nil
            notifyStatus = .notTested
            isNotifying = false
            appendLog(.connect, "DISCONNECT callback: id=\(peripheral.identifier.uuidString) error=\(String(describing: error))")
        }
    }
}

extension BLEFoundationViewModel: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: (any Error)?) {
        Task { @MainActor in
            appendLog(.connect,
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
            appendLog(.connect,
                "CHAR discovered: service=\(service.uuid.uuidString) count=\(service.characteristics?.count ?? 0) error=\(String(describing: error))"
            )
            service.characteristics?.forEach { characteristic in
                if serviceUUIDs.contains(service.uuid) {
                    if characteristic.uuid == CBUUID(string: TCBConstant.uuidWrite),
                       characteristic.properties.contains(.writeWithoutResponse) {
                        writeCharacteristic = characteristic
                        appendLog(.connect, "CHAR ready write=\(characteristic.uuid.uuidString)")
                    } else if characteristic.uuid == CBUUID(string: TCBConstant.uuidNotify),
                              characteristic.properties.contains(.notify) {
                        notifyCharacteristic = characteristic
                        appendLog(.notify, "CHAR ready notify=\(characteristic.uuid.uuidString)")
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
            appendLog(.notify,
                "NOTIFY state: char=\(characteristic.uuid.uuidString) isNotifying=\(characteristic.isNotifying) error=\(String(describing: error))"
            )
            if error == nil {
                isNotifying = characteristic.isNotifying
                notifyStatus = characteristic.isNotifying ? .passed : .partial
            } else {
                notifyStatus = .failed
                isNotifying = false
            }
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: (any Error)?
    ) {
        Task { @MainActor in
            let data = characteristic.value ?? Data()
            appendLog(.rx, "RX callback: char=\(characteristic.uuid.uuidString) bytes=\(data.hexString) error=\(String(describing: error))")
            let model = TCBManager.convertToModel(data: data)
            appendLog(.sdkParse, "SDK parsed model: \(type(of: model))")
            if let bindModel = model as? TCB02Model {
                if pendingTcb02Action == .bind {
                    bindStatus = .passed
                } else if pendingTcb02Action == .unbind {
                    unbindStatus = .passed
                }
                pendingTcb02Action = nil
                appendLog(.sdkParse,
                    "SDK parsed TCB02Model: bluetoothStatus=\(bindModel.bluetoothStatus) lockStatus=\(bindModel.lockStatus) boundId=\(bindModel.boundId)"
                )
            } else if let heartbeatModel = model as? TCB01Model {
                heartbeatStatus = .passed
                heartbeatCount += 1
                lastHeartbeat = HeartbeatSnapshot(
                    powerPercent: heartbeatModel.power,
                    realTimeSpeed: heartbeatModel.realTimeSpeed,
                    batteryVoltageRaw: heartbeatModel.batteryVoltage,
                    gear: heartbeatModel.gear,
                    lockStatus: heartbeatModel.lockStatus,
                    cruiseStatus: heartbeatModel.cruiseStatus,
                    controllerFault: heartbeatModel.controllerFault
                )
                appendLog(.sdkParse,
                    "SDK parsed TCB01Model: power=\(heartbeatModel.power) speed=\(heartbeatModel.realTimeSpeed) batteryVoltageRaw=\(heartbeatModel.batteryVoltage) gear=\(heartbeatModel.gear) lock=\(heartbeatModel.lockStatus) cruise=\(heartbeatModel.cruiseStatus) controllerFault=\(heartbeatModel.controllerFault)"
                )
            }
        }
    }

    private func send(_ data: Data) {
        guard let connectedPeripheral, let writeCharacteristic else {
            appendLog(.error, "TX skipped: connection/characteristic not ready")
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
