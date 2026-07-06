//
//  WatchConnectivityManager.swift
//  ZaineWatch Watch App
//

import Foundation
import WatchConnectivity
import WatchKit
import Combine
import HealthKit

class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchConnectivityManager()

    @Published var isReachable = false
    @Published var activationState = "未激活"
    @Published var lastAction = "无"
    @Published var lastError = ""
    @Published var lastActionTime: Date?
    @Published var healthData: [String: Any] = [:]
    @Published var lastCheckIn: String?

    // 【v1.94.0】签到结果状态（用于酷炫庆祝 UI）
    @Published var checkInSuccess = false
    @Published var checkInFailed = false
    @Published var checkInStreak = 0
    @Published var checkInTotal = 0
    @Published var checkInAlreadyDone = false
    @Published var autoCheckInSuccess = false   // 【P0 心跳自动签到】独立庆祝态
    @Published var isHeartbeatGuardian = false  // 【P0 心跳守护中】状态指示
    @Published var lastHeartRate: Double = 0
    private var pendingClientId: String?

    // 【P0】HealthKit 心率监控
    private let healthStore = HKHealthStore()
    private var heartRateQuery: HKAnchoredObjectQuery?

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
    /// 【v1.94.0 重写】以 transferUserInfo 为主路径（可靠队列，不依赖可达性，后台也能投递）
    /// sendMessage 仅作为「加速」：手机可达时即时拿到回包，失败不影响（transferUserInfo 已兜底）
    func sendCheckIn() {
        print("[Watch] 📨 用户点击签到")
        lastActionTime = Date()
        lastError = ""
        checkInSuccess = false
        checkInFailed = false
        checkInAlreadyDone = false

        // 触觉反馈
        WKInterfaceDevice.current().play(.click)

        let clientId = UUID().uuidString
        pendingClientId = clientId
        let message: [String: Any] = [
            "action": "checkin",
            "client_id": clientId,
            "timestamp": Date().timeIntervalSince1970,
        ]

        if WCSession.default.activationState != .activated {
            lastError = "WCSession 未激活"
            checkInFailed = true
            print("[Watch] ❌ WCSession 未激活，无法发送")
            WKInterfaceDevice.current().play(.failure)
            return
        }

        // 主路径：可靠队列（一定会被 iPhone 接收并处理）
        WCSession.default.transferUserInfo(message)
        print("[Watch] 📤 transferUserInfo 已排队签到 (clientId=\(clientId))")

        // 乐观 UI：立即进入「签到中」状态
        lastAction = "签到中..."

        // 加速路径：手机可达时尝试 sendMessage 即时确认（失败不影响主路径）
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: { _ in
                print("[Watch] ✅ sendMessage 即时回包成功")
            }, errorHandler: { error in
                print("[Watch] ℹ️ sendMessage 即时回包失败(已走 transferUserInfo 兜底，无影响): \(error.localizedDescription)")
            })
        }

        // 兜底：1.4s 内未收到 ack 则先显示「已发送」，避免一直转圈
        let capturedClientId = clientId
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self] in
            guard let self = self else { return }
            if !self.checkInSuccess && self.pendingClientId == capturedClientId {
                self.lastAction = "签到已发送 ⏳"
            }
        }
    }

    // MARK: - Send SOS
    /// 【v1.94.0 重写】同样以 transferUserInfo 为主路径
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

        // 主路径：可靠队列（SOS 绝不能丢）
        WCSession.default.transferUserInfo(message)
        print("[Watch] 📤 SOS transferUserInfo 已排队")
        lastAction = "SOS 已发送 📤"

        // 加速路径
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: { _ in
                print("[Watch] ✅ SOS sendMessage 成功")
            }, errorHandler: { error in
                print("[Watch] ℹ️ SOS sendMessage 失败(已走 transferUserInfo 兜底): \(error.localizedDescription)")
            })
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

    // MARK: - 【P0】自动心跳签到（核心酷炫功能）
    /// 由 ContentView.onAppear 调用，启动 HealthKit 心率监控
    /// 检测到有效心率后自动触发签到，用户零操作
    func startHeartRateMonitoring() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("[Watch] ⚠️ HealthKit 不可用，无法启用心跳守护")
            return
        }
        let hrType = HKObjectType.quantityType(forIdentifier: .heartRate)!
        healthStore.requestAuthorization(toShare: nil, read: [hrType]) { [weak self] success, error in
            guard let self = self else { return }
            if !success {
                print("[Watch] ⚠️ 心率授权失败: \(error?.localizedDescription ?? "unknown")")
                return
            }
            DispatchQueue.main.async { self.isHeartbeatGuardian = true }
            self.startHeartRateQuery()
        }
    }

    private func startHeartRateQuery() {
        let hrType = HKObjectType.quantityType(forIdentifier: .heartRate)!
        let query = HKAnchoredObjectQuery(
            type: hrType,
            predicate: nil,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, _ in
            self?.processHeartRateSamples(samples)
        }
        query.updateHandler = { [weak self] _, samples, _, _, _ in
            self?.processHeartRateSamples(samples)
        }
        healthStore.execute(query)
        heartRateQuery = query
        print("[Watch] 💓 心率守护监听已启动")
    }

    private func processHeartRateSamples(_ samples: [HKSample]?) {
        guard let samples = samples as? [HKQuantitySample], !samples.isEmpty else { return }
        let today = Calendar.current.component(.day, from: Date())
        let lastDay = UserDefaults.standard.integer(forKey: "watch_last_auto_checkin_day")

        // 更新实时心率显示 + 守护状态
        if let latest = samples.last {
            let hr = latest.quantity.doubleValue(for: HKUnit(from: "count/min"))
            DispatchQueue.main.async {
                self.lastHeartRate = hr
                self.isHeartbeatGuardian = true
            }
        }

        // 今天已自动签过 → 只更新心率，不再触发
        if lastDay == today { return }

        // 检测有效心率（48-130bpm，排除噪声/异常）
        for sample in samples.reversed() {
            let hr = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
            if hr >= 48 && hr <= 130 {
                DispatchQueue.main.async { self.sendAutoCheckIn(heartRate: hr) }
                break
            }
        }
    }

    /// 自动心跳签到：WCSession 不可达时排队 transferUserInfo（后台也能投递）
    func sendAutoCheckIn(heartRate: Double) {
        print("[Watch] 💓 检测到有效心率 \(Int(heartRate)) bpm，触发自动签到")
        let today = Calendar.current.component(.day, from: Date())
        let lastDay = UserDefaults.standard.integer(forKey: "watch_last_auto_checkin_day")
        if lastDay == today {
            print("[Watch] 今天已自动签到过，跳过")
            return
        }

        guard WCSession.default.activationState == .activated else {
            print("[Watch] ⚠️ WCSession 未激活，自动签到推迟到下次心率检测")
            return
        }

        // 标记今日已自动签（防重复），WCSession 未激活不标记
        UserDefaults.standard.set(today, forKey: "watch_last_auto_checkin_day")

        let clientId = UUID().uuidString
        pendingClientId = clientId
        let message: [String: Any] = [
            "action": "auto_checkin",
            "client_id": clientId,
            "heart_rate": heartRate,
            "timestamp": Date().timeIntervalSince1970,
        ]
        WCSession.default.transferUserInfo(message)
        print("[Watch] 📤 auto_checkin 已排队 (心率=\(Int(heartRate)), clientId=\(clientId))")

        DispatchQueue.main.async {
            self.lastAction = "心跳签到 💓"
            self.autoCheckInSuccess = true
        }

        // 触觉反馈：轻触提示（不打断用户）
        WKInterfaceDevice.current().play(.success)
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

            // 【v1.94.0】签到成功回包 — 显示庆祝态
            if let action = userInfo["action"] as? String, action == "checkin_ack" {
                self.checkInSuccess = true
                self.checkInFailed = false
                self.checkInStreak = userInfo["streak"] as? Int ?? 0
                self.checkInTotal = userInfo["total"] as? Int ?? 0
                self.checkInAlreadyDone = userInfo["already_done"] as? Bool ?? false
                self.lastAction = self.checkInAlreadyDone ? "今日已签到 ✅" : "签到成功 ✅"
                self.lastCheckIn = self.formatNow()
                self.pendingClientId = nil
                WKInterfaceDevice.current().play(.success)
                return
            }

            if let health = userInfo["health_data"] as? [String: Any] {
                self.healthData = health
            }
            if let checkIn = userInfo["last_check_in"] as? String {
                self.lastCheckIn = checkIn
            }
        }
    }

    /// 格式化为「HH:mm」用于本地显示签到时间
    private func formatNow() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return fmt.string(from: Date())
    }
    
    // iOS 端回调用
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        print("[Watch] 📥 收到来自 iPhone 的消息: \(message)")
        replyHandler(["received": true])
    }
}
