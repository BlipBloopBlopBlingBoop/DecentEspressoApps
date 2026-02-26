//
//  ContentView.swift
//  Good Espresso
//
//  Main navigation container with adaptive layout:
//  - iPhone: Tab bar navigation
//  - iPad/macOS: Sidebar navigation via NavigationSplitView
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var machineStore: MachineStore
    @EnvironmentObject var bluetoothService: BluetoothService
    @State private var selectedTab: NavigationTab? = .home
    @State private var showingLegal = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                compactNavigation
            } else {
                regularNavigation
            }
        }
        .tint(.orange)
        .onAppear {
            if !UserDefaults.standard.bool(forKey: "hasAcceptedLegal") {
                showingLegal = true
            }
        }
        .sheet(isPresented: $showingLegal) {
            LegalView(isPresented: $showingLegal)
        }
    }

    // MARK: - iPhone: Tab Bar

    private var tabBinding: Binding<NavigationTab> {
        Binding(
            get: { selectedTab ?? .home },
            set: { selectedTab = $0 }
        )
    }

    var compactNavigation: some View {
        TabView(selection: tabBinding) {
            ForEach(NavigationTab.allCases) { tab in
                tabDestination(for: tab)
                    .tabItem {
                        Label(tab.label, systemImage: tab.systemImage)
                    }
                    .tag(tab)
            }
        }
    }

    // MARK: - iPad / macOS: Sidebar

    var regularNavigation: some View {
        NavigationSplitView {
            List(selection: $selectedTab) {
                ForEach(NavigationTab.allCases) { tab in
                    Label(tab.label, systemImage: tab.systemImage)
                        .tag(tab)
                }
            }
            .navigationTitle("Good Espresso")
            .listStyle(.sidebar)
        } detail: {
            tabDestination(for: selectedTab ?? .home)
        }
        .frame(minWidth: 600, minHeight: 400)
    }

    // MARK: - Tab Destination

    @ViewBuilder
    func tabDestination(for tab: NavigationTab) -> some View {
        switch tab {
        case .home:
            HomeView()
        case .profiles:
            ProfilesView()
        case .control:
            ControlView()
        case .history:
            HistoryView()
        case .analytics:
            AnalyticsView()
        case .puckSim:
            PuckSimulationView()
        case .settings:
            SettingsView()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(MachineStore())
        .environmentObject(BluetoothService())
}
