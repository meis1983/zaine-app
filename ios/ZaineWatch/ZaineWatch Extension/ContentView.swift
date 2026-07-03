import SwiftUI
import HealthKit

struct ContentView: View {
    @State private var heartRate: String = "--"
    @State private var oxygen: String = "--"
    @State private var lastCheckIn: String = "今天还没签到"
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // 签到按钮
                Button(action: {
                    checkIn()
                }) {
                    VStack {
                        Image(systemName: "hand.wave.fill")
                            .font(.title2)
                        Text("签到")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.green.opacity(0.2))
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                
                // 健康数据速览
                VStack(alignment: .leading, spacing: 8) {
                    Text("健康速览")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        VStack {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.red)
                            Text(heartRate)
                                .font(.caption2)
                        }
                        .frame(maxWidth: .infinity)
                        
                        VStack {
                            Image(systemName: "lungs.fill")
                                .foregroundColor(.blue)
                            Text(oxygen)
                                .font(.caption2)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                
                // SOS 按钮
                Button(action: {
                    sendSOS()
                }) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text("SOS")
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.2))
                    .foregroundColor(.red)
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                
                Text(lastCheckIn)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .onAppear {
            print("[Watch UI] ✅ ContentView 已显示（Watch App 已启动）")
            print("[Watch UI] WCSession.isSupported=\(WCSession.isSupported()), isReachable=\(WCSession.default.isReachable)")
        }
    }
    
    private func checkIn() {
        // 发送签到消息到 iOS App
        print("[Watch UI] 📨 用户点击签到，发送 WatchCheckIn 通知")
        NotificationCenter.default.post(name: NSNotification.Name("WatchCheckIn"), object: nil)
        lastCheckIn = "刚刚签到"
    }
    
    private func sendSOS() {
        // 发送 SOS 消息到 iOS App
        print("[Watch UI] 🚨 用户点击 SOS，发送 WatchSOS 通知")
        NotificationCenter.default.post(name: NSNotification.Name("WatchSOS"), object: nil)
    }
}

#Preview {
    ContentView()
}
