//
//  WatchContentView.swift
//  Good Espresso Watch
//
//  Main content view for Apple Watch
//

import SwiftUI

struct WatchContentView: View {
    @EnvironmentObject var machineStore: WatchMachineStore
    @EnvironmentObject var connectivityService: WatchConnectivityService

    var body: some View {
        NavigationStack {
            TabView {
                // Status Tab
                WatchStatusView()

                // Controls Tab
                WatchControlsView()

                // Quick Actions Tab
                WatchQuickActionsView()
            }
            .tabViewStyle(.verticalPage)
            .navigationTitle("Espresso")
            .onAppear {
                connectivityService.requestStatus()
            }
            .onChange(of: connectivityService.lastMessage) { _, newMessage in
                machineStore.updateFromMessage(newMessage)
            }
        }
    }
}

// MARK: - Status View
struct WatchStatusView: View {
    @EnvironmentObject var machineStore: WatchMachineStore

    var body: some View {
        VStack(spacing: 8) {
            // Connection Status
            HStack {
                Image(systemName: machineStore.machineState.icon)
                    .foregroundStyle(machineStore.machineState.color)
                Text(machineStore.machineState.rawValue)
                    .font(.headline)
            }

            // Temperature
            HStack {
                Image(systemName: "thermometer")
                    .foregroundStyle(.orange)
                Text("\(machineStore.temperature, specifier: "%.1f")\u{00B0}C")
                    .font(.title2)
                    .fontWeight(.semibold)
            }

            // If brewing, show shot stats
            if machineStore.machineState == .brewing {
                Divider()

                HStack(spacing: 16) {
                    VStack {
                        Text("\(machineStore.pressure, specifier: "%.1f")")
                            .font(.title3)
                            .fontWeight(.bold)
                        Text("bar")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    VStack {
                        Text("\(machineStore.shotTime, specifier: "%.0f")")
                            .font(.title3)
                            .fontWeight(.bold)
                        Text("sec")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    VStack {
                        Text("\(machineStore.weight, specifier: "%.1f")")
                            .font(.title3)
                            .fontWeight(.bold)
                        Text("g")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Active Profile
            Text(machineStore.activeProfileName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding()
    }
}

// MARK: - Controls View
struct WatchControlsView: View {
    @EnvironmentObject var machineStore: WatchMachineStore
    @EnvironmentObject var connectivityService: WatchConnectivityService

    var body: some View {
        VStack(spacing: 12) {
            // Main Espresso Button
            Button {
                if machineStore.machineState == .brewing {
                    connectivityService.stopShot()
                } else {
                    connectivityService.startEspresso()
                }
            } label: {
                VStack {
                    Image(systemName: machineStore.machineState == .brewing ? "stop.fill" : "cup.and.saucer.fill")
                        .font(.title2)
                    Text(machineStore.machineState == .brewing ? "Stop" : "Espresso")
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(machineStore.machineState == .brewing ? .red : .orange)

            HStack(spacing: 8) {
                // Steam Button
                Button {
                    connectivityService.startSteam()
                } label: {
                    VStack {
                        Image(systemName: "cloud")
                        Text("Steam")
                            .font(.caption2)
                    }
                }
                .buttonStyle(.bordered)

                // Flush Button
                Button {
                    connectivityService.startFlush()
                } label: {
                    VStack {
                        Image(systemName: "drop.fill")
                        Text("Flush")
                            .font(.caption2)
                    }
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
    }
}

// MARK: - Quick Actions View
struct WatchQuickActionsView: View {
    @EnvironmentObject var connectivityService: WatchConnectivityService

    var body: some View {
        List {
            Button {
                connectivityService.sendCommand("wake")
            } label: {
                Label("Wake Machine", systemImage: "sunrise")
            }

            Button {
                connectivityService.sendCommand("sleep")
            } label: {
                Label("Sleep", systemImage: "moon.zzz")
            }

            Button {
                connectivityService.sendCommand("hotWater")
            } label: {
                Label("Hot Water", systemImage: "mug")
            }

            Button {
                connectivityService.requestStatus()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
        }
    }
}

#Preview {
    WatchContentView()
        .environmentObject(WatchMachineStore())
        .environmentObject(WatchConnectivityService())
}
