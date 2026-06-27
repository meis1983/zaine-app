import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../models/menstrual_record.dart';

/// 经期服务
class MenstrualService {
  static const String _tag = 'MenstrualService';

  // 本地存储键
  static const String _recordsKey = 'menstrual_records';
  static const String _settingsKey = 'menstrual_settings';

  /// 保存经期记录
  static Future<bool> saveRecord(MenstrualRecord record) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 获取现有记录
      final records = await getRecords();

      // 添加新记录
      records.add(record);

      // 转为 JSON 并保存
      final recordsJson = records.map((r) => r.toJson()).toList();
      await prefs.setString(_recordsKey, jsonEncode(recordsJson));

      return true;
    } catch (e) {
      debugPrint('$_tag: 保存经期记录失败: $e');
      return false;
    }
  }

  /// 获取所有经期记录
  static Future<List<MenstrualRecord>> getRecords() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recordsString = prefs.getString(_recordsKey);

      if (recordsString == null || recordsString.isEmpty) {
        return [];
      }

      // 解析 JSON
      final List<dynamic> recordsJson = jsonDecode(recordsString);
      return recordsJson.map((json) => MenstrualRecord.fromJson(json)).toList();
    } catch (e) {
      debugPrint('$_tag: 获取经期记录失败: $e');
      return [];
    }
  }

  /// 获取最近一次经期记录
  static Future<MenstrualRecord?> getLastRecord() async {
    final records = await getRecords();
    if (records.isEmpty) return null;

    // 按开始日期排序
    records.sort((a, b) => b.startDate.compareTo(a.startDate));
    return records.first;
  }

  /// 预测下次经期
  static Future<MenstrualPrediction?> predictNextPeriod() async {
    try {
      final lastRecord = await getLastRecord();
      if (lastRecord == null) return null;

      final settings = await getSettings();

      // 计算下次经期日期
      final nextPeriodDate = lastRecord.startDate.add(
        Duration(days: settings.cycleLength),
      );

      // 计算排卵期（下次经期前14天）
      final ovulationDate = nextPeriodDate.subtract(
        const Duration(days: 14),
      );

      // 距离下次经期的天数
      final now = DateTime.now();
      final daysUntilNextPeriod = nextPeriodDate.difference(now).inDays;

      return MenstrualPrediction(
        nextPeriodDate: nextPeriodDate,
        ovulationDate: ovulationDate,
        daysUntilNextPeriod: daysUntilNextPeriod,
        isPeriodComing: daysUntilNextPeriod <= settings.reminderDaysBefore,
      );
    } catch (e) {
      debugPrint('$_tag: 预测下次经期失败: $e');
      return null;
    }
  }

  /// 保存设置
  static Future<bool> saveSettings(MenstrualSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
      return true;
    } catch (e) {
      debugPrint('$_tag: 保存设置失败: $e');
      return false;
    }
  }

  /// 获取设置
  static Future<MenstrualSettings> getSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsString = prefs.getString(_settingsKey);

      if (settingsString == null || settingsString.isEmpty) {
        return MenstrualSettings();
      }

      // 解析 JSON
      final Map<String, dynamic> settingsJson = jsonDecode(settingsString);
      return MenstrualSettings.fromJson(settingsJson);
    } catch (e) {
      debugPrint('$_tag: 获取设置失败: $e');
      return MenstrualSettings();
    }
  }

  /// 检查是否需要提醒
  static Future<bool> shouldRemind() async {
    final prediction = await predictNextPeriod();
    if (prediction == null) return false;

    final settings = await getSettings();
    if (!settings.enableReminder) return false;

    return prediction.isPeriodComing;
  }

  /// 格式化日期
  static String formatDate(DateTime date) {
    return DateFormat('yyyy年MM月dd日').format(date);
  }

  /// 获取流量级别文本
  static String getFlowLevelText(int level) {
    switch (level) {
      case 1:
        return '少量';
      case 2:
        return '偏少';
      case 3:
        return '正常';
      case 4:
        return '偏多';
      case 5:
        return '大量';
      default:
        return '正常';
    }
  }

  /// 常见症状列表
  static List<String> get commonSymptoms {
    return [
      '腹痛',
      '腰酸',
      '头痛',
      '乳房胀痛',
      '疲劳',
      '情绪波动',
      '食欲增加',
      '失眠',
      '痘痘',
      '便秘',
    ];
  }
}
