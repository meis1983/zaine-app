//
//  HealthKitManager.swift
//  ZaineWatch Watch App Watch App
//
//  感应签到 - 心率检测自动签到
//

import Foundation
import HealthKit

class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()
    
    private let healthStore = HKHealthStore()
    private let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!
    
    @Published var isAuthorized = false
    @Published var currentHeartRate: Double = 0.0
    @Published var lastCheckinTime: Date?
    
    private var query: HKAnchoredObjectQuery?
    private var lastAutoCheckinDate: Date?
    
    private init() {}
    
    // MARK: - 请求 HealthKit 权限
    
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        // 检查 HealthKit 是否可用
        guard HKHealthStore.isHealthDataAvailable() else {
            print("[HealthKit] ❌ HealthKit 不可用")
            completion(false)
            return
        }
        
        // 请求读取心率权限
        let typesToRead: Set<HKObjectType> = [heartRateType]
        
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
            DispatchQueue.main.async {
                if success {
                    print("[HealthKit] ✅ HealthKit 授权成功")
                    self.isAuthorized = true
                    completion(true)
                } else {
                    print("[HealthKit] ❌ HealthKit 授权失败: \(error?.localizedDescription ?? "未知错误")")
                    self.isAuthorized = false
                    completion(false)
                }
            }
        }
    }
    
    // MARK: - 开始监控心率
    
    func startMonitoringHeartRate(completion: @escaping (Double) -> Void) {
        guard isAuthorized else {
            print("[HealthKit] ⚠️ 未授权，无法监控心率")
            return
        }
        
        // 创建心率查询
        let predicate = HKQuery.predicateForSamples(
            withStart: Date().addingTimeInterval(-300), // 过去5分钟
            end: nil,
            options: .strictStartDate
        )
        
        query = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: predicate,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] query, samples, deletedObjects, anchor, error in
            self?.handleHeartRateSamples(samples)
        }
        
        query?.updateHandler = { [weak self] query, samples, deletedObjects, anchor, error in
            self?.handleHeartRateSamples(samples)
        }
        
        if let query = query {
            healthStore.execute(query)
            print("[HealthKit] ✅ 开始监控心率")
        }
    }
    
    private func handleHeartRateSamples(_ samples: [HKSample]) {
        guard let heartRateSamples = samples as? [HKQuantitySample] else {
            return
        }
        
        for sample in heartRateSamples {
            let heartRate = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
            
            DispatchQueue.main.async {
                self.currentHeartRate = heartRate
                print("[HealthKit] 💓 检测到心率: \(Int(heartRate)) bpm")
                
                // 感应签到逻辑：心率 > 60 bpm 且今天还未自动签到
                self.checkAutoCheckin(heartRate: heartRate)
            }
        }
    }
    
    // MARK: - 感应签到逻辑
    
    private func checkAutoCheckin(heartRate: Double) {
        // 心率阈值：> 60 bpm 表示用户清醒/活动
        let threshold: Double = 60.0
        
        guard heartRate > threshold else {
            return
        }
        
        // 检查今天是否已经自动签到过（避免频繁签到）
        let calendar = Calendar.current
        let now = Date()
        
        if let lastCheckin = lastAutoCheckinDate {
            if calendar.isDate(lastCheckin, inSameDayAs: now) {
                // 今天已经签到过了
                return
            }
        }
        
        // 触发自动签到
        print("[HealthKit] 🎯 检测到心率 > \(Int(threshold)) bpm，触发感应签到")
        performAutoCheckin()
    }
    
    private func performAutoCheckin() {
        // 更新最后签到时间
        lastAutoCheckinDate = Date()
        
        // 发送签到消息到 iPhone
        let message: [String: Any] = [
            "action": "auto_checkin",
            "timestamp": Date().timeIntervalSince1970,
            "source": "heart_rate",
            "heart_rate": currentHeartRate
        ]
        
        WatchConnectivityManager.shared.sendMessage(message) { success in
            DispatchQueue.main.async {
                if success {
                    print("[HealthKit] ✅ 感应签到消息已发送")
                    WKInterfaceDevice.current().play(.success)
                } else {
                    print("[HealthKit] ❌ 感应签到消息发送失败")
                }
            }
        }
    }
    
    // MARK: - 停止监控
    
    func stopMonitoring() {
        if let query = query {
            healthStore.stop(query)
            self.query = nil
            print("[HealthKit] ⏹️ 停止监控心率")
        }
    }
}
