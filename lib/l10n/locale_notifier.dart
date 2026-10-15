import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App 可切换的语言选项。
/// - [system]：跟随系统（locale = null，由设备语言决定）
/// - 其余为显式指定语言
enum AppLanguage {
  system,
  simplifiedChinese,
  traditionalTaiwan,
  traditionalHongKong,
  english,
}

extension AppLanguageX on AppLanguage {
  /// 应用到 MaterialApp 的 Locale；[system] 返回 null（跟随系统）。
  Locale? get locale {
    switch (this) {
      case AppLanguage.simplifiedChinese:
        return const Locale('zh', 'CN');
      case AppLanguage.traditionalTaiwan:
        return const Locale('zh', 'TW');
      case AppLanguage.traditionalHongKong:
        return const Locale('zh', 'HK');
      case AppLanguage.english:
        return const Locale('en');
      case AppLanguage.system:
        return null;
    }
  }

  /// 持久化键（SharedPreferences 中存的值）。
  String get prefKey {
    switch (this) {
      case AppLanguage.simplifiedChinese:
        return 'zh-CN';
      case AppLanguage.traditionalTaiwan:
        return 'zh-TW';
      case AppLanguage.traditionalHongKong:
        return 'zh-HK';
      case AppLanguage.english:
        return 'en';
      case AppLanguage.system:
        return 'system';
    }
  }

  static AppLanguage fromPref(String? v) {
    switch (v) {
      case 'zh-CN':
        return AppLanguage.simplifiedChinese;
      case 'zh-TW':
        return AppLanguage.traditionalTaiwan;
      case 'zh-HK':
        return AppLanguage.traditionalHongKong;
      case 'en':
        return AppLanguage.english;
      default:
        return AppLanguage.system;
    }
  }
}

/// 全局语言偏好通知器（与 ThemeNotifier 同模式）。
/// - [load] 从 SharedPreferences 读取持久化语言（main() 启动时 await）。
/// - [setLanguage] 写持久化并 notifyListeners，驱动 MaterialApp 重建。
class LocaleNotifier extends ChangeNotifier {
  AppLanguage _language = AppLanguage.system;

  AppLanguage get language => _language;

  /// 当前应施加到 MaterialApp 的 Locale（system 时为 null）。
  Locale? get locale => _language.locale;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _language = AppLanguageX.fromPref(prefs.getString('app_language'));
    notifyListeners();
  }

  Future<void> setLanguage(AppLanguage lang) async {
    _language = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', lang.prefKey);
    notifyListeners();
  }
}

/// 全局单例，main.dart 启动时 load()，UI 通过它读写语言偏好。
final localeNotifier = LocaleNotifier();
