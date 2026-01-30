//
//  SettingsView.swift
//  Good Espresso
//
//  App settings and machine configuration
//

import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var machineStore: MachineStore
    @EnvironmentObject var bluetoothService: BluetoothService
    @EnvironmentObject var scaleService: ScaleService
    @State private var showingLegal = false
    @State private var showingAbout = false
    @State private var showingScaleSheet = false
    @State private var showingImportSheet = false
    @State private var importError: String?
    @State private var showingImportError = false

    var body: some View {
        NavigationStack {
            List {
                // Machine Connection Section
                Section("Espresso Machine") {
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

                // Scale Connection Section
                Section("BLE Scale") {
                    HStack {
                        Label("Scale Status", systemImage: "scalemass")
                        Spacer()
                        Text(machineStore.isScaleConnected ? "Connected" : "Disconnected")
                            .foregroundStyle(.secondary)
                    }

                    if let scaleName = machineStore.scaleName {
                        HStack {
                            Label("Scale", systemImage: "scalemass.fill")
                            Spacer()
                            Text(scaleName)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if machineStore.isScaleConnected {
                        HStack {
                            Label("Weight", systemImage: "number")
                            Spacer()
                            Text(String(format: "%.1f g", machineStore.scaleWeight))
                                .foregroundStyle(.secondary)
                        }

                        Button {
                            scaleService.tare()
                        } label: {
                            Label("Tare Scale", systemImage: "arrow.counterclockwise")
                        }

                        Button(role: .destructive) {
                            scaleService.disconnect()
                            machineStore.setScaleConnected(false)
                        } label: {
                            Label("Disconnect Scale", systemImage: "xmark.circle")
                        }
                    } else {
                        Button {
                            showingScaleSheet = true
                        } label: {
                            Label("Connect Scale", systemImage: "plus.circle")
                        }
                    }
                }

                // Scale Settings
                Section("Scale Settings") {
                    Toggle("Auto Tare on Start", isOn: $machineStore.autoTare)
                        .onChange(of: machineStore.autoTare) { _ in
                            machineStore.saveSettings()
                        }

                    Toggle("Auto Stop on Target Weight", isOn: $machineStore.autoStopOnWeight)
                        .onChange(of: machineStore.autoStopOnWeight) { _ in
                            machineStore.saveSettings()
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

                // Profiles Section
                Section("Profiles") {
                    HStack {
                        Label("Custom Profiles", systemImage: "square.stack.3d.up")
                        Spacer()
                        Text("\(machineStore.customRecipes.count)")
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        showingImportSheet = true
                    } label: {
                        Label("Import Profile", systemImage: "square.and.arrow.down")
                    }

                    if !machineStore.customRecipes.isEmpty {
                        Button(role: .destructive) {
                            machineStore.customRecipes.removeAll()
                            machineStore.saveCustomRecipes()
                            machineStore.loadRecipes()
                        } label: {
                            Label("Delete All Custom Profiles", systemImage: "trash")
                        }
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
            .sheet(isPresented: $showingScaleSheet) {
                ScaleConnectionSheet(scaleService: scaleService, machineStore: machineStore)
            }
            .fileImporter(
                isPresented: $showingImportSheet,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        // Access the file
                        if url.startAccessingSecurityScopedResource() {
                            defer { url.stopAccessingSecurityScopedResource() }

                            if machineStore.importAndSaveProfile(from: (try? Data(contentsOf: url)) ?? Data()) {
                                // Success - profile imported
                            } else {
                                importError = "Could not parse profile file. Make sure it's a valid JSON profile."
                                showingImportError = true
                            }
                        }
                    }
                case .failure(let error):
                    importError = error.localizedDescription
                    showingImportError = true
                }
            }
            .alert("Import Error", isPresented: $showingImportError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(importError ?? "Unknown error")
            }
        }
    }
}

// MARK: - Scale Connection Sheet

struct ScaleConnectionSheet: View {
    @ObservedObject var scaleService: ScaleService
    @ObservedObject var machineStore: MachineStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if scaleService.isScanning {
                    Section {
                        HStack {
                            ProgressView()
                                .padding(.trailing, 8)
                            Text("Scanning for scales...")
                        }
                    }
                }

                Section("Supported Scales") {
                    Text("• Bookoo (Ultra, Mini)")
                    Text("• Acaia (Lunar, Pearl, Pyxis)")
                    Text("• Felicita (Arc, Incline)")
                    Text("• Hiroia Jimmy")
                    Text("• Timemore Black Mirror")
                    Text("• Generic BLE scales")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if !scaleService.discoveredScales.isEmpty {
                    Section("Found Scales") {
                        ForEach(scaleService.discoveredScales, id: \.identifier) { scale in
                            Button {
                                scaleService.connect(to: scale)
                            } label: {
                                HStack {
                                    Image(systemName: "scalemass")
                                    Text(scale.name ?? "Unknown Scale")
                                    Spacer()
                                    if scaleService.connectedScale?.identifier == scale.identifier {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.green)
                                    }
                                }
                            }
                        }
                    }
                }

                if let error = scaleService.connectionError {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Connect Scale")
            .inlineNavigationBarTitle()
            .toolbar {
                ToolbarItem(placement: .topBarLeadingCompat) {
                    Button("Cancel") {
                        scaleService.stopScanning()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailingCompat) {
                    if scaleService.isConnected {
                        Button("Done") {
                            machineStore.setScaleConnected(true, name: scaleService.connectedScale?.name)
                            dismiss()
                        }
                    } else {
                        Button(scaleService.isScanning ? "Stop" : "Scan") {
                            if scaleService.isScanning {
                                scaleService.stopScanning()
                            } else {
                                scaleService.startScanning()
                            }
                        }
                    }
                }
            }
            .onAppear {
                scaleService.startScanning()
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
                    .background(Color.secondarySystemGroupedBg)
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
                    .background(Color.secondarySystemGroupedBg)
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
                    .background(Color.secondarySystemGroupedBg)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding()
            }
            .background(Color.systemGroupedBg)
            .navigationTitle("About")
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
