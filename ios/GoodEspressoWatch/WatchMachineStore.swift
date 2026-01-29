//
//  WatchMachineStore.swift
//  Good Espresso Watch
//
//  Simplified state store for Watch
//

import Foundation
import SwiftUI

@MainActor
class WatchMachineStore: ObservableObject {
    @Published var isConnected = false
    @Published var machineState: WatchMachineState = .disconnected
    @Published var temperature: Double = 0
    @Published var pressure: Double = 0
    @Published var flow: Double = 0
    @Published var shotTime: TimeInterval = 0
    @Published var weight: Double = 0
    @Published var activeProfileName: String = "Classic Italian"

    enum WatchMachineState: String {
        case disconnected = "Disconnected"
        case idle = "Idle"
        case warming = "Warming"
        case ready = "Ready"
        case brewing = "Brewing"
        case steam = "Steaming"
        case error = "Error"

        var color: Color {
            switch self {
            case .disconnected: return .gray
            case .idle: return .gray
            case .warming: return .orange
            case .ready: return .green
            case .brewing: return .blue
            case .steam: return .red
            case .error: return .red
            }
        }

        var icon: String {
            switch self {
            case .disconnected: return "wifi.slash"
            case .idle: return "moon.zzz"
            case .warming: return "flame"
            case .ready: return "checkmark.circle"
            case .brewing: return "cup.and.saucer.fill"
            case .steam: return "cloud"
            case .error: return "exclamationmark.triangle"
            }
        }
    }

    func updateFromMessage(_ message: [String: Any]) {
        if let connected = message["connected"] as? Bool {
            isConnected = connected
        }
        if let state = message["state"] as? String {
            machineState = WatchMachineState(rawValue: state) ?? .disconnected
        }
        if let temp = message["temperature"] as? Double {
            temperature = temp
        }
        if let press = message["pressure"] as? Double {
            pressure = press
        }
        if let fl = message["flow"] as? Double {
            flow = fl
        }
        if let time = message["shotTime"] as? Double {
            shotTime = time
        }
        if let w = message["weight"] as? Double {
            weight = w
        }
        if let profile = message["activeProfile"] as? String {
            activeProfileName = profile
        }
    }
}
