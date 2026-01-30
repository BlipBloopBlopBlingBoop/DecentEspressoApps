//
//  WatchConnectivityService.swift
//  Good Espresso Watch
//
//  Handles communication between Watch and iPhone
//

import Foundation
#if canImport(WatchConnectivity)
import WatchConnectivity

@MainActor
class WatchConnectivityService: NSObject, ObservableObject {
    @Published var isReachable = false
    @Published var lastMessage: [String: Any] = [:]

    private var session: WCSession?

    override init() {
        super.init()

        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }

    func sendCommand(_ command: String) {
        guard let session = session, session.isReachable else {
            print("iPhone not reachable")
            return
        }

        session.sendMessage(
            ["command": command],
            replyHandler: { reply in
                Task { @MainActor in
                    self.lastMessage = reply
                }
            },
            errorHandler: { error in
                print("Error sending message: \(error)")
            }
        )
    }

    func requestStatus() {
        sendCommand("status")
    }

    func startEspresso() {
        sendCommand("espresso")
    }

    func stopShot() {
        sendCommand("stop")
    }

    func startSteam() {
        sendCommand("steam")
    }

    func startFlush() {
        sendCommand("flush")
    }
}

extension WatchConnectivityService: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            self.isReachable = session.isReachable
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isReachable = session.isReachable
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        Task { @MainActor in
            self.lastMessage = message
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        Task { @MainActor in
            self.lastMessage = applicationContext
        }
    }
}
#endif
