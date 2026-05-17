import SwiftUI
import UIKit

struct BLEFoundationView: View {
    @StateObject private var viewModel = BLEFoundationViewModel()
    @State private var path: [Route] = []

    private enum Route: Hashable {
        case scooterControls
    }

    var body: some View {
        NavigationStack(path: $path) {
            BLEScanScreen(viewModel: viewModel)
                .navigationTitle("BLE Scanner")
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .scooterControls:
                        BLEScooterControlView(viewModel: viewModel)
                    }
                }
                .onChange(of: viewModel.connectionState) { _, newState in
                    if newState == .connected {
                        if path.last != .scooterControls {
                            path = [.scooterControls]
                        }
                    } else if newState == .disconnected {
                        path.removeAll()
                    }
                }
        }
    }
}

private struct BLEScanScreen: View {
    @ObservedObject var viewModel: BLEFoundationViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                scanCard
                devicesCard
                scanLogsCard
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
    }

    private var scanCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Find Nearby Scooters")
                .font(.title2.weight(.semibold))

            HStack(spacing: 10) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
                Text(viewModel.scanStatusLabel)
                    .font(.headline)
                Spacer()
                if viewModel.isScanning {
                    ProgressView()
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                LabeledContent("State", value: viewModel.scanStateLabel)
                LabeledContent("Bluetooth", value: viewModel.bluetoothStateLabel)
                LabeledContent("Permission", value: viewModel.bluetoothAuthorizationLabel)
                LabeledContent("Devices Found", value: "\(viewModel.devices.count)")
                LabeledContent("Callbacks", value: "\(viewModel.scanCallbackCount)")
            }
            .font(.subheadline)

            if let error = viewModel.lastScanError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Button {
                viewModel.toggleScan()
            } label: {
                Text(viewModel.isScanning ? "Stop Scan" : "Start Scan")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(viewModel.isScanning ? .orange : .blue)
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var devicesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Scooters")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.devices.count)")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.12), in: Capsule())
            }

            Text("Prioritized by name prefix: cardoOX1 / cardoOX2 / cardoOX3")
                .font(.caption)
                .foregroundStyle(.secondary)

            if viewModel.devices.isEmpty {
                Text(emptyStateText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.devices) { device in
                        scooterRow(device)
                    }
                }
            }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var scanLogsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Scan / Connect Logs")
                .font(.headline)
            if scanAndConnectLogs.isEmpty {
                Text("No scan/connect logs yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(scanAndConnectLogs) { log in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(log.category.rawValue)
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(logCategoryColor(log.category).opacity(0.2), in: Capsule())
                                .foregroundStyle(logCategoryColor(log.category))
                            Text(log.timestamp.formatted(date: .omitted, time: .standard))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Text(log.message)
                            .font(.caption)
                            .textSelection(.enabled)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func scooterRow(_ device: BLEScanDevice) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "scooter")
                .font(.title2)
                .foregroundStyle(device.hasScooterNamePrefix ? .green : .blue)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(device.name)
                        .font(.title3.weight(.semibold))
                    Spacer()
                    Text(viewModel.connectionLabel(for: device.peripheralID))
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(connectionPillColor(for: device.peripheralID).opacity(0.15), in: Capsule())
                        .foregroundStyle(connectionPillColor(for: device.peripheralID))
                }

                Text("Identifier: \(device.peripheralID.uuidString)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)

                Text("RSSI: \(device.rssi) dBm")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Button("Connect") {
                        viewModel.connect(peripheralID: device.peripheralID)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(device.isConnectable == false || viewModel.connectionState == .connecting)
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var scanAndConnectLogs: [ValidationLog] {
        viewModel.logs.filter { log in
            log.category == .scan || log.category == .connect || log.category == .error
        }
    }

    private var emptyStateText: String {
        if viewModel.isScanning {
            return "Scanning nearby BLE advertisements..."
        }
        if viewModel.hasScanAttempted {
            return "No devices found during the last scan."
        }
        return "Press Start Scan to discover nearby scooters."
    }

    private var statusColor: Color {
        let status = viewModel.scanStatusLabel
        if status == "Connected" || status.starts(with: "Devices found") {
            return .green
        }
        if status == "Scanning..." {
            return .blue
        }
        if status == "Bluetooth OFF" || status == "Permissions missing" || status == "Failed" {
            return .red
        }
        return .secondary
    }

    private func connectionPillColor(for deviceID: UUID) -> Color {
        let label = viewModel.connectionLabel(for: deviceID)
        switch label {
        case "Connected": return .green
        case "Connecting": return .orange
        default: return .secondary
        }
    }

    private func logCategoryColor(_ category: ValidationLogCategory) -> Color {
        switch category {
        case .scan: return .blue
        case .connect: return .teal
        case .error: return .red
        case .notify: return .mint
        case .rx: return .purple
        case .tx: return .indigo
        case .sdkParse: return .green
        }
    }
}

private struct BLEScooterControlView: View {
    @ObservedObject var viewModel: BLEFoundationViewModel
    @State private var selectedSection: Section = .foundation
    @State private var selectedGear = 0
    @State private var selectedZeroStartMode = true
    @State private var selectedMetricUnit = true
    @State private var gearMaxSpeedWriteDraft: Double = 25
    @State private var customProfileG1Draft: Double = 18
    @State private var customProfileG2Draft: Double = 25
    @State private var customProfileG3Draft: Double = 32
    @State private var throttleResponseDraft: Double = 5
    @State private var brakeResponseDraft: Double = 5
    @State private var ambientModeDraft = 1
    @State private var ambientColorDraft: Color = .cyan

    private enum Section: String, CaseIterable, Identifiable {
        case foundation = "Foundation"
        case telemetry = "Telemetry"
        case mileageTrip = "Mileage & Trip"
        case coreControls = "Core Controls"
        case lights = "Lights"
        case logs = "Logs"

        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 12) {
            Picker("Section", selection: $selectedSection) {
                ForEach(Section.allCases) { section in
                    Text(section.rawValue).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 8)

            ScrollView {
                VStack(spacing: 16) {
                    switch selectedSection {
                    case .foundation:
                        connectedScooterCard
                        heartbeatCard
                        validationStatusCard
                    case .telemetry:
                        telemetryBatteryCard
                        telemetryVoltageCard
                        telemetrySpeedCard
                        telemetryFaultFlagsCard
                        telemetryOperationalFlagsCard
                        telemetryControllerTempCard
                        telemetryBatteryTempCard
                        telemetryMotorTempCard
                        telemetryDrivingCurrentCard
                        telemetryBatteryVoltageDetailCard
                    case .mileageTrip:
                        mileageTripCard
                    case .coreControls:
                        coreControlsCard
                    case .lights:
                        lightsControlsCard
                    case .logs:
                        logsCard
                    }
                }
                .padding(16)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Scooter Controls")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var connectedScooterCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Connected Scooter")
                .font(.headline)
            liveStatusBadges

            if let device = viewModel.connectedDevice {
                Text(device.name)
                    .font(.title3.weight(.semibold))
                Text(device.peripheralID.uuidString)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                Text("RSSI: \(device.rssi) dBm")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            LabeledContent("Bind Status", value: viewModel.bindStatus.rawValue)
            LabeledContent("Notify Status", value: viewModel.notifyStatus.rawValue)
            LabeledContent("Notify Enabled", value: viewModel.isNotifying ? "YES" : "NO")
            LabeledContent("Write Channel Ready", value: viewModel.writeChannelReady ? "YES" : "NO")
            LabeledContent("Command Channel Ready", value: viewModel.isCommandChannelReady ? "YES" : "NO")
            LabeledContent("Bound", value: viewModel.isBound ? "YES" : "NO")
            LabeledContent("Lock State", value: viewModel.lockStateLabel)

            HStack {
                Button("Bind (TCB02)") {
                    viewModel.bindScooter()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.isCommandChannelReady)

                Button("Unbind (TCB02)") {
                    viewModel.unbindScooter()
                }
                .buttonStyle(.bordered)
                .disabled(!viewModel.isCommandChannelReady)
            }

            HStack {
                Button("Lock") {
                    viewModel.lockScooter()
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(!viewModel.isCommandChannelReady)

                Button("Unlock") {
                    viewModel.unlockScooter()
                }
                .buttonStyle(.bordered)
                .disabled(!viewModel.isCommandChannelReady)

                Button("Disconnect") {
                    viewModel.disconnect()
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var heartbeatCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Heartbeat Stream (TCB01)")
                .font(.headline)
            LabeledContent("Status", value: viewModel.heartbeatStatus.rawValue)
            LabeledContent("Received Frames", value: "\(viewModel.heartbeatCount)")
            if let heartbeat = viewModel.lastHeartbeat {
                LabeledContent("Power", value: "\(heartbeat.powerPercent)%")
                LabeledContent("Speed", value: "\(heartbeat.realTimeSpeed)")
                LabeledContent("Battery Voltage Raw", value: "\(heartbeat.batteryVoltageRaw)")
                LabeledContent("Gear", value: "\(heartbeat.gear)")
                LabeledContent("Cruise", value: heartbeat.cruiseStatus ? "ON" : "OFF")
                LabeledContent("Controller Fault", value: heartbeat.controllerFault ? "TRUE" : "FALSE")
            } else {
                Text("No heartbeat parsed yet")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var coreControlsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Core Controls")
                .font(.headline)
            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Gear Validation", value: viewModel.gearSelectionStatus.rawValue)
                LabeledContent("Current Gear", value: gearLabel(viewModel.currentGearSelection))
                Picker("Gear", selection: gearBinding) {
                    Text("Walk").tag(0)
                    Text("Gear1").tag(1)
                    Text("Gear2").tag(2)
                    Text("Gear3").tag(3)
                }
                .pickerStyle(.segmented)
                .disabled(!viewModel.isCommandChannelReady)
            }
            .padding(.bottom, 8)

            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Gear Max Speed Read", value: viewModel.gearMaxSpeedReadStatus.rawValue)
                LabeledContent("Gear1 Max Speed", value: viewModel.gear1MaxSpeed.map(String.init) ?? "Unknown")
                LabeledContent("Gear2 Max Speed", value: viewModel.gear2MaxSpeed.map(String.init) ?? "Unknown")
                LabeledContent("Gear3 Max Speed", value: viewModel.gear3MaxSpeed.map(String.init) ?? "Unknown")
                HStack {
                    Button("Read G1") {
                        viewModel.readGearMaxSpeed(gear: 1)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!viewModel.isCommandChannelReady)

                    Button("Read G2") {
                        viewModel.readGearMaxSpeed(gear: 2)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!viewModel.isCommandChannelReady)

                    Button("Read G3") {
                        viewModel.readGearMaxSpeed(gear: 3)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!viewModel.isCommandChannelReady)
                }
                Text("Official SDK API: `TCB05Command.readGearMaxSpeed(gear:)`")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 8)

            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Gear Max Speed Write", value: viewModel.gearMaxSpeedWriteStatus.rawValue)
                LabeledContent("Target Speed", value: "\(Int(gearMaxSpeedWriteDraft.rounded()))")
                Slider(value: $gearMaxSpeedWriteDraft, in: 0...50, step: 1)
                    .disabled(!viewModel.isCommandChannelReady)
                HStack {
                    Button("Write G1") {
                        viewModel.writeGearMaxSpeed(gear: 1, speed: Int(gearMaxSpeedWriteDraft.rounded()))
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.isCommandChannelReady)

                    Button("Write G2") {
                        viewModel.writeGearMaxSpeed(gear: 2, speed: Int(gearMaxSpeedWriteDraft.rounded()))
                    }
                    .buttonStyle(.bordered)
                    .disabled(!viewModel.isCommandChannelReady)

                    Button("Write G3") {
                        viewModel.writeGearMaxSpeed(gear: 3, speed: Int(gearMaxSpeedWriteDraft.rounded()))
                    }
                    .buttonStyle(.bordered)
                    .disabled(!viewModel.isCommandChannelReady)
                }
                let summaryGear = viewModel.lastGearMaxSpeedWriteRequestedGear.map { "G\($0)" } ?? "n/a"
                let summaryRequested = viewModel.lastGearMaxSpeedWriteRequestedSpeed.map(String.init) ?? "n/a"
                let summarySdk = viewModel.lastGearMaxSpeedWriteSdkSpeed.map(String.init) ?? "n/a"
                let summaryReadback = viewModel.lastGearMaxSpeedWriteReadbackSpeed.map(String.init) ?? "n/a"
                Text("Last write \(summaryGear): requested=\(summaryRequested) sdkValue=\(summarySdk) readback=\(summaryReadback)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Official SDK API: `TCB05Command.writeGearMaxSpeed(gear:speed:)`")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 8)

            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Custom Gear Profiles", value: viewModel.customGearProfilesStatus.rawValue)
                LabeledContent("G1 Target", value: "\(Int(customProfileG1Draft.rounded()))")
                Slider(value: $customProfileG1Draft, in: 0...50, step: 1)
                    .disabled(!viewModel.isCommandChannelReady)
                LabeledContent("G2 Target", value: "\(Int(customProfileG2Draft.rounded()))")
                Slider(value: $customProfileG2Draft, in: 0...50, step: 1)
                    .disabled(!viewModel.isCommandChannelReady)
                LabeledContent("G3 Target", value: "\(Int(customProfileG3Draft.rounded()))")
                Slider(value: $customProfileG3Draft, in: 0...50, step: 1)
                    .disabled(!viewModel.isCommandChannelReady)

                Button("Apply Custom Profile") {
                    viewModel.applyCustomGearProfile(
                        g1: Int(customProfileG1Draft.rounded()),
                        g2: Int(customProfileG2Draft.rounded()),
                        g3: Int(customProfileG3Draft.rounded())
                    )
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.isCommandChannelReady)

                let requestedText = "Requested: G1=\(viewModel.customProfileRequestedG1.map(String.init) ?? "n/a") G2=\(viewModel.customProfileRequestedG2.map(String.init) ?? "n/a") G3=\(viewModel.customProfileRequestedG3.map(String.init) ?? "n/a")"
                let sdkText = "SDK values: G1=\(viewModel.customProfileSdkG1.map(String.init) ?? "n/a") G2=\(viewModel.customProfileSdkG2.map(String.init) ?? "n/a") G3=\(viewModel.customProfileSdkG3.map(String.init) ?? "n/a")"
                let readbackText = "Readback: G1=\(viewModel.customProfileReadbackG1.map(String.init) ?? "n/a") G2=\(viewModel.customProfileReadbackG2.map(String.init) ?? "n/a") G3=\(viewModel.customProfileReadbackG3.map(String.init) ?? "n/a")"
                Text(requestedText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(sdkText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(readbackText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Flow: writes use 1500ms spacing, then readback starts after ~4500ms delay.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 8)

            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Global Max Speed Read", value: viewModel.globalMaxSpeedReadStatus.rawValue)
                LabeledContent("Global Max Speed", value: viewModel.globalMaxSpeed.map(String.init) ?? "Unknown")
                Button("Read Global Max Speed") {
                    viewModel.readGlobalMaxSpeed()
                }
                .buttonStyle(.bordered)
                .disabled(!viewModel.isCommandChannelReady)
                Text("Official SDK API: `TCB05Command.readMaxSpeed()`")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 8)

            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Start Mode Validation", value: viewModel.startModeStatus.rawValue)
                LabeledContent("Current Start Mode", value: startModeLabel(viewModel.isZeroStartModeEnabled))
                Picker("Start Mode", selection: startModeBinding) {
                    Text("Zero Start").tag(true)
                    Text("Kick Start").tag(false)
                }
                .pickerStyle(.segmented)
                .disabled(!viewModel.isCommandChannelReady)
            }
            .padding(.bottom, 8)

            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Unit Validation", value: viewModel.unitSystemStatus.rawValue)
                LabeledContent("Current Unit", value: unitLabel(viewModel.isMetricUnitEnabled))
                Picker("Unit", selection: unitBinding) {
                    Text("KM").tag(true)
                    Text("Mile").tag(false)
                }
                .pickerStyle(.segmented)
                .disabled(!viewModel.isCommandChannelReady)
            }
            .padding(.bottom, 8)

            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Throttle Response Read", value: viewModel.throttleResponseReadStatus.rawValue)
                LabeledContent("Throttle Response Value", value: viewModel.throttleResponseValue.map(String.init) ?? "Unknown")
                Button("Read Throttle Response") {
                    viewModel.readThrottleResponse()
                }
                .buttonStyle(.bordered)
                .disabled(!viewModel.isCommandChannelReady)
            }
            .padding(.bottom, 8)

            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Brake Response Read", value: viewModel.brakeResponseReadStatus.rawValue)
                LabeledContent("Brake Response Value", value: viewModel.brakeResponseValue.map(String.init) ?? "Unknown")
                Button("Read Brake Response") {
                    viewModel.readBrakeResponse()
                }
                .buttonStyle(.bordered)
                .disabled(!viewModel.isCommandChannelReady)
            }
            .padding(.bottom, 8)

            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Throttle Response Write", value: viewModel.throttleResponseWriteStatus.rawValue)
                LabeledContent("Target Value", value: "\(Int(throttleResponseDraft.rounded()))")
                Slider(value: $throttleResponseDraft, in: 0...10, step: 1)
                    .disabled(!viewModel.isCommandChannelReady)
                Button("Write Throttle Response") {
                    viewModel.writeThrottleResponse(value: Int(throttleResponseDraft.rounded()))
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.isCommandChannelReady)
            }
            .padding(.bottom, 8)

            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Brake Response Write", value: viewModel.brakeResponseWriteStatus.rawValue)
                LabeledContent("Target Value", value: "\(Int(brakeResponseDraft.rounded()))")
                Slider(value: $brakeResponseDraft, in: 0...10, step: 1)
                    .disabled(!viewModel.isCommandChannelReady)
                Button("Write Brake Response") {
                    viewModel.writeBrakeResponse(value: Int(brakeResponseDraft.rounded()))
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.isCommandChannelReady)
            }
            .padding(.bottom, 8)

            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("NFC Read Validation", value: viewModel.nfcReadStatus.rawValue)
                LabeledContent("Current NFC Status", value: viewModel.isNfcEnabled == nil ? "Unknown" : (viewModel.isNfcEnabled == true ? "Enabled" : "Disabled"))
                Button("Read NFC Status") {
                    viewModel.readNfcStatus()
                }
                .buttonStyle(.bordered)
                .disabled(!viewModel.isCommandChannelReady)
            }
            .padding(.bottom, 8)

            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("NFC Write Validation", value: viewModel.nfcWriteStatus.rawValue)
                HStack {
                    Button("Enable NFC") {
                        viewModel.setNfcStatus(enabled: true)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.isCommandChannelReady)

                    Button("Disable NFC") {
                        viewModel.setNfcStatus(enabled: false)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!viewModel.isCommandChannelReady)
                }
            }
            .padding(.bottom, 8)

            LabeledContent("Cruise Command Validation", value: viewModel.cruiseControlStatus.rawValue)
            LabeledContent(
                "Current Cruise State",
                value: viewModel.lastKnownCruiseControlEnabled == nil ? "Unknown" : (viewModel.lastKnownCruiseControlEnabled == true ? "ON" : "OFF")
            )
            HStack {
                Button("Cruise ON") {
                    viewModel.setCruiseControl(enabled: true)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.isCommandChannelReady)

                Button("Cruise OFF") {
                    viewModel.setCruiseControl(enabled: false)
                }
                .buttonStyle(.bordered)
                .disabled(!viewModel.isCommandChannelReady)
            }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onChange(of: viewModel.currentGearSelection) { _, newGear in
            if let newGear {
                selectedGear = newGear
            }
        }
        .onChange(of: viewModel.isZeroStartModeEnabled) { _, newMode in
            if let newMode {
                selectedZeroStartMode = newMode
            }
        }
        .onChange(of: viewModel.isMetricUnitEnabled) { _, newUnit in
            if let newUnit {
                selectedMetricUnit = newUnit
            }
        }
        .onChange(of: viewModel.throttleResponseValue) { _, newValue in
            if let newValue {
                throttleResponseDraft = Double(newValue)
            }
        }
        .onChange(of: viewModel.brakeResponseValue) { _, newValue in
            if let newValue {
                brakeResponseDraft = Double(newValue)
            }
        }
        .onChange(of: viewModel.ambientLightMode) { _, newMode in
            if let newMode, (1...3).contains(newMode) {
                ambientModeDraft = newMode
            }
        }
        .onChange(of: viewModel.ambientLightRed) { _, _ in
            syncAmbientColorFromModel()
        }
        .onChange(of: viewModel.ambientLightGreen) { _, _ in
            syncAmbientColorFromModel()
        }
        .onChange(of: viewModel.ambientLightBlue) { _, _ in
            syncAmbientColorFromModel()
        }
    }

    private var validationStatusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("BLE Foundation Validation")
                .font(.headline)
            LabeledContent("BLE Scan", value: viewModel.scanStatus.rawValue)
            LabeledContent("BLE Connect", value: viewModel.connectStatus.rawValue)
            LabeledContent("BLE Bind", value: viewModel.bindStatus.rawValue)
            LabeledContent("BLE Unbind", value: viewModel.unbindStatus.rawValue)
            LabeledContent("BLE Lock", value: viewModel.lockStatus.rawValue)
            LabeledContent("BLE Unlock", value: viewModel.unlockStatus.rawValue)
            LabeledContent("Core Controls - Gear", value: viewModel.gearSelectionStatus.rawValue)
            LabeledContent("Core Controls - Gear Max Speed Read", value: viewModel.gearMaxSpeedReadStatus.rawValue)
            LabeledContent("Core Controls - Gear Max Speed Write", value: viewModel.gearMaxSpeedWriteStatus.rawValue)
            LabeledContent("Core Controls - Custom Gear Profiles", value: viewModel.customGearProfilesStatus.rawValue)
            LabeledContent("Core Controls - Global Max Speed Read", value: viewModel.globalMaxSpeedReadStatus.rawValue)
            LabeledContent("Core Controls - Start Mode", value: viewModel.startModeStatus.rawValue)
            LabeledContent("Core Controls - Unit", value: viewModel.unitSystemStatus.rawValue)
            LabeledContent("Core Controls - Throttle Read", value: viewModel.throttleResponseReadStatus.rawValue)
            LabeledContent("Core Controls - Brake Read", value: viewModel.brakeResponseReadStatus.rawValue)
            LabeledContent("Core Controls - Throttle Write", value: viewModel.throttleResponseWriteStatus.rawValue)
            LabeledContent("Core Controls - Brake Write", value: viewModel.brakeResponseWriteStatus.rawValue)
            LabeledContent("Core Controls - NFC Read", value: viewModel.nfcReadStatus.rawValue)
            LabeledContent("Core Controls - NFC Write", value: viewModel.nfcWriteStatus.rawValue)
            LabeledContent("Core Controls - Cruise", value: viewModel.cruiseControlStatus.rawValue)
            LabeledContent("Lights - Front Light", value: viewModel.frontLightStatus.rawValue)
            LabeledContent("Lights - Ambient Power", value: viewModel.ambientLightStatus.rawValue)
            LabeledContent("Lights - Ambient RGB/Mode", value: viewModel.ambientLightStyleStatus.rawValue)
            LabeledContent("Telemetry - Battery Percentage", value: viewModel.telemetryBatteryPercentageStatus.rawValue)
            LabeledContent("Telemetry - Battery Voltage", value: viewModel.telemetryBatteryVoltageStatus.rawValue)
            LabeledContent("Telemetry - Real-Time Speed", value: viewModel.telemetryRealTimeSpeedStatus.rawValue)
            LabeledContent("Telemetry - Fault Flags", value: viewModel.telemetryFaultFlagsStatus.rawValue)
            LabeledContent("Telemetry - Operational Flags", value: viewModel.telemetryOperationalFlagsStatus.rawValue)
            LabeledContent("Telemetry - Controller Temp", value: viewModel.telemetryControllerTempStatus.rawValue)
            LabeledContent("Telemetry - Battery Temp", value: viewModel.telemetryBatteryTempStatus.rawValue)
            LabeledContent("Telemetry - Motor Temp", value: viewModel.telemetryMotorTempStatus.rawValue)
            LabeledContent("Telemetry - Driving Current", value: viewModel.telemetryDrivingCurrentStatus.rawValue)
            LabeledContent("Telemetry - Battery Voltage Detail", value: viewModel.telemetryBatteryVoltageDetailStatus.rawValue)
            LabeledContent("Mileage & Trip - Remaining Mileage", value: viewModel.mileageRemainingStatus.rawValue)
            LabeledContent("Mileage & Trip - Single Trip", value: viewModel.mileageSingleTripStatus.rawValue)
            LabeledContent("Mileage & Trip - Total ODO", value: viewModel.mileageTotalOdoStatus.rawValue)
            LabeledContent("Mileage & Trip - Avg/Max Speed", value: viewModel.mileageSpeedStatsStatus.rawValue)
            LabeledContent("Mileage & Trip - Riding Time", value: viewModel.mileageRidingTimeStatus.rawValue)
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var telemetryBatteryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Telemetry")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Battery Percentage", value: viewModel.batteryPercent.map { "\($0)%" } ?? "--")
                LabeledContent("Heartbeat Frames", value: "\(viewModel.heartbeatCount)")
                LabeledContent("Validation", value: viewModel.telemetryBatteryPercentageStatus.rawValue)
                Text("Source: TCB01 heartbeat stream (`TCB01Model.power`)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var telemetrySpeedCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Real-Time Speed")
                .font(.headline)

            let speedText = viewModel.realTimeSpeed.map(String.init) ?? "--"
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(speedText)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .contentTransition(.numericText(value: Double(viewModel.realTimeSpeed ?? 0)))
                Text("km/h")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            .animation(.easeInOut(duration: 0.2), value: viewModel.realTimeSpeed)

            LabeledContent("Validation", value: viewModel.telemetryRealTimeSpeedStatus.rawValue)
            Text("Source: TCB01 heartbeat stream (`TCB01Model.realtimeSpeed`)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var telemetryFaultFlagsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Fault Flags")
                .font(.headline)

            if viewModel.activeFaultFlags.isEmpty {
                Text("No faults")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], spacing: 8) {
                    ForEach(viewModel.activeFaultFlags, id: \.self) { fault in
                        Text(fault)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .foregroundStyle(.red)
                    }
                }
            }

            LabeledContent("Validation", value: viewModel.telemetryFaultFlagsStatus.rawValue)
            Text("Source: TCB01 heartbeat fault bitfields")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var telemetryOperationalFlagsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Operational Status Flags")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], spacing: 8) {
                statusChip("Lock", value: viewModel.operationalLockStatus)
                statusChip("Front Light", value: viewModel.operationalFrontLightStatus)
                statusChip("Cruise", value: viewModel.operationalCruiseStatus)
                statusChip("Charging", value: viewModel.operationalChargingStatus)
                statusChip("NFC", value: viewModel.operationalNfcStatus)
                statusChip("Push Assist", value: viewModel.operationalPushAssistStatus)
                statusChip("Motor Running", value: viewModel.operationalMotorRunningStatus)
            }

            LabeledContent("Validation", value: viewModel.telemetryOperationalFlagsStatus.rawValue)
            Text("Heartbeat source: lock/light/cruise/charging/push/motor (`TCB01Model`); NFC is sourced from `TCB03Model` when available.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func statusChip(_ label: String, value: Bool?) -> some View {
        let text = value == nil ? "Unknown" : (value == true ? "ON" : "OFF")
        let tint: Color = value == nil ? .secondary : (value == true ? .green : .orange)
        return HStack {
            Text(label)
                .font(.caption.weight(.semibold))
            Spacer()
            Text(text)
                .font(.caption2.weight(.bold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .foregroundStyle(tint)
    }

    private var telemetryControllerTempCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Controller Temperature")
                .font(.headline)

            LabeledContent("Value", value: viewModel.controllerTemperatureC.map { "\($0) °C" } ?? "--")
            LabeledContent("Validation", value: viewModel.telemetryControllerTempStatus.rawValue)

            Button("Read Controller Temperature") {
                viewModel.readControllerTemperature()
            }
            .buttonStyle(.bordered)
            .disabled(!viewModel.isCommandChannelReady)

            Text("Official SDK API: `TCB0ACommand.readTemp()`")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var telemetryBatteryTempCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Battery Temperature")
                .font(.headline)

            Text("Not available in official iOS SDK")
                .font(.subheadline.weight(.semibold))
            LabeledContent("Validation", value: viewModel.telemetryBatteryTempStatus.rawValue)
            LabeledContent("Classification", value: ValidationIssueType.iosSdkGap.rawValue)
            Text("No documented helper equivalent to `readTemp(.battery)` exists in current iOS SDK source.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var telemetryMotorTempCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Motor Temperature")
                .font(.headline)

            Text("Not available in official iOS SDK")
                .font(.subheadline.weight(.semibold))
            LabeledContent("Validation", value: viewModel.telemetryMotorTempStatus.rawValue)
            LabeledContent("Classification", value: ValidationIssueType.iosSdkGap.rawValue)
            Text("No documented helper equivalent to `readTemp(.motor)` exists in current iOS SDK source.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var telemetryDrivingCurrentCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Driving Current")
                .font(.headline)

            LabeledContent("Value", value: viewModel.drivingCurrentA.map { String(format: "%.1f A", $0) } ?? "--")
            LabeledContent("Validation", value: viewModel.telemetryDrivingCurrentStatus.rawValue)

            Button("Read Driving Current") {
                viewModel.readDrivingCurrent()
            }
            .buttonStyle(.bordered)
            .disabled(!viewModel.isCommandChannelReady)

            Text("Official SDK API: `TCB0BCommand.readDrivingCurrent()`")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var telemetryBatteryVoltageDetailCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Battery Voltage Detail")
                .font(.headline)

            Text("Not available in official iOS SDK")
                .font(.subheadline.weight(.semibold))
            LabeledContent("Validation", value: viewModel.telemetryBatteryVoltageDetailStatus.rawValue)
            LabeledContent("Classification", value: ValidationIssueType.iosSdkGap.rawValue)
            Text("The iOS SDK exposes `cmd0C` enum metadata but no official command helper/model parser flow for this feature.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var telemetryVoltageCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Battery Voltage")
                .font(.headline)

            let volts = viewModel.batteryVoltageRaw.map { Double($0) / 10.0 }
            LabeledContent("Raw Value", value: viewModel.batteryVoltageRaw.map(String.init) ?? "--")
            LabeledContent("Voltage", value: volts.map { String(format: "%.1f V", $0) } ?? "--")
            LabeledContent("Validation", value: viewModel.telemetryBatteryVoltageStatus.rawValue)
            Text("Source: TCB01 heartbeat stream (`TCB01Model.batteryVoltage`)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var mileageTripCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mileage & Trip")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Remaining Range", value: viewModel.remainingMileageKm.map { String(format: "%.1f km", $0) } ?? "--")
                LabeledContent("Validation", value: viewModel.mileageRemainingStatus.rawValue)
                LabeledContent("Battery Reference", value: viewModel.batteryPercent.map { "\($0)%" } ?? "--")

                Button("Read Remaining Mileage") {
                    viewModel.readRemainingMileage()
                }
                .buttonStyle(.bordered)
                .disabled(!viewModel.isCommandChannelReady)

                Text("Official SDK API: `TCB30Command.readRemainingMileage()`")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Single-Trip Mileage", value: viewModel.singleTripMileageKm.map { String(format: "%.1f km", $0) } ?? "--")
                LabeledContent("Validation", value: viewModel.mileageSingleTripStatus.rawValue)
                Text("Last successful read is persisted in UI until disconnected.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Read Single-Trip Mileage") {
                    viewModel.readSingleTripMileage()
                }
                .buttonStyle(.bordered)
                .disabled(!viewModel.isCommandChannelReady)

                Text("Official SDK API: `TCB08Command.readSingleTripMileage()`")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Total Mileage (ODO)", value: viewModel.totalOdoMileageKm.map { String(format: "%.1f km", $0) } ?? "--")
                LabeledContent("Validation", value: viewModel.mileageTotalOdoStatus.rawValue)

                Button("Read Total Mileage (ODO)") {
                    viewModel.readTotalTripMileage()
                }
                .buttonStyle(.bordered)
                .disabled(!viewModel.isCommandChannelReady)

                Text("Official SDK API: `TCB09Command.readTotalTripMileage()`")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Text("Speed Stats (Avg / Max)")
                    .font(.subheadline.weight(.semibold))
                LabeledContent("Validation", value: viewModel.mileageSpeedStatsStatus.rawValue)
                LabeledContent("Classification", value: ValidationIssueType.iosSdkGap.rawValue)
                Text("No official iOS SDK command helper/model parser is exposed for cmd32 speed stats.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Placeholder only: manual frame path is intentionally not used.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Text("Riding Time")
                    .font(.subheadline.weight(.semibold))
                LabeledContent("Validation", value: viewModel.mileageRidingTimeStatus.rawValue)
                LabeledContent("Classification", value: ValidationIssueType.iosSdkGap.rawValue)
                Text("No official iOS SDK command helper/model parser is exposed for cmd31 riding time.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Placeholder only: manual frame path is intentionally not used.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var logsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Validation Logs")
                .font(.headline)
            if viewModel.logs.isEmpty {
                Text("No logs yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.logs) { log in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(log.category.rawValue)
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(logCategoryColor(log.category).opacity(0.2), in: Capsule())
                                .foregroundStyle(logCategoryColor(log.category))
                            Text(log.timestamp.formatted(date: .omitted, time: .standard))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Text(log.message)
                            .font(.caption)
                            .textSelection(.enabled)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var lightsControlsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Lights")
                .font(.headline)
            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Front Light Validation", value: viewModel.frontLightStatus.rawValue)
                LabeledContent("Current Front Light", value: viewModel.isFrontLightOn == nil ? "Unknown" : (viewModel.isFrontLightOn == true ? "ON" : "OFF"))
                HStack {
                    Button("Front Light ON") {
                        viewModel.setFrontLightStatus(enabled: true)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.isCommandChannelReady)

                    Button("Front Light OFF") {
                        viewModel.setFrontLightStatus(enabled: false)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!viewModel.isCommandChannelReady)
                }
            }
            .padding(.bottom, 8)

            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Ambient Light Validation", value: viewModel.ambientLightStatus.rawValue)
                LabeledContent("Current Ambient Light", value: viewModel.isAmbientLightOn == nil ? "Unknown" : (viewModel.isAmbientLightOn == true ? "ON" : "OFF"))
                HStack {
                    Button("Ambient ON") {
                        viewModel.setAmbientLightStatus(enabled: true)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.isCommandChannelReady)

                    Button("Ambient OFF") {
                        viewModel.setAmbientLightStatus(enabled: false)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!viewModel.isCommandChannelReady)
                }
            }
            .padding(.bottom, 8)

            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Ambient RGB/Mode Validation", value: viewModel.ambientLightStyleStatus.rawValue)
                LabeledContent("Current Mode", value: ambientModeLabel(viewModel.ambientLightMode))
                Picker("Ambient Mode", selection: $ambientModeDraft) {
                    Text("Solid").tag(1)
                    Text("Breathing").tag(2)
                    Text("7-Color Magic").tag(3)
                }
                .pickerStyle(.segmented)
                .disabled(!viewModel.isCommandChannelReady)

                ColorPicker("Ambient Color", selection: $ambientColorDraft, supportsOpacity: false)
                    .disabled(!viewModel.isCommandChannelReady)

                HStack {
                    Button("Apply Ambient Style") {
                        let rgb = colorComponents(for: ambientColorDraft)
                        viewModel.writeAmbientLightStyle(
                            mode: ambientModeDraft,
                            red: rgb.red,
                            green: rgb.green,
                            blue: rgb.blue
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.isCommandChannelReady)

                    Button("Read Ambient Style") {
                        viewModel.readAmbientLightStyle()
                    }
                    .buttonStyle(.bordered)
                    .disabled(!viewModel.isCommandChannelReady)
                }
            }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var liveStatusBadges: some View {
        HStack(spacing: 8) {
            statusBadge("CONNECTED", active: viewModel.connectionState == .connected, color: .green)
            statusBadge("NOTIFY READY", active: viewModel.notifyChannelReady, color: .mint)
            statusBadge("AUTHENTICATED", active: viewModel.isBound, color: .purple)
            statusBadge("HEARTBEAT", active: viewModel.heartbeatCount > 0, color: .blue)
        }
    }

    private func statusBadge(_ title: String, active: Bool, color: Color) -> some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background((active ? color : .secondary).opacity(0.15), in: Capsule())
            .foregroundStyle(active ? color : .secondary)
    }

    private var gearBinding: Binding<Int> {
        Binding(
            get: {
                viewModel.currentGearSelection ?? selectedGear
            },
            set: { newValue in
                selectedGear = newValue
                viewModel.setGear(newValue)
            }
        )
    }

    private func gearLabel(_ gear: Int?) -> String {
        guard let gear else { return "Unknown" }
        switch gear {
        case 0: return "Walk"
        case 1: return "Gear1"
        case 2: return "Gear2"
        case 3: return "Gear3"
        default: return "Gear\(gear)"
        }
    }

    private var startModeBinding: Binding<Bool> {
        Binding(
            get: {
                viewModel.isZeroStartModeEnabled ?? selectedZeroStartMode
            },
            set: { newValue in
                selectedZeroStartMode = newValue
                viewModel.setStartMode(zeroStart: newValue)
            }
        )
    }

    private func startModeLabel(_ isZeroStart: Bool?) -> String {
        guard let isZeroStart else { return "Unknown" }
        return isZeroStart ? "Zero Start" : "Kick Start"
    }

    private var unitBinding: Binding<Bool> {
        Binding(
            get: {
                viewModel.isMetricUnitEnabled ?? selectedMetricUnit
            },
            set: { newValue in
                selectedMetricUnit = newValue
                viewModel.setUnitSystem(metric: newValue)
            }
        )
    }

    private func unitLabel(_ isMetric: Bool?) -> String {
        guard let isMetric else { return "Unknown" }
        return isMetric ? "KM" : "Mile"
    }

    private func ambientModeLabel(_ mode: Int?) -> String {
        guard let mode else { return "Unknown" }
        switch mode {
        case 1: return "Solid"
        case 2: return "Breathing"
        case 3: return "7-Color Magic"
        default: return "Mode \(mode)"
        }
    }

    private func syncAmbientColorFromModel() {
        guard
            let red = viewModel.ambientLightRed,
            let green = viewModel.ambientLightGreen,
            let blue = viewModel.ambientLightBlue
        else { return }
        ambientColorDraft = Color(
            .sRGB,
            red: Double(red) / 255.0,
            green: Double(green) / 255.0,
            blue: Double(blue) / 255.0,
            opacity: 1.0
        )
    }

    private func colorComponents(for color: Color) -> (red: Int, green: Int, blue: Int) {
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        if uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            return (
                red: Int((red * 255.0).rounded()),
                green: Int((green * 255.0).rounded()),
                blue: Int((blue * 255.0).rounded())
            )
        }
        return (red: 0, green: 255, blue: 255)
    }

    private func logCategoryColor(_ category: ValidationLogCategory) -> Color {
        switch category {
        case .scan: return .blue
        case .connect: return .teal
        case .notify: return .mint
        case .rx: return .purple
        case .tx: return .indigo
        case .sdkParse: return .green
        case .error: return .red
        }
    }
}

#Preview {
    BLEFoundationView()
}
