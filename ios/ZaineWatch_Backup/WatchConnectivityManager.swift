//
//  WatchConnectivityManager.swift
//  ZaineWatch Watch App
//

import Foundation
import WatchConnectivity

class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchConnectivityManager()

    @Published var isReachable = false
    @Published var healthData: [String: Any] = [:]
    @Published var lastCheckIn: String?

    private override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }

    // MARK: - Send Check-in
    func sendCheckIn() {
        guard WCSession.default.isReachable else { return }
        let message = ["action": "checkin", "timestamp": Date().timeIntervalSince1970] as [String : Any]
        WCSession.default.sendMessage(message, replyHandler: nil) { error in
            print("Watch: send check-in failed - \(error.localizedDescription)")
        }
    }

    // MARK: - Send SOS
    func sendSOS() {
        guard WCSession.default.isReachable else { return }
        let message = ["action": "sos", "timestamp": Date().timeIntervalSince1970] as [String : Any]
        WCSession.default.sendMessage(message, replyHandler: nil) { error in
            print("Watch: send SOS failed - \(error.localizedDescription)")
        }
    }

    // MARK: - Request Health Data
    func requestHealthData() {
        guard WCSession.default.isReachable else { return }
        let message = ["action": "request_health_data"]
        WCSession.default.sendMessage(message, replyHandler: nil) { error in
            print("Watch: request health data failed - \(error.localizedDescription)")
        }
    }

    // MARK: - WCSessionDelegate (watchOS compatible)
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any]) {
        DispatchQueue.main.async {
            if let health = userInfo["health_data"] as? [String: Any] {
                self.healthData = health
            }
            if let checkIn = userInfo["last_check_in"] as? String {
                self.lastCheckIn = checkIn
            }
        }
    }
}
