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
  /// 【2026-07-15 修复】暂存 Watch sendMessage 的 replyHandler，待 Flutter 真正完成签到后回包结果
  /// （替代单纯「已收到」回包，让 Watch 红心→绿心不再依赖 transferUserInfo 单向队列）
  private var pendingCheckinReplyHandler: (([String: Any]) -> Void)?
  /// 【2026-07-15 修复】replyHandler 超时兜底计时器，避免 Watch 永远等待
  private var checkinReplyTimeoutTimer: Timer?
  /// 【2026-07-16 修复】后台任务 ID：收到 Watch 签到时申请 iOS 后台时间窗，
  /// 确保 Flutter(Dart) 在被唤醒/后台时也能跑完网络签到，回包后再释放。
  private var watchCheckinBackgroundTask: UIBackgroundTaskIdentifier = .invalid
  /// 【2026-07-16 修复】Dart 侧 initWatchChannel 是否就绪。
  /// App 被 Watch 冷启动唤醒时 Dart 可能尚未初始化，native invokeMethod 会丢失，
  /// 此时把 clientId 写入 UserDefaults，由 Flutter 侧轮询补发，彻底绕过 messenger 路由不确定性。
  private var watchChannelReady = false
  
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
    
    // 初始化 HealthKit（MethodChannel 已在引擎就绪回调 didInitializeImplicitFlutterEngine 注册）
    if HKHealthStore.isHealthDataAvailable() {
        healthStore = HKHealthStore()
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // MARK: - HealthKit Method Channel

  /// 【v1.97.0 修复】接收引擎级 binaryMessenger（来自 didInitializeImplicitFlutterEngine），
  /// 不再强转 FlutterViewController（implicit engine 模式下 rootViewController 经常为 nil）。
  private func setupHealthKitMethodChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: fallMethodChannel, binaryMessenger: messenger)
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
  /// 【v1.97.0 修复】接收引擎级 binaryMessenger（来自 didInitializeImplicitFlutterEngine），不再强转 VC
  private func setupWatchMethodChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "zaine/watch", binaryMessenger: messenger)
    // 缓存引用，供 notifyFlutterWatchCheckin / notifyFlutterWatchSOS 复用
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
    self.watchChannelReady = true
    print("[AppDelegate] ✅ watchChannelReady=true，Dart 侧 handler 已就绪")
  }

  /// 把签到成功结果(streak/total)通过 transferUserInfo 回包给 Apple Watch
  private func sendWatchAck(args: [String: Any]) {
    guard WCSession.default.activationState == .activated else {
      print("[AppDelegate] ⚠️ WCSession 未激活，无法回包 Watch")
      return
    }
    let ack: [String: Any] = [
      "action": "checkin_ack",
      "client_id": args["client_id"] ?? "",
      "success": args["success"] ?? true,
      "already_done": args["already_done"] ?? false,
      "streak": args["streak"] ?? 0,
      "total": args["total"] ?? 0,
    ]
    // 主路径：可靠队列（后台/transferUserInfo 来源的消息也走这里）
    WCSession.default.transferUserInfo(ack)
    print("[AppDelegate] 📤 已回包 Watch 签到结果(transferUserInfo): client_id=\(args["client_id"] ?? ""), streak=\(args["streak"] ?? 0)")

    // 【2026-07-15 修复】快速回包：若本次签到来自 Watch 的 sendMessage，则通过其 replyHandler 即时回包，
    // 让 Watch 红心→绿心不再依赖 transferUserInfo 单向队列（队列未双向投递时会卡死）。
    if let handler = self.pendingCheckinReplyHandler {
      handler(ack)
      self.pendingCheckinReplyHandler = nil
      self.checkinReplyTimeoutTimer?.invalidate()
      print("[AppDelegate] ⚡ 已通过 sendMessage replyHandler 即时回包 Watch 签到结果")
    }
    self.endWatchCheckinBackgroundTask()
  }

  /// 【v1.97.0 修复】Watch 主动请求当前连续/累计签到天数 → 向 Flutter 查询后回包
  private func notifyFlutterWatchStatus(result: @escaping ([String: Any]) -> Void) {
    guard let channel = self.watchChannel else {
      // 不回包（避免用 0/0 覆盖手表已有的正确值），手表会保留本地持久化的最新已知值
      print("[AppDelegate] ⚠️ watchChannel 未初始化，暂不回包 Watch 状态查询")
      return
    }
    DispatchQueue.main.async {
      channel.invokeMethod("queryWatchStatus", arguments: nil) { response in
        guard let dict = response as? [String: Any],
              let streak = dict["streak"] as? Int,
              let total = dict["total"] as? Int else {
          // 返回格式异常时不回包，手表保留已有正确值
          print("[AppDelegate] ⚠️ Watch 状态查询返回格式异常，暂不回包")
          return
        }
        result(["streak": streak, "total": total])
      }
    }
  }

  // MARK: - Background Task 辅助
  /// 【2026-07-16 修复】收到 Watch 签到时申请后台时间窗，确保 Dart 在后台/被唤醒时能跑完网络签到
  private func startWatchCheckinBackgroundTask() {
      guard watchCheckinBackgroundTask == .invalid else { return }
      watchCheckinBackgroundTask = UIApplication.shared.beginBackgroundTask(withName: "watch-checkin") {
          // 系统即将回收时强制结束，避免泄漏
          self.endWatchCheckinBackgroundTask()
      }
      print("[AppDelegate] 🔋 已申请后台任务(watch-checkin)，id=\(watchCheckinBackgroundTask.rawValue)")
  }
  private func endWatchCheckinBackgroundTask() {
      if watchCheckinBackgroundTask != .invalid {
          let id = watchCheckinBackgroundTask
          watchCheckinBackgroundTask = .invalid
          UIApplication.shared.endBackgroundTask(id)
          print("[AppDelegate] 🔋 已释放后台任务(watch-checkin)，id=\(id.rawValue)")
      }
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
    // 【v1.97.0 修复】在引擎就绪回调里用「引擎级 binaryMessenger」注册通道，
    // 不再依赖 FlutterViewController（implicit engine 模式下 rootViewController
    // 经常为 nil，导致此前 Watch/HealthKit 通道从未初始化、Watch 签到被静默丢弃）。
    let messenger = engineBridge.applicationRegistrar.messenger()
    self.setupHealthKitMethodChannel(messenger: messenger)
    self.setupWatchMethodChannel(messenger: messenger)
    print("[AppDelegate] ✅ 引擎就绪，Watch/HealthKit MethodChannel 已在 didInitializeImplicitFlutterEngine 注册")

    // 【2026-07-16 修复】重新夺回 WCSession delegate。
    // watch_connectivity 插件在 GeneratedPluginRegistrant.register 时会把自己设为
    // WCSession.default.delegate，覆盖掉 AppDelegate 的 delegate，导致收不到 Watch
    // 发来的签到消息（didReceiveMessage / didReceiveUserInfo 未被调用），手表永远「签到中」。
    // 这里在插件注册之后把 delegate 重新绑定回 AppDelegate，并重新 activate 使其立即生效。
    if WCSession.isSupported() {
      WCSession.default.delegate = self
      WCSession.default.activate()
      print("[AppDelegate] ✅ WCSession delegate 已重新绑定到 AppDelegate（修复 watch_connectivity 覆盖冲突）")
    }
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
          self.startWatchCheckinBackgroundTask()
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

          // 【2026-07-15 修复】暂存 replyHandler，待 Flutter 真正完成签到后由 sendWatchAck 回包结果
          // （不再立即回「已收到」，否则 Watch 会以为签到已成功而误绿心）
          self.checkinReplyTimeoutTimer?.invalidate()
          self.pendingCheckinReplyHandler = replyHandler
          self.checkinReplyTimeoutTimer = Timer.scheduledTimer(withTimeInterval: 12.0, repeats: false) { [weak self] _ in
              guard let self = self else { return }
              if let handler = self.pendingCheckinReplyHandler {
                  print("[AppDelegate] ⏱️ Watch 签到回包超时(12s)，回包失败避免手表无限等待")
                  handler(["success": false, "error": "timeout"])
                  self.pendingCheckinReplyHandler = nil
              }
          }
          if isAutoCheckin {
              print("[AppDelegate] 💓 已暂存心跳签到 replyHandler，等待 Flutter 处理")
          }

      case "status_query":
          // 【v1.97.0 修复】Watch 主动请求当前连续/累计天数 → 查 Flutter 后回包
          print("[AppDelegate] 📥 收到 Watch 状态查询(status_query)")
          self.notifyFlutterWatchStatus { status in
              let ack: [String: Any] = [
                  "action": "status_query_ack",
                  "streak": status["streak"] ?? 0,
                  "total": status["total"] ?? 0,
              ]
              if WCSession.default.activationState == .activated {
                  WCSession.default.transferUserInfo(ack)
                  print("[AppDelegate] 📤 已回包 Watch 状态查询(status_query_ack): streak=\(status["streak"] ?? 0)")
              }
              replyHandler(ack)
          }

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

      // 【2026-07-16 修复】写入 UserDefaults 供 Flutter 轮询兜底（彻底绕过 messenger 路由问题）
      if let cid = clientId {
        UserDefaults.standard.set(cid, forKey: "watch_pending_client_id")
        UserDefaults.standard.set(true, forKey: "pending_watch_checkin")
        print("[AppDelegate] 📝 已写入 UserDefaults 待签到(client_id=\(cid))，供 Flutter 轮询补发")
      }

      // 确保在主线程调用
      DispatchQueue.main.async {
          // 【v1.94.0 修复】优先使用启动时缓存的 channel（implicit engine 下 rootViewController 强转不可靠）
          guard let channel = self.watchChannel else {
              print("[AppDelegate] ⚠️ watchChannel 未初始化（Dart 可能尚未就绪）。改为写入 UserDefaults 由 Flutter 轮询补发，暂不判失败")
              // 【2026-07-16 修复】不再立即回包 false：Dart 侧 initWatchChannel 会轮询
              // UserDefaults 的 pending_watch_checkin + watch_pending_client_id 自行补发签到，
              // 彻底绕过 native→Flutter invokeMethod 在冷启动/后台时的路由不确定性。
              if let cid = clientId {
                  UserDefaults.standard.set(cid, forKey: "watch_pending_client_id")
                  UserDefaults.standard.set(true, forKey: "pending_watch_checkin")
              }
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
          guard let channel = self.watchChannel else {
              print("[AppDelegate] ⚠️ watchChannel 未初始化，Watch SOS 通知失败")
              return
          }
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
          self.startWatchCheckinBackgroundTask()
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

      case "status_query":
          // 【v1.97.0 修复】Watch 主动请求当前连续/累计天数(transferUserInfo 兜底路径)
          print("[AppDelegate] 📥 收到 Watch 状态查询(status_query, transferUserInfo 兜底)")
          self.notifyFlutterWatchStatus { status in
              let ack: [String: Any] = [
                  "action": "status_query_ack",
                  "streak": status["streak"] ?? 0,
                  "total": status["total"] ?? 0,
              ]
              if WCSession.default.activationState == .activated {
                  WCSession.default.transferUserInfo(ack)
                  print("[AppDelegate] 📤 已回包 Watch 状态查询(status_query_ack, transferUserInfo): streak=\(status["streak"] ?? 0)")
              }
          }

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
