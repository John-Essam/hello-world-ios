import Foundation

enum ValidationStatus: String, CaseIterable {
    case passed = "PASSED"
    case partial = "PARTIAL"
    case failed = "FAILED"
    case notTested = "NOT_TESTED"
}

enum ValidationIssueType: String {
    case iosSdkGap = "IOS_SDK_GAP"
    case iosSdkBug = "IOS_SDK_BUG"
    case implementationIssue = "IMPLEMENTATION_ISSUE"
}

enum BLEConnectionState: String {
    case disconnected = "DISCONNECTED"
    case connecting = "CONNECTING"
    case connected = "CONNECTED"
}

struct ValidationLog: Identifiable {
    let id = UUID()
    let timestamp = Date()
    let category: ValidationLogCategory
    let message: String
}

enum ValidationLogCategory: String {
    case scan = "SCAN"
    case connect = "CONNECT"
    case notify = "NOTIFY"
    case rx = "RX"
    case tx = "TX"
    case sdkParse = "SDK PARSE"
    case error = "ERROR"
}

struct BLEScanDevice: Identifiable {
    var id: UUID { peripheralID }
    let peripheralID: UUID
    var name: String
    var rssi: Int
    var discoverCount: Int
    var lastSeen: Date
    var isConnectable: Bool?
    var advertisedServiceUUIDs: [String]
    var hasVendorServiceMatch: Bool
}

struct HeartbeatSnapshot {
    let powerPercent: Int
    let realTimeSpeed: Int
    let batteryVoltageRaw: Int
    let gear: Int
    let lockStatus: Bool
    let cruiseStatus: Bool
    let controllerFault: Bool
}
