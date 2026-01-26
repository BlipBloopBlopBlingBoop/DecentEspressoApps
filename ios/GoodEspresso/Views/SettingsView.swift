//
//  SettingsView.swift
//  Good Espresso
//
//  App settings and machine configuration
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var machineStore: MachineStore
    @EnvironmentObject var bluetoothService: BluetoothService
    @State private var showingLegal = false
    @State private var showingAbout = false

    var body: some View {
        NavigationStack {
            List {
                // Connection Section
                Section("Connection") {
                    HStack {
                        Label("Status", systemImage: "antenna.radiowaves.left.and.right")
                        Spacer()
                        Text(machineStore.isConnected ? "Connected" : "Disconnected")
                            .foregroundStyle(.secondary)
                    }

                    if let name = machineStore.deviceName {
                        HStack {
                            Label("Device", systemImage: "cup.and.saucer")
                            Spacer()
                            Text(name)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if machineStore.isConnected {
                        Button(role: .destructive) {
                            bluetoothService.disconnect()
                        } label: {
                            Label("Disconnect", systemImage: "xmark.circle")
                        }
                    }
                }

                // Units Section
                Section("Units") {
                    Picker("Temperature", selection: $machineStore.temperatureUnit) {
                        Text("Celsius (\u{00B0}C)").tag("celsius")
                        Text("Fahrenheit (\u{00B0}F)").tag("fahrenheit")
                    }

                    Picker("Weight", selection: $machineStore.weightUnit) {
                        Text("Grams (g)").tag("grams")
                        Text("Ounces (oz)").tag("ounces")
                    }
                }

                // Data Section
                Section("Data") {
                    HStack {
                        Label("Shot History", systemImage: "clock.arrow.circlepath")
                        Spacer()
                        Text("\(machineStore.shotHistory.count) shots")
                            .foregroundStyle(.secondary)
                    }

                    Button(role: .destructive) {
                        machineStore.shotHistory.removeAll()
                        machineStore.saveShotHistory()
                    } label: {
                        Label("Clear History", systemImage: "trash")
                    }
                    .disabled(machineStore.shotHistory.isEmpty)
                }

                // About Section
                Section("About") {
                    Button {
                        showingAbout = true
                    } label: {
                        HStack {
                            Label("About Good Espresso", systemImage: "info.circle")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                        }
                        .foregroundStyle(.primary)
                    }

                    Button {
                        showingLegal = true
                    } label: {
                        HStack {
                            Label("Legal & Disclaimers", systemImage: "doc.text")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                        }
                        .foregroundStyle(.primary)
                    }

                    HStack {
                        Label("Version", systemImage: "number")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                }

                // Support Section
                Section("Support") {
                    Link(destination: URL(string: "https://github.com/goodespresso/app")!) {
                        HStack {
                            Label("GitHub Repository", systemImage: "link")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Link(destination: URL(string: "https://decentespresso.com")!) {
                        HStack {
                            Label("Decent Espresso", systemImage: "link")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingLegal) {
                LegalView(isPresented: $showingLegal)
            }
            .sheet(isPresented: $showingAbout) {
                AboutView()
            }
        }
    }
}

// MARK: - About View
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // App Icon and Name
                    VStack(spacing: 12) {
                        Image(systemName: "cup.and.saucer.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.orange)

                        Text("Good Espresso")
                            .font(.title)
                            .fontWeight(.bold)

                        Text("Version 1.0.0")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 20)

                    // Description
                    VStack(alignment: .leading, spacing: 16) {
                        Text("About")
                            .font(.headline)

                        Text("Good Espresso is an open-source iOS application for controlling Decent espresso machines via Bluetooth. It provides real-time monitoring, professional brewing profiles, and shot history tracking.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Features
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Features")
                            .font(.headline)

                        FeatureItem(icon: "antenna.radiowaves.left.and.right", title: "Bluetooth Control", description: "Connect and control your Decent machine wirelessly")

                        FeatureItem(icon: "waveform.path.ecg", title: "Real-time Monitoring", description: "Live pressure, flow, and temperature graphs")

                        FeatureItem(icon: "list.bullet.rectangle", title: "Professional Profiles", description: "Espresso profiles for every style and taste")

                        FeatureItem(icon: "leaf.fill", title: "Tea Profiles", description: "Pulse-brewing tea profiles for perfect extraction")

                        FeatureItem(icon: "chart.line.uptrend.xyaxis", title: "Shot History", description: "Track and analyze your brewing history")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Credits
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Credits")
                            .font(.headline)

                        Text("Built with SwiftUI and CoreBluetooth")
                            .font(.body)
                            .foregroundStyle(.secondary)

                        Text("Decent Protocol implementation based on official documentation")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct FeatureItem: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.orange)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(MachineStore())
        .environmentObject(BluetoothService())
}
