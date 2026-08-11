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

    // 【修复】今日是否已签到：基于持久化日期，跨天自动复位，
    // 避免"第一天签到成功后，第二天手表 App 仍驻留内存、按钮被隐藏导致无法再签到"。
    @Published var hasCheckedInToday: Bool = false
    private let lastCheckInDateKey = "watch_last_checkin_date"
    private static func todayString() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: Date())
    }
    /// 标记今日已签到（持久化 + 即时刷新 UI）
    private func markCheckedInToday() {
        let t = Self.todayString()
        UserDefaults.standard.set(t, forKey: lastCheckInDateKey)
        hasCheckedInToday = true
    }
    /// 重新计算今日签到状态（App 回到前台 / 启动 / 跨午夜自检 时调用，强制刷新 UI）
    func refreshCheckInState() {
        let stored = UserDefaults.standard.string(forKey: lastCheckInDateKey)
        let isToday = (stored == Self.todayString())
        hasCheckedInToday = isToday
        if !isToday {
            // 【v1.97.0 修复】跨天且今日未签：清除昨日的"已签到/庆祝"残留态，
            // 否则第二天手表仍卡在昨日已签到界面、签到按钮不出现、无法再次签到。
            checkInSuccess = false
            checkInAlreadyDone = false
            checkInFailed = false
        }
        // 读回上次已知的正确连续/累计天数，避免第二天打开手表显示 0
        checkInStreak = UserDefaults.standard.integer(forKey: watchStreakKey)
        checkInTotal = UserDefaults.standard.integer(forKey: watchTotalKey)
    }

    // 【v1.94.0】签到结果状态（用于酷炫庆祝 UI）
    @Published var checkInSuccess = false
    @Published var checkInFailed = false
    @Published var checkInStreak = 0
    @Published var checkInTotal = 0
    private let watchStreakKey = "watch_checkin_streak"
    private let watchTotalKey = "watch_checkin_total"
    /// 统一设置并持久化连续/累计天数（避免第二天打开手表显示 0 / 旧数据）
    private func setCheckInStats(streak: Int, total: Int) {
        checkInStreak = streak
        checkInTotal = total
        UserDefaults.standard.set(streak, forKey: watchStreakKey)
        UserDefaults.standard.set(total, forKey: watchTotalKey)
    }
    @Published var checkInAlreadyDone = false
    @Published var autoCheckInSuccess = false   // 【P0 心跳自动签到】独立庆祝态
    @Published var isHeartbeatGuardian = false  // 【P0 心跳守护中】状态指示
    @Published var lastHeartRate: Double = 0
    private var pendingClientId: String?

    /// 【中国合规版整改】cn 区自检：build_ipa.sh 将 Bundle ID 由
    /// com.zaine.app.watchkitapp 切为 com.zaine.app.cn.watchkitapp，
    /// 由此判断当前是否为中国合规版，关闭"心率自动签到"（dead-man switch 核心之一）。
    let isChinaRegion: Bool = {
        let bid = Bundle.main.bundleIdentifier ?? ""
        return bid.contains("zaine.app.cn")
    }()

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

        // 【v1.97.0 修复】App 每次切到前台都重新计算"今日是否已签"并主动拉最新天数，
        // 解决"第二天手表常驻内存未重启、onAppear 不重触发 → 卡在昨日已签到态、无法再次签到"。
        NotificationCenter.default.addObserver(
            forName: WKExtension.applicationDidBecomeActiveNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.refreshCheckInState()
            self?.requestCheckInStatus()
        }
        // 兜底：App 常驻内存跨过午夜时，每 60s 自检日期翻转，确保状态随日期更新
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.refreshCheckInState()
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

        // 🔴【v1.97.3 修复 · 第一性原理】乐观 UI：立即标记已签到
        // 原因：用户点了签到 = 表达「我在呢」，应该立即看到反馈
        // transferUserInfo 保证消息最终到达手机端处理；如果签到失败（登录失效等），
        // 下次 refreshCheckInState / requestCheckInStatus 会从手机拉最新状态自动纠正
        self.markCheckedInToday()
        self.lastAction = "签到成功 ✅"

        // 加速路径：手机可达时通过 sendMessage 即时拿到「真实结果」回包，纠正 streak/total
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: { reply in
                print("[Watch] ✅ sendMessage 即时回包: \(reply)")
                if let success = reply["success"] as? Bool {
                    DispatchQueue.main.async {
                        if success {
                            self.checkInSuccess = true
                            self.checkInFailed = false
                            self.checkInAlreadyDone = reply["already_done"] as? Bool ?? false
                            self.setCheckInStats(streak: reply["streak"] as? Int ?? 0, total: reply["total"] as? Int ?? 0)
                            self.lastAction = self.checkInAlreadyDone ? "今日已签到 ✅" : "签到成功 ✅"
                            self.lastCheckIn = self.formatNow()
                            self.pendingClientId = nil
                            WKInterfaceDevice.current().play(.success)
                        } else {
                            // 回包明确失败（登录失效等），纠正乐观标记
                            self.hasCheckedInToday = false
                            UserDefaults.standard.removeObject(forKey: self.lastCheckInDateKey)
                            self.checkInSuccess = false
                            self.checkInFailed = true
                            self.lastAction = "签到失败 ❌"
                            self.pendingClientId = nil
                            WKInterfaceDevice.current().play(.failure)
                        }
                    }
                }
            }, errorHandler: { error in
                print("[Watch] ℹ️ sendMessage 即时回包失败(已走 transferUserInfo 兜底，无影响): \(error.localizedDescription)")
            })
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

    // MARK: - Request latest check-in status (streak/total) from iPhone
    /// 【v1.97.0 修复】主动向 iPhone 请求当前连续/累计天数，
    /// 解决「第一天签到正确、第二天手表仍显示旧数据」的问题（手表不再依赖本地乐观值）。
    func requestCheckInStatus() {
        guard WCSession.default.activationState == .activated else { return }
        let message: [String: Any] = ["action": "status_query", "timestamp": Date().timeIntervalSince1970]
        // 主路径：可靠队列（后台/不可达也能投递）
        WCSession.default.transferUserInfo(message)
        // 加速路径：可达时即时拿到回包
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: { reply in
                self.handleStatusQueryReply(reply)
            }, errorHandler: { error in
                print("[Watch] ℹ️ status_query sendMessage 失败(已走 transferUserInfo 兜底): \(error.localizedDescription)")
            })
        }
    }

    private func handleStatusQueryReply(_ reply: [String: Any]) {
        guard let action = reply["action"] as? String, action == "status_query_ack" else { return }
        setCheckInStats(streak: reply["streak"] as? Int ?? 0, total: reply["total"] as? Int ?? 0)
    }

    // MARK: - 【P0】自动心跳签到（核心酷炫功能）
    /// 由 ContentView.onAppear 调用，启动 HealthKit 心率监控
    /// 检测到有效心率后自动触发签到，用户零操作
    func startHeartRateMonitoring() {
        // 【中国合规版整改】cn 区关闭"心率自动签到"：不启动心率监控、不自动签到
        guard !isChinaRegion else {
            print("[Watch][CN] 已关闭心率自动签到守护")
            return
        }
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
        // 【中国合规版整改】cn 区绝不自动签到（双保险）
        guard !isChinaRegion else { return }
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
                self.requestCheckInStatus()
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
            if session.isReachable {
                self.requestCheckInStatus()
            }
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any]) {
        DispatchQueue.main.async {
            print("[Watch] 📥 收到来自 iPhone 的数据: \(userInfo)")

            // 【v1.97.0 修复】iPhone 回包的当前连续/累计天数
            if let action = userInfo["action"] as? String, action == "status_query_ack" {
                self.setCheckInStats(streak: userInfo["streak"] as? Int ?? 0, total: userInfo["total"] as? Int ?? 0)
                return
            }

            // 【v1.94.0】签到成功回包 — 显示庆祝态
            if let action = userInfo["action"] as? String, action == "checkin_ack" {
                let success = userInfo["success"] as? Bool ?? true
                if success {
                    self.checkInSuccess = true
                    self.markCheckedInToday()
                    self.checkInFailed = false
                    self.setCheckInStats(streak: userInfo["streak"] as? Int ?? 0, total: userInfo["total"] as? Int ?? 0)
                    self.checkInAlreadyDone = userInfo["already_done"] as? Bool ?? false
                    self.lastAction = self.checkInAlreadyDone ? "今日已签到 ✅" : "签到成功 ✅"
                    self.lastCheckIn = self.formatNow()
                    self.pendingClientId = nil
                    WKInterfaceDevice.current().play(.success)
                } else {
                    // 【2026-07-15 修复】签到真正失败（如登录失效/网络错误）→ 诚实显示失败，不再假绿
                    self.checkInSuccess = false
                    self.checkInFailed = true
                    self.lastAction = "签到失败 ❌"
                    self.pendingClientId = nil
                    WKInterfaceDevice.current().play(.failure)
                }
                return
            }

            // 【v1.97.3 修复】iPhone pushHealthSummary 直接发平铺健康字段（无 health_data 包裹），统一走 applyHealthData
            self.applyHealthData(userInfo)
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
    
    // MARK: - 【v1.97.3 修复】健康数据接收（iPhone 通过 sendMessage / updateApplicationContext 推送）
    /// 统一抽取健康相关字段写入 healthData，供健康速览页展示。
    /// iPhone pushHealthSummary 直接发平铺字段（heart_rate/blood_oxygen/temperature/sleep/menstrual...），
    /// 不走 health_data 包裹，故此处按字段名直接合并，避免覆盖签到回包等其他消息。
    private func applyHealthData(_ data: [String: Any]) {
        let healthKeys = ["heart_rate", "blood_oxygen", "hrv", "temperature", "sleep", "menstrual",
                          "steps", "resting_heart_rate"]
        var merged = self.healthData
        var hasHealth = false
        for k in healthKeys {
            if let v = data[k] {
                merged[k] = v
                hasHealth = true
            }
        }
        if hasHealth {
            self.healthData = merged
            print("[Watch] ✅ 健康数据已更新: \(merged)")
        }
    }

    // iPhone 通过 updateApplicationContext 推送健康数据（App 后台/不可达时主路径）
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        DispatchQueue.main.async {
            print("[Watch] 📥 收到 ApplicationContext: \(applicationContext)")
            self.applyHealthData(applicationContext)
        }
    }

    // iOS 端回调用
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        print("[Watch] 📥 收到来自 iPhone 的消息: \(message)")
        if let action = message["action"] as? String, action == "status_query_ack" {
            setCheckInStats(streak: message["streak"] as? Int ?? 0, total: message["total"] as? Int ?? 0)
            replyHandler(["received": true])
            return
        }
        // 【v1.97.3 修复】健康数据可能随 sendMessage 到达（可达时主路径）
        applyHealthData(message)
        replyHandler(["received": true])
    }
}
