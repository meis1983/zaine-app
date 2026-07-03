//
//  ContentView.swift
//  ZaineWatch Watch App
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var watchManager: WatchConnectivityManager
    @State private var showSOSConfirmation = false

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Header
                HStack {
                    Text("在呢+")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    Circle()
                        .fill(watchManager.isReachable ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                }
                
                // 🆕 诊断信息
                VStack(alignment: .leading, spacing: 2) {
                    Text("状态: \(watchManager.activationState)")
                        .font(.system(size: 9))
                        .foregroundColor(watchManager.activationState.contains("✅") ? .green : .orange)
                    Text("连接: \(watchManager.isReachable ? "可达" : "不可达")")
                        .font(.system(size: 9))
                        .foregroundColor(watchManager.isReachable ? .green : .red)
                    if !watchManager.lastAction.isEmpty {
                        Text("操作: \(watchManager.lastAction)")
                            .font(.system(size: 9))
                            .foregroundColor(.cyan)
                    }
                    if !watchManager.lastError.isEmpty {
                        Text("错误: \(watchManager.lastError)")
                            .font(.system(size: 9))
                            .foregroundColor(.red)
                    }
                }
                .padding(6)
                .background(Color.white.opacity(0.08))
                .cornerRadius(8)

                // Sign-in Button
                Button(action: {
                    watchManager.sendCheckIn()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                        Text("签到")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.green.opacity(0.8))
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())

                // Last Check-in Status
                if let last = watchManager.lastCheckIn {
                    Text("上次签到: \(last)")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Health Data Section
                VStack(spacing: 8) {
                    Text("健康速览")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.cyan)
                        .frame(maxWidth: .infinity, alignment: .leading)

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

                // SOS Button
                Button(action: {
                    showSOSConfirmation = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 18))
                        Text("SOS")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.red.opacity(0.9))
                    .cornerRadius(12)
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
