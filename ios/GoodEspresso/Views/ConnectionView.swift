//
//  ConnectionView.swift
//  Good Espresso
//
//  Bluetooth device discovery and connection view
//

import SwiftUI
import CoreBluetooth

struct ConnectionView: View {
    @EnvironmentObject var machineStore: MachineStore
    @EnvironmentObject var bluetoothService: BluetoothService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if machineStore.isConnected {
                    // Connected state
                    ConnectedView(dismiss: dismiss)
                } else if machineStore.isConnecting {
                    // Connecting state
                    ConnectingView()
                } else {
                    // Scanning/Discovery state
                    ScanningView()
                }
            }
            .padding()
            .navigationTitle("Connection")
            .inlineNavigationBarTitle()
            .toolbar {
                ToolbarItem(placement: .topBarTrailingCompat) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Connected View
struct ConnectedView: View {
    @EnvironmentObject var machineStore: MachineStore
    @EnvironmentObject var bluetoothService: BluetoothService
    let dismiss: DismissAction

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)

            VStack(spacing: 8) {
                Text("Connected")
                    .font(.title)
                    .fontWeight(.bold)

                if let name = machineStore.deviceName {
                    Text(name)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                bluetoothService.disconnect()
            } label: {
                Label("Disconnect", systemImage: "xmark.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.red)

            Button {
                dismiss()
            } label: {
                Text("Continue")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)

            Spacer()
        }
    }
}

// MARK: - Connecting View
struct ConnectingView: View {
    var body: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(2)
                .padding()

            Text("Connecting...")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Please wait while we connect to your Decent machine")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
    }
}

// MARK: - Scanning View
struct ScanningView: View {
    @EnvironmentObject var machineStore: MachineStore
    @EnvironmentObject var bluetoothService: BluetoothService

    var body: some View {
        VStack(spacing: 20) {
            // Instructions
            VStack(spacing: 8) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 50))
                    .foregroundStyle(.orange)

                Text("Find Your Machine")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Make sure your Decent espresso machine is powered on and in Bluetooth range")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom)

            // Scan button
            Button {
                bluetoothService.startScanning()
            } label: {
                HStack {
                    if bluetoothService.isScanning {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(bluetoothService.isScanning ? "Scanning..." : "Scan for Machines")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .disabled(bluetoothService.isScanning)

            // Error message
            if let error = machineStore.connectionError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Discovered devices
            if !bluetoothService.discoveredDevices.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Discovered Devices")
                        .font(.headline)
                        .padding(.top)

                    ForEach(bluetoothService.discoveredDevices, id: \.identifier) { device in
                        DeviceRow(device: device)
                    }
                }
            } else if bluetoothService.isScanning {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Looking for Decent machines...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 40)
            }

            Spacer()

            // Troubleshooting
            TroubleshootingSection()
        }
    }
}

// MARK: - Device Row
struct DeviceRow: View {
    @EnvironmentObject var bluetoothService: BluetoothService
    let device: CBPeripheral

    var body: some View {
        Button {
            bluetoothService.connect(to: device)
        } label: {
            HStack {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text(device.name ?? "Unknown Device")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text("Tap to connect")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color.secondarySystemGroupedBg)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Troubleshooting Section
struct TroubleshootingSection: View {
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("Troubleshooting")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                }
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    TroubleshootingItem(text: "Ensure Bluetooth is enabled on your device")
                    TroubleshootingItem(text: "Make sure the machine is powered on")
                    TroubleshootingItem(text: "Stay within 10 meters of the machine")
                    TroubleshootingItem(text: "Try turning the machine off and on")
                    TroubleshootingItem(text: "Disconnect from other Bluetooth devices")
                }
                .font(.caption)
            }
        }
        .padding()
        .background(Color.tertiarySystemGroupedBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct TroubleshootingItem: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "circle.fill")
                .font(.system(size: 4))
                .padding(.top, 6)

            Text(text)
        }
        .foregroundStyle(.secondary)
    }
}

#Preview {
    ConnectionView()
        .environmentObject(MachineStore())
        .environmentObject(BluetoothService())
}
