/// 编译期区域开关
///
/// 通过 build flag 注入，一套代码生成两个产物：
///   - 海外全功能版（默认）：`flutter build --dart-define=ZAI_REGION=global`
///   - 中国合规版：          `flutter build --dart-define=ZAI_REGION=cn`
///
/// 【中国合规版整改背景】
/// Apple 判定本 App 含 "dead-man switch" 功能（用户无响应 / 传感器触发
/// → 系统自动通知第三方或自动代操作）。中国合规版据此关闭所有「自动外发 /
/// 自动代操作」，改为仅本地提醒用户本人，由用户手动确认后守护人才可见。
/// 海外版保持原有全功能（含自动通知亲友）。
class AppConfig {
  /// 是否中国合规版（关闭自动通知第三方亲友）
  static const bool isChinaRegion =
      String.fromEnvironment('ZAI_REGION', defaultValue: 'global') == 'cn';
}
