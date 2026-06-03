import SwiftUI
import WatchConnectivity

@main
struct ZaineWatchApp: App {
    @StateObject private var connectivityManager = WatchConnectivityManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(connectivityManager)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var connectivityManager: WatchConnectivityManager
    @State private var isAnimating = false
    @State private var checkinStatus: String = "我在呢"
    @State private var lastCheckinTime: Date?
    
    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            
            // 核心签到按钮（心跳呼吸感 UI）
            Button(action: {
                performCheckin()
            }) {
                ZStack {
                    // 呼吸光晕背景
                    Circle()
                        .fill(Color.orange.opacity(0.2))
                        .frame(width: 100, height: 100)
                        .scaleEffect(isAnimating ? 1.2 : 0.9)
                        .animation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimating)
                    
                    Circle()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [Color(hex: "FF9A8B"), Color(hex: "FF6A88")]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 80, height: 80)
                        .shadow(radius: 5)
                    
                    VStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .scaleEffect(isAnimating ? 1.1 : 1.0)
                        
                        Text(checkinStatus)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            .onAppear {
                isAnimating = true
            }
            
            Spacer()
            
            if let lastTime = lastCheckinTime {
                Text("上次签到: \(timeAgo(lastTime))")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }
        }
        .navigationTitle("在呢+")
    }
    
    func performCheckin() {
        // 触感反馈：模拟真实心跳
        WKInterfaceDevice.current().play(.heartbeat)
        
        checkinStatus = "同步中..."
        
        // 发送给手机端
        connectivityManager.sendMessage(["action": "checkin", "timestamp": Date().timeIntervalSince1970]) { success in
            DispatchQueue.main.async {
                if success {
                    checkinStatus = "已平安"
                    lastCheckinTime = Date()
                    // 成功后延时恢复
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        checkinStatus = "我在呢"
                    }
                } else {
                    checkinStatus = "重试一下"
                }
            }
        }
    }
    
    func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// 手机端通信管理
class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    @Published var isReachable = false
    
    override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
    }
    
    func sendMessage(_ message: [String: Any], completion: @escaping (Bool) -> Void) {
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: { _ in
                completion(true)
            }, errorHandler: { _ in
                completion(false)
            })
        } else {
            completion(false)
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}
