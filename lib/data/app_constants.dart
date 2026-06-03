// lib/data/app_constants.dart
// App 全局常量（v1.6 新增）

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppConstants {
  /// 版本号（运行时从 pubspec.yaml 读取，保证与构建版本一致）
  static String version = '1.9.85';
  /// Build 号（运行时读取，用于区分每次编译）
  static String buildNumber = '1';
  static const String appName = '在呢+';

  /// 初始化版本号（在 main.dart 中调用，确保读取到真实构建版本）
  static Future<void> initVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    version = packageInfo.version;
    buildNumber = packageInfo.buildNumber;
  }

  /// iOS App Store 下载链接（审核通过后生效）
  static const String appStoreUrl = 'https://apps.apple.com/app/zaine/id6763441206';

  /// Android Google Play 下载链接（待上架后补充，25美元个人开发者即可）
  static const String googlePlayUrl = ''; // 待 Google Play 上架后补充

  /// 获取当前平台的下载链接
  /// iOS → App Store，Android → Google Play（未上架时返回空字符串）
  static String getPlatformDownloadUrl(bool isIOS) {
    return isIOS ? appStoreUrl : googlePlayUrl;
  }
  static const String h5ShareBaseUrl =
      'https://zaine-share.oss-cn-hangzhou.aliyuncs.com/index.html';
  static const String ossLandingPageUrl =
      'https://zaine-share.oss-cn-hangzhou.aliyuncs.com/landing.html';
  static const String backendBaseUrl =
      'https://zaine-api-skhntjskvp.cn-hangzhou.fcapp.run';
  /// 【临时方案】landing 页基础域名
  /// ICP 备案完成前使用阿里云 FC 默认域名，备案通过后切回 https://zaine.love
  static const String landingBaseUrl =
      'https://zaine-api-skhntjskvp.cn-hangzhou.fcapp.run';

  /// 高德地图 Web 服务 API Key（逆地理编码等）
  /// 从 .env 文件读取，不硬编码在源码中
  /// 申请地址: https://console.amap.com/dev/key/app
  static String get amapApiKey => dotenv.env['AMAP_API_KEY'] ?? '';
}
