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
    @Published private(set) var lockStatus: ValidationStatus = .notTested
    @Published private(set) var unlockStatus: ValidationStatus = .notTested
    @Published private(set) var heartbeatStatus: ValidationStatus = .notTested
    @Published private(set) var notifyStatus: ValidationStatus = .notTested
    @Published private(set) var isNotifying = false
    @Published private(set) var writeChannelReady = false
    @Published private(set) var notifyChannelReady = false
    @Published private(set) var hasConnectedCallback = false
    @Published private(set) var hasVendorServiceDiscovered = false
    @Published private(set) var isBound = false
    @Published private(set) var lastKnownLockStatus: Bool?
    @Published private(set) var heartbeatCount = 0
    @Published private(set) var scanCallbackCount = 0
    @Published private(set) var scanDuplicateCallbackCount = 0
    @Published private(set) var lastHeartbeat: HeartbeatSnapshot?
    @Published private(set) var connectionState: BLEConnectionState = .disconnected
    @Published private(set) var connectedDeviceID: UUID?
    @Published private(set) var connectingDeviceID: UUID?
    @Published private(set) var hasScanAttempted = false
    @Published private(set) var lastScanError: String?
    @Published private(set) var scanFilterLabel = "All BLE Services (duplicates coalesced)"
    @Published private(set) var runtimeEnvironment = "Device"

    private var centralManager: CBCentralManager!
    private var peripheralByID: [UUID: CBPeripheral] = [:]
    private var connectedPeripheral: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?
    private var notifyCharacteristic: CBCharacteristic?
    private var pendingTcb02Action: TCB02Action?
    private var scanSessionID = UUID()
    private var connectAttemptID = UUID()
    private var bindAttemptID = UUID()
    private var bindStartedAt: Date?
    private var bindResponseCount = 0
    private var lastBindRequestedUserID: UInt32?

    private let serviceUUIDs: [CBUUID] = [
        CBUUID(string: "54430011-0153-3236-FFFF-FFFFFFFBFFFF"),
        CBUUID(string: "54430011-0153-3239-FFFF-FFFFFFF7FFFF")
    ]
    private let writeUUID = CBUUID(string: TCBConstant.uuidWrite)
    private let notifyUUID = CBUUID(string: TCBConstant.uuidNotify)
    private let scooterNamePrefixes = ["cardoOX1", "cardoOX2", "cardoOX3"]
    // Validation target scooter is bound with ID 5 in observed RX evidence.
    private let validatorUserID: UInt32 = 5

    private enum TCB02Action {
        case bind
        case unbind
        case lock
        case unlock
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
        guard !isScanning else {
            appendLog(.scan, "SCAN ignored: already scanning")
            return
        }
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
        peripheralByID.removeAll()
        scanCallbackCount = 0
        scanDuplicateCallbackCount = 0
        scanFilterLabel = "All BLE Services (duplicates coalesced)"
        scanSessionID = UUID()
        let options: [String: Any] = [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        centralManager.scanForPeripherals(withServices: nil, options: options)
        isScanning = true
        appendLog(.scan, "SCAN started: services=nil allowDuplicates=false")
        appendLog(.scan, "Vendor reference service UUIDs: \(serviceUUIDs.map(\.uuidString).joined(separator: ","))")
        appendLog(.scan, "Authorization=\(bluetoothAuthorizationLabel) plistKeysPresent=\(hasBluetoothUsageDescriptions) runtime=\(runtimeEnvironment)")
        if !hasBluetoothUsageDescriptions {
            appendLog(.error, "Info.plist BLE usage keys missing; iOS may suppress permission prompts/results.")
        }
        scheduleScanDiagnostics(for: scanSessionID)
    }

    private func stopScan() {
        guard isScanning else {
            appendLog(.scan, "SCAN stop ignored: not currently scanning")
            return
        }
        centralManager.stopScan()
        isScanning = false
        appendLog(.scan, "SCAN stopped: callbacks=\(scanCallbackCount) duplicates=\(scanDuplicateCallbackCount) devices=\(devices.count)")
    }

    func connect(peripheralID: UUID) {
        guard connectionState == .disconnected else {
            appendLog(.connect, "CONNECT ignored: currentState=\(connectionState.rawValue)")
            return
        }
        guard let peripheral = peripheralByID[peripheralID] else {
            appendLog(.error, "CONNECT failed: peripheral not found id=\(peripheralID.uuidString)")
            connectStatus = .failed
            return
        }
        if isScanning {
            appendLog(.scan, "SCAN auto-stop: connect requested")
            stopScan()
        }
        connectingDeviceID = peripheralID
        connectionState = .connecting
        hasConnectedCallback = false
        hasVendorServiceDiscovered = false
        writeChannelReady = false
        notifyChannelReady = false
        pendingTcb02Action = nil
        connectAttemptID = UUID()
        connectStatus = .notTested
        let candidate = deviceCandidateLabel(for: peripheralID)
        appendLog(.connect, "CONNECT candidate: \(candidate)")
        appendLog(.connect, "CONNECT request: id=\(peripheralID.uuidString) name=\(peripheral.name ?? "NoName")")
        centralManager.connect(peripheral, options: nil)
        scheduleConnectDiagnostics(for: peripheralID, attemptID: connectAttemptID)
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
        guard isCommandChannelReady else {
            appendLog(.error, "BIND blocked: command channel not ready")
            bindStatus = .failed
            return
        }
        guard writeCharacteristic != nil else {
            appendLog(.error, "BIND failed: write characteristic not ready")
            bindStatus = .failed
            return
        }
        do {
            bindAttemptID = UUID()
            bindStartedAt = Date()
            bindResponseCount = 0
            lastBindRequestedUserID = validatorUserID
            appendLog(.connect, "BIND sequence start: attempt=\(bindAttemptID.uuidString) notifyReady=\(notifyChannelReady) writeReady=\(writeChannelReady) vendorService=\(hasVendorServiceDiscovered)")
            let payload = try TCB02Command.writeConnect(on: true, userID: validatorUserID)
            pendingTcb02Action = .bind
            appendLog(.tx, "TX SDK TCB02Command.writeConnect(on:true,userID:\(validatorUserID)) bytes=\(payload.hexString)")
            send(payload)
            scheduleBindDiagnostics(for: bindAttemptID)
        } catch {
            appendLog(.error, "BIND sdk error: \(error)")
            bindStatus = .failed
            pendingTcb02Action = nil
        }
    }

    func unbindScooter() {
        guard isCommandChannelReady else {
            appendLog(.error, "UNBIND blocked: command channel not ready")
            unbindStatus = .failed
            return
        }
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

    func lockScooter() {
        guard isCommandChannelReady else {
            appendLog(.error, "LOCK blocked: command channel not ready")
            lockStatus = .failed
            return
        }
        guard writeCharacteristic != nil else {
            appendLog(.error, "LOCK failed: write characteristic not ready")
            lockStatus = .failed
            return
        }
        do {
            let payload = try TCB02Command.writeLockStatus(status: true)
            pendingTcb02Action = .lock
            appendLog(.tx, "TX SDK TCB02Command.writeLockStatus(status:true) bytes=\(payload.hexString)")
            send(payload)
        } catch {
            appendLog(.error, "LOCK sdk error: \(error)")
            lockStatus = .failed
            pendingTcb02Action = nil
        }
    }

    func unlockScooter() {
        guard isCommandChannelReady else {
            appendLog(.error, "UNLOCK blocked: command channel not ready")
            unlockStatus = .failed
            return
        }
        guard writeCharacteristic != nil else {
            appendLog(.error, "UNLOCK failed: write characteristic not ready")
            unlockStatus = .failed
            return
        }
        do {
            let payload = try TCB02Command.writeLockStatus(status: false)
            pendingTcb02Action = .unlock
            appendLog(.tx, "TX SDK TCB02Command.writeLockStatus(status:false) bytes=\(payload.hexString)")
            send(payload)
        } catch {
            appendLog(.error, "UNLOCK sdk error: \(error)")
            unlockStatus = .failed
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

    private func scheduleConnectDiagnostics(for peripheralID: UUID, attemptID: UUID) {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(15))
            guard attemptID == connectAttemptID else { return }
            guard connectionState == .connecting, connectingDeviceID == peripheralID else { return }
            appendLog(.error, "CONNECT diagnostics: still connecting after 15s id=\(peripheralID.uuidString)")
            appendLog(.error, "CoreBluetooth connect can remain pending when peripheral is out of range or busy; canceling this attempt for a clean retry")
            if let peripheral = peripheralByID[peripheralID] {
                centralManager.cancelPeripheralConnection(peripheral)
            }
            connectionState = .disconnected
            connectingDeviceID = nil
            connectStatus = .failed
        }
    }

    private func scheduleChannelReadinessDiagnostics(for peripheralID: UUID, attemptID: UUID) {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(6))
            guard attemptID == connectAttemptID else { return }
            guard connectedDeviceID == peripheralID, connectionState == .connected else { return }
            appendLog(
                .connect,
                "CHANNEL diagnostics: connected=\(hasConnectedCallback) vendorService=\(hasVendorServiceDiscovered) writeReady=\(writeChannelReady) notifyReady=\(notifyChannelReady) commandReady=\(isCommandChannelReady)"
            )
            if !isCommandChannelReady {
                appendLog(.error, "Connected callback fired but BLE channels are not fully ready yet")
                connectStatus = .partial
            }
        }
    }

    private func scheduleBindDiagnostics(for attemptID: UUID) {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(6))
            guard attemptID == bindAttemptID else { return }
            guard pendingTcb02Action == .bind else { return }
            let elapsedMs = bindStartedAt.map { Int(Date().timeIntervalSince($0) * 1000) } ?? -1
            appendLog(
                .error,
                "BIND diagnostics timeout: no TCB02 bind response yet after \(elapsedMs)ms responsesSeen=\(bindResponseCount)"
            )
            appendLog(
                .error,
                "BIND pending state: connected=\(connectionState == .connected) notifyReady=\(notifyChannelReady) writeReady=\(writeChannelReady) vendorService=\(hasVendorServiceDiscovered)"
            )
            bindStatus = .partial
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
        if connectionState == .connecting {
            return "Connecting"
        }
        if connectionState == .connected {
            return "Connected"
        }
        if isScanning {
            return devices.isEmpty ? "Scanning" : "Devices Found"
        }
        return "Idle"
    }

    var lockStateLabel: String {
        guard let lastKnownLockStatus else { return "Unknown" }
        return lastKnownLockStatus ? "Locked" : "Unlocked"
    }

    var isCommandChannelReady: Bool {
        connectionState == .connected && hasVendorServiceDiscovered && writeChannelReady && notifyChannelReady
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

    func deviceCandidateLabel(for deviceID: UUID) -> String {
        guard let device = devices.first(where: { $0.peripheralID == deviceID }) else {
            return "UNKNOWN"
        }
        if device.hasScooterNamePrefix {
            return "LIKELY SCOOTER"
        }
        if device.hasVendorServiceMatch {
            return "LIKELY SCOOTER"
        }
        if device.isConnectable == false {
            return "NOT CONNECTABLE"
        }
        return "UNVERIFIED"
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
            guard isScanning else {
                appendLog(.scan, "SCAN callback ignored: received while not scanning id=\(peripheral.identifier.uuidString)")
                return
            }
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
                devices[index].isConnectable = connectable
                devices[index].advertisedServiceUUIDs = advServiceUUIDs.map(\.uuidString)
                devices[index].hasVendorServiceMatch = !Set(advServiceUUIDs).isDisjoint(with: Set(serviceUUIDs))
                devices[index].hasScooterNamePrefix = hasScooterPrefix(name)
                scanDuplicateCallbackCount += 1
                if devices[index].discoverCount == 5 || devices[index].discoverCount % 20 == 0 {
                    appendLog(.scan, "SCAN advertisement update: name=\(name) id=\(id.uuidString) rssi=\(rssi) seen=\(devices[index].discoverCount)")
                }
            } else {
                let hasVendorService = !Set(advServiceUUIDs).isDisjoint(with: Set(serviceUUIDs))
                peripheralByID[id] = peripheral
                devices.append(
                    BLEScanDevice(
                        peripheralID: id,
                        name: name,
                        rssi: rssi,
                        discoverCount: 1,
                        lastSeen: Date(),
                        isConnectable: connectable,
                        advertisedServiceUUIDs: advServiceUUIDs.map(\.uuidString),
                        hasVendorServiceMatch: hasVendorService,
                        hasScooterNamePrefix: hasScooterPrefix(name)
                    )
                )
            }

            devices.sort { lhs, rhs in
                let lScore = candidatePriorityScore(for: lhs)
                let rScore = candidatePriorityScore(for: rhs)
                if lScore != rScore { return lScore > rScore }
                if lhs.rssi != rhs.rssi { return lhs.rssi > rhs.rssi }
                return lhs.name < rhs.name
            }
            if devices.contains(where: { $0.peripheralID == id && $0.discoverCount == 1 }) {
                appendLog(
                    .scan,
                    "SCAN callback triggered: name=\(name) id=\(id.uuidString) rssi=\(rssi) connectable=\(String(describing: connectable)) advServices=\(advServiceUUIDs.map(\.uuidString)) overflowServices=\(advOverflowUUIDs.map(\.uuidString))"
                )
                appendLog(.scan, "Device discovered: name=\(name), rssi=\(rssi), identifier=\(id.uuidString), candidate=\(deviceCandidateLabel(for: id))")
            }
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
            hasConnectedCallback = true
            connectAttemptID = UUID()
            appendLog(.connect, "CONNECT success: id=\(peripheral.identifier.uuidString) name=\(peripheral.name ?? "NoName")")
            peripheral.delegate = self
            writeCharacteristic = nil
            notifyCharacteristic = nil
            notifyStatus = .notTested
            isNotifying = false
            writeChannelReady = false
            notifyChannelReady = false
            hasVendorServiceDiscovered = false
            heartbeatCount = 0
            heartbeatStatus = .notTested
            bindStatus = .notTested
            unbindStatus = .notTested
            lockStatus = .notTested
            unlockStatus = .notTested
            isBound = false
            lastKnownLockStatus = nil
            peripheral.discoverServices(nil)
            scheduleChannelReadinessDiagnostics(for: peripheral.identifier, attemptID: connectAttemptID)
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
            hasConnectedCallback = false
            connectAttemptID = UUID()
            writeCharacteristic = nil
            notifyCharacteristic = nil
            notifyStatus = .failed
            isNotifying = false
            writeChannelReady = false
            notifyChannelReady = false
            isBound = false
            pendingTcb02Action = nil
            bindStartedAt = nil
            appendLog(.error, "CONNECT failed: id=\(peripheral.identifier.uuidString) error=\(describe(error))")
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
            hasConnectedCallback = false
            connectAttemptID = UUID()
            writeCharacteristic = nil
            notifyCharacteristic = nil
            notifyStatus = .notTested
            isNotifying = false
            writeChannelReady = false
            notifyChannelReady = false
            isBound = false
            hasVendorServiceDiscovered = false
            pendingTcb02Action = nil
            bindStartedAt = nil
            appendLog(.connect, "DISCONNECT callback: id=\(peripheral.identifier.uuidString) error=\(describe(error))")
        }
    }
}

extension BLEFoundationViewModel: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: (any Error)?) {
        Task { @MainActor in
            if let error {
                appendLog(.error, "SERVICES discovery error: \(describe(error))")
            }
            appendLog(.connect,
                "SERVICES discovered: id=\(peripheral.identifier.uuidString) count=\(peripheral.services?.count ?? 0) error=\(String(describing: error))"
            )
            let discoveredServices = peripheral.services?.map(\.uuid.uuidString) ?? []
            let hasVendorService = peripheral.services?.contains(where: { serviceUUIDs.contains($0.uuid) }) ?? false
            appendLog(.connect, "SERVICES list: \(discoveredServices)")
            if !hasVendorService {
                appendLog(.connect, "Reference vendor services not found on this device; checking characteristics globally for FFE1/FFE2")
            }
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
            if let error {
                appendLog(.error, "CHAR discovery error for service \(service.uuid.uuidString): \(describe(error))")
            }
            appendLog(.connect,
                "CHAR discovered: service=\(service.uuid.uuidString) count=\(service.characteristics?.count ?? 0) error=\(String(describing: error))"
            )
            var foundWrite = false
            var foundNotify = false
            service.characteristics?.forEach { characteristic in
                appendLog(.connect, "CHAR detail: service=\(service.uuid.uuidString) uuid=\(characteristic.uuid.uuidString) props=\(characteristic.properties.rawValue)")
                if characteristic.uuid == writeUUID,
                   characteristic.properties.contains(.writeWithoutResponse) {
                    writeCharacteristic = characteristic
                    writeChannelReady = true
                    foundWrite = true
                    appendLog(.connect, "CHAR ready write=\(characteristic.uuid.uuidString) service=\(service.uuid.uuidString)")
                } else if characteristic.uuid == notifyUUID,
                          characteristic.properties.contains(.notify) {
                    notifyCharacteristic = characteristic
                    foundNotify = true
                    appendLog(.notify, "CHAR ready notify=\(characteristic.uuid.uuidString) service=\(service.uuid.uuidString)")
                    appendLog(.notify, "NOTIFY register request: char=\(characteristic.uuid.uuidString)")
                    peripheral.setNotifyValue(true, for: characteristic)
                }
            }
            if foundWrite || foundNotify {
                hasVendorServiceDiscovered = true
            }
            if service.characteristics?.isEmpty ?? true {
                appendLog(.error, "No characteristics returned for service \(service.uuid.uuidString)")
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
                "NOTIFY state: char=\(characteristic.uuid.uuidString) isNotifying=\(characteristic.isNotifying) error=\(describe(error))"
            )
            if error == nil {
                isNotifying = characteristic.isNotifying
                notifyStatus = characteristic.isNotifying ? .passed : .partial
                notifyChannelReady = characteristic.isNotifying
            } else {
                notifyStatus = .failed
                isNotifying = false
                notifyChannelReady = false
            }
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: (any Error)?
    ) {
        Task { @MainActor in
            if let error {
                appendLog(.error, "RX callback error: char=\(characteristic.uuid.uuidString) error=\(describe(error))")
                return
            }
            let data = characteristic.value ?? Data()
            appendLog(.rx, "RX callback: char=\(characteristic.uuid.uuidString) bytes=\(data.hexString) error=\(String(describing: error))")
            let model = TCBManager.convertToModel(data: data)
            appendLog(.sdkParse, "SDK parsed model: \(type(of: model))")
            if pendingTcb02Action == .bind {
                bindResponseCount += 1
                appendLog(.sdkParse, "BIND pending response #\(bindResponseCount): model=\(type(of: model))")
            }
            if let bindModel = model as? TCB02Model {
                let wasBindAction = pendingTcb02Action == .bind
                isBound = bindModel.bluetoothStatus
                lastKnownLockStatus = bindModel.lockStatus
                if pendingTcb02Action == .bind {
                    let latencyMs = bindStartedAt.map { Int(Date().timeIntervalSince($0) * 1000) } ?? -1
                    appendLog(.sdkParse, "BIND callback: attempt=\(bindAttemptID.uuidString) latencyMs=\(latencyMs) bluetoothStatus=\(bindModel.bluetoothStatus) boundId=\(bindModel.boundId)")
                    if bindModel.bluetoothStatus {
                        bindStatus = .passed
                        appendLog(.sdkParse, "BIND result: PASSED (bluetoothStatus=true)")
                    } else {
                        bindStatus = .partial
                        appendLog(.error, "BIND response received but bluetoothStatus=false")
                        if let requested = lastBindRequestedUserID, bindModel.boundId != "\(requested)" {
                            appendLog(
                                .error,
                                "BIND mismatch: requestedUserID=\(requested) meterBoundId=\(bindModel.boundId) (bind rejected)"
                            )
                        }
                    }
                } else if pendingTcb02Action == .unbind {
                    if !bindModel.bluetoothStatus {
                        unbindStatus = .passed
                        appendLog(.sdkParse, "UNBIND result: PASSED (bluetoothStatus=false)")
                    } else {
                        unbindStatus = .partial
                        appendLog(.error, "UNBIND response received but bluetoothStatus=true")
                    }
                } else if pendingTcb02Action == .lock {
                    if bindModel.lockStatus {
                        lockStatus = .passed
                        appendLog(.sdkParse, "LOCK result: PASSED (lockStatus=true)")
                    } else {
                        lockStatus = .partial
                        appendLog(.error, "LOCK response received but lockStatus=false")
                    }
                } else if pendingTcb02Action == .unlock {
                    if !bindModel.lockStatus {
                        unlockStatus = .passed
                        appendLog(.sdkParse, "UNLOCK result: PASSED (lockStatus=false)")
                    } else {
                        unlockStatus = .partial
                        appendLog(.error, "UNLOCK response received but lockStatus=true")
                    }
                }
                pendingTcb02Action = nil
                if wasBindAction {
                    bindStartedAt = nil
                }
                appendLog(.sdkParse,
                    "SDK parsed TCB02Model: bluetoothStatus=\(bindModel.bluetoothStatus) lockStatus=\(bindModel.lockStatus) boundId=\(bindModel.boundId)"
                )
            } else if let heartbeatModel = model as? TCB01Model {
                heartbeatStatus = .passed
                heartbeatCount += 1
                isBound = true
                lastKnownLockStatus = heartbeatModel.lockStatus
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
            } else if pendingTcb02Action == .bind {
                appendLog(.error, "BIND pending but received non-TCB02 model: \(type(of: model))")
            }
        }
    }

    private func send(_ data: Data) {
        guard isCommandChannelReady else {
            appendLog(
                .error,
                "TX blocked: channel not ready connected=\(connectionState == .connected) vendorService=\(hasVendorServiceDiscovered) writeReady=\(writeChannelReady) notifyReady=\(notifyChannelReady)"
            )
            return
        }
        guard let connectedPeripheral, let writeCharacteristic else {
            appendLog(.error, "TX skipped: connection/characteristic not ready")
            return
        }
        connectedPeripheral.writeValue(data, for: writeCharacteristic, type: .withoutResponse)
        appendLog(.tx, "TX write dispatched to char=\(writeCharacteristic.uuid.uuidString)")
    }

    private func describe(_ error: (any Error)?) -> String {
        guard let error else { return "nil" }
        let nsError = error as NSError
        return "domain=\(nsError.domain) code=\(nsError.code) localized=\(nsError.localizedDescription)"
    }

    private func hasScooterPrefix(_ name: String) -> Bool {
        scooterNamePrefixes.contains(where: { prefix in
            name.lowercased().hasPrefix(prefix.lowercased())
        })
    }

    private func candidatePriorityScore(for device: BLEScanDevice) -> Int {
        if device.hasScooterNamePrefix { return 3 }
        if device.hasVendorServiceMatch { return 2 }
        if device.isConnectable == true { return 1 }
        return 0
    }
}

private extension Data {
    var hexString: String {
        map { String(format: "%02X", $0) }.joined()
    }
}
