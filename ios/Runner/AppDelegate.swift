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

    // 【v1.97.3 SOS 后台】注册可操作通知类别：手表 SOS → 手机弹🆘通知(带"立即求助"按钮)
    // 用户点击按钮/横幅 → App 回到前台 → userNotificationCenter(didReceive:) 驱动 Flutter SOS 流程
    let sosAction = UNNotificationAction(
        identifier: "SOS_ACTION",
        title: "立即求助",
        options: [.foreground]
    )
    let sosCategory = UNNotificationCategory(
        identifier: "SOS_CATEGORY",
        actions: [sosAction],
        intentIdentifiers: [],
        options: []
    )
    UNUserNotificationCenter.current().setNotificationCategories([sosCategory])
    UNUserNotificationCenter.current().delegate = self

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
        case "getWristTemperature":
            self.getWristTemperature(result: result)
        case "getFullHealthSummary":
            // 【v1.97.2】全量健康镜像：一次性读取 Apple Watch 同步进 HealthKit 的所有可读指标
            self.getFullHealthSummary(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
  }
  
  // MARK: - 手腕温度（Apple Watch 同步）
  /// 【v1.97.2 修复】读取由 Apple Watch 同步到 iPhone HealthKit 的手腕温度。
  /// health Flutter 包未暴露 APPLE_SLEEPING_WRIST_TEMPERATURE 类型，故走原生桥。
  /// 返回: {"value": 摄氏度(Double), "date": ISO8601}；无数据/未授权返回 nil（Dart 侧显示 "--"）。
  private func getWristTemperature(result: @escaping FlutterResult) {
    guard HKHealthStore.isHealthDataAvailable() else {
      result(FlutterError(code: "NO_HEALTH", message: "HealthKit unavailable", details: nil))
      return
    }
    guard let healthStore = self.healthStore else {
      result(FlutterError(code: "NO_HEALTH", message: "HealthKit store not initialized", details: nil))
      return
    }
    // 手腕温度需 iOS 16+（HKQuantityTypeIdentifierAppleSleepingWristTemperature 始于 iOS 16）
    guard #available(iOS 16.0, *) else {
      result(nil)
      return
    }
    let type = HKQuantityType.quantityType(forIdentifier: .appleSleepingWristTemperature)!
    // 首次调用可能触发一次性系统授权弹窗；已决定则不再弹。
    healthStore.requestAuthorization(toShare: nil, read: [type]) { granted, _ in
      guard granted else {
        result(nil)
        return
      }
      let now = Date()
      let start = Calendar.current.date(byAdding: .day, value: -7, to: now)!
      let predicate = HKQuery.predicateForSamples(withStart: start, end: now, options: .strictStartDate)
      let sort = [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
      let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 1, sortDescriptors: sort) { _, samples, error in
        guard error == nil, let sample = samples?.first as? HKQuantitySample else {
          result(nil)
          return
        }
        let celsius = sample.quantity.doubleValue(for: HKUnit.degreeCelsius())
        let dateStr = ISO8601DateFormatter().string(from: sample.endDate)
        result(["value": celsius, "date": dateStr])
      }
      healthStore.execute(query)
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
          // Watch 端紧急求助
          UserDefaults.standard.set(true, forKey: "pending_watch_sos")
          UserDefaults.standard.set("sos", forKey: "watch_last_action")
          UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "watch_last_action_ts")
          if UIApplication.shared.applicationState == .active {
              // App 前台：立即驱动 Flutter SOS 流程（5秒倒计时 + 自动发短信/拨号）
              self.notifyFlutterWatchSOS()
          } else {
              // App 后台/锁屏：弹🆘可操作通知，用户点按后 userNotificationCenter(didReceive:) 再驱动
              self.sendLocalNotification(
                  title: "🆘 手表紧急求助",
                  body: "Apple Watch 已发起 SOS，点击立即展开求助倒计时并自动联系守护人")
          }
          replyHandler(["success": true])

      case "request_health_data":
          // 【v1.97.3 修复 Issue A】手表健康速览主动拉取：触发 Flutter 同步并推送健康数据到 Watch
          print("[AppDelegate] 📥 收到 Watch 健康数据请求(request_health_data)")
          self.notifyFlutterRequestHealth()
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

  /// 【v1.97.3 修复 Issue A】通知 Flutter 端按需同步健康数据并推送到 Watch
  /// 手表健康速览页主动发起 request_health_data 时调用
  private func notifyFlutterRequestHealth() {
      DispatchQueue.main.async {
          guard let channel = self.watchChannel else {
              print("[AppDelegate] ⚠️ watchChannel 未初始化，无法响应手表健康请求")
              return
          }
          channel.invokeMethod("requestHealthData", arguments: nil) { result in
              DispatchQueue.main.async {
                  if let error = result as? FlutterError {
                      print("[AppDelegate] 手表健康请求 Flutter 回调失败: \(error.message ?? "unknown")")
                  } else {
                      print("[AppDelegate] ✅ 已通知 Flutter 同步并推送健康数据到 Watch")
                  }
              }
          }
      }
  }

  // 【v1.97.3 SOS 后台】发送手表 SOS 可操作通知（带"立即求助"按钮，点击自动展开倒计时）
  private func sendLocalNotification(title: String, body: String) {
      let content = UNMutableNotificationContent()
      content.title = title
      content.body = body
      content.sound = .defaultCritical
      content.categoryIdentifier = "SOS_CATEGORY"
      content.userInfo = ["zaine_sos": true]

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
  
  // 【v1.97.3 SOS 后台】用户点按 SOS 通知(或"立即求助"按钮) → App 回到前台 → 驱动 Flutter SOS 流程
  // override 是因为 FlutterAppDelegate 父类已声明 UNUserNotificationCenterDelegate 并实现该方法
  // 父类无 firebase_messaging 时默认只调 completionHandler()，不会做任何额外动作，override 安全
  override func userNotificationCenter(
      _ center: UNUserNotificationCenter,
      didReceive response: UNNotificationResponse,
      withCompletionHandler completionHandler: @escaping () -> Void
  ) {
      let category = response.notification.request.content.categoryIdentifier
      if category == "SOS_CATEGORY" {
          print("[AppDelegate] 🚨 用户点按 SOS 通知，触发紧急求助流程")
          // App 已前台、引擎存活 → 直接驱动 Flutter（5秒倒计时 + 自动发短信/拨号）
          self.notifyFlutterWatchSOS()
          // 保持 flag，供 Dart 在引擎尚未就绪的极端情况下兜底
          UserDefaults.standard.set(true, forKey: "pending_watch_sos")
      }
      // 本项目未使用 FCM 远程推送，无需转发给 super；直接完成回调即可。
      completionHandler()
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
          if UIApplication.shared.applicationState == .active {
              // App 前台：立即驱动 Flutter SOS 流程
              self.notifyFlutterWatchSOS()
          } else {
              // App 后台/锁屏：弹🆘可操作通知，用户点按后再驱动
              self.sendLocalNotification(
                  title: "🆘 手表紧急求助",
                  body: "Apple Watch 已发起 SOS，点击立即展开求助倒计时并自动联系守护人")
          }

      case "request_health_data":
          // 【v1.97.3 修复 Issue A】手表健康速览主动拉取：触发 Flutter 同步并推送健康数据到 Watch
          print("[AppDelegate] 📥 收到 Watch 健康数据请求(request_health_data, transferUserInfo 兜底)")
          self.notifyFlutterRequestHealth()

      default:
          break
      }
  }

  /// 【v1.93.2 修复】监听可达性变化
  func sessionReachabilityDidChange(_ session: WCSession) {
      print("[iOS AppDelegate] 📡 WCSession 可达性变化: isReachable=\(session.isReachable)")
  }
}

// MARK: - ==================== 全量健康镜像 HealthMirror (v1.97.2) ====================
//
// 目标：把 Apple Watch 系统级同步进 iPhone HealthKit 的**全部可读**健康指标一次性读出，
//      让「在呢+」健康页 ≈ Apple Watch 健康页，用户不必再回系统「健康」App 查看。
//
// 设计要点：
//  1) 单一数据源：Dart 侧 HealthService 只调 getFullHealthSummary，
//     杜绝「health 包 + 原生桥」两套逻辑分叉（历史上多次因此出现数据不一致）。
//  2) 容错优先：任一项查询失败/未授权 → 该 key 缺失，绝不抛错、绝不影响其他项。
//  3) 部署目标 iOS 15.0 → 仅 iOS 16+ 符号需 #available 守卫。
//  4) 全部 key 扁平 snake_case，兼容既有 key（heart_rate / steps / sleep_* 等）。

/// 线程安全结果收集盒：HealthKit 各查询回调来自不同队列，必须加锁写入。
private final class ZaiMirrorBox {
  private let lock = NSLock()
  private var data: [String: Any] = [:]
  func set(_ key: String, _ value: Any?) {
    guard let v = value else { return }
    lock.lock(); data[key] = v; lock.unlock()
  }
  func snapshot() -> [String: Any] {
    lock.lock(); let d = data; lock.unlock(); return d
  }
}

extension AppDelegate {

  // MARK: - 入口

  /// 一次性读取全部可读健康指标，返回扁平 Map。
  func getFullHealthSummary(result: @escaping FlutterResult) {
    guard HKHealthStore.isHealthDataAvailable(), let store = self.healthStore else {
      result(FlutterError(code: "NO_HEALTH", message: "HealthKit unavailable", details: nil))
      return
    }
    let readTypes = self.zaiMirrorReadTypes()
    store.requestAuthorization(toShare: nil, read: readTypes) { _, _ in
      // 授权结果不判断：HealthKit 出于隐私从不告知读权限真实状态，
      // 未授权类型查询会返回空数组，天然降级，不阻塞其余指标。
      self.zaiRunMirrorQueries(store: store, result: result)
    }
  }

  // MARK: - 读权限清单

  private func zaiMirrorReadTypes() -> Set<HKObjectType> {
    var t = Set<HKObjectType>()
    func q(_ id: HKQuantityTypeIdentifier) {
      if let x = HKObjectType.quantityType(forIdentifier: id) { t.insert(x) }
    }
    func c(_ id: HKCategoryTypeIdentifier) {
      if let x = HKObjectType.categoryType(forIdentifier: id) { t.insert(x) }
    }

    // ① 活动（三环）
    q(.stepCount); q(.distanceWalkingRunning); q(.activeEnergyBurned); q(.basalEnergyBurned)
    q(.appleExerciseTime); q(.appleStandTime); q(.flightsClimbed)
    c(.appleStandHour)
    t.insert(HKObjectType.activitySummaryType())

    // ② 步行稳定性
    q(.walkingSpeed); q(.walkingStepLength); q(.walkingAsymmetryPercentage)
    q(.walkingDoubleSupportPercentage); q(.sixMinuteWalkTestDistance); q(.stairAscentSpeed)
    q(.appleWalkingSteadiness)

    // ③ 心脏
    q(.heartRate); q(.restingHeartRate); q(.walkingHeartRateAverage)
    q(.heartRateVariabilitySDNN); q(.vo2Max)
    c(.highHeartRateEvent); c(.lowHeartRateEvent); c(.irregularHeartRhythmEvent)
    t.insert(HKObjectType.electrocardiogramType())          // 心电图（iOS 14+ 可读）
    if #available(iOS 16.0, *) { q(.atrialFibrillationBurden) }

    // ④ 呼吸
    q(.oxygenSaturation); q(.respiratoryRate)

    // ⑤ 身体
    q(.bodyTemperature); q(.bloodPressureSystolic); q(.bloodPressureDiastolic)
    q(.bodyMass); q(.height); q(.bodyMassIndex); q(.bodyFatPercentage)
    if #available(iOS 16.0, *) { q(.appleSleepingWristTemperature) }

    // ⑥ 听力
    q(.environmentalAudioExposure); q(.headphoneAudioExposure)
    c(.environmentalAudioExposureEvent)
    if #available(iOS 14.2, *) { c(.headphoneAudioExposureEvent) }

    // ⑦ 睡眠 / 正念
    c(.sleepAnalysis); c(.mindfulSession)

    // ⑧ 训练
    t.insert(HKObjectType.workoutType())

    return t
  }

  // MARK: - 查询编排

  private func zaiRunMirrorQueries(store: HKHealthStore, result: @escaping FlutterResult) {
    let box = ZaiMirrorBox()
    let group = DispatchGroup()
    let cal = Calendar.current
    let now = Date()
    let todayStart = cal.startOfDay(for: now)
    let d7 = cal.date(byAdding: .day, value: -7, to: now) ?? now
    let d30 = cal.date(byAdding: .day, value: -30, to: now) ?? now
    // 睡眠窗：昨日 18:00 → 现在（与 Dart 侧 v1.97.2 口径一致，避免 48h 窗口串天）
    let yst = cal.date(byAdding: .day, value: -1, to: now) ?? now
    let sleepStart = cal.date(bySettingHour: 18, minute: 0, second: 0, of: yst) ?? d7

    let bpm = HKUnit.count().unitDivided(by: .minute())
    let mps = HKUnit.meter().unitDivided(by: .second())

    // ---------- ① 活动（今日累计） ----------
    zaiSum(store, .stepCount, .count(), todayStart, now, group) { box.set("steps", Int($0)) }
    zaiSum(store, .distanceWalkingRunning, .meter(), todayStart, now, group) { box.set("distance_m", Int($0)) }
    zaiSum(store, .activeEnergyBurned, .kilocalorie(), todayStart, now, group) { box.set("active_energy", Int($0)) }
    zaiSum(store, .basalEnergyBurned, .kilocalorie(), todayStart, now, group) { box.set("basal_energy", Int($0)) }
    zaiSum(store, .appleExerciseTime, .minute(), todayStart, now, group) { box.set("exercise_minutes", Int($0)) }
    zaiSum(store, .flightsClimbed, .count(), todayStart, now, group) { box.set("flights_climbed", Int($0)) }
    zaiActivityRings(store, cal, now, group, box)

    // ---------- ② 步行稳定性（近 7 天最新值） ----------
    zaiLatest(store, .walkingSpeed, mps, d30, now, group) { v, _ in box.set("walking_speed_mps", v) }
    zaiLatest(store, .walkingStepLength, HKUnit.meterUnit(with: .centi), d30, now, group) { v, _ in box.set("walking_step_length_cm", v) }
    zaiLatest(store, .walkingAsymmetryPercentage, .percent(), d30, now, group) { v, _ in box.set("walking_asymmetry_pct", v * 100) }
    zaiLatest(store, .walkingDoubleSupportPercentage, .percent(), d30, now, group) { v, _ in box.set("walking_double_support_pct", v * 100) }
    zaiLatest(store, .sixMinuteWalkTestDistance, .meter(), d30, now, group) { v, _ in box.set("six_min_walk_m", v) }
    zaiLatest(store, .stairAscentSpeed, mps, d30, now, group) { v, _ in box.set("stair_ascent_speed_mps", v) }
    zaiLatest(store, .appleWalkingSteadiness, .percent(), d30, now, group) { v, _ in box.set("walking_steadiness_pct", v * 100) }

    // ---------- ③ 心脏 ----------
    zaiLatest(store, .heartRate, bpm, d7, now, group) { v, d in
      box.set("heart_rate", v); box.set("heart_rate_date", ZaiMirrorFmt.iso(d))
    }
    zaiStats(store, .heartRate, bpm, todayStart, now, group) { mn, mx, avg in
      box.set("heart_rate_min", mn); box.set("heart_rate_max", mx); box.set("heart_rate_avg", avg)
    }
    zaiLatest(store, .restingHeartRate, bpm, d7, now, group) { v, _ in box.set("resting_heart_rate", v) }
    zaiLatest(store, .walkingHeartRateAverage, bpm, d7, now, group) { v, _ in box.set("walking_heart_rate_avg", v) }
    zaiLatest(store, .heartRateVariabilitySDNN, HKUnit.secondUnit(with: .milli), d7, now, group) { v, _ in box.set("hrv", v) }
    zaiLatest(store, .vo2Max, HKUnit(from: "ml/kg*min"), d30, now, group) { v, _ in box.set("vo2max", v) }
    zaiCount(store, .highHeartRateEvent, d30, now, group) { box.set("high_hr_events_30d", $0) }
    zaiCount(store, .lowHeartRateEvent, d30, now, group) { box.set("low_hr_events_30d", $0) }
    zaiCount(store, .irregularHeartRhythmEvent, d30, now, group) { box.set("irregular_rhythm_events_30d", $0) }
    zaiEcg(store, d30, now, group, box)
    if #available(iOS 16.0, *) {
      zaiLatest(store, .atrialFibrillationBurden, .percent(), d30, now, group) { v, _ in box.set("afib_burden_pct", v * 100) }
    }

    // ---------- ④ 呼吸 ----------
    zaiLatest(store, .oxygenSaturation, .percent(), d7, now, group) { v, d in
      box.set("blood_oxygen", v * 100); box.set("blood_oxygen_date", ZaiMirrorFmt.iso(d))
    }
    zaiLatest(store, .respiratoryRate, bpm, d7, now, group) { v, _ in box.set("respiratory_rate", v) }

    // ---------- ⑤ 身体 ----------
    zaiLatest(store, .bodyTemperature, .degreeCelsius(), d30, now, group) { v, _ in box.set("body_temperature", v) }
    zaiLatest(store, .bloodPressureSystolic, .millimeterOfMercury(), d30, now, group) { v, d in
      box.set("bp_systolic", v); box.set("bp_date", ZaiMirrorFmt.iso(d))
    }
    zaiLatest(store, .bloodPressureDiastolic, .millimeterOfMercury(), d30, now, group) { v, _ in box.set("bp_diastolic", v) }
    zaiLatest(store, .bodyMass, HKUnit.gramUnit(with: .kilo), d30, now, group) { v, _ in box.set("body_mass_kg", v) }
    zaiLatest(store, .height, .meter(), d30, now, group) { v, _ in box.set("height_cm", v * 100) }
    zaiLatest(store, .bodyMassIndex, .count(), d30, now, group) { v, _ in box.set("bmi", v) }
    zaiLatest(store, .bodyFatPercentage, .percent(), d30, now, group) { v, _ in box.set("body_fat_pct", v * 100) }
    if #available(iOS 16.0, *) {
      zaiLatest(store, .appleSleepingWristTemperature, .degreeCelsius(), d7, now, group) { v, d in
        box.set("wrist_temperature", v); box.set("wrist_temperature_date", ZaiMirrorFmt.iso(d))
      }
    }

    // ---------- ⑥ 听力 ----------
    // 注意：音量暴露属 discreteEquivalentContinuousLevel 聚合风格，
    // 用 HKStatisticsQuery 的 discreteAverage 可能抛 ObjC 异常直接崩溃，故只取最新样本。
    let dbUnit = HKUnit.decibelAWeightedSoundPressureLevel()
    zaiLatest(store, .environmentalAudioExposure, dbUnit, d7, now, group) { v, d in
      box.set("env_audio_db", v); box.set("env_audio_db_date", ZaiMirrorFmt.iso(d))
    }
    zaiLatest(store, .headphoneAudioExposure, dbUnit, d7, now, group) { v, d in
      box.set("headphone_audio_db", v); box.set("headphone_audio_db_date", ZaiMirrorFmt.iso(d))
    }
    zaiCount(store, .environmentalAudioExposureEvent, d7, now, group) { box.set("env_audio_events_7d", $0) }
    if #available(iOS 14.2, *) {
      zaiCount(store, .headphoneAudioExposureEvent, d7, now, group) { box.set("headphone_audio_events_7d", $0) }
    }

    // ---------- ⑦ 睡眠 / 正念 ----------
    zaiSleep(store, sleepStart, now, group, box)
    zaiMindful(store, d7, now, group, box)

    // ---------- ⑧ 训练 ----------
    zaiWorkouts(store, d7, now, group, box)

    // ---------- 汇总 ----------
    group.notify(queue: .main) {
      var out = box.snapshot()
      out["generated_at"] = ZaiMirrorFmt.iso(now)
      out["mirror_version"] = "1.97.2"
      print("[HealthMirror] ✅ 全量读取完成，共 \(out.count) 项")
      result(out)
    }
  }

  // MARK: - 通用查询工具

  /// 区间累计（cumulative 类型）
  private func zaiSum(_ store: HKHealthStore, _ id: HKQuantityTypeIdentifier, _ unit: HKUnit,
                      _ start: Date, _ end: Date, _ group: DispatchGroup,
                      _ done: @escaping (Double) -> Void) {
    guard let type = HKQuantityType.quantityType(forIdentifier: id) else { return }
    group.enter()
    let pred = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
    let q = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: pred, options: .cumulativeSum) { _, stats, _ in
      defer { group.leave() }
      guard let sum = stats?.sumQuantity() else { return }
      done(sum.doubleValue(for: unit))
    }
    store.execute(q)
  }

  /// 最新一条离散样本
  private func zaiLatest(_ store: HKHealthStore, _ id: HKQuantityTypeIdentifier, _ unit: HKUnit,
                         _ start: Date, _ end: Date, _ group: DispatchGroup,
                         _ done: @escaping (Double, Date) -> Void) {
    guard let type = HKQuantityType.quantityType(forIdentifier: id) else { return }
    group.enter()
    let pred = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
    let sort = [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
    let q = HKSampleQuery(sampleType: type, predicate: pred, limit: 1, sortDescriptors: sort) { _, samples, _ in
      defer { group.leave() }
      guard let s = samples?.first as? HKQuantitySample else { return }
      done(s.quantity.doubleValue(for: unit), s.endDate)
    }
    store.execute(q)
  }

  /// 区间 min / max / avg（离散类型）
  private func zaiStats(_ store: HKHealthStore, _ id: HKQuantityTypeIdentifier, _ unit: HKUnit,
                        _ start: Date, _ end: Date, _ group: DispatchGroup,
                        _ done: @escaping (Double?, Double?, Double?) -> Void) {
    guard let type = HKQuantityType.quantityType(forIdentifier: id) else { return }
    group.enter()
    let pred = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
    let q = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: pred,
                              options: [.discreteMin, .discreteMax, .discreteAverage]) { _, stats, _ in
      defer { group.leave() }
      guard let s = stats else { return }
      done(s.minimumQuantity()?.doubleValue(for: unit),
           s.maximumQuantity()?.doubleValue(for: unit),
           s.averageQuantity()?.doubleValue(for: unit))
    }
    store.execute(q)
  }

  /// Category 事件计数
  private func zaiCount(_ store: HKHealthStore, _ id: HKCategoryTypeIdentifier,
                        _ start: Date, _ end: Date, _ group: DispatchGroup,
                        _ done: @escaping (Int) -> Void) {
    guard let type = HKCategoryType.categoryType(forIdentifier: id) else { return }
    group.enter()
    let pred = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
    let q = HKSampleQuery(sampleType: type, predicate: pred, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
      defer { group.leave() }
      done(samples?.count ?? 0)
    }
    store.execute(q)
  }

  // MARK: - 专项查询

  /// 活动三环（含目标值）——HKActivitySummary 是唯一能拿到「圆环目标」的接口
  private func zaiActivityRings(_ store: HKHealthStore, _ cal: Calendar, _ now: Date,
                                _ group: DispatchGroup, _ box: ZaiMirrorBox) {
    group.enter()
    var comps = cal.dateComponents([.year, .month, .day], from: now)
    comps.calendar = cal
    let pred = HKQuery.predicateForActivitySummary(with: comps)
    let q = HKActivitySummaryQuery(predicate: pred) { _, summaries, _ in
      defer { group.leave() }
      guard let s = summaries?.first else { return }
      box.set("ring_move_kcal", s.activeEnergyBurned.doubleValue(for: .kilocalorie()))
      box.set("ring_move_goal_kcal", s.activeEnergyBurnedGoal.doubleValue(for: .kilocalorie()))
      box.set("ring_exercise_min", s.appleExerciseTime.doubleValue(for: .minute()))
      box.set("ring_exercise_goal_min", s.appleExerciseTimeGoal.doubleValue(for: .minute()))
      box.set("ring_stand_hours", s.appleStandHours.doubleValue(for: .count()))
      box.set("ring_stand_goal_hours", s.appleStandHoursGoal.doubleValue(for: .count()))
    }
    store.execute(q)
  }

  /// 心电图（iOS 14+ 第三方可读：分类结果 + 平均心率 + 症状标记）
  private func zaiEcg(_ store: HKHealthStore, _ start: Date, _ end: Date,
                      _ group: DispatchGroup, _ box: ZaiMirrorBox) {
    group.enter()
    let type = HKObjectType.electrocardiogramType()
    let pred = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
    let sort = [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
    let q = HKSampleQuery(sampleType: type, predicate: pred, limit: HKObjectQueryNoLimit, sortDescriptors: sort) { _, samples, _ in
      defer { group.leave() }
      guard let list = samples as? [HKElectrocardiogram], let latest = list.first else { return }
      box.set("ecg_count_30d", list.count)
      box.set("ecg_date", ZaiMirrorFmt.iso(latest.endDate))
      box.set("ecg_classification", ZaiMirrorFmt.ecgText(latest.classification))
      if let hr = latest.averageHeartRate?.doubleValue(for: HKUnit.count().unitDivided(by: .minute())) {
        box.set("ecg_avg_bpm", hr)
      }
    }
    store.execute(q)
  }

  /// 睡眠：阶段时长 + 入睡/起床时间 + 睡眠期间心率/血氧/呼吸均值
  private func zaiSleep(_ store: HKHealthStore, _ start: Date, _ end: Date,
                        _ group: DispatchGroup, _ box: ZaiMirrorBox) {
    guard let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return }
    group.enter()
    let pred = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
    let sort = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
    let q = HKSampleQuery(sampleType: type, predicate: pred, limit: HKObjectQueryNoLimit, sortDescriptors: sort) { _, samples, _ in
      defer { group.leave() }
      guard let list = samples as? [HKCategorySample], !list.isEmpty else { return }
      // 原始 rawValue：0=inBed 1=asleepUnspecified 2=awake 3=asleepCore 4=asleepDeep 5=asleepREM
      var inBed = 0.0, core = 0.0, deep = 0.0, rem = 0.0, awake = 0.0, unspecified = 0.0
      var sleepStart: Date? = nil
      var sleepEnd: Date? = nil
      for s in list {
        let mins = s.endDate.timeIntervalSince(s.startDate) / 60.0
        switch s.value {
        case 0: inBed += mins
        case 1: unspecified += mins
        case 2: awake += mins
        case 3: core += mins
        case 4: deep += mins
        case 5: rem += mins
        default: break
        }
        if s.value != 0 && s.value != 2 {
          if sleepStart == nil || s.startDate < sleepStart! { sleepStart = s.startDate }
          if sleepEnd == nil || s.endDate > sleepEnd! { sleepEnd = s.endDate }
        }
      }
      let asleep = core + deep + rem + unspecified
      box.set("sleep_in_bed", Int(inBed.rounded()))
      box.set("sleep_core", Int(core.rounded()))
      box.set("sleep_deep", Int(deep.rounded()))
      box.set("sleep_rem", Int(rem.rounded()))
      box.set("sleep_awake", Int(awake.rounded()))
      box.set("sleep_asleep", Int(asleep.rounded()))
      box.set("sleep_total", Int(asleep.rounded()))
      if let ss = sleepStart { box.set("sleep_bedtime", ZaiMirrorFmt.iso(ss)) }
      if let se = sleepEnd { box.set("sleep_wake_time", ZaiMirrorFmt.iso(se)) }

      // 睡眠区间内的生命体征均值（Apple Watch 夜间监测的核心价值）
      if let ss = sleepStart, let se = sleepEnd, se > ss {
        let bpm = HKUnit.count().unitDivided(by: .minute())
        self.zaiStats(store, .heartRate, bpm, ss, se, group) { _, _, avg in box.set("sleep_heart_rate_avg", avg) }
        self.zaiStats(store, .oxygenSaturation, .percent(), ss, se, group) { _, _, avg in
          if let a = avg { box.set("sleep_spo2_avg", a * 100) }
        }
        self.zaiStats(store, .respiratoryRate, bpm, ss, se, group) { _, _, avg in box.set("sleep_respiratory_avg", avg) }
      }
    }
    store.execute(q)
  }

  /// 正念/呼吸训练
  private func zaiMindful(_ store: HKHealthStore, _ start: Date, _ end: Date,
                          _ group: DispatchGroup, _ box: ZaiMirrorBox) {
    guard let type = HKCategoryType.categoryType(forIdentifier: .mindfulSession) else { return }
    group.enter()
    let pred = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
    let q = HKSampleQuery(sampleType: type, predicate: pred, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
      defer { group.leave() }
      guard let list = samples, !list.isEmpty else { return }
      let total = list.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) / 60.0 }
      box.set("mindful_sessions_7d", list.count)
      box.set("mindful_minutes_7d", Int(total.rounded()))
    }
    store.execute(q)
  }

  /// 训练记录（近 7 天，最多 20 条）
  private func zaiWorkouts(_ store: HKHealthStore, _ start: Date, _ end: Date,
                           _ group: DispatchGroup, _ box: ZaiMirrorBox) {
    group.enter()
    let pred = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
    let sort = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
    let q = HKSampleQuery(sampleType: HKObjectType.workoutType(), predicate: pred, limit: 20, sortDescriptors: sort) { _, samples, _ in
      defer { group.leave() }
      guard let list = samples as? [HKWorkout], !list.isEmpty else { return }
      var arr: [[String: Any]] = []
      for w in list {
        var item: [String: Any] = [
          "type": ZaiMirrorFmt.workoutText(w.workoutActivityType),
          "start": ZaiMirrorFmt.iso(w.startDate),
          "end": ZaiMirrorFmt.iso(w.endDate),
          "minutes": Int((w.duration / 60.0).rounded()),
        ]
        if let e = w.totalEnergyBurned?.doubleValue(for: .kilocalorie()) { item["kcal"] = Int(e.rounded()) }
        if let d = w.totalDistance?.doubleValue(for: .meter()) { item["distance_m"] = Int(d.rounded()) }
        arr.append(item)
      }
      box.set("workouts", arr)
      box.set("workout_count_7d", arr.count)
    }
    store.execute(q)
  }
}

// MARK: - 格式化工具

private enum ZaiMirrorFmt {
  static let isoFormatter = ISO8601DateFormatter()

  static func iso(_ d: Date) -> String { isoFormatter.string(from: d) }

  static func ecgText(_ c: HKElectrocardiogram.Classification) -> String {
    switch c {
    case .sinusRhythm: return "sinus_rhythm"
    case .atrialFibrillation: return "atrial_fibrillation"
    case .inconclusiveHighHeartRate: return "inconclusive_high_hr"
    case .inconclusiveLowHeartRate: return "inconclusive_low_hr"
    case .inconclusivePoorReading: return "inconclusive_poor_reading"
    case .inconclusiveOther: return "inconclusive_other"
    case .unrecognized: return "unrecognized"
    case .notSet: return "not_set"
    @unknown default: return "unknown"
    }
  }

  static func workoutText(_ t: HKWorkoutActivityType) -> String {
    switch t {
    case .walking: return "walking"
    case .running: return "running"
    case .cycling: return "cycling"
    case .swimming: return "swimming"
    case .hiking: return "hiking"
    case .yoga: return "yoga"
    case .traditionalStrengthTraining, .functionalStrengthTraining: return "strength"
    case .highIntensityIntervalTraining: return "hiit"
    case .elliptical: return "elliptical"
    case .rowing: return "rowing"
    case .cardioDance, .socialDance: return "dance"
    case .coreTraining: return "core"
    case .mindAndBody: return "mind_body"
    case .stairClimbing, .stairs: return "stairs"
    default: return "other"
    }
  }
}
