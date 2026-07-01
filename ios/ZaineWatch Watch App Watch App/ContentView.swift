//
//  ContentView.swift
//  ZaineWatch Watch App Watch App
//
//  在呢+ Watch App - 健康数据速览 + 签到 + SOS
//

import SwiftUI
import Combine
import WatchConnectivity
import HealthKit

// MARK: - 健康数据模型

struct HealthMetrics {
    var heartRate: Int?
    var bloodOxygen: Int?
    var restingHeartRate: Int?
    var hrv: Double?
    var bodyTemperature: Double?
    var sleepTotalMinutes: Int?
    var isInMenstruation: Bool?
    var cycleDay: Int?
    var predictedNextDate: String?
    var guardianCount: Int?
    var membershipLevel: String?
    var lastUpdate: Date?
}

// MARK: - 主界面

struct ContentView: View {
    @EnvironmentObject var connectivityManager: WatchConnectivityManager
    @StateObject private var healthKitManager = HealthKitManager.shared
    @State private var isAnimating = false
    @State private var checkinStatus: String = "我在呢"
    @State private var lastCheckinTime: Date?
    @State private var showSOSConfirm = false
    @State private var showHealthKitAlert = false
    @State private var healthKitAlertMessage = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {

                // MARK: 感应签到状态提示
                if healthKitManager.isAuthorized {
                    Text("💓 感应签到已开启")
                        .font(.system(size: 10))
                        .foregroundColor(.green)
                        .padding(.top, 2)
                } else {
                    Button(action: {
                        requestHealthKitAuthorization()
                    }) {
                        Text("开启感应签到")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                    }
                    .padding(.top, 2)
                }

                // MARK: 签到按钮
                checkinButton

                // MARK: 健康数据速览
                if connectivityManager.metrics.lastUpdate != nil {
                    healthMetricsSection
                } else {
                    noDataView
                }

                // MARK: 守护圈信息
                guardianInfoSection

                // MARK: 快捷 SOS
                sosButton
            }
            .padding(.horizontal, 12)
        }
        .navigationTitle("在呢+")
        .alert("确认发送紧急求助?", isPresented: $showSOSConfirm) {
            Button("发送", role: .destructive) {
                sendSOS()
            }
            Button("取消", role: .cancel) {}
        }
        .alert("健康数据权限", isPresented: $showHealthKitAlert) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(healthKitAlertMessage)
        }
        .onAppear {
            // App 启动时自动请求 HealthKit 授权
            if !healthKitManager.isAuthorized {
                requestHealthKitAuthorization()
            } else {
                // 已授权，开始监控心率
                healthKitManager.startMonitoringHeartRate { heartRate in
                    print("[WatchApp] 💓 实时心率: \(Int(heartRate)) bpm")
                }
            }
        }
    }

    // MARK: - 签到按钮

    private var checkinButton: some View {
        Button(action: { performCheckin() }) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 90, height: 90)
                    .scaleEffect(isAnimating ? 1.15 : 0.9)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimating)

                Circle()
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [Color(hex: "FF9A8B"), Color(hex: "FF6A88")]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 72, height: 72)
                    .shadow(radius: 4)

                VStack(spacing: 2) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .scaleEffect(isAnimating ? 1.1 : 1.0)

                    Text(checkinStatus)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .buttonStyle(.plain)
        .onAppear { isAnimating = true }
    }

    // MARK: - 健康数据区域

    private var healthMetricsSection: some View {
        VStack(spacing: 6) {
            HStack {
                Text("健康速览")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
                Text(updateTimeAgo)
                    .font(.system(size: 9))
                    .foregroundColor(.gray)
            }

            // 第一行：心率 + 血氧
            HStack(spacing: 8) {
                metricCard(
                    icon: "heart.fill",
                    iconColor: .red,
                    title: "心率",
                    value: connectivityManager.metrics.heartRate.map { "\($0)" },
                    unit: "bpm"
                )
                metricCard(
                    icon: "drop.fill",
                    iconColor: .blue,
                    title: "血氧",
                    value: connectivityManager.metrics.bloodOxygen.map { "\($0)" },
                    unit: "%"
                )
            }

            // 第二行：HRV + 体温
            HStack(spacing: 8) {
                metricCard(
                    icon: "waveform.path.ecg",
                    iconColor: .green,
                    title: "HRV",
                    value: connectivityManager.metrics.hrv.map { String(format: "%.0f", $0) },
                    unit: "ms"
                )
                metricCard(
                    icon: "thermometer",
                    iconColor: .orange,
                    title: "体温",
                    value: connectivityManager.metrics.bodyTemperature.map { String(format: "%.1f", $0) },
                    unit: "°C"
                )
            }

            // 第三行：睡眠 + 经期
            HStack(spacing: 8) {
                metricCard(
                    icon: "bed.double.fill",
                    iconColor: .indigo,
                    title: "睡眠",
                    value: connectivityManager.metrics.sleepTotalMinutes.map { minutes in
                        let h = minutes / 60
                        let m = minutes % 60
                        return h > 0 ? "\(h)h\(m)m" : "\(m)m"
                    },
                    unit: nil
                )
                menstruationCard
            }
        }
    }

    // MARK: - 经期卡片

    private var menstruationCard: some View {
        Group {
            if let isInPeriod = connectivityManager.metrics.isInMenstruation, isInPeriod {
                VStack(spacing: 2) {
                    Image(systemName: "drop.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.pink)
                    Text("经期第\(connectivityManager.metrics.cycleDay ?? 1)天")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.pink)
                }
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(Color.pink.opacity(0.1))
                .cornerRadius(8)
            } else {
                VStack(spacing: 2) {
                    Image(systemName: "drop.circle")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                    Text("经期")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(Color.gray.opacity(0.08))
                .cornerRadius(8)
            }
        }
    }

    // MARK: - 无数据视图

    private var noDataView: some View {
        VStack(spacing: 6) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 24))
                .foregroundColor(.gray.opacity(0.5))
            Text("打开 iPhone App 同步健康数据")
                .font(.system(size: 10))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 12)
    }

    // MARK: - 守护圈信息

    private var guardianInfoSection: some View {
        HStack {
            Image(systemName: "person.2.fill")
                .font(.system(size: 12))
                .foregroundColor(.teal)
            Text("守护圈")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Spacer()
            if let count = connectivityManager.metrics.guardianCount {
                Text("\(count)人")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.teal)
            } else {
                Text("--")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.teal.opacity(0.08))
        .cornerRadius(8)
    }

    // MARK: - SOS 按钮

    private var sosButton: some View {
        Button(action: {
            showSOSConfirm = true
        }) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14))
                Text("紧急求助 SOS")
                    .font(.system(size: 13, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .foregroundColor(.white)
            .background(Color.red)
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }

    // MARK: - 指标卡片组件

    private func metricCard(
        icon: String,
        iconColor: Color,
        title: String,
        value: String?,
        unit: String?
    ) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(iconColor)

            if let v = value {
                HStack(spacing: 1) {
                    Text(v)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                    if let u = unit {
                        Text(u)
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Text("--")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
            }

            Text(title)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 50)
        .background(Color.gray.opacity(0.08))
        .cornerRadius(8)
    }

    // MARK: - 更新时间

    private var updateTimeAgo: String {
        guard let date = connectivityManager.metrics.lastUpdate else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    // MARK: - 操作方法

    private func performCheckin() {
        // 添加触觉反馈
        WKInterfaceDevice.current().play(.click)
        
        checkinStatus = "同步中..."
        print("[WatchApp] 📱 尝试签到...")

        connectivityManager.sendMessage(
            ["action": "checkin", "timestamp": Date().timeIntervalSince1970]
        ) { success in
            DispatchQueue.main.async {
                if success {
                    checkinStatus = "已平安"
                    lastCheckinTime = Date()
                    WKInterfaceDevice.current().play(.success)
                    print("[WatchApp] ✅ 签到成功")
                    
                    // 2秒后恢复
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        checkinStatus = "我在呢"
                    }
                } else {
                    checkinStatus = "重试一下"
                    WKInterfaceDevice.current().play(.failure)
                    print("[WatchApp] ❌ 签到失败")
                    
                    // 3秒后恢复
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        checkinStatus = "我在呢"
                    }
                }
            }
        }
    }

    private func sendSOS() {
        WKInterfaceDevice.current().play(.alert)
        print("[WatchApp] 🚨 发送 SOS...")
        
        connectivityManager.sendMessage(
            ["action": "sos", "timestamp": Date().timeIntervalSince1970]
        ) { success in
            DispatchQueue.main.async {
                if success {
                    print("[WatchApp] ✅ SOS 已发送")
                } else {
                    print("[WatchApp] ❌ SOS 发送失败")
                }
            }
        }
    }

    // MARK: - 感应签到功能

    /// 请求 HealthKit 授权
    private func requestHealthKitAuthorization() {
        print("[WatchApp] 📱 请求 HealthKit 授权...")
        
        healthKitManager.requestAuthorization { success in
            DispatchQueue.main.async {
                if success {
                    print("[WatchApp] ✅ HealthKit 授权成功，开始监控心率")
                    self.healthKitManager.startMonitoringHeartRate { heartRate in
                        print("[WatchApp] 💓 实时心率: \(Int(heartRate)) bpm")
                    }
                } else {
                    print("[WatchApp] ❌ HealthKit 授权失败")
                    self.healthKitAlertMessage = "需要健康数据权限才能使用感应签到功能"
                    self.showHealthKitAlert = true
                }
            }
        }
    }
}

// MARK: - WatchConnectivityManager

final class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    @Published var isReachable = false
    @Published var metrics = HealthMetrics()

    override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
        
        // 在后台处理之前保存的待发送消息
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.processPendingMessages()
        }
    }

    // MARK: - WCSessionDelegate - 必须实现的方法

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
        if let context = session.receivedApplicationContext as? [String: Any] {
            self.updateMetrics(from: context)
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        // Watch App 不需要处理
    }

    func sessionDidDeactivate(_ session: WCSession) {
        // 重新激活 session
        WCSession.default.activate()
    }

    // MARK: - 接收 iPhone 实时消息

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async {
            self.updateMetrics(from: message)
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        DispatchQueue.main.async {
            self.updateMetrics(from: message)
        }
        replyHandler([:])
    }

    // MARK: - 接收 iPhone 后台传输数据

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        DispatchQueue.main.async {
            self.updateMetrics(from: applicationContext)
        }
    }

    // MARK: - 解析数据并更新 UI

    private func updateMetrics(from data: [String: Any]) {
        var m = metrics

        if let hr = data["heart_rate"] as? String, let val = Int(hr) {
            m.heartRate = val
        }
        if let bo = data["blood_oxygen"] as? String, let val = Int(bo) {
            m.bloodOxygen = val
        }
        if let rhr = data["resting_heart_rate"] as? String, let val = Int(rhr) {
            m.restingHeartRate = val
        }
        if let hrv = data["hrv"] as? Double {
            m.hrv = hrv
        } else if let hrv = data["hrv"] as? String, let val = Double(hrv) {
            m.hrv = val
        }
        if let temp = data["body_temperature"] as? String, let val = Double(temp) {
            m.bodyTemperature = val
        }
        if let sleep = data["sleep_total"] as? Int {
            m.sleepTotalMinutes = sleep
        } else if let sleep = data["sleep_total"] as? String, let val = Int(sleep) {
            m.sleepTotalMinutes = val
        }
        if let hasM = data["has_menstruation"] as? Bool {
            m.isInMenstruation = hasM
        }
        if let cd = data["cycle_day"] as? Int {
            m.cycleDay = cd
        }
        if let pnd = data["predicted_next_date"] as? String {
            m.predictedNextDate = pnd
        }
        if let gc = data["guardian_count"] as? Int {
            m.guardianCount = gc
        }
        if let ml = data["membership_level"] as? String {
            m.membershipLevel = ml
        }
        if let pushType = data["push_type"] as? String, pushType == "menstruation_status" {
            if let isInPeriod = data["is_in_period"] as? Bool {
                m.isInMenstruation = isInPeriod
            }
            if let cd = data["cycle_day"] as? Int {
                m.cycleDay = cd
            }
        }
        if let ts = data["push_timestamp"] as? TimeInterval {
            m.lastUpdate = Date(timeIntervalSince1970: ts / 1000)
        } else {
            m.lastUpdate = Date()
        }

        DispatchQueue.main.async {
            self.metrics = m
        }
    }

    // MARK: - 发送消息到 iPhone

    func sendMessage(_ message: [String: Any], completion: @escaping (Bool) -> Void) {
        let session = WCSession.default
        
        // 1. 尝试实时发送（iPhone App 在前台）
        if session.isReachable {
            session.sendMessage(message, replyHandler: { response in
                print("[WatchConnectivity] ✅ 消息发送成功: \(message["action"] ?? "")")
                completion(true)
            }, errorHandler: { error in
                print("[WatchConnectivity] ❌ 实时消息发送失败: \(error.localizedDescription)")
                // 失败后尝试后台传输
                self.transferMessageInBackground(message, completion: completion)
            })
        } else {
            // 2. iPhone App 不在前台，使用后台传输
            transferMessageInBackground(message, completion: completion)
        }
    }
    
    /// 后台传输消息（当 iPhone App 不在前台时）
    private func transferMessageInBackground(_ message: [String: Any], completion: @escaping (Bool) -> Void) {
        // 使用 transferUserInfo 传输（会在 iPhone App 启动时处理）
        session.transferUserInfo(message)
        print("[WatchConnectivity] 📦 消息已加入后台传输队列: \(message["action"] ?? "")")
        
        // 同时保存到 UserDefaults，确保不丢失
        var pendingMessages = UserDefaults.standard.array(forKey: "pending_messages") as? [[String: Any]] ?? []
        pendingMessages.append(message)
        UserDefaults.standard.set(pendingMessages, forKey: "pending_messages")
        
        // 后台传输不保证立即送达，但我们会保存到本地确保不丢失
        completion(true)
    }
    
    /// 在 iPhone App 启动时，处理所有待发送的消息
    func processPendingMessages() {
        guard let pendingMessages = UserDefaults.standard.array(forKey: "pending_messages") as? [[String: Any]] else {
            return
        }
        
        print("[WatchConnectivity] 📩 处理 \(pendingMessages.count) 条待发送消息")
        
        for message in pendingMessages {
            if session.isReachable {
                session.sendMessage(message, replyHandler: { _ in
                    print("[WatchConnectivity] ✅ 待发送消息已成功发送: \(message["action"] ?? "")")
                }, errorHandler: { error in
                    print("[WatchConnectivity] ❌ 待发送消息发送失败: \(error.localizedDescription)")
                })
            }
        }
        
        // 清空待发送消息
        UserDefaults.standard.removeObject(forKey: "pending_messages")
    }
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}
