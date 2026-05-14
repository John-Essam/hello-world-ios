import CoreBluetooth
import SwiftUI

struct BLEFoundationView: View {
    @StateObject private var viewModel = BLEFoundationViewModel()

    var body: some View {
        NavigationStack {
            List {
                Section("Feature Status") {
                    LabeledContent("BLE Scan", value: viewModel.scanStatus.rawValue)
                    LabeledContent("BLE Connect", value: viewModel.connectStatus.rawValue)
                    LabeledContent("BLE Bind", value: viewModel.bindStatus.rawValue)
                    LabeledContent("BLE Unbind", value: viewModel.unbindStatus.rawValue)
                    LabeledContent("Connection", value: viewModel.connectionState.rawValue)
                    LabeledContent("Bluetooth State", value: bluetoothStateText(viewModel.bluetoothState))
                }

                Section("Scan Control") {
                    Button(viewModel.isScanning ? "Stop Scan" : "Start Scan") {
                        viewModel.toggleScan()
                    }
                }

                Section("Authentication") {
                    Button("Bind (TCB02)") {
                        viewModel.bindScooter()
                    }
                    .disabled(viewModel.connectionState != .connected)

                    Button("Unbind (TCB02)") {
                        viewModel.unbindScooter()
                    }
                    .disabled(viewModel.connectionState != .connected)
                }

                Section("Discovered Devices") {
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
                        }
                    }
                }

                Section("Validation Logs") {
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
                        }
                    }
                }
            }
            .navigationTitle("BLE Foundation")
        }
    }

    private func bluetoothStateText(_ state: CBManagerState) -> String {
        switch state {
        case .unknown: return "unknown"
        case .resetting: return "resetting"
        case .unsupported: return "unsupported"
        case .unauthorized: return "unauthorized"
        case .poweredOff: return "poweredOff"
        case .poweredOn: return "poweredOn"
        @unknown default: return "unknownFutureState"
        }
    }
}

#Preview {
    BLEFoundationView()
}
