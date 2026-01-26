//
//  ContentView.swift
//  Good Espresso
//
//  Main navigation container with tab bar
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var machineStore: MachineStore
    @EnvironmentObject var bluetoothService: BluetoothService
    @State private var selectedTab = 0
    @State private var showingLegal = false

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)

            ProfilesView()
                .tabItem {
                    Label("Profiles", systemImage: "list.bullet.rectangle.portrait.fill")
                }
                .tag(1)

            ControlView()
                .tabItem {
                    Label("Control", systemImage: "dial.medium.fill")
                }
                .tag(2)

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.fill")
                }
                .tag(3)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(4)
        }
        .tint(.orange)
        .onAppear {
            // Check if first launch to show legal disclaimer
            if !UserDefaults.standard.bool(forKey: "hasAcceptedLegal") {
                showingLegal = true
            }
        }
        .sheet(isPresented: $showingLegal) {
            LegalView(isPresented: $showingLegal)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(MachineStore())
        .environmentObject(BluetoothService())
}
