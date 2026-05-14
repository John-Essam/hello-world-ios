import CoreBluetooth
import SwiftUI

struct BLEFoundationView: View {
    @StateObject private var viewModel = BLEFoundationViewModel()
    @State private var showScanSection = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if viewModel.connectionState == .connected {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Scan Section")
                                    .font(.headline)
                                Spacer()
                                Button(showScanSection ? "Collapse" : "Show") {
                                    showScanSection.toggle()
                                }
                                .buttonStyle(.borderless)
                                .font(.caption)
                            }
                            if showScanSection {
                                scanCard
                            } else {
                                Text("Hidden while connected to speed up testing.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(16)
                        .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    } else {
                        scanCard
                    }

                    if viewModel.connectionState == .connected {
                        connectedScooterCard
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Current Feature Status")
                            .font(.headline)
                        LabeledContent("BLE Scan", value: viewModel.scanStatus.rawValue)
                        LabeledContent("BLE Connect", value: viewModel.connectStatus.rawValue)
                        LabeledContent("BLE Bind", value: viewModel.bindStatus.rawValue)
                        LabeledContent("BLE Unbind", value: viewModel.unbindStatus.rawValue)
                        LabeledContent("BLE Lock", value: viewModel.lockStatus.rawValue)
                        LabeledContent("BLE Unlock", value: viewModel.unlockStatus.rawValue)
                        LabeledContent("Heartbeat (TCB01)", value: viewModel.heartbeatStatus.rawValue)
                        LabeledContent("Connection", value: viewModel.connectionState.rawValue)
                    }
                    .padding(16)
                    .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Connection Validation Pipeline")
                            .font(.headline)
                        stageRow("Scanning", isComplete: viewModel.isScanning)
                        stageRow("Device discovered", isComplete: !viewModel.devices.isEmpty)
                        stageRow("Connecting", isComplete: viewModel.connectionState == .connecting)
                        stageRow("Connected", isComplete: viewModel.hasConnectedCallback)
                        stageRow("Notify enabled", isComplete: viewModel.isNotifying)
                        stageRow("Bound", isComplete: viewModel.isBound)
                        stageRow("Heartbeat receiving", isComplete: viewModel.heartbeatCount > 0)
                    }
                    .padding(16)
                    .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Heartbeat Stream")
                            .font(.headline)
                        LabeledContent("Received Frames", value: "\(viewModel.heartbeatCount)")
                        if let heartbeat = viewModel.lastHeartbeat {
                            LabeledContent("Power", value: "\(heartbeat.powerPercent)%")
                            LabeledContent("Speed", value: "\(heartbeat.realTimeSpeed)")
                            LabeledContent("Battery Voltage Raw", value: "\(heartbeat.batteryVoltageRaw)")
                            LabeledContent("Gear", value: "\(heartbeat.gear)")
                            LabeledContent("Lock", value: heartbeat.lockStatus ? "ON" : "OFF")
                            LabeledContent("Cruise", value: heartbeat.cruiseStatus ? "ON" : "OFF")
                            LabeledContent("Controller Fault", value: heartbeat.controllerFault ? "TRUE" : "FALSE")
                        } else {
                            Text("No heartbeat parsed yet")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(16)
                    .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Nearby BLE Devices")
                                .font(.headline)
                            Spacer()
                            Text("\(viewModel.devices.count)")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.secondary.opacity(0.12), in: Capsule())
                        }
                        Text("MAC is not exposed by iOS; identifier is shown for validation.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 4)
                        Text("Scan callbacks: \(viewModel.scanCallbackCount)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 1)
                        Text("Duplicate callbacks: \(viewModel.scanDuplicateCallbackCount)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 2)

                        if viewModel.devices.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                if viewModel.isScanning {
                                    Text("Scanning nearby BLE advertisements...")
                                        .font(.subheadline.weight(.medium))
                                    Text("If this stays empty, check SCAN logs for callback count and permission status.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else if viewModel.hasScanAttempted {
                                    Text("No devices found")
                                        .font(.subheadline.weight(.medium))
                                    Text("No BLE advertisements were added to the list during the last scan.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("Press Start Scan to discover nearby BLE devices.")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 8)
                        } else {
                            LazyVStack(spacing: 10) {
                                ForEach(viewModel.devices) { device in
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "scooter")
                                        .font(.title3)
                                        .foregroundStyle(.blue)
                                        .padding(.top, 2)

                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Text(device.name)
                                                .font(.headline)
                                            Spacer()
                                            Text(viewModel.connectionLabel(for: device.peripheralID))
                                                .font(.caption.weight(.semibold))
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 3)
                                                .background(connectionPillColor(for: device.peripheralID).opacity(0.15), in: Capsule())
                                                .foregroundStyle(connectionPillColor(for: device.peripheralID))
                                        }

                                        Text("Identifier: \(device.peripheralID.uuidString)")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .textSelection(.enabled)

                                        Text("RSSI: \(device.rssi) dBm • Discoveries: \(device.discoverCount)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)

                                        HStack {
                                            if viewModel.connectedDeviceID == device.peripheralID {
                                                Button("Disconnect") {
                                                    viewModel.disconnect()
                                                }
                                                .buttonStyle(.bordered)
                                                .tint(.red)
                                            } else {
                                                Button("Connect") {
                                                    viewModel.connect(peripheralID: device.peripheralID)
                                                }
                                                .buttonStyle(.borderedProminent)
                                            }
                                            Spacer()
                                        }
                                    }
                                }
                                .padding(12)
                                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            }
                        }
                    }
                    .padding(16)
                    .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

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
                .padding(16)
            }
            .navigationTitle("BLE Foundation")
            .background(Color(.systemGroupedBackground))
            .onChange(of: viewModel.connectionState) { _, newState in
                if newState == .connected {
                    showScanSection = false
                }
            }
        }
    }

    private var scanCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("BLE Scan")
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
                        .controlSize(.regular)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                LabeledContent("Scan State", value: viewModel.scanStateLabel)
                LabeledContent("Bluetooth", value: viewModel.bluetoothStateLabel)
                LabeledContent("Authorization", value: viewModel.bluetoothAuthorizationLabel)
                LabeledContent("Info.plist BLE Keys", value: viewModel.hasBluetoothUsageDescriptions ? "Present" : "Missing")
                LabeledContent("Runtime", value: viewModel.runtimeEnvironment)
                LabeledContent("Scan Filter", value: viewModel.scanFilterLabel)
                LabeledContent("Scan Callbacks", value: "\(viewModel.scanCallbackCount)")
                LabeledContent("Duplicate Callbacks", value: "\(viewModel.scanDuplicateCallbackCount)")
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

    private var connectedScooterCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Connected Scooter")
                .font(.headline)

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
            LabeledContent("Bound", value: viewModel.isBound ? "YES" : "NO")
            LabeledContent("Lock State", value: viewModel.lockStateLabel)
            LabeledContent("Heartbeat Status", value: viewModel.heartbeatStatus.rawValue)
            LabeledContent("Heartbeat Frames", value: "\(viewModel.heartbeatCount)")

            HStack {
                Button("Bind (TCB02)") {
                    viewModel.bindScooter()
                }
                .buttonStyle(.borderedProminent)

                Button("Unbind (TCB02)") {
                    viewModel.unbindScooter()
                }
                .buttonStyle(.bordered)
            }

            HStack {
                Button("Lock") {
                    viewModel.lockScooter()
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)

                Button("Unlock") {
                    viewModel.unlockScooter()
                }
                .buttonStyle(.bordered)

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

    private func stageRow(_ label: String, isComplete: Bool) -> some View {
        HStack {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isComplete ? Color.green : Color.secondary)
            Text(label)
                .font(.subheadline)
            Spacer()
            Text(isComplete ? "YES" : "NO")
                .font(.caption.weight(.semibold))
                .foregroundStyle(isComplete ? Color.green : Color.secondary)
        }
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

    private func connectionPillColor(for deviceID: UUID) -> Color {
        let label = viewModel.connectionLabel(for: deviceID)
        switch label {
        case "Connected": return .green
        case "Connecting": return .orange
        default: return .secondary
        }
    }
}

#Preview {
    BLEFoundationView()
}
