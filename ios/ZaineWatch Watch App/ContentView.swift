//
//  ContentView.swift
//  ZaineWatch Watch App
//
//  【v1.94.0 重做】年轻化酷炫 UI：大号动画签到按钮 + 成功庆祝态 + 健康速览卡片
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var watchManager: WatchConnectivityManager
    @State private var showSOSConfirmation = false
    @State private var pulse = false

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                // ===== Header =====
                HStack(spacing: 6) {
                    Text("在呢+")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    // 连接状态小圆点（绿=可达 / 灰=后台守护中）
                    HStack(spacing: 3) {
                        Circle()
                            .fill(watchManager.isReachable ? Color.green : Color.gray)
                            .frame(width: 7, height: 7)
                        Text(watchManager.isReachable ? "在线" : "守护中")
                            .font(.system(size: 9))
                            .foregroundColor(watchManager.isReachable ? .green : .gray)
                    }
                }

                // ===== 签到主区域 =====
                if watchManager.checkInSuccess {
                    // ✅ 成功庆祝态
                    VStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 46))
                            .foregroundColor(.green)
                            .scaleEffect(pulse ? 1.12 : 1.0)
                            .onAppear { startPulse() }
                        Text(watchManager.checkInAlreadyDone ? "今日已签到" : "签到成功")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                        HStack(spacing: 14) {
                            VStack(spacing: 1) {
                                Text("🔥 \(watchManager.checkInStreak)")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.orange)
                                Text("连续天")
                                    .font(.system(size: 9))
                                    .foregroundColor(.gray)
                            }
                            VStack(spacing: 1) {
                                Text("\(watchManager.checkInTotal)")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.cyan)
                                Text("累计天")
                                    .font(.system(size: 9))
                                    .foregroundColor(.gray)
                            }
                        }
                        if let last = watchManager.lastCheckIn {
                            Text("最后 \(last)")
                                .font(.system(size: 9))
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(
                            colors: [Color.green.opacity(0.22), Color.teal.opacity(0.12)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .cornerRadius(16)
                } else {
                    // 大号动画签到按钮
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            watchManager.sendCheckIn()
                        }
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: "hand.wave.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                                .scaleEffect(pulse ? 1.08 : 1.0)
                                .onAppear { startPulse() }
                            Text(watchManager.lastAction == "签到中..." ? "签到中..." : "我很好 · 签到")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            LinearGradient(
                                colors: [Color.green, Color.teal],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(18)
                        .shadow(color: .green.opacity(0.5), radius: pulse ? 12 : 4, x: 0, y: 0)
                    }
                .buttonStyle(PlainButtonStyle())
                .opacity(watchManager.lastAction == "签到中..." ? 0.7 : 1.0)
                }

                // ===== 【P0】智能心跳守护状态条 =====
                HStack(spacing: 6) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 13))
                        .foregroundColor(watchManager.isHeartbeatGuardian ? .red : .gray)
                        .scaleEffect(watchManager.isHeartbeatGuardian ? 1.1 : 1.0)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(watchManager.autoCheckInSuccess
                             ? "今日心跳打卡已完成 ✅"
                             : "心跳守护中 · 戴着表就自动签到")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(watchManager.autoCheckInSuccess ? .green : .cyan)
                        if watchManager.lastHeartRate > 0 {
                            Text("实时心率 \(Int(watchManager.lastHeartRate)) bpm")
                                .font(.system(size: 9))
                                .foregroundColor(.gray)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.06))
                .cornerRadius(10)

                // ===== 健康速览 =====
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.red)
                        Text("健康速览")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.cyan)
                    }

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                        if let heartRate = watchManager.healthData["heart_rate"] as? String {
                            HealthItemView(icon: "heart.fill", value: heartRate, unit: "bpm", color: .red)
                        }
                        if let bloodOxygen = watchManager.healthData["blood_oxygen"] as? String {
                            HealthItemView(icon: "lungs.fill", value: bloodOxygen, unit: "%", color: .blue)
                        }
                        if let hrv = watchManager.healthData["hrv"] as? String {
                            HealthItemView(icon: "waveform.path.ecg", value: hrv, unit: "ms", color: .orange)
                        }
                        if let temperature = watchManager.healthData["temperature"] as? String {
                            HealthItemView(icon: "thermometer", value: temperature, unit: "°C", color: .yellow)
                        }
                        if let sleep = watchManager.healthData["sleep"] as? String {
                            HealthItemView(icon: "bed.double.fill", value: sleep, unit: "h", color: .purple)
                        }
                        if let menstrual = watchManager.healthData["menstrual"] as? String {
                            HealthItemView(icon: "drop.fill", value: menstrual, unit: "", color: .pink)
                        }
                    }
                }
                .padding(.top, 4)

                Spacer(minLength: 8)

                // ===== SOS 紧急求助 =====
                Button(action: {
                    showSOSConfirmation = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 18))
                        Text("SOS 紧急求助")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.red.opacity(0.92))
                    .cornerRadius(14)
                }
                .buttonStyle(PlainButtonStyle())
                .alert("确认发送 SOS 紧急求助？", isPresented: $showSOSConfirmation) {
                    Button("确认发送", role: .destructive) {
                        watchManager.sendSOS()
                    }
                    Button("取消", role: .cancel) {}
                }
            }
            .padding(12)
        }
        .onAppear {
            watchManager.requestHealthData()
            watchManager.startHeartRateMonitoring()
        }
    }

    /// 启动柔和呼吸动画（用于签到图标与阴影）
    private func startPulse() {
        withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
            pulse = true
        }
    }
}

struct HealthItemView: View {
    let icon: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                }
            }
            Spacer()
        }
        .padding(8)
        .background(Color.white.opacity(0.08))
        .cornerRadius(8)
    }
}

#Preview {
    ContentView()
        .environmentObject(WatchConnectivityManager.shared)
}
