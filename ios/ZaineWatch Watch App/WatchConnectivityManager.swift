//
//  WatchConnectivityManager.swift
//  ZaineWatch Watch App
//

import Foundation
import WatchConnectivity
import WatchKit
import Combine

class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchConnectivityManager()

    @Published var isReachable = false
    @Published var activationState = "未激活"
    @Published var lastAction = "无"
    @Published var lastError = ""
    @Published var lastActionTime: Date?
    @Published var healthData: [String: Any] = [:]
    @Published var lastCheckIn: String?

    private override init() {
        super.init()
        print("[Watch] WatchConnectivityManager init")
        if WCSession.isSupported() {
            print("[Watch] WCSession 支持，开始激活...")
            let session = WCSession.default
            session.delegate = self
            session.activate()
            activationState = "激活中..."
        } else {
            print("[Watch] ❌ WCSession 不支持！")
            activationState = "不支持"
        }
    }

    // MARK: - Send Check-in
    func sendCheckIn() {
        print("[Watch] 📨 用户点击签到")
        lastAction = "签到"
        lastActionTime = Date()
        lastError = ""
        
        // 触觉反馈
        WKInterfaceDevice.current().play(.click)
        
        let message = ["action": "checkin", "timestamp": Date().timeIntervalSince1970] as [String : Any]
        
        print("[Watch] WCSession 状态: isReachable=\(WCSession.default.isReachable), activationState=\(WCSession.default.activationState.rawValue)")
        
        if WCSession.default.activationState != .activated {
            lastError = "WCSession 未激活"
            print("[Watch] ❌ WCSession 未激活，无法发送")
            WKInterfaceDevice.current().play(.failure)
            return
        }
        
        if WCSession.default.isReachable {
            print("[Watch] 📡 手机可达，发送 sendMessage...")
            lastAction = "签到 (sendMessage)"
            WCSession.default.sendMessage(message, replyHandler: { reply in
                print("[Watch] ✅ sendMessage 成功: \(reply)")
                DispatchQueue.main.async {
                    self.lastAction = "签到 ✅"
                    self.lastError = ""
                }
                WKInterfaceDevice.current().play(.success)
            }, errorHandler: { error in
                print("[Watch] ❌ sendMessage 失败: \(error.localizedDescription)，自动转 transferUserInfo 兜底...")
                // 【v1.93.4 修复】sendMessage 失败时立即用 transferUserInfo 兜底重发
                // 解决：isReachable=true 但实际发送时连接断开导致消息丢失
                WCSession.default.transferUserInfo(message)
                DispatchQueue.main.async {
                    self.lastAction = "签到 📤 已发送(兜底)"
                    self.lastError = "实时发送失败，已转后台队列"
                }
                WKInterfaceDevice.current().play(.click)
            })
        } else {
            print("[Watch] ⚠️ 手机不可达，用 transferUserInfo 兜底")
            lastAction = "签到 (transferUserInfo)"
            let userInfo = WCSession.default.transferUserInfo(message)
            print("[Watch] transferUserInfo 已排队: \(userInfo.isTransferring ? "传输中" : "等待中")")
            DispatchQueue.main.async {
                self.lastAction = "签到 📤 已发送"
                self.lastError = "等待 iPhone 接收..."
            }
            WKInterfaceDevice.current().play(.click)
        }
    }

    // MARK: - Send SOS
    func sendSOS() {
        print("[Watch] 🚨 用户点击 SOS")
        lastAction = "SOS"
        lastActionTime = Date()
        lastError = ""
        
        // 强触觉反馈
        WKInterfaceDevice.current().play(.notification)
        
        let message = ["action": "sos", "timestamp": Date().timeIntervalSince1970] as [String : Any]
        
        if WCSession.default.activationState != .activated {
            lastError = "WCSession 未激活"
            print("[Watch] ❌ WCSession 未激活，无法发送 SOS")
            WKInterfaceDevice.current().play(.failure)
            return
        }
        
        if WCSession.default.isReachable {
            print("[Watch] 📡 手机可达，发送 SOS sendMessage...")
            WCSession.default.sendMessage(message, replyHandler: { reply in
                print("[Watch] ✅ SOS sendMessage 成功")
                DispatchQueue.main.async {
                    self.lastAction = "SOS ✅ 已发送"
                }
                WKInterfaceDevice.current().play(.success)
            }, errorHandler: { error in
                print("[Watch] ❌ SOS sendMessage 失败: \(error.localizedDescription)，自动转 transferUserInfo 兜底...")
                // 【v1.93.4 修复】SOS 绝不能丢 — sendMessage 失败时立即用 transferUserInfo 兜底重发
                WCSession.default.transferUserInfo(message)
                DispatchQueue.main.async {
                    self.lastAction = "SOS 📤 已发送(兜底)"
                    self.lastError = "实时发送失败，已转后台队列"
                }
                WKInterfaceDevice.current().play(.notification)
            })
        } else {
            print("[Watch] ⚠️ 手机不可达，SOS 用 transferUserInfo")
            WCSession.default.transferUserInfo(message)
            DispatchQueue.main.async {
                self.lastAction = "SOS 📤 已发送"
                self.lastError = "等待 iPhone 接收..."
            }
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

    // MARK: - WCSessionDelegate
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            switch activationState {
            case .activated:
                self.activationState = "✅ 已激活"
                print("[Watch] ✅ WCSession 激活成功, isReachable=\(session.isReachable)")
            case .inactive:
                self.activationState = "⚠️ 未激活"
                print("[Watch] ⚠️ WCSession 未激活")
            case .notActivated:
                self.activationState = "❌ 失败"
                print("[Watch] ❌ WCSession 激活失败")
            @unknown default:
                self.activationState = "❓ 未知"
            }
            if let error = error {
                self.lastError = "激活错误: \(error.localizedDescription)"
                print("[Watch] ❌ 激活错误: \(error.localizedDescription)")
            }
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            print("[Watch] 📡 可达性变化: isReachable=\(session.isReachable)")
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any]) {
        DispatchQueue.main.async {
            print("[Watch] 📥 收到来自 iPhone 的数据: \(userInfo)")
            if let health = userInfo["health_data"] as? [String: Any] {
                self.healthData = health
            }
            if let checkIn = userInfo["last_check_in"] as? String {
                self.lastCheckIn = checkIn
            }
        }
    }
    
    // iOS 端回调用
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        print("[Watch] 📥 收到来自 iPhone 的消息: \(message)")
        replyHandler(["received": true])
    }
}
