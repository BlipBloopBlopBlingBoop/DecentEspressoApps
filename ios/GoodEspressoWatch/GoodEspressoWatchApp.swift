//
//  GoodEspressoWatchApp.swift
//  Good Espresso Watch
//
//  Companion app for Apple Watch
//

import SwiftUI

@main
struct GoodEspressoWatchApp: App {
    @StateObject private var machineStore = WatchMachineStore()
    @StateObject private var connectivityService = WatchConnectivityService()

    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .environmentObject(machineStore)
                .environmentObject(connectivityService)
        }
    }
}
