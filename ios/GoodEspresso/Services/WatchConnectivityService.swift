//
//  WatchConnectivityService.swift
//  Good Espresso
//
//  Handles communication with Apple Watch companion app
//

import Foundation
#if canImport(WatchConnectivity)
import WatchConnectivity

@MainActor
class iOSWatchConnectivityService: NSObject, ObservableObject {
    @Published var isWatchReachable = false

    private var session: WCSession?
    weak var machineStore: MachineStore?
    weak var bluetoothService: BluetoothService?

    override init() {
        super.init()

        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }

    func configure(machineStore: MachineStore, bluetoothService: BluetoothService) {
        self.machineStore = machineStore
        self.bluetoothService = bluetoothService
    }

    func sendStatusUpdate() {
        guard let session = session, session.isReachable,
              let machineStore = machineStore else { return }

        let context: [String: Any] = [
            "connected": machineStore.isConnected,
            "state": machineStore.machineState.state.displayName,
            "temperature": machineStore.machineState.temperature.mix,
            "pressure": machineStore.machineState.pressure,
            "flow": machineStore.machineState.flow,
            "weight": machineStore.machineState.weight,
            "activeProfile": machineStore.activeRecipe?.name ?? "None"
        ]

        do {
            try session.updateApplicationContext(context)
        } catch {
            print("Failed to update watch context: \(error)")
        }
    }

    private func handleCommand(_ command: String) {
        guard let bluetoothService = bluetoothService else { return }

        Task {
            do {
                switch command {
                case "espresso":
                    try await bluetoothService.startEspresso()
                case "stop":
                    try await bluetoothService.sendCommand(.idle)
                case "steam":
                    try await bluetoothService.startSteam()
                case "flush":
                    try await bluetoothService.startFlush()
                case "hotWater":
                    try await bluetoothService.startHotWater()
                case "wake":
                    try await bluetoothService.sendCommand(.idle)
                case "sleep":
                    try await bluetoothService.sendCommand(.goToSleep)
                case "status":
                    sendStatusUpdate()
                default:
                    print("Unknown watch command: \(command)")
                }
            } catch {
                print("Error executing watch command: \(error)")
            }
        }
    }
}

extension iOSWatchConnectivityService: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            self.isWatchReachable = session.isReachable
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isWatchReachable = session.isReachable
            if session.isReachable {
                self.sendStatusUpdate()
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        if let command = message["command"] as? String {
            Task { @MainActor in
                self.handleCommand(command)

                // Send current status as reply
                if let machineStore = self.machineStore {
                    let reply: [String: Any] = [
                        "connected": machineStore.isConnected,
                        "state": machineStore.machineState.state.displayName,
                        "temperature": machineStore.machineState.temperature.mix,
                        "pressure": machineStore.machineState.pressure,
                        "flow": machineStore.machineState.flow,
                        "weight": machineStore.machineState.weight,
                        "activeProfile": machineStore.activeRecipe?.name ?? "None"
                    ]
                    replyHandler(reply)
                } else {
                    replyHandler(["error": "Not configured"])
                }
            }
        }
    }
}
#endif
