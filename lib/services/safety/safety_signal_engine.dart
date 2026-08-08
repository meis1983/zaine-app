import 'package:flutter/material.dart';

/// ============================================================================
/// 安全信号引擎 (SafetySignalEngine) — v1.97.2
/// ============================================================================
///
/// 【产品底层逻辑 · 勿改】
/// 「在呢+」不是健康 App，是**安全** App。核心命题：让在乎的人知道你很好。
///
/// Apple 健康 App 的目标是「让你了解自己的身体」——它做了十年，有原生权限、
/// 专业团队，我们复制它只会更差且多余。
///
/// 健康数据在本 App 中的**唯一价值**是回答一个问题：
///
///     「这个独居的人，可能出事了吗？」
///
/// 因此指标不是越多越好，而是**越准越少越好**。一个指标能不能上首屏，
/// 不看它多高级，只看它异常时守护圈需不需要被惊动：
///   - VO2Max 掉 3 个点 → 守护圈不需要知道 → L2 折叠区
///   - 连续 11 小时零活动 → 守护圈必须知道 → L1 首屏
///
/// 【本引擎的职责】
/// 把原生桥读到的 ~70 项 HealthKit 原始指标，翻译成**一句人话结论** +
/// **一个可执行动作**。这是 Apple 永远不会做的事：它不会替你通知家人。
///
///     Apple 健康说：静息心率 62 bpm
///     在呢+ 说：    今天状态平稳，已可向守护圈报平安 ❤️
///
/// 【中国合规版红线 · 必读】
/// 本引擎**只做本机判定与展示，不含任何自动外发**。
/// 若后续要接「异常 → 自动通知守护圈」，必须包 `!AppConfig.isChinaRegion` 闸门，
/// CN 版仅保留本机提醒 + 用户手动确认后外发。这正是当初中国区下架的那根红线。
/// ============================================================================

/// 安全等级
enum SafetyLevel {
  /// 一切正常，可安心报平安
  ok,

  /// 有值得注意的信号，建议本人留意（不惊动守护圈）
  attention,

  /// 疑似异常，建议主动报平安或联系守护人
  alert,

  /// 数据不足，无法判定（未佩戴手表 / 未授权）
  unknown,
}

/// 单条安全信号原因
class SafetyReason {
  final String text;
  final SafetyLevel level;
  final IconData icon;

  const SafetyReason(this.text, this.level, this.icon);
}

/// 引擎输出结果
class SafetySignal {
  /// 综合等级（取所有原因中最高级别）
  final SafetyLevel level;

  /// 一句人话结论（首屏大字）
  final String headline;

  /// 补充说明（结论下方小字）
  final String detail;

  /// 判定依据明细
  final List<SafetyReason> reasons;

  /// 今日静止时长估算（小时）；-1 表示数据不足
  final double inactiveHours;

  const SafetySignal({
    required this.level,
    required this.headline,
    required this.detail,
    required this.reasons,
    this.inactiveHours = -1,
  });

  bool get isNormal => level == SafetyLevel.ok;

  /// 状态主色
  Color get color {
    switch (level) {
      case SafetyLevel.ok:
        return const Color(0xFF34C759); // iOS 系统绿
      case SafetyLevel.attention:
        return const Color(0xFFFF9500); // iOS 系统橙
      case SafetyLevel.alert:
        return const Color(0xFFFF3B30); // iOS 系统红
      case SafetyLevel.unknown:
        return const Color(0xFF8E8E93); // iOS 系统灰
    }
  }

  IconData get icon {
    switch (level) {
      case SafetyLevel.ok:
        return Icons.verified_user_rounded;
      case SafetyLevel.attention:
        return Icons.info_rounded;
      case SafetyLevel.alert:
        return Icons.warning_rounded;
      case SafetyLevel.unknown:
        return Icons.watch_off_rounded;
    }
  }
}

class SafetySignalEngine {
  SafetySignalEngine._();

  // ---------- 判定阈值（集中管理，便于调参） ----------

  /// 「几乎没动」的步数上限
  static const int _kQuietSteps = 200;

  /// 严重静止的步数上限
  static const int _kVeryQuietSteps = 60;

  /// 触发静止提醒的最早时刻（避免早上刚起床就报警）
  static const int _kQuietCheckHour = 13;

  /// 触发严重静止的时刻
  static const int _kVeryQuietCheckHour = 18;

  static const int _kHeartRateLow = 45;
  static const int _kHeartRateHigh = 130;
  static const double _kSpo2Alert = 90;
  static const double _kSpo2Attention = 94;

  /// 步行稳定性：Apple 定义 <50% 为 Low / Very Low（跌倒风险高）
  static const double _kSteadinessLow = 50;

  /// 睡眠异常阈值（分钟）
  static const int _kSleepTooShort = 180;
  static const int _kSleepTooLong = 720;

  /// 主入口：把原始指标翻译成安全结论
  ///
  /// [m] 合并后的健康指标（getHealthSummary 的返回值，已叠加原生全量镜像）
  /// [now] 注入当前时间，便于单测
  static SafetySignal evaluate(Map<String, dynamic> m, {DateTime? now}) {
    final t = now ?? DateTime.now();
    final reasons = <SafetyReason>[];

    // ---------- ① 长时间无活动（本 App 的头牌信号） ----------
    // 独居风险最强的信号从来不是 VO2Max，而是「这个人今天一动没动」。
    // 手表在腕上、步数为 0、无运动、无站立 —— 这几个信号叠加，
    // 比任何单项生理指标都准。Apple 健康 App 永远不会做这个判定，
    // 因为它不是安全产品。这就是我们与它的分水岭。
    final steps = _num(m['steps']);
    final exercise = _num(m['exercise_minutes'] ?? m['ring_exercise_min']);
    final standHours = _num(m['ring_stand_hours']);
    final activeKcal = _num(m['active_energy'] ?? m['ring_move_kcal']);
    final hasActivityData = m['steps'] != null || m['ring_stand_hours'] != null;

    double inactiveHours = -1;
    if (hasActivityData) {
      final quiet = steps < _kQuietSteps && exercise < 1 && standHours <= 1;
      final veryQuiet = steps < _kVeryQuietSteps && exercise < 1 && standHours < 1 && activeKcal < 30;

      // 粗略估算静止时长：从今日 08:00 起算（大多数人起床时间）
      if (quiet) {
        final since = DateTime(t.year, t.month, t.day, 8);
        inactiveHours = t.difference(since).inMinutes / 60.0;
        if (inactiveHours < 0) inactiveHours = 0;
      }

      if (veryQuiet && t.hour >= _kVeryQuietCheckHour) {
        reasons.add(SafetyReason(
          '今天几乎没有活动记录（${steps.toInt()} 步）',
          SafetyLevel.alert,
          Icons.airline_seat_flat_rounded,
        ));
      } else if (quiet && t.hour >= _kQuietCheckHour) {
        reasons.add(SafetyReason(
          '今日活动偏少，已静止约 ${inactiveHours.toStringAsFixed(0)} 小时',
          SafetyLevel.attention,
          Icons.airline_seat_recline_normal_rounded,
        ));
      }
    }

    // ---------- ② 心率异常 ----------
    final hr = _num(m['heart_rate']);
    final hrMin = _num(m['heart_rate_min']);
    final hrMax = _num(m['heart_rate_max']);
    if (hr > 0) {
      if (hr < _kHeartRateLow || hr > _kHeartRateHigh) {
        reasons.add(SafetyReason(
          '心率 ${hr.toInt()} bpm，超出常规区间',
          SafetyLevel.alert,
          Icons.monitor_heart_rounded,
        ));
      } else if ((hrMin > 0 && hrMin < _kHeartRateLow) || (hrMax > 0 && hrMax > _kHeartRateHigh + 20)) {
        reasons.add(SafetyReason(
          '今日心率波动较大（${hrMin.toInt()}–${hrMax.toInt()} bpm）',
          SafetyLevel.attention,
          Icons.show_chart_rounded,
        ));
      }
    }

    // 手表自身记录的高/低心率通知事件（近 30 天）
    final lowEvents = _num(m['low_hr_events_30d']).toInt();
    final highEvents = _num(m['high_hr_events_30d']).toInt();
    if (lowEvents + highEvents > 0) {
      reasons.add(SafetyReason(
        'Apple Watch 近 30 天记录到 ${lowEvents + highEvents} 次心率通知',
        SafetyLevel.attention,
        Icons.notifications_active_rounded,
      ));
    }

    // ---------- ③ 血氧 ----------
    final spo2 = _normalizeSpo2(m['blood_oxygen']);
    if (spo2 > 0) {
      if (spo2 < _kSpo2Alert) {
        reasons.add(SafetyReason(
          '血氧 ${spo2.toStringAsFixed(0)}%，明显偏低',
          SafetyLevel.alert,
          Icons.bloodtype_rounded,
        ));
      } else if (spo2 < _kSpo2Attention) {
        reasons.add(SafetyReason(
          '血氧 ${spo2.toStringAsFixed(0)}%，略低于常规值',
          SafetyLevel.attention,
          Icons.bloodtype_outlined,
        ));
      }
    }

    // ---------- ④ 步行稳定性（跌倒风险） ----------
    // Apple 官方的 Walking Steadiness 就是为跌倒风险设计的，
    // 对独居长者场景高度对口，是我们最该抓住的一项。
    final steadiness = _num(m['walking_steadiness_pct']);
    if (steadiness > 0 && steadiness < _kSteadinessLow) {
      reasons.add(SafetyReason(
        '步行稳定性 ${steadiness.toStringAsFixed(0)}%，跌倒风险偏高',
        SafetyLevel.attention,
        Icons.accessibility_new_rounded,
      ));
    }

    // ---------- ⑤ 睡眠 ----------
    final sleep = _num(m['sleep_total']).toInt();
    if (sleep > 0) {
      if (sleep < _kSleepTooShort) {
        reasons.add(SafetyReason(
          '昨晚仅睡 ${(sleep / 60).toStringAsFixed(1)} 小时',
          SafetyLevel.attention,
          Icons.bedtime_off_rounded,
        ));
      } else if (sleep > _kSleepTooLong) {
        reasons.add(SafetyReason(
          '昨晚睡眠 ${(sleep / 60).toStringAsFixed(1)} 小时，异常偏长',
          SafetyLevel.attention,
          Icons.bedtime_rounded,
        ));
      }
    }

    // ---------- 汇总 ----------
    if (!hasActivityData && hr <= 0 && spo2 <= 0 && sleep <= 0) {
      return const SafetySignal(
        level: SafetyLevel.unknown,
        headline: '暂无健康数据',
        detail: '佩戴 Apple Watch 并开启健康权限后，这里会显示你的今日状态',
        reasons: [],
      );
    }

    SafetyLevel level = SafetyLevel.ok;
    for (final r in reasons) {
      if (r.level == SafetyLevel.alert) {
        level = SafetyLevel.alert;
        break;
      }
      if (r.level == SafetyLevel.attention) level = SafetyLevel.attention;
    }

    return SafetySignal(
      level: level,
      headline: _headline(level, t),
      detail: _detail(level, reasons, m),
      reasons: reasons,
      inactiveHours: inactiveHours,
    );
  }

  // ---------- 文案生成：指标是原料，结论才是产品 ----------

  static String _headline(SafetyLevel level, DateTime t) {
    switch (level) {
      case SafetyLevel.ok:
        if (t.hour < 11) return '早上状态不错';
        if (t.hour < 18) return '今天状态平稳';
        return '今天一切都好';
      case SafetyLevel.attention:
        return '有几项值得留意';
      case SafetyLevel.alert:
        return '建议向守护圈报个平安';
      case SafetyLevel.unknown:
        return '暂无健康数据';
    }
  }

  static String _detail(SafetyLevel level, List<SafetyReason> reasons, Map<String, dynamic> m) {
    switch (level) {
      case SafetyLevel.ok:
        final steps = _num(m['steps']).toInt();
        if (steps > 0) return '今日 $steps 步，各项体征正常，可以让家人放心';
        return '各项体征正常，可以让家人放心';
      case SafetyLevel.attention:
        return '共 ${reasons.length} 项提醒，不一定有问题，但建议留意一下';
      case SafetyLevel.alert:
        return '检测到异常信号，主动报个平安能让家人少担心一点';
      case SafetyLevel.unknown:
        return '佩戴 Apple Watch 并开启健康权限后，这里会显示你的今日状态';
    }
  }

  // ---------- 工具 ----------

  static double _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  /// HealthKit 血氧可能返回 0.0–1.0 分数或 0–100 百分比，统一归一化
  static double _normalizeSpo2(dynamic raw) {
    final v = _num(raw);
    if (v <= 0) return 0;
    final pct = v <= 1.0 ? v * 100 : v;
    return (pct >= 70 && pct <= 100) ? pct : 0; // 越界视为脏数据
  }
}
