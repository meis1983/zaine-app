import 'package:intl/intl.dart';

/// 经期记录模型
class MenstrualRecord {
  final String? id;
  final DateTime startDate;
  final DateTime? endDate;
  final int flowLevel; // 1-5 (少量到大量)
  final List<String> symptoms; // 症状列表
  final String? notes;
  final DateTime createdAt;

  MenstrualRecord({
    this.id,
    required this.startDate,
    this.endDate,
    this.flowLevel = 3,
    this.symptoms = const [],
    this.notes,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// 经期天数
  int get duration {
    if (endDate == null) return 0;
    return endDate!.difference(startDate).inDays + 1;
  }

  /// 转为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'start_date': DateFormat('yyyy-MM-dd').format(startDate),
      'end_date': endDate != null ? DateFormat('yyyy-MM-dd').format(endDate!) : null,
      'flow_level': flowLevel,
      'symptoms': symptoms.join(','),
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// 从 JSON 创建
  factory MenstrualRecord.fromJson(Map<String, dynamic> json) {
    return MenstrualRecord(
      id: json['id'],
      startDate: DateTime.parse(json['start_date']),
      endDate: json['end_date'] != null ? DateTime.parse(json['end_date']) : null,
      flowLevel: json['flow_level'] ?? 3,
      symptoms: json['symptoms'] != null && json['symptoms'].toString().isNotEmpty
          ? json['symptoms'].toString().split(',')
          : [],
      notes: json['notes'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  /// 复制并修改
  MenstrualRecord copyWith({
    String? id,
    DateTime? startDate,
    DateTime? endDate,
    int? flowLevel,
    List<String>? symptoms,
    String? notes,
    DateTime? createdAt,
  }) {
    return MenstrualRecord(
      id: id ?? this.id,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      flowLevel: flowLevel ?? this.flowLevel,
      symptoms: symptoms ?? this.symptoms,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// 经期设置模型
class MenstrualSettings {
  int cycleLength; // 月经周期长度（天）
  int periodLength; // 经期长度（天）
  int reminderDaysBefore; // 提前几天提醒
  bool enableReminder; // 是否开启提醒
  bool enableOvulationReminder; // 是否开启排卵期提醒

  MenstrualSettings({
    this.cycleLength = 28,
    this.periodLength = 5,
    this.reminderDaysBefore = 3,
    this.enableReminder = true,
    this.enableOvulationReminder = false,
  });

  /// 转为 JSON
  Map<String, dynamic> toJson() {
    return {
      'cycle_length': cycleLength,
      'period_length': periodLength,
      'reminder_days_before': reminderDaysBefore,
      'enable_reminder': enableReminder,
      'enable_ovulation_reminder': enableOvulationReminder,
    };
  }

  /// 从 JSON 创建
  factory MenstrualSettings.fromJson(Map<String, dynamic> json) {
    return MenstrualSettings(
      cycleLength: json['cycle_length'] ?? 28,
      periodLength: json['period_length'] ?? 5,
      reminderDaysBefore: json['reminder_days_before'] ?? 3,
      enableReminder: json['enable_reminder'] ?? true,
      enableOvulationReminder: json['enable_ovulation_reminder'] ?? false,
    );
  }

  /// 复制并修改
  MenstrualSettings copyWith({
    int? cycleLength,
    int? periodLength,
    int? reminderDaysBefore,
    bool? enableReminder,
    bool? enableOvulationReminder,
  }) {
    return MenstrualSettings(
      cycleLength: cycleLength ?? this.cycleLength,
      periodLength: periodLength ?? this.periodLength,
      reminderDaysBefore: reminderDaysBefore ?? this.reminderDaysBefore,
      enableReminder: enableReminder ?? this.enableReminder,
      enableOvulationReminder: enableOvulationReminder ?? this.enableOvulationReminder,
    );
  }
}

/// 经期预测模型
class MenstrualPrediction {
  final DateTime nextPeriodDate; // 下次经期日期
  final DateTime ovulationDate; // 排卵期日期
  final int daysUntilNextPeriod; // 距离下次经期的天数
  final bool isPeriodComing; // 经期是否即将到来
  final double fertilityWindowStart; // 易孕窗口开始（距离下次经期的天数）
  final double fertilityWindowEnd; // 易孕窗口结束

  MenstrualPrediction({
    required this.nextPeriodDate,
    required this.ovulationDate,
    required this.daysUntilNextPeriod,
    this.isPeriodComing = false,
    this.fertilityWindowStart = 0,
    this.fertilityWindowEnd = 0,
  });

  /// 是否在易孕期内
  bool get isInFertilityWindow {
    final now = DateTime.now();
    final start = ovulationDate.subtract(Duration(days: fertilityWindowStart.toInt()));
    final end = ovulationDate.add(Duration(days: fertilityWindowEnd.toInt()));
    return now.isAfter(start) && now.isBefore(end);
  }

  /// 距离排卵期的天数
  int get daysUntilOvulation {
    final now = DateTime.now();
    return ovulationDate.difference(now).inDays;
  }
}
