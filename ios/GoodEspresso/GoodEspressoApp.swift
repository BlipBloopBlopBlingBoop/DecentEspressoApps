//
//  GoodEspressoApp.swift
//  Good Espresso - Decent Espresso Machine Controller
//
//  A complete iOS application for controlling Decent espresso machines
//  via Bluetooth LE. Features real-time monitoring, profile management,
//  shot history, and advanced brewing controls.
//
//  Copyright (c) 2025 Good Espresso Contributors
//  Licensed under the MIT License
//

import SwiftUI

@main
struct GoodEspressoApp: App {
    @StateObject private var machineStore = MachineStore()
    @StateObject private var bluetoothService = BluetoothService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(machineStore)
                .environmentObject(bluetoothService)
                .preferredColorScheme(.dark)
                .onAppear {
                    // Set up the connection between bluetooth service and machine store
                    bluetoothService.machineStore = machineStore
                }
        }
    }
}
