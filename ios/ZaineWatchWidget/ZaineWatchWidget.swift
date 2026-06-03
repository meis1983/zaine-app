//
//  ZaineWatchWidget.swift
//  ZaineWatchWidget
//
//  在呢+ Watch 复杂表盘 - 守护状态、健康数据、经期追踪
//

import WidgetKit
import SwiftUI

// MARK: - 数据模型

struct ZaineWidgetData: Codable {
    var heartRate: Int?
    var bloodOxygen: Int?
    var sleepMinutes: Int?
    var isInMenstruation: Bool
    var cycleDay: Int?
    var guardianCount: Int
    var lastCheckinTime: Date?
    var hasAlert: Bool
    var alertType: String? // "sos", "checkin_missed", "period"
    
    static let `default` = ZaineWidgetData(
        heartRate: nil,
        bloodOxygen: nil,
        sleepMinutes: nil,
        isInMenstruation: false,
        cycleDay: nil,
        guardianCount: 0,
        lastCheckinTime: nil,
        hasAlert: false,
        alertType: nil
    )
}

// MARK: - Timeline Entry

struct ZaineWidgetEntry: TimelineEntry {
    let date: Date
    let data: ZaineWidgetData
    let family: WidgetFamily
}

// MARK: - Provider

struct ZaineWidgetProvider: AppIntentTimelineProvider {
    typealias Entry = ZaineWidgetEntry
    typealias Intent = ConfigurationAppIntent
    
    func placeholder(in context: Context) -> ZaineWidgetEntry {
        ZaineWidgetEntry(
            date: Date(),
            data: .default,
            family: context.family
        )
    }
    
    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> ZaineWidgetEntry {
        let data = loadWidgetData()
        return ZaineWidgetEntry(
            date: Date(),
            data: data,
            family: context.family
        )
    }
    
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<ZaineWidgetEntry> {
        let data = loadWidgetData()
        let currentDate = Date()
        
        // 根据数据变化频率决定刷新间隔
        let refreshInterval: TimeInterval = data.hasAlert ? 60 : 300 // 有告警时1分钟刷新，否则5分钟
        let nextUpdate = currentDate.addingTimeInterval(refreshInterval)
        
        let entry = ZaineWidgetEntry(
            date: currentDate,
            data: data,
            family: context.family
        )
        
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }
    
    // 从共享 UserDefaults 加载数据
    private func loadWidgetData() -> ZaineWidgetData {
        guard let defaults = UserDefaults(suiteName: "group.com.zaine.app"),
              let data = defaults.data(forKey: "widget_data"),
              let widgetData = try? JSONDecoder().decode(ZaineWidgetData.self, from: data) else {
            return .default
        }
        return widgetData
    }
}

// MARK: - 复杂表盘视图

struct ZaineComplicationView: View {
    let entry: ZaineWidgetEntry
    @Environment(\.widgetRenderingMode) var renderingMode
    
    var body: some View {
        switch entry.family {
        case .accessoryCircular:
            CircularComplicationView(data: entry.data)
        case .accessoryRectangular:
            RectangularComplicationView(data: entry.data)
        case .accessoryInline:
            InlineComplicationView(data: entry.data)
        case .accessoryCorner:
            CornerComplicationView(data: entry.data)
        default:
            EmptyView()
        }
    }
}

// MARK: - 圆形表盘 (Circular)

struct CircularComplicationView: View {
    let data: ZaineWidgetData
    @Environment(\.widgetRenderingMode) var renderingMode
    
    var body: some View {
        ZStack {
            // 背景圆环
            Circle()
                .stroke(lineWidth: 4)
                .foregroundStyle(.secondary.opacity(0.3))
            
            // 进度圆环 - 根据健康状态
            Circle()
                .trim(from: 0, to: healthProgress)
                .stroke(
                    healthGradient,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            
            // 中心内容
            VStack(spacing: 2) {
                if data.hasAlert {
                    Image(systemName: alertIcon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(alertColor)
                } else if data.isInMenstruation, let day = data.cycleDay {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.pink)
                    Text("\(day)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.primary)
                } else if let hr = data.heartRate {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.red)
                    Text("\(hr)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.primary)
                } else {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.red.opacity(0.7))
                }
            }
        }
        .padding(4)
    }
    
    private var healthProgress: CGFloat {
        // 根据健康数据完整性计算进度
        var score = 0
        if data.heartRate != nil { score += 1 }
        if data.bloodOxygen != nil { score += 1 }
        if data.sleepMinutes != nil { score += 1 }
        return CGFloat(score) / 3.0
    }
    
    private var healthGradient: AngularGradient {
        AngularGradient(
            gradient: Gradient(colors: [.green, .cyan, .blue]),
            center: .center,
            startAngle: .degrees(0),
            endAngle: .degrees(360)
        )
    }
    
    private var alertIcon: String {
        switch data.alertType {
        case "sos": return "exclamationmark.triangle.fill"
        case "checkin_missed": return "bell.fill"
        case "period": return "drop.fill"
        default: return "exclamationmark.circle.fill"
        }
    }
    
    private var alertColor: Color {
        switch data.alertType {
        case "sos": return .red
        case "checkin_missed": return .orange
        case "period": return .pink
        default: return .yellow
        }
    }
}

// MARK: - 矩形表盘 (Rectangular)

struct RectangularComplicationView: View {
    let data: ZaineWidgetData
    @Environment(\.widgetRenderingMode) var renderingMode
    
    var body: some View {
        HStack(spacing: 8) {
            // 左侧：主要健康指标
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.red)
                    Text(data.heartRate.map { "\($0)" } ?? "--")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.primary)
                    Text("bpm")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.blue)
                    Text(data.bloodOxygen.map { "\($0)" } ?? "--")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.primary)
                    Text("%")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                }
            }
            
            Divider()
            
            // 右侧：守护圈/经期状态
            VStack(alignment: .trailing, spacing: 4) {
                if data.isInMenstruation, let day = data.cycleDay {
                    HStack(spacing: 2) {
                        Image(systemName: "drop.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.pink)
                        Text("经期\(day)天")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.pink)
                    }
                } else if let sleep = data.sleepMinutes {
                    HStack(spacing: 2) {
                        Image(systemName: "bed.double.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.indigo)
                        Text(formatSleep(sleep))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.primary)
                    }
                }
                
                HStack(spacing: 2) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.teal)
                    Text("\(data.guardianCount)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.teal)
                }
            }
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.1))
        )
    }
    
    private func formatSleep(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        return h > 0 ? "\(h)h\(m)m" : "\(m)m"
    }
}

// MARK: - 行内表盘 (Inline)

struct InlineComplicationView: View {
    let data: ZaineWidgetData
    
    var body: some View {
        HStack(spacing: 4) {
            if data.hasAlert {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Text(alertText)
                    .font(.system(size: 12, weight: .medium))
            } else if data.isInMenstruation, let day = data.cycleDay {
                Image(systemName: "drop.fill")
                    .foregroundStyle(.pink)
                Text("经期第\(day)天")
                    .font(.system(size: 12))
            } else if let hr = data.heartRate {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.red)
                Text("\(hr) bpm")
                    .font(.system(size: 12))
            } else {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.red.opacity(0.5))
                Text("在呢+")
                    .font(.system(size: 12))
            }
        }
    }
    
    private var alertText: String {
        switch data.alertType {
        case "sos": return "紧急求助"
        case "checkin_missed": return "未签到"
        case "period": return "经期提醒"
        default: return "新消息"
        }
    }
}

// MARK: - 角落表盘 (Corner)

struct CornerComplicationView: View {
    let data: ZaineWidgetData
    
    var body: some View {
        ZStack {
            // 角落弧形背景
            GeometryReader { geo in
                Path { path in
                    let width = geo.size.width
                    let height = geo.size.height
                    path.move(to: CGPoint(x: width, y: 0))
                    path.addLine(to: CGPoint(x: width, y: height * 0.6))
                    path.addQuadCurve(
                        to: CGPoint(x: width * 0.6, y: height),
                        control: CGPoint(x: width, y: height)
                    )
                    path.addLine(to: CGPoint(x: 0, y: height))
                }
                .fill(cornerGradient)
            }
            
            // 内容
            VStack(alignment: .trailing, spacing: 2) {
                Spacer()
                HStack {
                    Spacer()
                    if data.hasAlert {
                        Image(systemName: alertIcon)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                    } else if let hr = data.heartRate {
                        Text("\(hr)")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                HStack {
                    Spacer()
                    if data.isInMenstruation {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    Text("\(data.guardianCount)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
            .padding(.trailing, 8)
            .padding(.bottom, 8)
        }
    }
    
    private var cornerGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                data.hasAlert ? .red : .cyan,
                data.hasAlert ? .orange : .blue
            ]),
            startPoint: .topTrailing,
            endPoint: .bottomLeading
        )
    }
    
    private var alertIcon: String {
        switch data.alertType {
        case "sos": return "exclamationmark.triangle.fill"
        case "checkin_missed": return "bell.fill"
        default: return "exclamationmark.circle.fill"
        }
    }
}

// MARK: - Widget Configuration

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Configuration"
    static var description = IntentDescription("配置在呢+表盘显示内容")
}

// MARK: - Widget Entry View

struct ZaineWatchWidgetEntryView: View {
    var entry: ZaineWidgetProvider.Entry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        ZaineComplicationView(entry: entry)
    }
}

// MARK: - Main Widget

@main
struct ZaineWatchWidget: Widget {
    let kind: String = "ZaineWatchWidget"
    
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: ConfigurationAppIntent.self,
            provider: ZaineWidgetProvider()
        ) { entry in
            ZaineWatchWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("在呢+ 守护表盘")
        .description("显示健康数据、守护圈状态和经期追踪")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCorner
        ])
    }
}

// MARK: - Preview

#Preview("Circular", as: .accessoryCircular) {
    ZaineWatchWidget()
} timeline: {
    ZaineWidgetEntry(
        date: .now,
        data: ZaineWidgetData(
            heartRate: 72,
            bloodOxygen: 98,
            sleepMinutes: 420,
            isInMenstruation: true,
            cycleDay: 3,
            guardianCount: 5,
            lastCheckinTime: Date(),
            hasAlert: false,
            alertType: nil
        ),
        family: .accessoryCircular
    )
}

#Preview("Rectangular", as: .accessoryRectangular) {
    ZaineWatchWidget()
} timeline: {
    ZaineWidgetEntry(
        date: .now,
        data: ZaineWidgetData(
            heartRate: 72,
            bloodOxygen: 98,
            sleepMinutes: 420,
            isInMenstruation: false,
            cycleDay: nil,
            guardianCount: 3,
            lastCheckinTime: Date(),
            hasAlert: true,
            alertType: "checkin_missed"
        ),
        family: .accessoryRectangular
    )
}

#Preview("Inline", as: .accessoryInline) {
    ZaineWatchWidget()
} timeline: {
    ZaineWidgetEntry(
        date: .now,
        data: ZaineWidgetData(
            heartRate: 72,
            bloodOxygen: nil,
            sleepMinutes: nil,
            isInMenstruation: false,
            cycleDay: nil,
            guardianCount: 0,
            lastCheckinTime: nil,
            hasAlert: false,
            alertType: nil
        ),
        family: .accessoryInline
    )
}

#Preview("Corner", as: .accessoryCorner) {
    ZaineWatchWidget()
} timeline: {
    ZaineWidgetEntry(
        date: .now,
        data: ZaineWidgetData(
            heartRate: 75,
            bloodOxygen: 97,
            sleepMinutes: 380,
            isInMenstruation: true,
            cycleDay: 2,
            guardianCount: 4,
            lastCheckinTime: Date(),
            hasAlert: false,
            alertType: nil
        ),
        family: .accessoryCorner
    )
}
