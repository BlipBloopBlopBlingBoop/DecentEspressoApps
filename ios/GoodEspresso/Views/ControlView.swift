//
//  ControlView.swift
//  Good Espresso
//
//  Real-time machine control with live monitoring
//

import SwiftUI

struct ControlView: View {
    @EnvironmentObject var machineStore: MachineStore
    @EnvironmentObject var bluetoothService: BluetoothService
    @State private var showingProfileSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if !machineStore.isConnected {
                        NotConnectedBanner()
                    } else {
                        // Live Status Display
                        LiveStatusDisplay()

                        // Main Control Buttons
                        MainControlButtons()

                        // Active Profile Section
                        ActiveProfileSection(showingProfileSheet: $showingProfileSheet)

                        // Live Extraction Chart
                        if machineStore.machineState.state == .brewing {
                            LiveExtractionSection()
                        }

                        // Temperature Gauge
                        TemperatureGaugeSection()
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Control")
            .sheet(isPresented: $showingProfileSheet) {
                ProfilesView()
            }
        }
    }
}

// MARK: - Not Connected Banner
struct NotConnectedBanner: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 50))
                .foregroundStyle(.gray)

            Text("Not Connected")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Connect to your Decent machine to access controls")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Live Status Display
struct LiveStatusDisplay: View {
    @EnvironmentObject var machineStore: MachineStore

    var body: some View {
        VStack(spacing: 16) {
            // State badge
            HStack {
                StatusBadge(state: machineStore.machineState.state)
                Spacer()

                if machineStore.isRecording {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.red)
                            .frame(width: 8, height: 8)
                        Text("REC")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.red)
                    }
                }
            }

            // Large readouts
            HStack(spacing: 20) {
                LiveReadout(
                    value: machineStore.machineState.pressure,
                    unit: "bar",
                    icon: "gauge.with.needle",
                    color: .blue,
                    maxValue: 12
                )

                LiveReadout(
                    value: machineStore.machineState.flow,
                    unit: "ml/s",
                    icon: "drop.fill",
                    color: .cyan,
                    maxValue: 8
                )

                LiveReadout(
                    value: machineStore.machineState.temperature.head,
                    unit: "\u{00B0}C",
                    icon: "thermometer.medium",
                    color: .orange,
                    maxValue: 100
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct LiveReadout: View {
    let value: Double
    let unit: String
    let icon: String
    let color: Color
    let maxValue: Double

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 6)

                Circle()
                    .trim(from: 0, to: min(value / maxValue, 1.0))
                    .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    Image(systemName: icon)
                        .font(.caption)
                        .foregroundStyle(color)

                    Text(String(format: "%.1f", value))
                        .font(.headline)
                        .monospacedDigit()
                }
            }
            .frame(width: 70, height: 70)

            Text(unit)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Main Control Buttons
struct MainControlButtons: View {
    @EnvironmentObject var machineStore: MachineStore
    @EnvironmentObject var bluetoothService: BluetoothService

    var isBrewing: Bool {
        machineStore.machineState.state == .brewing
    }

    var body: some View {
        VStack(spacing: 16) {
            // Main Espresso Button
            Button {
                Task {
                    do {
                        if isBrewing {
                            try await bluetoothService.stop()
                        } else {
                            try await bluetoothService.startEspresso()
                        }
                    } catch {
                        print("Error: \(error)")
                    }
                }
            } label: {
                HStack {
                    Image(systemName: isBrewing ? "stop.fill" : "play.fill")
                        .font(.title2)

                    Text(isBrewing ? "Stop" : "Start Espresso")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
            .buttonStyle(.borderedProminent)
            .tint(isBrewing ? .red : .orange)

            // Secondary Controls
            HStack(spacing: 12) {
                SecondaryControlButton(
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

                SecondaryControlButton(
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

                SecondaryControlButton(
                    title: "Water",
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
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct SecondaryControlButton: View {
    let title: String
    let icon: String
    let color: Color
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isActive ? color : Color(.tertiarySystemGroupedBackground))
            .foregroundStyle(isActive ? .white : color)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Active Profile Section
struct ActiveProfileSection: View {
    @EnvironmentObject var machineStore: MachineStore
    @Binding var showingProfileSheet: Bool

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Active Profile")
                    .font(.headline)

                Spacer()

                Button("Change") {
                    showingProfileSheet = true
                }
                .font(.subheadline)
            }

            if let recipe = machineStore.activeRecipe {
                HStack(spacing: 12) {
                    Image(systemName: recipe.id.contains("tea") ? "leaf.fill" : "cup.and.saucer.fill")
                        .font(.title2)
                        .foregroundStyle(recipe.id.contains("tea") ? .green : .orange)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(recipe.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Text("\(recipe.steps.count) steps \u{2022} \(Int(recipe.targetWeight))g")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding()
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Button {
                    showingProfileSheet = true
                } label: {
                    Label("Select a Profile", systemImage: "plus.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Live Extraction Section
struct LiveExtractionSection: View {
    @EnvironmentObject var machineStore: MachineStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Live Extraction")
                    .font(.headline)

                Spacer()

                if let shot = machineStore.activeShot {
                    let elapsed = Date().timeIntervalSince(shot.startTime)
                    Text(String(format: "%.1fs", elapsed))
                        .font(.headline)
                        .monospacedDigit()
                        .foregroundStyle(.orange)
                }
            }

            if let shot = machineStore.activeShot {
                ShotChartView(dataPoints: shot.dataPoints, isLive: true)
                    .frame(height: 180)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Temperature Gauge Section
struct TemperatureGaugeSection: View {
    @EnvironmentObject var machineStore: MachineStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Temperatures")
                .font(.headline)

            HStack(spacing: 20) {
                TemperatureItem(
                    label: "Head",
                    value: machineStore.machineState.temperature.head,
                    target: machineStore.machineState.temperature.target
                )

                TemperatureItem(
                    label: "Mix",
                    value: machineStore.machineState.temperature.mix,
                    target: machineStore.machineState.temperature.target
                )

                TemperatureItem(
                    label: "Steam",
                    value: machineStore.machineState.temperature.steam,
                    target: 140
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct TemperatureItem: View {
    let label: String
    let value: Double
    let target: Double

    var progress: Double {
        guard target > 0 else { return 0 }
        return min(value / target, 1.0)
    }

    var isReady: Bool {
        value >= target * 0.95
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.orange.opacity(0.2), lineWidth: 4)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        isReady ? Color.green : Color.orange,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                Text(String(format: "%.0f\u{00B0}", value))
                    .font(.callout)
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }
            .frame(width: 60, height: 60)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ControlView()
        .environmentObject(MachineStore())
        .environmentObject(BluetoothService())
}
