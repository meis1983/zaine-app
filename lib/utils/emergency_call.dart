import 'dart:io';
import 'dart:ui' as ui;

import 'package:url_launcher/url_launcher.dart';

/// 急救号码按设备地区自适应。
///
/// 单一全功能构建（com.zaine.app）服务全球用户（海外 + 港澳台 + 海外华裔），
/// 不再有任何"中国大陆专属"的固定 120 硬编码。SOS 一键拨打与文案中的急救号
/// 一律跟随设备地区返回当地急救号码，拨打时同样使用此号码。
class EmergencyCall {
  /// 各地区急救/紧急号码映射（医疗急救优先）。
  /// 112 为欧盟及 GSM 国际通用紧急号，作为默认值覆盖绝大多数未列出地区。
  static const Map<String, String> _emergencyNumbers = {
    // 北美
    'US': '911', 'CA': '911', 'PR': '911', 'VI': '911', 'AS': '911', 'GU': '911',
    // 英国 / 皇家属地 / 部分加勒比及大西洋地区
    'GB': '999', 'HK': '999', 'SG': '999', 'MY': '999', 'IE': '999',
    'BS': '999', 'BB': '999', 'BM': '999', 'KY': '999', 'TC': '999',
    'FK': '999', 'GI': '999',
    // 东亚
    'TW': '119', 'JP': '119', 'KR': '119', 'MO': '999', 'CN': '120',
    // 大洋洲
    'AU': '000', 'NZ': '111',
    // 菲律宾（全国 911）
    'PH': '911',
    // 其他（德/法/意/西/荷/比/奥/葡/瑞/挪/丹/芬/波/捷/匈/希/冰/卢等）默认 112
  };

  /// 返回设备当前地区对应的急救号码（默认 112）。
  static String localEmergencyNumber() {
    final region = _deviceRegion();
    return _emergencyNumbers[region] ?? '112';
  }

  /// 解析设备地区码（ISO 3166-1 alpha-2）。
  static String _deviceRegion() {
    String? region;
    try {
      final locale = ui.PlatformDispatcher.instance.locale;
      if (locale.countryCode != null && locale.countryCode!.isNotEmpty) {
        region = locale.countryCode;
      }
    } catch (_) {
      region = null;
    }
    if (region == null || region.isEmpty) {
      // 兜底：解析 Platform.localeName，例如 "en_US" / "zh-Hant_HK"。
      final name = Platform.localeName;
      final parts = name.split('_');
      if (parts.length > 1) region = parts.last;
    }
    return (region ?? '').toUpperCase();
  }

  /// 直接拨打当地急救号码。
  static Future<void> callEmergency() async {
    final number = localEmergencyNumber();
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }
}
