import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import '../../l10n/i18n.dart';

/// ============================================================================
/// 体征评估引擎 (VitalsAssessment)
/// ============================================================================
///
/// 【产品底层逻辑 · 勿改】
/// 「在呢+」不是健康 App，是**安全** App。核心命题：让在乎的人知道你很好。
///
/// 健康数据在本 App 中的**唯一价值**是回答一个问题：
///
///     「这个独居的人，可能出事了吗？」
///
/// 本引擎把原生桥读到的 ~70 项 HealthKit 原始指标，翻译成**一句人话结论** +
/// **一个可执行动作**。
///
/// 【中国合规版红线 · 必读】
/// 本引擎**只做本机判定与展示，不含任何自动外发**。
/// 若后续要接「异常 → 自动通知守护圈」，必须包 `!kIsChinaBuild` 编译期闸门，
/// CN 版仅保留本机提醒 + 用户手动确认后外发。这正是当初中国区下架的那根红线。
/// （CN 版二进制中本文件随 `kIsChinaBuild` 仍编译，但所有自动外发分支已被物理剔除。）
/// ============================================================================

/// 评估等级
enum VitalsLevel {
  /// 一切正常，可安心报平安
  ok,

  /// 有值得注意的信号，建议本人留意（不惊动守护圈）
  attention,

  /// 疑似异常，建议主动报平安或联系守护人
  alert,

  /// 数据不足，无法判定（未佩戴手表 / 未授权）
  unknown,
}

/// 单条评估原因
class VitalsReason {
  final String text;
  final VitalsLevel level;
  final IconData icon;

  const VitalsReason(this.text, this.level, this.icon);
}

/// 引擎输出结果
class VitalsAssessment {
  /// 综合等级（取所有原因中最高级别）
  final VitalsLevel level;

  /// 一句人话结论（首屏大字）
  final String headline;

  /// 补充说明（结论下方小字）
  final String detail;

  /// 判定依据明细
  final List<VitalsReason> reasons;

  /// 今日静止时长估算（小时）；-1 表示数据不足
  final double inactiveHours;

  const VitalsAssessment({
    required this.level,
    required this.headline,
    required this.detail,
    required this.reasons,
    this.inactiveHours = -1,
  });

  bool get isNormal => level == VitalsLevel.ok;

  /// 状态主色
  Color get color {
    switch (level) {
      case VitalsLevel.ok:
        return const Color(0xFF34C759); // iOS 系统绿
      case VitalsLevel.attention:
        return const Color(0xFFFF9500); // iOS 系统橙
      case VitalsLevel.alert:
        return const Color(0xFFFF3B30); // iOS 系统红
      case VitalsLevel.unknown:
        return const Color(0xFF8E8E93); // iOS 系统灰
    }
  }

  IconData get icon {
    switch (level) {
      case VitalsLevel.ok:
        return Icons.verified_user_rounded;
      case VitalsLevel.attention:
        return Icons.info_rounded;
      case VitalsLevel.alert:
        return Icons.warning_rounded;
      case VitalsLevel.unknown:
        return Icons.watch_off_rounded;
    }
  }
}

/// 主入口：把原始指标翻译成体征评估结论。
///
/// [m] 合并后的健康指标（getHealthSummary 的返回值，已叠加原生全量镜像）
/// [now] 注入当前时间，便于单测
VitalsAssessment evaluateVitals(Map<String, dynamic> m, {DateTime? now}) {
  final t = now ?? DateTime.now();
  final reasons = <VitalsReason>[];

  // ---------- ① 长时间无活动（本 App 的头牌信号） ----------
  // 独居风险最强的信号从来不是 VO2Max，而是「这个人今天一动没动」。
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
      reasons.add(VitalsReason(
        tr.z0353(steps.toInt()),
        VitalsLevel.alert,
        Icons.airline_seat_flat_rounded,
      ));
    } else if (quiet && t.hour >= _kQuietCheckHour) {
      reasons.add(VitalsReason(
        tr.z0354(inactiveHours.toStringAsFixed(0)),
        VitalsLevel.attention,
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
      reasons.add(VitalsReason(
        tr.z0355(hr.toInt()),
        VitalsLevel.alert,
        Icons.monitor_heart_rounded,
      ));
    } else if ((hrMin > 0 && hrMin < _kHeartRateLow) || (hrMax > 0 && hrMax > _kHeartRateHigh + 20)) {
      reasons.add(VitalsReason(
        tr.z0356(hrMin.toInt(), hrMax.toInt()),
        VitalsLevel.attention,
        Icons.show_chart_rounded,
      ));
    }
  }

  // 手表自身记录的高/低心率通知事件（近 30 天）
  final lowEvents = _num(m['low_hr_events_30d']).toInt();
  final highEvents = _num(m['high_hr_events_30d']).toInt();
  if (lowEvents + highEvents > 0) {
    reasons.add(VitalsReason(
      tr.z0357(lowEvents + highEvents),
      VitalsLevel.attention,
      Icons.notifications_active_rounded,
    ));
  }

  // ---------- ③ 血氧 ----------
  final spo2 = _normalizeSpo2(m['blood_oxygen']);
  if (spo2 > 0) {
    if (spo2 < _kSpo2Alert) {
      reasons.add(VitalsReason(
        tr.z0358(spo2.toStringAsFixed(0)),
        VitalsLevel.alert,
        Icons.bloodtype_rounded,
      ));
    } else if (spo2 < _kSpo2Attention) {
      reasons.add(VitalsReason(
        tr.z0359(spo2.toStringAsFixed(0)),
        VitalsLevel.attention,
        Icons.bloodtype_outlined,
      ));
    }
  }

  // ---------- ④ 步行稳定性（跌倒风险） ----------
  final steadiness = _num(m['walking_steadiness_pct']);
  if (steadiness > 0 && steadiness < _kSteadinessLow) {
    reasons.add(VitalsReason(
      tr.z0360(steadiness.toStringAsFixed(0)),
      VitalsLevel.attention,
      Icons.accessibility_new_rounded,
    ));
  }

  // ---------- ⑤ 睡眠 ----------
  final sleep = _num(m['sleep_total']).toInt();
  if (sleep > 0) {
    if (sleep < _kSleepTooShort) {
      reasons.add(VitalsReason(
        tr.z0361((sleep / 60).toStringAsFixed(1)),
        VitalsLevel.attention,
        Icons.bedtime_off_rounded,
      ));
    } else if (sleep > _kSleepTooLong) {
      reasons.add(VitalsReason(
        tr.z0362((sleep / 60).toStringAsFixed(1)),
        VitalsLevel.attention,
        Icons.bedtime_rounded,
      ));
    }
  }

  // ---------- 汇总 ----------
  if (!hasActivityData && hr <= 0 && spo2 <= 0 && sleep <= 0) {
    return VitalsAssessment(
      level: VitalsLevel.unknown,
      headline: tr.z0008,
      detail: tr.z0009,
      reasons: [],
    );
  }

  VitalsLevel level = VitalsLevel.ok;
  for (final r in reasons) {
    if (r.level == VitalsLevel.alert) {
      level = VitalsLevel.alert;
      break;
    }
    if (r.level == VitalsLevel.attention) level = VitalsLevel.attention;
  }

  return VitalsAssessment(
    level: level,
    headline: _headline(level, t),
    detail: _detail(level, reasons, m),
    reasons: reasons,
    inactiveHours: inactiveHours,
  );
}

// ---------- 文案生成：指标是原料，结论才是产品 ----------
// 【v1.97.2 合规】CN 版禁用任何「守护圈/报平安/通知」措辞，
// 走 manual-confirm 路线，文案须中性与主动；海外版保留自动外发相关用语。
String _headline(VitalsLevel level, DateTime t) {
  if (AppConfig.isChinaRegion) {
    switch (level) {
      case VitalsLevel.ok:
        if (t.hour < 11) return tr.z0016;
        if (t.hour < 18) return tr.z0017;
        return tr.z0018;
      case VitalsLevel.attention:
        return tr.z0019;
      case VitalsLevel.alert:
        return tr.z0363; // CN 中性版（你的拍板）
      case VitalsLevel.unknown:
        return tr.z0008;
    }
  }
  switch (level) {
    case VitalsLevel.ok:
      if (t.hour < 11) return tr.z0016;
      if (t.hour < 18) return tr.z0017;
      return tr.z0018;
    case VitalsLevel.attention:
      return tr.z0019;
    case VitalsLevel.alert:
      return tr.z0364;
    case VitalsLevel.unknown:
      return tr.z0008;
  }
}

String _detail(VitalsLevel level, List<VitalsReason> reasons, Map<String, dynamic> m) {
  if (AppConfig.isChinaRegion) {
    switch (level) {
      case VitalsLevel.ok:
        final steps = _num(m['steps']).toInt();
        if (steps > 0) return tr.z0365(steps);
        return tr.z0366;
      case VitalsLevel.attention:
        return tr.z0367(reasons.length);
      case VitalsLevel.alert:
        return tr.z0368;
      case VitalsLevel.unknown:
        return tr.z0009;
    }
  }
  switch (level) {
    case VitalsLevel.ok:
      final steps = _num(m['steps']).toInt();
      if (steps > 0) return tr.z0369(steps);
      return tr.z0370;
    case VitalsLevel.attention:
      return tr.z0371(reasons.length);
    case VitalsLevel.alert:
      return tr.z0372;
    case VitalsLevel.unknown:
      return tr.z0009;
  }
}

// ---------- 工具 ----------

double _num(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

/// HealthKit 血氧可能返回 0.0–1.0 分数或 0–100 百分比，统一归一化
double _normalizeSpo2(dynamic raw) {
  final v = _num(raw);
  if (v <= 0) return 0;
  final pct = v <= 1.0 ? v * 100 : v;
  return (pct >= 70 && pct <= 100) ? pct : 0; // 越界视为脏数据
}

// ---------- 判定阈值（集中管理，便于调参） ----------
const int _kQuietSteps = 200;
const int _kVeryQuietSteps = 60;
const int _kQuietCheckHour = 13;
const int _kVeryQuietCheckHour = 18;
const int _kHeartRateLow = 45;
const int _kHeartRateHigh = 130;
const double _kSpo2Alert = 90;
const double _kSpo2Attention = 94;
const double _kSteadinessLow = 50;
const int _kSleepTooShort = 180;
const int _kSleepTooLong = 720;
