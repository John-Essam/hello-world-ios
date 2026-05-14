import CoreBluetooth
import SwiftUI

struct BLEFoundationView: View {
    @StateObject private var viewModel = BLEFoundationViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
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

                        Text("Bluetooth: \(viewModel.bluetoothStateLabel)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

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

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Current Feature Status")
                            .font(.headline)
                        LabeledContent("BLE Scan", value: viewModel.scanStatus.rawValue)
                        LabeledContent("BLE Connect", value: viewModel.connectStatus.rawValue)
                        LabeledContent("BLE Bind", value: viewModel.bindStatus.rawValue)
                        LabeledContent("BLE Unbind", value: viewModel.unbindStatus.rawValue)
                        LabeledContent("Heartbeat (TCB01)", value: viewModel.heartbeatStatus.rawValue)
                        LabeledContent("Connection", value: viewModel.connectionState.rawValue)
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
                        Text("Discovered Devices")
                            .font(.headline)
                        if viewModel.devices.isEmpty {
                            Text("No devices yet")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(viewModel.devices) { device in
                                VStack(alignment: .leading, spacing: 8) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(device.name)
                                            .font(.headline)
                                        Text(device.peripheralID.uuidString)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        Text("RSSI: \(device.rssi) • Seen: \(device.discoverCount)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    if viewModel.connectedDeviceID == device.peripheralID {
                                        Button("Disconnect") {
                                            viewModel.disconnect()
                                        }
                                    } else {
                                        Button("Connect") {
                                            viewModel.connect(peripheralID: device.peripheralID)
                                        }
                                    }
                                }
                                .padding(.vertical, 6)
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
                                    Text(log.timestamp.formatted(date: .omitted, time: .standard))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
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
        }
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
}

#Preview {
    BLEFoundationView()
}
