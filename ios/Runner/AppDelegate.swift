import Flutter
import UIKit
import WatchConnectivity
import UserNotifications
import HealthKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, WCSessionDelegate {
  
  private var healthStore: HKHealthStore?
  private let fallMethodChannel = "zaine/healthkit"
  /// 【v1.94.0 修复】缓存 Watch MethodChannel，避免每次强转 window?.rootViewController
  /// （implicit engine 模式下 rootViewController 强转 FlutterViewController 经常为 nil，导致 Watch 签到通知静默失败）
  private var watchChannel: FlutterMethodChannel?
  /// 【v1.94.0 修复】去重：Watch 同时发 transferUserInfo + sendMessage，防止重复触发签到
  private var processedWatchClientIds = Set<String>()
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    print("[iOS AppDelegate] ✅ application didFinishLaunching")
    
    // 初始化 WatchConnectivity
    if WCSession.isSupported() {
        let session = WCSession.default
        session.delegate = self
        session.activate()
        print("[iOS AppDelegate] ✅ WCSession 已激活，isReachable=\(session.isReachable)")
    } else {
        print("[iOS AppDelegate] ❌ WCSession 不支持")
    }
    
    // 初始化 HealthKit 与 MethodChannel（延迟到引擎准备就绪）
    if HKHealthStore.isHealthDataAvailable() {
        healthStore = HKHealthStore()
    }
    
    // 注册 MethodChannel 需要在 Flutter 引擎可用后执行
    DispatchQueue.main.async {
        self.setupHealthKitMethodChannel()
        self.setupWatchMethodChannel()
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // MARK: - HealthKit Method Channel
  
  /// 【v1.94.0 修复】递归查找 FlutterViewController（implicit engine / 自定义 launch 可能包了一层容器 VC）
  private func findFlutterViewController() -> FlutterViewController? {
      if let vc = window?.rootViewController as? FlutterViewController {
          return vc
      }
      func find(in vc: UIViewController?) -> FlutterViewController? {
          guard let vc = vc else { return nil }
          if let fvc = vc as? FlutterViewController { return fvc }
          for child in vc.children {
              if let found = find(in: child) { return found }
          }
          return nil
      }
      return find(in: window?.rootViewController)
  }

  private func setupHealthKitMethodChannel() {
    guard let controller = findFlutterViewController() else {
        print("[AppDelegate] 无法获取 FlutterViewController，MethodChannel 注册失败")
        return
    }
    
    let channel = FlutterMethodChannel(name: fallMethodChannel, binaryMessenger: controller.binaryMessenger)
    channel.setMethodCallHandler { [weak self] call, result in
        guard let self = self else {
            result(FlutterError(code: "UNAVAILABLE", message: "AppDelegate released", details: nil))
            return
        }
        
        switch call.method {
        case "requestFallDetectionAuthorization":
            self.requestFallDetectionAuthorization(result: result)
        case "getRecentFallEvents":
            let args = call.arguments as? [String: Any] ?? [:]
            let hours = args["hours"] as? Int ?? 24
            self.getRecentFallEvents(hours: hours, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
  }
  
  // MARK: - Watch Method Channel（v1.94.0）
  /// 接收 Flutter 回包的 Watch 签到结果，转发给 Apple Watch
  private func setupWatchMethodChannel() {
    guard let controller = findFlutterViewController() else {
      print("[AppDelegate] 无法获取 FlutterViewController，Watch MethodChannel 注册失败")
      return
    }
    let channel = FlutterMethodChannel(name: "zaine/watch", binaryMessenger: controller.binaryMessenger)
    // 缓存引用，供 notifyFlutterWatchCheckin 复用（不再依赖每次强转 rootViewController）
    self.watchChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterError(code: "UNAVAILABLE", message: "AppDelegate released", details: nil))
        return
      }
      switch call.method {
      case "ackWatchCheckin":
        if let args = call.arguments as? [String: Any] {
          self.sendWatchAck(args: args)
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    print("[AppDelegate] ✅ Watch MethodChannel (zaine/watch) 已注册，可接收 ackWatchCheckin")
  }

  /// 把签到成功结果(streak/total)通过 transferUserInfo 回包给 Apple Watch
  private func sendWatchAck(args: [String: Any]) {
    guard WCSession.default.activationState == .activated else {
      print("[AppDelegate] ⚠️ WCSession 未激活，无法回包 Watch")
      return
    }
    WCSession.default.transferUserInfo([
      "action": "checkin_ack",
      "client_id": args["client_id"] ?? "",
      "success": args["success"] ?? true,
      "already_done": args["already_done"] ?? false,
      "streak": args["streak"] ?? 0,
      "total": args["total"] ?? 0,
    ])
    print("[AppDelegate] 📤 已回包 Watch 签到结果: client_id=\(args["client_id"] ?? ""), streak=\(args["streak"] ?? 0)")
  }

  private func requestFallDetectionAuthorization(result: @escaping FlutterResult) {
    guard let healthStore = healthStore else {
        result(false)
        return
    }

    // 使用字符串构造 identifier，兼容不同 SDK 版本
    // HKCategoryTypeIdentifierFall 在 iOS 15.2+ 可用，但 Swift overlay 可能未导出 .fall
    let fallTypeId = HKCategoryTypeIdentifier(rawValue: "HKCategoryTypeIdentifierFall")
    guard let fallType = HKObjectType.categoryType(forIdentifier: fallTypeId) else {
        result(false)
        return
    }

    healthStore.requestAuthorization(toShare: nil, read: [fallType]) { success, error in
        DispatchQueue.main.async {
            if let error = error {
                print("[AppDelegate] 请求跌倒检测授权失败: \(error)")
            }
            result(success)
        }
    }
  }
  
  private func getRecentFallEvents(hours: Int, result: @escaping FlutterResult) {
    guard let healthStore = healthStore else {
        result([])
        return
    }

    let fallTypeId = HKCategoryTypeIdentifier(rawValue: "HKCategoryTypeIdentifierFall")
    guard let fallType = HKObjectType.categoryType(forIdentifier: fallTypeId) else {
        result([])
        return
    }

    let now = Date()
    let startDate = Calendar.current.date(byAdding: .hour, value: -hours, to: now) ?? now.addingTimeInterval(TimeInterval(-hours * 3600))
    let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)
    
    let query = HKSampleQuery(sampleType: fallType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]) { _, samples, error in
        
        if let error = error {
            print("[AppDelegate] 查询跌倒事件失败: \(error)")
            DispatchQueue.main.async { result([]) }
            return
        }
        
        let events = samples?.compactMap { sample -> [String: Any]? in
            guard let categorySample = sample as? HKCategorySample else { return nil }
            return [
                "timestamp": ISO8601DateFormatter().string(from: categorySample.startDate),
                "endTimestamp": ISO8601DateFormatter().string(from: categorySample.endDate),
                "value": categorySample.value
            ]
        } ?? []
        
        DispatchQueue.main.async { result(events) }
    }
    
    healthStore.execute(query)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  // 处理来自 Watch 的消息
  func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        print("[iOS AppDelegate] 📥 收到 Watch 消息: \(message)")
        
      guard let action = message["action"] as? String else {
          print("[iOS AppDelegate] ❌ Watch 消息缺少 action 字段")
          replyHandler(["success": false, "error": "missing_action"])
          return
      }
        print("[iOS AppDelegate] ✅ Watch 消息 action=\(action)")

      switch action {
      case "checkin", "auto_checkin":
          // 【感应签到】Watch 自动检测到心率后触发的签到
          let isAutoCheckin = action == "auto_checkin"
          let clientId = message["client_id"] as? String
          if isAutoCheckin {
              print("[AppDelegate] 💓 收到 Watch 感应签到请求（心率: \(message["heart_rate"] ?? "unknown")）")
          }
          
          UserDefaults.standard.set(true, forKey: "pending_watch_checkin")
          UserDefaults.standard.set(action, forKey: "watch_last_action")
          UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "watch_last_action_ts")
          if isAutoCheckin {
              UserDefaults.standard.set(message["heart_rate"], forKey: "watch_auto_checkin_hr")
          }
          
          // 【修复 v1.91.0】立即通知 Flutter 执行签到（不再只设 flag 等待被动触发）
          // 【P0】手动签到 fromWatch=true；自动心率签到 fromHeartbeat=true（手机端区别展示，不打断用户）
          self.notifyFlutterWatchCheckin(clientId: clientId, heartRate: message["heart_rate"], fromHeartbeat: isAutoCheckin)
          replyHandler(["success": true])

      case "sos":
          // Watch 端紧急求助 → 记录到 UserDefaults + 立即通知 Flutter 执行 SOS 流程
          UserDefaults.standard.set(true, forKey: "pending_watch_sos")
          UserDefaults.standard.set("sos", forKey: "watch_last_action")
          UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "watch_last_action_ts")
          // 发送本地通知提醒用户
          self.sendLocalNotification(title: "紧急求助", body: "Apple Watch 发起了 SOS 紧急求助")
          // 【v1.93.0 修复】立即通知 Flutter 执行 SOS 流程（之前只设 flag，Flutter 端无人读取）
          self.notifyFlutterWatchSOS()
          replyHandler(["success": true])

      default:
          UserDefaults.standard.set(action, forKey: "watch_last_action")
          UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "watch_last_action_ts")
          replyHandler(["success": true])
      }
  }

  /// 【v1.91.0】通知 Flutter 端执行 Watch 签到
  /// [clientId] 本次签到的唯一 ID，用于把成功回包精准送回对应的 Watch
  /// [fromHeartbeat] true=Watch 自动心率签到（手机端区别展示，不打断用户）；false=手动点击签到
  private func notifyFlutterWatchCheckin(clientId: String?, heartRate: Any? = nil, fromHeartbeat: Bool = false) {
      // 【v1.94.0 修复】去重：Watch 同时发 transferUserInfo + sendMessage，clientId 相同，只处理一次
      if let cid = clientId {
          if processedWatchClientIds.contains(cid) {
              print("[AppDelegate] ⏭️ 跳过重复的 Watch 签到 (clientId=\(cid))")
              return
          }
          processedWatchClientIds.insert(cid)
          // 防止集合无限增长（保留最近 50 个）
          if processedWatchClientIds.count > 50 {
              processedWatchClientIds.removeAll()
          }
      }

      // 确保在主线程调用
      DispatchQueue.main.async {
          // 【v1.94.0 修复】优先使用启动时缓存的 channel（implicit engine 下 rootViewController 强转不可靠）
          guard let channel = self.watchChannel else {
              print("[AppDelegate] ⚠️ watchChannel 未初始化，Watch 签到通知失败（App 可能尚未完成初始化）")
              return
          }
          var arguments: [String: Any] = [:]
          arguments["fromWatch"] = !fromHeartbeat
          arguments["fromHeartbeat"] = fromHeartbeat
          if let clientId = clientId {
              arguments["client_id"] = clientId
          }
          if let heartRate = heartRate {
              arguments["heart_rate"] = heartRate
          }
          channel.invokeMethod("watchCheckin", arguments: arguments) { result in
              DispatchQueue.main.async {
                  if let error = result as? FlutterError {
                      print("[AppDelegate] Watch 签到 Flutter 回调失败: \(error.message ?? "unknown")")
                  } else {
                      let tag = fromHeartbeat ? "心跳自动" : "手动"
                      print("[AppDelegate] ✅ Watch \(tag)签到已通知 Flutter 侧 (clientId=\(clientId ?? ""))")
                  }
              }
          }
      }
  }

  /// 【v1.93.0 修复】通知 Flutter 端执行 Watch SOS 紧急求助
  /// 之前 Watch SOS 只设了 UserDefaults flag，但 Flutter 端无人读取，导致 SOS 永远不触发
  private func notifyFlutterWatchSOS() {
      DispatchQueue.main.async {
          guard let controller = self.window?.rootViewController as? FlutterViewController else {
              print("[AppDelegate] FlutterViewController 不可用，Watch SOS 通知失败")
              return
          }
          let channel = FlutterMethodChannel(name: "zaine/watch", binaryMessenger: controller.binaryMessenger)
          channel.invokeMethod("watchSOS", arguments: nil) { result in
              DispatchQueue.main.async {
                  if let error = result as? FlutterError {
                      print("[AppDelegate] Watch SOS Flutter 回调失败: \(error.message ?? "unknown")")
                  } else {
                      print("[AppDelegate] ✅ Watch SOS 已通知 Flutter 侧")
                  }
              }
          }
      }
  }

  // 发送本地通知
  private func sendLocalNotification(title: String, body: String) {
      let content = UNMutableNotificationContent()
      content.title = title
      content.body = body
      content.sound = .defaultCritical
      content.categoryIdentifier = "SOS"

      let request = UNNotificationRequest(
          identifier: "watch_sos_\(Date().timeIntervalSince1970)",
          content: content,
          trigger: nil // 立即发送
      )
      UNUserNotificationCenter.current().add(request) { error in
          if let error = error {
              print("[AppDelegate] 发送本地通知失败: \(error)")
          }
      }
  }
  
  func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
      print("[iOS AppDelegate] 📡 WCSession 激活完成，state=\(activationState.rawValue), isReachable=\(session.isReachable)")
  }
  func sessionDidBecomeInactive(_ session: WCSession) {
      print("[iOS AppDelegate] ⚠️ WCSession 变为 inactive")
  }
  func sessionDidDeactivate(_ session: WCSession) {
      print("[iOS AppDelegate] ⚠️ WCSession deactivate，重新激活")
      session.activate()
  }

  /// 【v1.93.2 修复】Watch 端使用 transferUserInfo 发送的消息走这里
  /// 当 iOS App 在后台时，Watch 用 sendMessage 会失败（isReachable=false），
  /// 此时改用 transferUserInfo 兜底，iOS 唤醒后通过此回调收到
  func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any]) {
      print("[iOS AppDelegate] 📥 收到 Watch transferUserInfo: \(userInfo)")

      // 处理逻辑与 didReceiveMessage 相同
      guard let action = userInfo["action"] as? String else {
          print("[iOS AppDelegate] ❌ transferUserInfo 缺少 action 字段")
          return
      }

      switch action {
      case "checkin", "auto_checkin":
          let isAutoCheckin = action == "auto_checkin"
          let clientId = userInfo["client_id"] as? String
          UserDefaults.standard.set(true, forKey: "pending_watch_checkin")
          UserDefaults.standard.set(action, forKey: "watch_last_action")
          UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "watch_last_action_ts")
          if isAutoCheckin {
              if let hr = userInfo["heart_rate"] {
                  UserDefaults.standard.set(hr, forKey: "watch_auto_checkin_hr")
              }
          }
          self.notifyFlutterWatchCheckin(clientId: clientId, heartRate: userInfo["heart_rate"], fromHeartbeat: isAutoCheckin)

      case "sos":
          UserDefaults.standard.set(true, forKey: "pending_watch_sos")
          UserDefaults.standard.set("sos", forKey: "watch_last_action")
          UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "watch_last_action_ts")
          self.sendLocalNotification(title: "紧急求助", body: "Apple Watch 发起了 SOS 紧急求助")
          self.notifyFlutterWatchSOS()

      default:
          break
      }
  }

  /// 【v1.93.2 修复】监听可达性变化
  func sessionReachabilityDidChange(_ session: WCSession) {
      print("[iOS AppDelegate] 📡 WCSession 可达性变化: isReachable=\(session.isReachable)")
  }
}
