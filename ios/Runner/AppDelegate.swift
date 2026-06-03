import Flutter
import UIKit
import WatchConnectivity
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, WCSessionDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 初始化 WatchConnectivity
    if WCSession.isSupported() {
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  // 处理来自 Watch 的消息
  func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
      guard let action = message["action"] as? String else {
          replyHandler(["success": false, "error": "missing_action"])
          return
      }

      switch action {
      case "checkin":
          UserDefaults.standard.set(true, forKey: "pending_watch_checkin")
          UserDefaults.standard.set("checkin", forKey: "watch_last_action")
          UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "watch_last_action_ts")
          replyHandler(["success": true])

      case "sos":
          // Watch 端紧急求助 → 记录到 UserDefaults，Flutter 端读取后触发 SOS
          UserDefaults.standard.set(true, forKey: "pending_watch_sos")
          UserDefaults.standard.set("sos", forKey: "watch_last_action")
          UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "watch_last_action_ts")
          // 发送本地通知提醒用户
          self.sendLocalNotification(title: "紧急求助", body: "Apple Watch 发起了 SOS 紧急求助")
          replyHandler(["success": true])

      default:
          UserDefaults.standard.set(action, forKey: "watch_last_action")
          UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "watch_last_action_ts")
          replyHandler(["success": true])
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
  
  func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
  func sessionDidBecomeInactive(_ session: WCSession) {}
  func sessionDidDeactivate(_ session: WCSession) {
      session.activate()
  }
}
