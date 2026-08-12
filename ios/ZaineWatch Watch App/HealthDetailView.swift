//
//  HealthDetailView.swift
//  ZaineWatch Watch App
//
//  【v1.97.3 新增】健康速览详情页 —— 点击"健康速览"后进入
//  展示完整健康数据 + 正常范围 + 状态色点
//

import SwiftUI

struct HealthDetailView: View {
    let healthData: [String: Any]

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                // 心率
                if let heartRate = healthData["heart_rate"] as? String {
                    HealthDetailRow(
                        icon: "heart.fill",
                        color: .red,
                        title: "心率",
                        value: heartRate,
                        unit: "bpm",
                        range: "60-100",
                        status: _getStatus(value: Double(heartRate) ?? 0, min: 60, max: 100)
                    )
                }

                // 血氧
                if let bloodOxygen = healthData["blood_oxygen"] as? String {
                    HealthDetailRow(
                        icon: "lungs.fill",
                        color: .blue,
                        title: "血氧",
                        value: bloodOxygen,
                        unit: "%",
                        range: "≥ 95",
                        status: _getStatus(value: Double(bloodOxygen) ?? 0, min: 95, max: 200)
                    )
                }

                // 血压（Apple Watch S9+/iOS 26 原生趋势，无硬件血压计也可读；旧系统无数据则跳过）
                if let bloodPressure = healthData["blood_pressure"] as? String {
                    HealthDetailRow(
                        icon: "waveform.path",
                        color: .green,
                        title: "血压",
                        value: bloodPressure,
                        unit: "mmHg",
                        range: "< 140/90",
                        status: _getBPStatus(value: bloodPressure)
                    )
                }

                // HRV
                if let hrv = healthData["hrv"] as? String {
                    HealthDetailRow(
                        icon: "waveform.path.ecg",
                        color: .orange,
                        title: "心率变异性",
                        value: hrv,
                        unit: "ms",
                        range: "20-100",
                        status: _getStatus(value: Double(hrv) ?? 0, min: 20, max: 200)
                    )
                } else if healthData["hrv"] != nil {
                    // 【v1.97.3 防御】上游误传非 String（曾出现 [11.65, 0.396, ...]）→ 显示 "--" 不崩
                    HealthDetailRow(
                        icon: "waveform.path.ecg",
                        color: .gray,
                        title: "心率变异性",
                        value: "--",
                        unit: "ms",
                        range: "20-100",
                        status: .info
                    )
                }

                // 体温
                if let temperature = healthData["temperature"] as? String {
                    HealthDetailRow(
                        icon: "thermometer",
                        color: .yellow,
                        title: "体温",
                        value: temperature,
                        unit: "°C",
                        range: "36.0-37.5",
                        status: _getStatus(value: Double(temperature) ?? 0, min: 36.0, max: 37.5)
                    )
                }

                // 睡眠
                if let sleep = healthData["sleep"] as? String {
                    HealthDetailRow(
                        icon: "bed.double.fill",
                        color: .purple,
                        title: "睡眠",
                        value: sleep,
                        unit: "h",
                        range: "≥ 7h",
                        status: .info
                    )
                }

                // 经期
                if let menstrual = healthData["menstrual"] as? String {
                    HealthDetailRow(
                        icon: "drop.fill",
                        color: .pink,
                        title: "经期",
                        value: menstrual,
                        unit: "",
                        range: "周期记录",
                        status: .info
                    )
                }

                // 如果没有数据
                if healthData.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "heart.text.square")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        Text("暂无健康数据")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                        Text("请确保已在 iPhone 上授权健康数据")
                            .font(.system(size: 10))
                            .foregroundColor(.gray.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)
                }
            }
            .padding(12)
        }
        .navigationTitle("健康速览")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// 根据数值范围返回状态
    private func _getStatus(value: Double, min: Double, max: Double) -> HealthStatus {
        if value == 0 { return .info }
        if value >= min && value <= max { return .normal }
        if value < min { return .warning }
        return .warning
    }

    /// 血压状态：收缩压≥140 或 舒张压≥90 → 关注；0 值 → 参考；否则正常
    private func _getBPStatus(value: String) -> HealthStatus {
        let parts = value.split(separator: "/").compactMap { Double($0) }
        guard parts.count == 2 else { return .info }
        let sys = parts[0], dia = parts[1]
        if sys == 0 || dia == 0 { return .info }
        if sys >= 140 || dia >= 90 { return .warning }
        return .normal
    }
}

enum HealthStatus {
    case normal   // 正常 - 绿色
    case warning  // 关注 - 橙色
    case info     // 参考值 - 灰色

    var color: Color {
        switch self {
        case .normal: return .green
        case .warning: return .orange
        case .info: return .gray
        }
    }

    var label: String {
        switch self {
        case .normal: return "正常"
        case .warning: return "关注"
        case .info: return "参考"
        }
    }
}

struct HealthDetailRow: View {
    let icon: String
    let color: Color
    let title: String
    let value: String
    let unit: String
    let range: String
    let status: HealthStatus

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(title)
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                    // 状态色点
                    Circle()
                        .fill(status.color)
                        .frame(width: 6, height: 6)
                    Text(status.label)
                        .font(.system(size: 8))
                        .foregroundColor(status.color)
                }
                HStack(spacing: 2) {
                    Text(value)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                }
                Text("正常 \(range)")
                    .font(.system(size: 8))
                    .foregroundColor(.gray.opacity(0.6))
            }

            Spacer()
        }
        .padding(10)
        .background(Color.white.opacity(0.06))
        .cornerRadius(10)
    }
}
