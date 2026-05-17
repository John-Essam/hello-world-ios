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
    @Published private(set) var cruiseControlStatus: ValidationStatus = .notTested
    @Published private(set) var gearSelectionStatus: ValidationStatus = .notTested
    @Published private(set) var startModeStatus: ValidationStatus = .notTested
    @Published private(set) var unitSystemStatus: ValidationStatus = .notTested
    @Published private(set) var throttleResponseReadStatus: ValidationStatus = .notTested
    @Published private(set) var brakeResponseReadStatus: ValidationStatus = .notTested
    @Published private(set) var throttleResponseWriteStatus: ValidationStatus = .notTested
    @Published private(set) var brakeResponseWriteStatus: ValidationStatus = .notTested
    @Published private(set) var nfcReadStatus: ValidationStatus = .notTested
    @Published private(set) var nfcWriteStatus: ValidationStatus = .notTested
    @Published private(set) var frontLightStatus: ValidationStatus = .notTested
    @Published private(set) var ambientLightStatus: ValidationStatus = .notTested
    @Published private(set) var ambientLightStyleStatus: ValidationStatus = .notTested
    @Published private(set) var heartbeatStatus: ValidationStatus = .notTested
    @Published private(set) var notifyStatus: ValidationStatus = .notTested
    @Published private(set) var isNotifying = false
    @Published private(set) var writeChannelReady = false
    @Published private(set) var notifyChannelReady = false
    @Published private(set) var hasConnectedCallback = false
    @Published private(set) var hasVendorServiceDiscovered = false
    @Published private(set) var isBound = false
    @Published private(set) var lastKnownLockStatus: Bool?
    @Published private(set) var lastKnownCruiseControlEnabled: Bool?
    @Published private(set) var currentGearSelection: Int?
    @Published private(set) var isZeroStartModeEnabled: Bool?
    @Published private(set) var isMetricUnitEnabled: Bool?
    @Published private(set) var throttleResponseValue: Int?
    @Published private(set) var brakeResponseValue: Int?
    @Published private(set) var isNfcEnabled: Bool?
    @Published private(set) var isFrontLightOn: Bool?
    @Published private(set) var isAmbientLightOn: Bool?
    @Published private(set) var ambientLightMode: Int?
    @Published private(set) var ambientLightRed: Int?
    @Published private(set) var ambientLightGreen: Int?
    @Published private(set) var ambientLightBlue: Int?
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
    private var cruiseCommandStartedAt: Date?
    private var pendingCruiseExpectedEnabled: Bool?
    private var gearCommandStartedAt: Date?
    private var pendingGearExpected: Int?
    private var startModeCommandStartedAt: Date?
    private var pendingZeroStartExpected: Bool?
    private var unitSystemCommandStartedAt: Date?
    private var pendingMetricUnitExpected: Bool?
    private var throttleReadRequestedAt: Date?
    private var isThrottleReadPending = false
    private var brakeReadRequestedAt: Date?
    private var isBrakeReadPending = false
    private var throttleWriteRequestedAt: Date?
    private var pendingThrottleWriteExpected: Int?
    private var brakeWriteRequestedAt: Date?
    private var pendingBrakeWriteExpected: Int?
    private var nfcReadRequestedAt: Date?
    private var isNfcReadPending = false
    private var nfcWriteRequestedAt: Date?
    private var pendingNfcWriteExpected: Bool?
    private var frontLightRequestedAt: Date?
    private var pendingFrontLightExpected: Bool?
    private var ambientLightRequestedAt: Date?
    private var pendingAmbientLightExpected: Bool?
    private var ambientStyleReadRequestedAt: Date?
    private var isAmbientStyleReadPending = false
    private var ambientStyleWriteRequestedAt: Date?
    private var pendingAmbientStyleExpected: (mode: Int, red: Int, green: Int, blue: Int)?
    private var pendingSdkAuditsByFunction: [UInt8: [PendingSDKAudit]] = [:]

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
        case cruise
    }

    private struct PendingSDKAudit {
        let id: UUID
        let commandName: String
        let featureName: String
        let functionCode: UInt8
        let expectedModel: String
        let startedAt: Date
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
        runStaticSDKCommandAudit()
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

    func setCruiseControl(enabled: Bool) {
        guard isCommandChannelReady else {
            appendLog(.error, "CRUISE blocked: command channel not ready")
            cruiseControlStatus = .failed
            return
        }
        guard writeCharacteristic != nil else {
            appendLog(.error, "CRUISE failed: write characteristic not ready")
            cruiseControlStatus = .failed
            return
        }
        do {
            cruiseCommandStartedAt = Date()
            pendingCruiseExpectedEnabled = enabled
            let payload = try TCB02Command.writeCruiseControlFunction(status: enabled)
            pendingTcb02Action = .cruise
            appendLog(.tx, "TX SDK TCB02Command.writeCruiseControlFunction(status:\(enabled)) bytes=\(payload.hexString)")
            send(payload)
            scheduleCruiseDiagnostics(expectedEnabled: enabled)
        } catch {
            appendLog(.error, "CRUISE sdk error: \(error)")
            cruiseControlStatus = .failed
            pendingTcb02Action = nil
            pendingCruiseExpectedEnabled = nil
            cruiseCommandStartedAt = nil
        }
    }

    func setGear(_ gear: Int) {
        guard isCommandChannelReady else {
            appendLog(.error, "GEAR blocked: command channel not ready")
            gearSelectionStatus = .failed
            return
        }
        guard writeCharacteristic != nil else {
            appendLog(.error, "GEAR failed: write characteristic not ready")
            gearSelectionStatus = .failed
            return
        }
        do {
            gearCommandStartedAt = Date()
            pendingGearExpected = gear
            let payload = try TCB05Command.writeGear(gear)
            appendLog(.tx, "TX SDK TCB05Command.writeGear(\(gear)) bytes=\(payload.hexString)")
            send(payload)
            scheduleGearDiagnostics(expectedGear: gear)
        } catch {
            appendLog(.error, "GEAR sdk error: \(error)")
            gearSelectionStatus = .failed
            pendingGearExpected = nil
            gearCommandStartedAt = nil
        }
    }

    func setStartMode(zeroStart: Bool) {
        guard isCommandChannelReady else {
            appendLog(.error, "START MODE blocked: command channel not ready")
            startModeStatus = .failed
            return
        }
        guard writeCharacteristic != nil else {
            appendLog(.error, "START MODE failed: write characteristic not ready")
            startModeStatus = .failed
            return
        }
        do {
            startModeCommandStartedAt = Date()
            pendingZeroStartExpected = zeroStart
            let payload = try TCB02Command.writeStartMode(zeroStart: zeroStart)
            appendLog(.tx, "TX SDK TCB02Command.writeStartMode(zeroStart:\(zeroStart)) bytes=\(payload.hexString)")
            send(payload)
            scheduleStartModeDiagnostics(expectedZeroStart: zeroStart)
        } catch {
            appendLog(.error, "START MODE sdk error: \(error)")
            startModeStatus = .failed
            pendingZeroStartExpected = nil
            startModeCommandStartedAt = nil
        }
    }

    func setUnitSystem(metric: Bool) {
        guard isCommandChannelReady else {
            appendLog(.error, "UNIT blocked: command channel not ready")
            unitSystemStatus = .failed
            return
        }
        guard writeCharacteristic != nil else {
            appendLog(.error, "UNIT failed: write characteristic not ready")
            unitSystemStatus = .failed
            return
        }
        do {
            unitSystemCommandStartedAt = Date()
            pendingMetricUnitExpected = metric
            let payload = try TCB02Command.writeMetricMileSystemTheme(isKM: metric)
            appendLog(.tx, "TX SDK TCB02Command.writeMetricMileSystemTheme(isKM:\(metric)) bytes=\(payload.hexString)")
            send(payload)
            scheduleUnitDiagnostics(expectedMetric: metric)
        } catch {
            appendLog(.error, "UNIT sdk error: \(error)")
            unitSystemStatus = .failed
            pendingMetricUnitExpected = nil
            unitSystemCommandStartedAt = nil
        }
    }

    func readThrottleResponse() {
        guard isCommandChannelReady else {
            appendLog(.error, "THROTTLE READ blocked: command channel not ready")
            throttleResponseReadStatus = .failed
            return
        }
        guard writeCharacteristic != nil else {
            appendLog(.error, "THROTTLE READ failed: write characteristic not ready")
            throttleResponseReadStatus = .failed
            return
        }
        do {
            throttleReadRequestedAt = Date()
            isThrottleReadPending = true
            let payload = try TCB22Command.readResponseTime(type: 0)
            appendLog(.tx, "TX SDK TCB22Command.readResponseTime(type:0) bytes=\(payload.hexString)")
            send(payload)
            scheduleThrottleReadDiagnostics()
        } catch {
            appendLog(.error, "THROTTLE READ sdk error: \(error)")
            throttleResponseReadStatus = .failed
            isThrottleReadPending = false
            throttleReadRequestedAt = nil
        }
    }

    func readBrakeResponse() {
        guard isCommandChannelReady else {
            appendLog(.error, "BRAKE READ blocked: command channel not ready")
            brakeResponseReadStatus = .failed
            return
        }
        guard writeCharacteristic != nil else {
            appendLog(.error, "BRAKE READ failed: write characteristic not ready")
            brakeResponseReadStatus = .failed
            return
        }
        do {
            brakeReadRequestedAt = Date()
            isBrakeReadPending = true
            let payload = try TCB22Command.readResponseTime(type: 1)
            appendLog(.tx, "TX SDK TCB22Command.readResponseTime(type:1) bytes=\(payload.hexString)")
            send(payload)
            scheduleBrakeReadDiagnostics()
        } catch {
            appendLog(.error, "BRAKE READ sdk error: \(error)")
            brakeResponseReadStatus = .failed
            isBrakeReadPending = false
            brakeReadRequestedAt = nil
        }
    }

    func writeThrottleResponse(value: Int) {
        guard isCommandChannelReady else {
            appendLog(.error, "THROTTLE WRITE blocked: command channel not ready")
            throttleResponseWriteStatus = .failed
            return
        }
        guard writeCharacteristic != nil else {
            appendLog(.error, "THROTTLE WRITE failed: write characteristic not ready")
            throttleResponseWriteStatus = .failed
            return
        }
        guard (0...10).contains(value) else {
            appendLog(.error, "THROTTLE WRITE rejected: value out of range \(value)")
            throttleResponseWriteStatus = .failed
            return
        }
        do {
            throttleWriteRequestedAt = Date()
            pendingThrottleWriteExpected = value
            let payload = try TCB22Command.writeResponseTime(type: 0, time: value)
            appendLog(.tx, "TX SDK TCB22Command.writeResponseTime(type:0,time:\(value)) bytes=\(payload.hexString)")
            send(payload)
            scheduleThrottleWriteDiagnostics(expectedValue: value)
        } catch {
            appendLog(.error, "THROTTLE WRITE sdk error: \(error)")
            throttleResponseWriteStatus = .failed
            pendingThrottleWriteExpected = nil
            throttleWriteRequestedAt = nil
        }
    }

    func writeBrakeResponse(value: Int) {
        guard isCommandChannelReady else {
            appendLog(.error, "BRAKE WRITE blocked: command channel not ready")
            brakeResponseWriteStatus = .failed
            return
        }
        guard writeCharacteristic != nil else {
            appendLog(.error, "BRAKE WRITE failed: write characteristic not ready")
            brakeResponseWriteStatus = .failed
            return
        }
        guard (0...10).contains(value) else {
            appendLog(.error, "BRAKE WRITE rejected: value out of range \(value)")
            brakeResponseWriteStatus = .failed
            return
        }
        do {
            brakeWriteRequestedAt = Date()
            pendingBrakeWriteExpected = value
            let payload = try TCB22Command.writeResponseTime(type: 1, time: value)
            appendLog(.tx, "TX SDK TCB22Command.writeResponseTime(type:1,time:\(value)) bytes=\(payload.hexString)")
            send(payload)
            scheduleBrakeWriteDiagnostics(expectedValue: value)
        } catch {
            appendLog(.error, "BRAKE WRITE sdk error: \(error)")
            brakeResponseWriteStatus = .failed
            pendingBrakeWriteExpected = nil
            brakeWriteRequestedAt = nil
        }
    }

    func readNfcStatus() {
        guard isCommandChannelReady else {
            appendLog(.error, "NFC READ blocked: command channel not ready")
            nfcReadStatus = .failed
            return
        }
        guard writeCharacteristic != nil else {
            appendLog(.error, "NFC READ failed: write characteristic not ready")
            nfcReadStatus = .failed
            return
        }
        do {
            nfcReadRequestedAt = Date()
            isNfcReadPending = true
            let payload = try TCB03Command.readNfcStatus()
            appendLog(.tx, "TX SDK TCB03Command.readNfcStatus() bytes=\(payload.hexString)")
            sendAudited(
                payload,
                commandName: "TCB03Command.readNfcStatus",
                featureName: "Core Controls / NFC Status Read",
                expectedModel: "TCB03Model"
            )
            scheduleNfcReadDiagnostics()
        } catch {
            appendLog(.error, "NFC READ sdk error: \(error)")
            nfcReadStatus = .failed
            isNfcReadPending = false
            nfcReadRequestedAt = nil
        }
    }

    func setNfcStatus(enabled: Bool) {
        guard isCommandChannelReady else {
            appendLog(.error, "NFC WRITE blocked: command channel not ready")
            nfcWriteStatus = .failed
            return
        }
        guard writeCharacteristic != nil else {
            appendLog(.error, "NFC WRITE failed: write characteristic not ready")
            nfcWriteStatus = .failed
            return
        }
        do {
            nfcWriteRequestedAt = Date()
            pendingNfcWriteExpected = enabled
            let payload = try TCB03Command.writeNfcStatus(enabled)
            appendLog(.tx, "TX SDK TCB03Command.writeNfcStatus(\(enabled)) bytes=\(payload.hexString)")
            sendAudited(
                payload,
                commandName: "TCB03Command.writeNfcStatus(\(enabled))",
                featureName: "Core Controls / NFC Enable Disable",
                expectedModel: "TCB03Model"
            )
            scheduleNfcWriteDiagnostics(expectedStatus: enabled)
        } catch {
            appendLog(.error, "NFC WRITE sdk error: \(error)")
            nfcWriteStatus = .failed
            pendingNfcWriteExpected = nil
            nfcWriteRequestedAt = nil
        }
    }

    func setFrontLightStatus(enabled: Bool) {
        guard isCommandChannelReady else {
            appendLog(.error, "FRONT LIGHT blocked: command channel not ready")
            frontLightStatus = .failed
            return
        }
        guard writeCharacteristic != nil else {
            appendLog(.error, "FRONT LIGHT failed: write characteristic not ready")
            frontLightStatus = .failed
            return
        }
        do {
            frontLightRequestedAt = Date()
            pendingFrontLightExpected = enabled
            let payload = try TCB04Command.writeFrontLightStatus(enabled)
            appendLog(.tx, "TX SDK TCB04Command.writeFrontLightStatus(\(enabled)) bytes=\(payload.hexString)")
            sendAudited(
                payload,
                commandName: "TCB04Command.writeFrontLightStatus(\(enabled))",
                featureName: "Lights / Front Light",
                expectedModel: "TCB01Model heartbeat or TCB04Model"
            )
            scheduleFrontLightDiagnostics(expectedStatus: enabled)
        } catch {
            appendLog(.error, "FRONT LIGHT sdk error: \(error)")
            frontLightStatus = .failed
            pendingFrontLightExpected = nil
            frontLightRequestedAt = nil
        }
    }

    func setAmbientLightStatus(enabled: Bool) {
        guard isCommandChannelReady else {
            appendLog(.error, "AMBIENT LIGHT blocked: command channel not ready")
            ambientLightStatus = .failed
            return
        }
        guard writeCharacteristic != nil else {
            appendLog(.error, "AMBIENT LIGHT failed: write characteristic not ready")
            ambientLightStatus = .failed
            return
        }
        do {
            ambientLightRequestedAt = Date()
            pendingAmbientLightExpected = enabled
            let payload = try TCB04Command.writeAmbientLightStatus(enabled)
            appendLog(.tx, "TX SDK TCB04Command.writeAmbientLightStatus(\(enabled)) bytes=\(payload.hexString)")
            sendAudited(
                payload,
                commandName: "TCB04Command.writeAmbientLightStatus(\(enabled))",
                featureName: "Lights / Ambient Light Power",
                expectedModel: "TCB04Model"
            )
            scheduleAmbientLightDiagnostics(expectedStatus: enabled)
        } catch {
            appendLog(.error, "AMBIENT LIGHT sdk error: \(error)")
            ambientLightStatus = .failed
            pendingAmbientLightExpected = nil
            ambientLightRequestedAt = nil
        }
    }

    func readAmbientLightStyle() {
        guard isCommandChannelReady else {
            appendLog(.error, "AMBIENT STYLE READ blocked: command channel not ready")
            ambientLightStyleStatus = .failed
            return
        }
        guard writeCharacteristic != nil else {
            appendLog(.error, "AMBIENT STYLE READ failed: write characteristic not ready")
            ambientLightStyleStatus = .failed
            return
        }
        do {
            ambientStyleReadRequestedAt = Date()
            isAmbientStyleReadPending = true
            let payload = try TCB1ACommand.readAmbientLight()
            appendLog(.tx, "TX SDK TCB1ACommand.readAmbientLight() bytes=\(payload.hexString)")
            sendAudited(
                payload,
                commandName: "TCB1ACommand.readAmbientLight",
                featureName: "Lights / Ambient Read Apply",
                expectedModel: "TCB1AModel"
            )
            scheduleAmbientStyleReadDiagnostics()
        } catch {
            appendLog(.error, "AMBIENT STYLE READ sdk error: \(error)")
            ambientLightStyleStatus = .failed
            isAmbientStyleReadPending = false
            ambientStyleReadRequestedAt = nil
        }
    }

    func writeAmbientLightStyle(mode: Int, red: Int, green: Int, blue: Int) {
        guard isCommandChannelReady else {
            appendLog(.error, "AMBIENT STYLE WRITE blocked: command channel not ready")
            ambientLightStyleStatus = .failed
            return
        }
        guard writeCharacteristic != nil else {
            appendLog(.error, "AMBIENT STYLE WRITE failed: write characteristic not ready")
            ambientLightStyleStatus = .failed
            return
        }
        guard (1...3).contains(mode) else {
            appendLog(.error, "AMBIENT STYLE WRITE rejected: mode out of range \(mode)")
            ambientLightStyleStatus = .failed
            return
        }
        guard (0...255).contains(red), (0...255).contains(green), (0...255).contains(blue) else {
            appendLog(.error, "AMBIENT STYLE WRITE rejected: RGB out of range r=\(red) g=\(green) b=\(blue)")
            ambientLightStyleStatus = .failed
            return
        }
        do {
            appendLog(
                .connect,
                "AMBIENT STYLE sequence check: connected=\(connectionState == .connected) bound=\(isBound) notifyReady=\(notifyChannelReady) ambientPower=\(String(describing: isAmbientLightOn)) heartbeatCount=\(heartbeatCount)"
            )
            ambientStyleWriteRequestedAt = Date()
            pendingAmbientStyleExpected = (mode: mode, red: red, green: green, blue: blue)
            let payload = try TCB1ACommand.writeAmbientLight(type: mode, R: red, G: green, B: blue)
            appendLog(.tx, "TX SDK TCB1ACommand.writeAmbientLight(type:\(mode),R:\(red),G:\(green),B:\(blue)) bytes=\(payload.hexString)")
            sendAudited(
                payload,
                commandName: "TCB1ACommand.writeAmbientLight(type:\(mode),R:\(red),G:\(green),B:\(blue))",
                featureName: "Lights / Ambient Solid Breathing Magic",
                expectedModel: "TCB1AModel"
            )
            scheduleAmbientStyleWriteDiagnostics(expected: (mode: mode, red: red, green: green, blue: blue))
        } catch {
            appendLog(.error, "AMBIENT STYLE WRITE sdk error: \(error)")
            ambientLightStyleStatus = .failed
            pendingAmbientStyleExpected = nil
            ambientStyleWriteRequestedAt = nil
        }
    }

    private func appendLog(_ category: ValidationLogCategory, _ message: String) {
        logs.insert(ValidationLog(category: category, message: message), at: 0)
        if logs.count > 200 {
            logs.removeLast(logs.count - 200)
        }
    }

    private func runStaticSDKCommandAudit() {
        let cases: [(name: String, payload: Data?)] = [
            ("TCB03Command.readNfcStatus", try? TCB03Command.readNfcStatus()),
            ("TCB03Command.writeNfcStatus(true)", try? TCB03Command.writeNfcStatus(true)),
            ("TCB04Command.writeAmbientLightStatus(true)", try? TCB04Command.writeAmbientLightStatus(true)),
            ("TCB1ACommand.readAmbientLight", try? TCB1ACommand.readAmbientLight()),
            ("TCB1ACommand.writeAmbientLight(type:1,R:255,G:0,B:0)", try? TCB1ACommand.writeAmbientLight(type: 1, R: 255, G: 0, B: 0))
        ]
        for entry in cases {
            guard let payload = entry.payload else {
                appendLog(.error, "SDK STATIC AUDIT build failed: \(entry.name)")
                continue
            }
            let frame = auditFrame(payload)
            appendLog(
                .sdkParse,
                "SDK STATIC AUDIT frame: command=\(entry.name) bytes=\(frame.totalBytes) declaredLen=\(frame.declaredDataLength) expectedFrameBytes=\(frame.expectedFrameBytes) frameValid=\(frame.frameValid)"
            )
            if !frame.frameValid {
                appendLog(.error, "SDK STATIC AUDIT malformed TX frame detected for \(entry.name)")
            }
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

    private func scheduleCruiseDiagnostics(expectedEnabled: Bool) {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(6))
            guard pendingTcb02Action == .cruise else { return }
            guard pendingCruiseExpectedEnabled == expectedEnabled else { return }
            let elapsedMs = cruiseCommandStartedAt.map { Int(Date().timeIntervalSince($0) * 1000) } ?? -1
            appendLog(
                .error,
                "CRUISE diagnostics timeout: no matching heartbeat confirmation after \(elapsedMs)ms expected=\(expectedEnabled)"
            )
            cruiseControlStatus = .partial
            pendingTcb02Action = nil
            pendingCruiseExpectedEnabled = nil
            cruiseCommandStartedAt = nil
        }
    }

    private func scheduleGearDiagnostics(expectedGear: Int) {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(6))
            guard pendingGearExpected == expectedGear else { return }
            let elapsedMs = gearCommandStartedAt.map { Int(Date().timeIntervalSince($0) * 1000) } ?? -1
            appendLog(
                .error,
                "GEAR diagnostics timeout: no matching gear confirmation after \(elapsedMs)ms expected=\(expectedGear)"
            )
            gearSelectionStatus = .partial
            pendingGearExpected = nil
            gearCommandStartedAt = nil
        }
    }

    private func scheduleStartModeDiagnostics(expectedZeroStart: Bool) {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(6))
            guard pendingZeroStartExpected == expectedZeroStart else { return }
            let elapsedMs = startModeCommandStartedAt.map { Int(Date().timeIntervalSince($0) * 1000) } ?? -1
            appendLog(
                .error,
                "START MODE diagnostics timeout: no matching heartbeat confirmation after \(elapsedMs)ms expectedZeroStart=\(expectedZeroStart)"
            )
            startModeStatus = .partial
            pendingZeroStartExpected = nil
            startModeCommandStartedAt = nil
        }
    }

    private func scheduleUnitDiagnostics(expectedMetric: Bool) {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(6))
            guard pendingMetricUnitExpected == expectedMetric else { return }
            let elapsedMs = unitSystemCommandStartedAt.map { Int(Date().timeIntervalSince($0) * 1000) } ?? -1
            appendLog(
                .error,
                "UNIT diagnostics timeout: no matching heartbeat confirmation after \(elapsedMs)ms expectedMetric=\(expectedMetric)"
            )
            unitSystemStatus = .partial
            pendingMetricUnitExpected = nil
            unitSystemCommandStartedAt = nil
        }
    }

    private func scheduleThrottleReadDiagnostics() {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(6))
            guard isThrottleReadPending else { return }
            let elapsedMs = throttleReadRequestedAt.map { Int(Date().timeIntervalSince($0) * 1000) } ?? -1
            appendLog(.error, "THROTTLE READ diagnostics timeout: no TCB22 throttle response after \(elapsedMs)ms")
            throttleResponseReadStatus = .partial
            isThrottleReadPending = false
            throttleReadRequestedAt = nil
        }
    }

    private func scheduleBrakeReadDiagnostics() {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(6))
            guard isBrakeReadPending else { return }
            let elapsedMs = brakeReadRequestedAt.map { Int(Date().timeIntervalSince($0) * 1000) } ?? -1
            appendLog(.error, "BRAKE READ diagnostics timeout: no TCB22 brake response after \(elapsedMs)ms")
            brakeResponseReadStatus = .partial
            isBrakeReadPending = false
            brakeReadRequestedAt = nil
        }
    }

    private func scheduleThrottleWriteDiagnostics(expectedValue: Int) {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(6))
            guard pendingThrottleWriteExpected == expectedValue else { return }
            let elapsedMs = throttleWriteRequestedAt.map { Int(Date().timeIntervalSince($0) * 1000) } ?? -1
            appendLog(.error, "THROTTLE WRITE diagnostics timeout: no TCB22 throttle confirmation after \(elapsedMs)ms")
            throttleResponseWriteStatus = .partial
            pendingThrottleWriteExpected = nil
            throttleWriteRequestedAt = nil
        }
    }

    private func scheduleBrakeWriteDiagnostics(expectedValue: Int) {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(6))
            guard pendingBrakeWriteExpected == expectedValue else { return }
            let elapsedMs = brakeWriteRequestedAt.map { Int(Date().timeIntervalSince($0) * 1000) } ?? -1
            appendLog(.error, "BRAKE WRITE diagnostics timeout: no TCB22 brake confirmation after \(elapsedMs)ms")
            brakeResponseWriteStatus = .partial
            pendingBrakeWriteExpected = nil
            brakeWriteRequestedAt = nil
        }
    }

    private func scheduleNfcReadDiagnostics() {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(6))
            guard isNfcReadPending else { return }
            let elapsedMs = nfcReadRequestedAt.map { Int(Date().timeIntervalSince($0) * 1000) } ?? -1
            appendLog(.error, "NFC READ diagnostics timeout: no TCB03 response after \(elapsedMs)ms")
            nfcReadStatus = .partial
            isNfcReadPending = false
            nfcReadRequestedAt = nil
        }
    }

    private func scheduleNfcWriteDiagnostics(expectedStatus: Bool) {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(6))
            guard pendingNfcWriteExpected == expectedStatus else { return }
            let elapsedMs = nfcWriteRequestedAt.map { Int(Date().timeIntervalSince($0) * 1000) } ?? -1
            appendLog(.error, "NFC WRITE diagnostics timeout: no TCB03 confirmation after \(elapsedMs)ms")
            nfcWriteStatus = .partial
            pendingNfcWriteExpected = nil
            nfcWriteRequestedAt = nil
        }
    }

    private func scheduleFrontLightDiagnostics(expectedStatus: Bool) {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(6))
            guard pendingFrontLightExpected == expectedStatus else { return }
            let elapsedMs = frontLightRequestedAt.map { Int(Date().timeIntervalSince($0) * 1000) } ?? -1
            appendLog(.error, "FRONT LIGHT diagnostics timeout: no heartbeat confirmation after \(elapsedMs)ms")
            frontLightStatus = .partial
            pendingFrontLightExpected = nil
            frontLightRequestedAt = nil
        }
    }

    private func scheduleAmbientLightDiagnostics(expectedStatus: Bool) {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(6))
            guard pendingAmbientLightExpected == expectedStatus else { return }
            let elapsedMs = ambientLightRequestedAt.map { Int(Date().timeIntervalSince($0) * 1000) } ?? -1
            appendLog(.error, "AMBIENT LIGHT diagnostics timeout: no TCB04 confirmation after \(elapsedMs)ms")
            ambientLightStatus = .partial
            pendingAmbientLightExpected = nil
            ambientLightRequestedAt = nil
        }
    }

    private func scheduleAmbientStyleReadDiagnostics() {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(6))
            guard isAmbientStyleReadPending else { return }
            let elapsedMs = ambientStyleReadRequestedAt.map { Int(Date().timeIntervalSince($0) * 1000) } ?? -1
            appendLog(.error, "AMBIENT STYLE READ diagnostics timeout: no TCB1A response after \(elapsedMs)ms")
            ambientLightStyleStatus = .partial
            isAmbientStyleReadPending = false
            ambientStyleReadRequestedAt = nil
        }
    }

    private func scheduleAmbientStyleWriteDiagnostics(expected: (mode: Int, red: Int, green: Int, blue: Int)) {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(6))
            guard let pending = pendingAmbientStyleExpected else { return }
            guard pending.mode == expected.mode && pending.red == expected.red && pending.green == expected.green && pending.blue == expected.blue else { return }
            let elapsedMs = ambientStyleWriteRequestedAt.map { Int(Date().timeIntervalSince($0) * 1000) } ?? -1
            appendLog(.error, "AMBIENT STYLE WRITE diagnostics timeout: no TCB1A confirmation after \(elapsedMs)ms")
            ambientLightStyleStatus = .partial
            pendingAmbientStyleExpected = nil
            ambientStyleWriteRequestedAt = nil
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
            cruiseControlStatus = .notTested
            gearSelectionStatus = .notTested
            startModeStatus = .notTested
            unitSystemStatus = .notTested
            throttleResponseReadStatus = .notTested
            brakeResponseReadStatus = .notTested
            throttleResponseWriteStatus = .notTested
            brakeResponseWriteStatus = .notTested
            nfcReadStatus = .notTested
            nfcWriteStatus = .notTested
            frontLightStatus = .notTested
            ambientLightStatus = .notTested
            ambientLightStyleStatus = .notTested
            isBound = false
            lastKnownLockStatus = nil
            lastKnownCruiseControlEnabled = nil
            currentGearSelection = nil
            isZeroStartModeEnabled = nil
            isMetricUnitEnabled = nil
            throttleResponseValue = nil
            brakeResponseValue = nil
            isNfcEnabled = nil
            isFrontLightOn = nil
            isAmbientLightOn = nil
            ambientLightMode = nil
            ambientLightRed = nil
            ambientLightGreen = nil
            ambientLightBlue = nil
            pendingSdkAuditsByFunction.removeAll()
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
            pendingCruiseExpectedEnabled = nil
            cruiseCommandStartedAt = nil
            pendingGearExpected = nil
            gearCommandStartedAt = nil
            pendingZeroStartExpected = nil
            startModeCommandStartedAt = nil
            pendingMetricUnitExpected = nil
            unitSystemCommandStartedAt = nil
            isThrottleReadPending = false
            throttleReadRequestedAt = nil
            isBrakeReadPending = false
            brakeReadRequestedAt = nil
            pendingThrottleWriteExpected = nil
            throttleWriteRequestedAt = nil
            pendingBrakeWriteExpected = nil
            brakeWriteRequestedAt = nil
            isNfcReadPending = false
            nfcReadRequestedAt = nil
            pendingNfcWriteExpected = nil
            nfcWriteRequestedAt = nil
            pendingFrontLightExpected = nil
            frontLightRequestedAt = nil
            pendingAmbientLightExpected = nil
            ambientLightRequestedAt = nil
            isAmbientStyleReadPending = false
            ambientStyleReadRequestedAt = nil
            pendingAmbientStyleExpected = nil
            ambientStyleWriteRequestedAt = nil
            pendingSdkAuditsByFunction.removeAll()
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
            pendingCruiseExpectedEnabled = nil
            cruiseCommandStartedAt = nil
            pendingGearExpected = nil
            gearCommandStartedAt = nil
            pendingZeroStartExpected = nil
            startModeCommandStartedAt = nil
            pendingMetricUnitExpected = nil
            unitSystemCommandStartedAt = nil
            isThrottleReadPending = false
            throttleReadRequestedAt = nil
            isBrakeReadPending = false
            brakeReadRequestedAt = nil
            pendingThrottleWriteExpected = nil
            throttleWriteRequestedAt = nil
            pendingBrakeWriteExpected = nil
            brakeWriteRequestedAt = nil
            isNfcReadPending = false
            nfcReadRequestedAt = nil
            pendingNfcWriteExpected = nil
            nfcWriteRequestedAt = nil
            pendingFrontLightExpected = nil
            frontLightRequestedAt = nil
            pendingAmbientLightExpected = nil
            ambientLightRequestedAt = nil
            isAmbientStyleReadPending = false
            ambientStyleReadRequestedAt = nil
            pendingAmbientStyleExpected = nil
            ambientStyleWriteRequestedAt = nil
            pendingSdkAuditsByFunction.removeAll()
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
            if data.isEmpty {
                appendLog(.error, "RX callback returned empty payload (nil/zero bytes)")
            }
            appendLog(.rx, "RX callback: char=\(characteristic.uuid.uuidString) bytes=\(data.hexString) error=\(String(describing: error))")
            let rxFrame = auditFrame(data)
            let crcValid = TCBManager.checkCRC16Data(data)
            let rxFunctionLabel = rxFrame.functionCode.map { String(format: "0x%02X", $0) } ?? "unknown"
            appendLog(
                .rx,
                "SDK AUDIT RX frame: bytes=\(rxFrame.totalBytes) declaredLen=\(rxFrame.declaredDataLength) expectedFrameBytes=\(rxFrame.expectedFrameBytes) frameValid=\(rxFrame.frameValid) crcValid=\(crcValid) function=\(rxFunctionLabel)"
            )
            if !rxFrame.frameValid {
                appendLog(.error, "SDK AUDIT RX malformed frame length detected before parse")
            }
            if !crcValid {
                appendLog(.error, "SDK AUDIT RX CRC invalid before parse")
            }
            if let functionCode = rxFrame.functionCode,
               functionCode == TCBFunctionCode.cmd1A.rawValue,
               data.count >= 5 {
                let declaredPayloadLen = Int(data[4])
                if declaredPayloadLen < 4 {
                    appendLog(.error, "SDK AUDIT parser risk: cmd1A payloadLen=\(declaredPayloadLen) but TCB1AModel expects >=4 bytes")
                }
            }
            let model = TCBManager.convertToModel(data: data)
            let parsedModelName = String(describing: type(of: model))
            appendLog(.sdkParse, "SDK parsed model: \(parsedModelName)")
            resolvePendingSDKAudit(with: data, parsedModelName: parsedModelName)
            if parsedModelName == "TCBBLEModel" {
                appendLog(.error, "SDK parser returned TCBBLEModel (unparsed/ignored frame)")
            }
            if pendingTcb02Action == .bind {
                bindResponseCount += 1
                appendLog(.sdkParse, "BIND pending response #\(bindResponseCount): model=\(type(of: model))")
            }
            if let bindModel = model as? TCB02Model {
                let action = pendingTcb02Action
                let wasBindAction = action == .bind
                isBound = bindModel.bluetoothStatus
                lastKnownLockStatus = bindModel.lockStatus
                if action == .bind {
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
                } else if action == .unbind {
                    if !bindModel.bluetoothStatus {
                        unbindStatus = .passed
                        appendLog(.sdkParse, "UNBIND result: PASSED (bluetoothStatus=false)")
                    } else {
                        unbindStatus = .partial
                        appendLog(.error, "UNBIND response received but bluetoothStatus=true")
                    }
                } else if action == .lock {
                    if bindModel.lockStatus {
                        lockStatus = .passed
                        appendLog(.sdkParse, "LOCK result: PASSED (lockStatus=true)")
                    } else {
                        lockStatus = .partial
                        appendLog(.error, "LOCK response received but lockStatus=false")
                    }
                } else if action == .unlock {
                    if !bindModel.lockStatus {
                        unlockStatus = .passed
                        appendLog(.sdkParse, "UNLOCK result: PASSED (lockStatus=false)")
                    } else {
                        unlockStatus = .partial
                        appendLog(.error, "UNLOCK response received but lockStatus=true")
                    }
                } else if action == .cruise {
                    appendLog(.sdkParse, "CRUISE command acknowledged via TCB02; waiting for TCB01 heartbeat confirmation")
                }
                if action != .cruise {
                    pendingTcb02Action = nil
                }
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
                lastKnownCruiseControlEnabled = heartbeatModel.cruiseControlFunction
                currentGearSelection = heartbeatModel.gear
                isZeroStartModeEnabled = !heartbeatModel.startMode
                isMetricUnitEnabled = !heartbeatModel.metricMileUnit
                isFrontLightOn = heartbeatModel.headlight
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
                if pendingTcb02Action == .cruise {
                    let expected = pendingCruiseExpectedEnabled
                    let actual = heartbeatModel.cruiseControlFunction
                    let latencyMs = cruiseCommandStartedAt.map { Int(Date().timeIntervalSince($0) * 1000) } ?? -1
                    appendLog(
                        .sdkParse,
                        "CRUISE callback: latencyMs=\(latencyMs) expected=\(String(describing: expected)) actual=\(actual)"
                    )
                    if let expected, expected == actual {
                        cruiseControlStatus = .passed
                        appendLog(.sdkParse, "CRUISE result: PASSED")
                    } else {
                        cruiseControlStatus = .partial
                        appendLog(.error, "CRUISE heartbeat received but expected state mismatch")
                    }
                    pendingTcb02Action = nil
                    pendingCruiseExpectedEnabled = nil
                    cruiseCommandStartedAt = nil
                }
                if let expectedGear = pendingGearExpected {
                    let actualGear = heartbeatModel.gear
                    let latencyMs = gearCommandStartedAt.map { Int(Date().timeIntervalSince($0) * 1000) } ?? -1
                    appendLog(.sdkParse, "GEAR heartbeat confirmation: latencyMs=\(latencyMs) expected=\(expectedGear) actual=\(actualGear)")
                    if expectedGear == actualGear {
                        gearSelectionStatus = .passed
                        appendLog(.sdkParse, "GEAR result: PASSED")
                    } else {
                        gearSelectionStatus = .partial
                        appendLog(.error, "GEAR heartbeat mismatch expected=\(expectedGear) actual=\(actualGear)")
                    }
                    pendingGearExpected = nil
                    gearCommandStartedAt = nil
                }
                if let expectedZeroStart = pendingZeroStartExpected {
                    let actualZeroStart = !heartbeatModel.startMode
                    let latencyMs = startModeCommandStartedAt.map { Int(Date().timeIntervalSince($0) * 1000) } ?? -1
                    appendLog(.sdkParse, "START MODE heartbeat confirmation: latencyMs=\(latencyMs) expectedZeroStart=\(expectedZeroStart) actualZeroStart=\(actualZeroStart)")
                    if expectedZeroStart == actualZeroStart {
                        startModeStatus = .passed
                        appendLog(.sdkParse, "START MODE result: PASSED")
                    } else {
                        startModeStatus = .partial
                        appendLog(.error, "START MODE heartbeat mismatch expectedZeroStart=\(expectedZeroStart) actualZeroStart=\(actualZeroStart)")
                    }
                    pendingZeroStartExpected = nil
                    startModeCommandStartedAt = nil
                }
                if let expectedMetric = pendingMetricUnitExpected {
                    let actualMetric = !heartbeatModel.metricMileUnit
                    let latencyMs = unitSystemCommandStartedAt.map { Int(Date().timeIntervalSince($0) * 1000) } ?? -1
                    appendLog(.sdkParse, "UNIT heartbeat confirmation: latencyMs=\(latencyMs) expectedMetric=\(expectedMetric) actualMetric=\(actualMetric)")
                    if expectedMetric == actualMetric {
                        unitSystemStatus = .passed
                        appendLog(.sdkParse, "UNIT result: PASSED")
                    } else {
                        unitSystemStatus = .partial
                        appendLog(.error, "UNIT heartbeat mismatch expectedMetric=\(expectedMetric) actualMetric=\(actualMetric)")
                    }
                    pendingMetricUnitExpected = nil
                    unitSystemCommandStartedAt = nil
                }
                if let expectedFrontLight = pendingFrontLightExpected {
                    let actualFrontLight = heartbeatModel.headlight
                    let latencyMs = frontLightRequestedAt.map { Int(Date().timeIntervalSince($0) * 1000) } ?? -1
                    appendLog(.sdkParse, "FRONT LIGHT heartbeat confirmation: latencyMs=\(latencyMs) expected=\(expectedFrontLight) actual=\(actualFrontLight)")
                    if expectedFrontLight == actualFrontLight {
                        frontLightStatus = .passed
                        appendLog(.sdkParse, "FRONT LIGHT result: PASSED")
                    } else {
                        frontLightStatus = .partial
                        appendLog(.error, "FRONT LIGHT heartbeat mismatch expected=\(expectedFrontLight) actual=\(actualFrontLight)")
                    }
                    pendingFrontLightExpected = nil
                    frontLightRequestedAt = nil
                }
            } else if let gearModel = model as? TCB05Model {
                currentGearSelection = gearModel.gear
                appendLog(.sdkParse, "SDK parsed TCB05Model: gear=\(gearModel.gear) speed=\(gearModel.speed)")
                if let expectedGear = pendingGearExpected {
                    let latencyMs = gearCommandStartedAt.map { Int(Date().timeIntervalSince($0) * 1000) } ?? -1
                    appendLog(.sdkParse, "GEAR callback: latencyMs=\(latencyMs) expected=\(expectedGear) actual=\(gearModel.gear)")
                    if expectedGear == gearModel.gear {
                        gearSelectionStatus = .passed
                        appendLog(.sdkParse, "GEAR result: PASSED")
                    } else {
                        gearSelectionStatus = .partial
                        appendLog(.error, "GEAR response mismatch expected=\(expectedGear) actual=\(gearModel.gear)")
                    }
                    pendingGearExpected = nil
                    gearCommandStartedAt = nil
                }
            } else if let responseModel = model as? TCB22Model {
                appendLog(.sdkParse, "SDK parsed TCB22Model: type=\(String(describing: responseModel.responseType)) response=\(responseModel.response)")
                if responseModel.responseType == .throttle {
                    throttleResponseValue = responseModel.response
                    if isThrottleReadPending {
                        let latencyMs = throttleReadRequestedAt.map { Int(Date().timeIntervalSince($0) * 1000) } ?? -1
                        appendLog(.sdkParse, "THROTTLE READ callback: latencyMs=\(latencyMs) value=\(responseModel.response)")
                        throttleResponseReadStatus = .passed
                        appendLog(.sdkParse, "THROTTLE READ result: PASSED")
                        isThrottleReadPending = false
                        throttleReadRequestedAt = nil
                    }
                    if let expected = pendingThrottleWriteExpected {
                        let latencyMs = throttleWriteRequestedAt.map { Int(Date().timeIntervalSince($0) * 1000) } ?? -1
                        appendLog(.sdkParse, "THROTTLE WRITE callback: latencyMs=\(latencyMs) expected=\(expected) actual=\(responseModel.response)")
                        if expected == responseModel.response {
                            throttleResponseWriteStatus = .passed
                            appendLog(.sdkParse, "THROTTLE WRITE result: PASSED")
                        } else {
                            throttleResponseWriteStatus = .partial
                            appendLog(.error, "THROTTLE WRITE mismatch expected=\(expected) actual=\(responseModel.response)")
                        }
                        pendingThrottleWriteExpected = nil
                        throttleWriteRequestedAt = nil
                    }
                } else if responseModel.responseType == .brake {
                    brakeResponseValue = responseModel.response
                    if isBrakeReadPending {
                        let latencyMs = brakeReadRequestedAt.map { Int(Date().timeIntervalSince($0) * 1000) } ?? -1
                        appendLog(.sdkParse, "BRAKE READ callback: latencyMs=\(latencyMs) value=\(responseModel.response)")
                        brakeResponseReadStatus = .passed
                        appendLog(.sdkParse, "BRAKE READ result: PASSED")
                        isBrakeReadPending = false
                        brakeReadRequestedAt = nil
                    }
                    if let expected = pendingBrakeWriteExpected {
                        let latencyMs = brakeWriteRequestedAt.map { Int(Date().timeIntervalSince($0) * 1000) } ?? -1
                        appendLog(.sdkParse, "BRAKE WRITE callback: latencyMs=\(latencyMs) expected=\(expected) actual=\(responseModel.response)")
                        if expected == responseModel.response {
                            brakeResponseWriteStatus = .passed
                            appendLog(.sdkParse, "BRAKE WRITE result: PASSED")
                        } else {
                            brakeResponseWriteStatus = .partial
                            appendLog(.error, "BRAKE WRITE mismatch expected=\(expected) actual=\(responseModel.response)")
                        }
                        pendingBrakeWriteExpected = nil
                        brakeWriteRequestedAt = nil
                    }
                }
            } else if let ambientModel = model as? TCB04Model {
                isAmbientLightOn = ambientModel.ambientLightStatus
                appendLog(.sdkParse, "SDK parsed TCB04Model: ambientLightStatus=\(ambientModel.ambientLightStatus)")
                if let expectedStatus = pendingAmbientLightExpected {
                    let latencyMs = ambientLightRequestedAt.map { Int(Date().timeIntervalSince($0) * 1000) } ?? -1
                    appendLog(.sdkParse, "AMBIENT LIGHT callback: latencyMs=\(latencyMs) expected=\(expectedStatus) actual=\(ambientModel.ambientLightStatus)")
                    if expectedStatus == ambientModel.ambientLightStatus {
                        ambientLightStatus = .passed
                        appendLog(.sdkParse, "AMBIENT LIGHT result: PASSED")
                    } else {
                        ambientLightStatus = .partial
                        appendLog(.error, "AMBIENT LIGHT mismatch expected=\(expectedStatus) actual=\(ambientModel.ambientLightStatus)")
                    }
                    pendingAmbientLightExpected = nil
                    ambientLightRequestedAt = nil
                }
            } else if let ambientStyleModel = model as? TCB1AModel {
                ambientLightMode = ambientStyleModel.magicLightMode
                ambientLightRed = ambientStyleModel.R
                ambientLightGreen = ambientStyleModel.G
                ambientLightBlue = ambientStyleModel.B
                appendLog(
                    .sdkParse,
                    "SDK parsed TCB1AModel: mode=\(ambientStyleModel.magicLightMode) R=\(ambientStyleModel.R) G=\(ambientStyleModel.G) B=\(ambientStyleModel.B)"
                )
                if isAmbientStyleReadPending {
                    let latencyMs = ambientStyleReadRequestedAt.map { Int(Date().timeIntervalSince($0) * 1000) } ?? -1
                    appendLog(.sdkParse, "AMBIENT STYLE READ callback: latencyMs=\(latencyMs) mode=\(ambientStyleModel.magicLightMode)")
                    ambientLightStyleStatus = .passed
                    appendLog(.sdkParse, "AMBIENT STYLE READ result: PASSED")
                    isAmbientStyleReadPending = false
                    ambientStyleReadRequestedAt = nil
                }
                if let expected = pendingAmbientStyleExpected {
                    let latencyMs = ambientStyleWriteRequestedAt.map { Int(Date().timeIntervalSince($0) * 1000) } ?? -1
                    let modeMatches = expected.mode == ambientStyleModel.magicLightMode
                    let rgbMatches = expected.red == ambientStyleModel.R && expected.green == ambientStyleModel.G && expected.blue == ambientStyleModel.B
                    let matches = expected.mode == 3 ? modeMatches : (modeMatches && rgbMatches)
                    appendLog(
                        .sdkParse,
                        "AMBIENT STYLE WRITE callback: latencyMs=\(latencyMs) expectedMode=\(expected.mode) actualMode=\(ambientStyleModel.magicLightMode) expectedRGB=(\(expected.red),\(expected.green),\(expected.blue)) actualRGB=(\(ambientStyleModel.R),\(ambientStyleModel.G),\(ambientStyleModel.B))"
                    )
                    if matches {
                        ambientLightStyleStatus = .passed
                        appendLog(.sdkParse, "AMBIENT STYLE WRITE result: PASSED")
                    } else {
                        ambientLightStyleStatus = .partial
                        appendLog(.error, "AMBIENT STYLE WRITE mismatch between expected and parsed model")
                    }
                    pendingAmbientStyleExpected = nil
                    ambientStyleWriteRequestedAt = nil
                }
            } else if let nfcModel = model as? TCB03Model {
                isNfcEnabled = nfcModel.nfcStatus
                appendLog(.sdkParse, "SDK parsed TCB03Model: nfcStatus=\(nfcModel.nfcStatus)")
                if isNfcReadPending {
                    let latencyMs = nfcReadRequestedAt.map { Int(Date().timeIntervalSince($0) * 1000) } ?? -1
                    appendLog(.sdkParse, "NFC READ callback: latencyMs=\(latencyMs) status=\(nfcModel.nfcStatus)")
                    nfcReadStatus = .passed
                    appendLog(.sdkParse, "NFC READ result: PASSED")
                    isNfcReadPending = false
                    nfcReadRequestedAt = nil
                }
                if let expectedStatus = pendingNfcWriteExpected {
                    let latencyMs = nfcWriteRequestedAt.map { Int(Date().timeIntervalSince($0) * 1000) } ?? -1
                    appendLog(.sdkParse, "NFC WRITE callback: latencyMs=\(latencyMs) expected=\(expectedStatus) actual=\(nfcModel.nfcStatus)")
                    if expectedStatus == nfcModel.nfcStatus {
                        nfcWriteStatus = .passed
                        appendLog(.sdkParse, "NFC WRITE result: PASSED")
                    } else {
                        nfcWriteStatus = .partial
                        appendLog(.error, "NFC WRITE mismatch expected=\(expectedStatus) actual=\(nfcModel.nfcStatus)")
                    }
                    pendingNfcWriteExpected = nil
                    nfcWriteRequestedAt = nil
                }
            } else if pendingTcb02Action == .bind {
                appendLog(.error, "BIND pending but received non-TCB02 model: \(type(of: model))")
            }
        }
    }

    private func sendAudited(_ data: Data, commandName: String, featureName: String, expectedModel: String) {
        let frameAudit = auditFrame(data)
        appendLog(
            .tx,
            "SDK AUDIT TX: command=\(commandName) feature=\(featureName) bytes=\(frameAudit.totalBytes) declaredLen=\(frameAudit.declaredDataLength) expectedFrameBytes=\(frameAudit.expectedFrameBytes) frameValid=\(frameAudit.frameValid)"
        )
        if !frameAudit.frameValid {
            appendLog(
                .error,
                "SDK AUDIT TX malformed frame for \(commandName): declaredLen does not match payload bytes"
            )
        }
        if let functionCode = frameAudit.functionCode {
            registerPendingSDKAudit(
                commandName: commandName,
                featureName: featureName,
                functionCode: functionCode,
                expectedModel: expectedModel
            )
        } else {
            appendLog(.error, "SDK AUDIT TX missing function code in payload for \(commandName)")
        }
        send(data)
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

    private func registerPendingSDKAudit(commandName: String, featureName: String, functionCode: UInt8, expectedModel: String) {
        let audit = PendingSDKAudit(
            id: UUID(),
            commandName: commandName,
            featureName: featureName,
            functionCode: functionCode,
            expectedModel: expectedModel,
            startedAt: Date()
        )
        pendingSdkAuditsByFunction[functionCode, default: []].append(audit)
        appendLog(
            .tx,
            "SDK AUDIT pending command registered: command=\(commandName) function=0x\(String(format: "%02X", functionCode)) expectedModel=\(expectedModel)"
        )
        schedulePendingSDKAuditTimeout(audit)
    }

    private func schedulePendingSDKAuditTimeout(_ audit: PendingSDKAudit) {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(6))
            guard let index = pendingSdkAuditsByFunction[audit.functionCode]?.firstIndex(where: { $0.id == audit.id }) else { return }
            pendingSdkAuditsByFunction[audit.functionCode]?.remove(at: index)
            if pendingSdkAuditsByFunction[audit.functionCode]?.isEmpty == true {
                pendingSdkAuditsByFunction[audit.functionCode] = nil
            }
            let elapsedMs = Int(Date().timeIntervalSince(audit.startedAt) * 1000)
            appendLog(
                .error,
                "SDK AUDIT timeout: command=\(audit.commandName) feature=\(audit.featureName) function=0x\(String(format: "%02X", audit.functionCode)) no matching RX/parse in \(elapsedMs)ms"
            )
        }
    }

    private func resolvePendingSDKAudit(with data: Data, parsedModelName: String) {
        guard data.count >= 3 else { return }
        let functionCode = data[2]
        guard var audits = pendingSdkAuditsByFunction[functionCode], !audits.isEmpty else { return }
        let audit = audits.removeFirst()
        if audits.isEmpty {
            pendingSdkAuditsByFunction[functionCode] = nil
        } else {
            pendingSdkAuditsByFunction[functionCode] = audits
        }
        let elapsedMs = Int(Date().timeIntervalSince(audit.startedAt) * 1000)
        appendLog(
            .sdkParse,
            "SDK AUDIT callback: command=\(audit.commandName) feature=\(audit.featureName) function=0x\(String(format: "%02X", audit.functionCode)) latencyMs=\(elapsedMs) parsedModel=\(parsedModelName)"
        )
    }

    private func auditFrame(_ data: Data) -> (totalBytes: Int, declaredDataLength: Int, expectedFrameBytes: Int, frameValid: Bool, functionCode: UInt8?) {
        let totalBytes = data.count
        guard totalBytes >= 5 else {
            return (totalBytes, -1, -1, false, nil)
        }
        let declaredDataLength = Int(data[4])
        let expectedFrameBytes = 5 + declaredDataLength + 2
        let frameValid = totalBytes == expectedFrameBytes
        let functionCode = data[2]
        return (totalBytes, declaredDataLength, expectedFrameBytes, frameValid, functionCode)
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
