import UIKit
import WatchConnectivity

@main
class AppDelegate: UIResponder, UIApplicationDelegate, WCSessionDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // 初始化 Watch Connectivity
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
        return true
    }
    
    // MARK: - WCSessionDelegate
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        // Watch Connectivity 激活完成
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        // Session 变为非活跃状态
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        // Session 停用，重新激活
        WCSession.default.activate()
    }
    
    // 接收 Watch 发送的消息
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        // 处理来自 Watch 的消息
        if message["action"] as? String == "checkIn" {
            // 处理签到
            NotificationCenter.default.post(name: NSNotification.Name("WatchDidCheckIn"), object: nil)
        } else if message["action"] as? String == "sos" {
            // 处理 SOS
            NotificationCenter.default.post(name: NSNotification.Name("WatchDidTriggerSOS"), object: nil)
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        // 处理来自 Watch 的消息，并回复
        didReceiveMessage(message)
        replyHandler(["status": "received"])
    }
}
