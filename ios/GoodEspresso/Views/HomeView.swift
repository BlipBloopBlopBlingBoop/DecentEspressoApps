//
//  HomeView.swift
//  Good Espresso
//
//  Main dashboard showing machine status and quick controls
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var machineStore: MachineStore
    @EnvironmentObject var bluetoothService: BluetoothService
    @State private var showingConnectionSheet = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var isCompact: Bool {
        horizontalSizeClass == .compact
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if machineStore.isConnected {
                    if isCompact {
                        // iPhone layout - vertical stack
                        compactLayout
                    } else {
                        // iPad layout - two column grid
                        regularLayout
                    }
                } else {
                    VStack(spacing: 20) {
                        ConnectionStatusCard(showingConnectionSheet: $showingConnectionSheet)
                        NotConnectedCard()
                    }
                    .padding()
                }
            }
            .background(Color.systemGroupedBg)
            .navigationTitle("Good Espresso")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingConnectionSheet = true
                    } label: {
                        Image(systemName: machineStore.isConnected ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                            .foregroundStyle(machineStore.isConnected ? .green : .gray)
                    }
                }
            }
            .sheet(isPresented: $showingConnectionSheet) {
                ConnectionView()
            }
        }
    }

    // MARK: - Compact Layout (iPhone)
    var compactLayout: some View {
        VStack(spacing: 20) {
            ConnectionStatusCard(showingConnectionSheet: $showingConnectionSheet)
            MachineStatusCard()
            QuickControlsCard()
            ActiveProfileCard()
            ShotChartCard()
        }
        .padding()
    }

    // MARK: - Regular Layout (iPad)
    var regularLayout: some View {
        VStack(spacing: 20) {
            // Top row: Connection + Status
            HStack(alignment: .top, spacing: 20) {
                ConnectionStatusCard(showingConnectionSheet: $showingConnectionSheet)
                    .frame(maxWidth: .infinity)
                MachineStatusCard()
                    .frame(maxWidth: .infinity)
            }

            // Main content: Chart + Controls side by side
            HStack(alignment: .top, spacing: 20) {
                // Left column: Chart (larger)
                VStack(spacing: 20) {
                    ShotChartCard()
                    ActiveProfileCard()
                }
                .frame(maxWidth: .infinity)

                // Right column: Controls
                VStack(spacing: 20) {
                    QuickControlsCard()
                    // Extra space for additional controls on iPad
                    iPadExtendedControlsCard()
                }
                .frame(width: 320)
            }
        }
        .padding()
    }
}

// MARK: - iPad Extended Controls
struct iPadExtendedControlsCard: View {
    @EnvironmentObject var machineStore: MachineStore
    @EnvironmentObject var bluetoothService: BluetoothService

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Machine")
                    .font(.headline)
                Spacer()
            }

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                iPadControlButton(title: "Sleep", icon: "moon.zzz", color: .purple) {
                    Task { try? await bluetoothService.sendCommand(.goToSleep) }
                }

                iPadControlButton(title: "Wake", icon: "sunrise", color: .orange) {
                    Task { try? await bluetoothService.sendCommand(.idle) }
                }

                iPadControlButton(title: "Clean", icon: "sparkles", color: .blue) {
                    Task { try? await bluetoothService.sendCommand(.clean) }
                }

                iPadControlButton(title: "Descale", icon: "drop.triangle", color: .cyan) {
                    Task { try? await bluetoothService.sendCommand(.descale) }
                }
            }
        }
        .padding()
        .background(Color.secondarySystemGroupedBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    func iPadControlButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.tertiarySystemGroupedBg)
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

// MARK: - Connection Status Card
struct ConnectionStatusCard: View {
    @EnvironmentObject var machineStore: MachineStore
    @Binding var showingConnectionSheet: Bool

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Circle()
                    .fill(machineStore.isConnected ? .green : .red)
                    .frame(width: 12, height: 12)

                Text(machineStore.isConnected ? "Connected" : "Disconnected")
                    .font(.headline)

                Spacer()

                if let name = machineStore.deviceName {
                    Text(name)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if !machineStore.isConnected {
                Button {
                    showingConnectionSheet = true
                } label: {
                    Label("Connect to Machine", systemImage: "link")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }

            if let error = machineStore.connectionError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .background(Color.secondarySystemGroupedBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Machine Status Card
struct MachineStatusCard: View {
    @EnvironmentObject var machineStore: MachineStore

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Machine Status")
                    .font(.headline)
                Spacer()
                StatusBadge(state: machineStore.machineState.state)
            }

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                StatusItem(
                    icon: "thermometer.medium",
                    value: machineStore.formatTemperature(machineStore.machineState.temperature.head),
                    label: "Head Temp"
                )

                StatusItem(
                    icon: "gauge.with.needle",
                    value: String(format: "%.1f bar", machineStore.machineState.pressure),
                    label: "Pressure"
                )

                StatusItem(
                    icon: "drop.fill",
                    value: String(format: "%.1f ml/s", machineStore.machineState.flow),
                    label: "Flow"
                )
            }
        }
        .padding()
        .background(Color.secondarySystemGroupedBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct StatusBadge: View {
    let state: MachineStateType

    var body: some View {
        Text(state.displayName)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .foregroundStyle(.white)
            .clipShape(Capsule())
    }

    var backgroundColor: Color {
        switch state {
        case .idle: return .gray
        case .sleep: return .purple
        case .warming: return .orange
        case .ready: return .green
        case .brewing: return .blue
        case .steam: return .red
        case .flush: return .cyan
        case .cleaning: return .yellow
        case .error: return .red
        case .disconnected: return .gray
        }
    }
}

struct StatusItem: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.orange)

            Text(value)
                .font(.headline)
                .monospacedDigit()

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Quick Controls Card
struct QuickControlsCard: View {
    @EnvironmentObject var machineStore: MachineStore
    @EnvironmentObject var bluetoothService: BluetoothService
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Quick Controls")
                    .font(.headline)
                Spacer()
            }

            HStack(spacing: 12) {
                ControlButton(
                    title: "Espresso",
                    icon: "cup.and.saucer.fill",
                    color: .orange,
                    isActive: machineStore.machineState.state == .brewing
                ) {
                    Task {
                        do {
                            if machineStore.machineState.state == .brewing {
                                try await bluetoothService.stop()
                            } else {
                                try await bluetoothService.startEspresso()
                            }
                        } catch {
                            print("Error: \(error)")
                        }
                    }
                }

                ControlButton(
                    title: "Steam",
                    icon: "cloud.fill",
                    color: .red,
                    isActive: machineStore.machineState.state == .steam
                ) {
                    Task {
                        do {
                            if machineStore.machineState.state == .steam {
                                try await bluetoothService.stop()
                            } else {
                                try await bluetoothService.startSteam()
                            }
                        } catch {
                            print("Error: \(error)")
                        }
                    }
                }

                ControlButton(
                    title: "Flush",
                    icon: "drop.fill",
                    color: .cyan,
                    isActive: machineStore.machineState.state == .flush
                ) {
                    Task {
                        do {
                            if machineStore.machineState.state == .flush {
                                try await bluetoothService.stop()
                            } else {
                                try await bluetoothService.startFlush()
                            }
                        } catch {
                            print("Error: \(error)")
                        }
                    }
                }

                ControlButton(
                    title: "Hot Water",
                    icon: "mug.fill",
                    color: .blue,
                    isActive: false
                ) {
                    Task {
                        do {
                            try await bluetoothService.startHotWater()
                        } catch {
                            print("Error: \(error)")
                        }
                    }
                }
            }

            // Stop button
            if machineStore.machineState.state == .brewing ||
               machineStore.machineState.state == .steam ||
               machineStore.machineState.state == .flush {
                Button {
                    Task {
                        try? await bluetoothService.stop()
                    }
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
        }
        .padding()
        .background(Color.secondarySystemGroupedBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct ControlButton: View {
    let title: String
    let icon: String
    let color: Color
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title)
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isActive ? color : Color.tertiarySystemGroupedBg)
            .foregroundStyle(isActive ? .white : color)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

// MARK: - Active Profile Card
struct ActiveProfileCard: View {
    @EnvironmentObject var machineStore: MachineStore

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Active Profile")
                    .font(.headline)
                Spacer()
                NavigationLink {
                    ProfilesView()
                } label: {
                    Text("Change")
                        .font(.subheadline)
                }
            }

            if let recipe = machineStore.activeRecipe {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(recipe.name)
                            .font(.title3)
                            .fontWeight(.semibold)

                        Text("\(recipe.steps.count) steps • Target: \(Int(recipe.targetWeight))g")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    NavigationLink {
                        ProfileDetailView(recipe: recipe)
                    } label: {
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(Color.tertiarySystemGroupedBg)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Text("No profile selected")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color.secondarySystemGroupedBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Shot Chart Card (Live or Last Shot)
struct ShotChartCard: View {
    @EnvironmentObject var machineStore: MachineStore

    var isLive: Bool {
        machineStore.machineState.state == .brewing || machineStore.isRecording
    }

    var dataPoints: [ShotDataPoint] {
        if let activeShot = machineStore.activeShot, !activeShot.dataPoints.isEmpty {
            return activeShot.dataPoints
        } else if let lastShot = machineStore.shotHistory.first, !lastShot.dataPoints.isEmpty {
            return lastShot.dataPoints
        }
        return []
    }

    var chartTitle: String {
        if isLive {
            return "Live Extraction"
        } else if machineStore.shotHistory.first != nil {
            return "Last Shot"
        }
        return "Extraction Chart"
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(chartTitle)
                    .font(.headline)

                Spacer()

                if isLive && machineStore.isRecording {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                    Text("Recording")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            if !dataPoints.isEmpty {
                ShotChartView(dataPoints: dataPoints, isLive: isLive)
                    .frame(height: 180)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No shot data yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Start an extraction to see the chart")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(height: 180)
            }
        }
        .padding()
        .background(Color.secondarySystemGroupedBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Not Connected Card
struct NotConnectedCard: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "cup.and.saucer")
                .font(.system(size: 60))
                .foregroundStyle(.orange)

            Text("Welcome to Good Espresso")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Connect to your Decent espresso machine to start brewing amazing coffee and tea.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 8) {
                FeatureRow(icon: "waveform.path.ecg", text: "Real-time extraction monitoring")
                FeatureRow(icon: "list.bullet.rectangle", text: "Professional brewing profiles")
                FeatureRow(icon: "leaf.fill", text: "Pulse-brew tea profiles")
                FeatureRow(icon: "chart.line.uptrend.xyaxis", text: "Shot history and analytics")
            }
            .padding(.top)
        }
        .padding(24)
        .background(Color.secondarySystemGroupedBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.orange)
                .frame(width: 24)

            Text(text)
                .font(.subheadline)
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(MachineStore())
        .environmentObject(BluetoothService())
}
