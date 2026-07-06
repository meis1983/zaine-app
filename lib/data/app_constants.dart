// lib/data/app_constants.dart
// App 全局常量（v1.6 新增，v1.17.4 配置迁移到 .env）

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppConstants {
  /// 版本号（运行时从 pubspec.yaml 读取，保证与构建版本一致）
  static String version = '1.93.10';
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

  // ─── 以下配置从 .env 读取，不复用硬编码 ────────────────────────

  /// H5 分享页 OSS 地址
  static String get h5ShareBaseUrl =>
      dotenv.env['H5_SHARE_BASE_URL'] ??
      'https://zaine-share.oss-cn-hangzhou.aliyuncs.com/index.html';

  /// OSS Landing 页地址
  static String get ossLandingPageUrl =>
      dotenv.env['OSS_LANDING_PAGE_URL'] ??
      'https://zaine-share.oss-cn-hangzhou.aliyuncs.com/landing.html';

  /// 后端 API 基础地址（阿里云 FC）
  static String get backendBaseUrl =>
      dotenv.env['BACKEND_BASE_URL'] ??
      'https://zaine-api-skhntjskvp.cn-hangzhou.fcapp.run';

  /// Landing 页基础域名（ICP 备案域名）
  static String get landingBaseUrl =>
      dotenv.env['LANDING_BASE_URL'] ?? 'https://zaine.love';

  /// 高德地图 Web 服务 API Key（逆地理编码等）
  /// 申请地址: https://console.amap.com/dev/key/app
  static String get amapApiKey => dotenv.env['AMAP_API_KEY'] ?? '';

  // ─── URL 辅助方法 ─────────────────────────────

  /// 拼接 Landing 页完整 URL
  /// 用法: landingUrl('/landing/contacts_13800138000')
  static String landingUrl(String path) => '$landingBaseUrl$path';

  /// 守护卡片分享链接
  static String guardianCardUrl(String cardCode) =>
      '$landingBaseUrl/landing/$cardCode';

  /// 联系人邀请链接
  /// 【修复 v1.75.0】使用更短路径 /i/c 替代 /landing/contacts_，缩短 15 字符避免短信换行
  static String contactsInviteUrl(String phone) =>
      '$landingBaseUrl/i/c${phone.replaceAll(RegExp(r'[^0-9]'), '')}';

  /// 【v1.76.0】签到里程碑分享二维码 — 跳转 Apple Store（不绑定守护关系，适合分享朋友圈/社群）
  static String get checkinMilestoneUrl => appStoreUrl;

  /// 欢迎页链接
  static String get welcomeUrl => '$landingBaseUrl/landing/welcome';

  /// 守护人邀请链接
  static String get guardianInviteUrl =>
      '$landingBaseUrl/landing/guardian_invite';

  /// 隐私政策链接
  static String get privacyUrl => '$landingBaseUrl/privacy';

  /// 服务条款（用户协议 / EULA）链接【Apple 审核 Guideline 3.1.2(c) 要求】
  static String get termsUrl => '$landingBaseUrl/terms';
}
