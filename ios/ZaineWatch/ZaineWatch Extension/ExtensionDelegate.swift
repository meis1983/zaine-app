import WatchKit
import WatchConnectivity

class ExtensionDelegate: NSObject, WKExtensionDelegate, WCSessionDelegate {
    
    func applicationDidFinishLaunching() {
        print("[Watch Extension] ✅ applicationDidFinishLaunching 已调用")
        
        // 初始化 Watch Connectivity
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
            print("[Watch Extension] ✅ WCSession 已激活")
        } else {
            print("[Watch Extension] ❌ WCSession 不支持")
        }
        
        // 【v1.93.2 关键修复】监听 ContentView 的签到/SOS 通知，通过 WCSession 转发到手机
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("WatchCheckIn"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("[Watch Extension] 📨 收到 WatchCheckIn 通知，准备转发到手机")
            self?.sendMessageToPhone(action: "checkin")
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("WatchSOS"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("[Watch Extension] 🚨 收到 WatchSOS 通知，准备转发到手机")
            self?.sendMessageToPhone(action: "sos")
        }
        
        print("[Watch Extension] ✅ 通知监听已注册（WatchCheckIn + WatchSOS）")
    }
    
    // MARK: - 通过 WCSession 发送消息到手机
    private func sendMessageToPhone(action: String) {
        print("[Watch Extension] 📡 尝试发送 action=\(action) 到手机，isReachable=\(WCSession.default.isReachable)")
        
        guard WCSession.default.isReachable else {
            print("[Watch Extension] ⚠️ 手机不可达，使用 transferUserInfo 兜底")
            let message = ["action": action, "timestamp": Date().timeIntervalSince1970] as [String : Any]
            WCSession.default.transferUserInfo(message)
            print("[Watch Extension] 📦 transferUserInfo 已发送（action=\(action)）")
            return
        }
        
        let message = ["action": action, "timestamp": Date().timeIntervalSince1970] as [String : Any]
        WCSession.default.sendMessage(message, replyHandler: { reply in
            print("[Watch Extension] ✅ 手机已确认收到 action=\(action)，reply=\(reply)")
        }) { error in
            print("[Watch Extension] ❌ sendMessage 失败: \(error.localizedDescription)，尝试 transferUserInfo 兜底")
            WCSession.default.transferUserInfo(message)
            print("[Watch Extension] 📦 transferUserInfo 已发送（action=\(action)）")
        }
    }
    
    // MARK: - WCSessionDelegate
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("[Watch Extension] WCSession 激活状态: \(activationState.rawValue)，error=\(error?.localizedDescription ?? "nil")")
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        print("[Watch Extension] 📡 手机可达性变化: isReachable=\(session.isReachable)")
    }
    
    // 接收 iOS App 发送的消息
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        print("[Watch Extension] 📥 收到手机消息: \(message)")
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        print("[Watch Extension] 📥 收到手机消息（需回复）: \(message)")
        replyHandler(["status": "received"])
    }
}
