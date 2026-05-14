import SwiftUI

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

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                connectedScooterCard
                heartbeatCard
                validationStatusCard
                logsCard
            }
            .padding(16)
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
