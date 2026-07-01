import WatchKit
import WatchConnectivity

class ExtensionDelegate: NSObject, WKExtensionDelegate, WCSessionDelegate {
    func applicationDidFinishLaunching() {
        // 初始化 Watch Connectivity
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }
    
    // MARK: - WCSessionDelegate
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        // Watch Connectivity 激活完成
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        // iOS App 可达性变化
    }
    
    // 接收 iOS App 发送的消息
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        // 处理来自 iOS App 的消息
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        // 处理来自 iOS App 的消息，并回复
        replyHandler(["status": "received"])
    }
}
