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
    let message: String
}

struct BLEScanDevice: Identifiable {
    var id: UUID { peripheralID }
    let peripheralID: UUID
    var name: String
    var rssi: Int
    var discoverCount: Int
    var lastSeen: Date
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
