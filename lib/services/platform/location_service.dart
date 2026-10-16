// lib/services/platform/location_service.dart
// 位置服务（v1.7: 新增逆地理编码；v1.97.8: 海外去高德——逆地理编码统一走系统原生）

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../l10n/i18n.dart';

class LocationService {
  static const String _diagProviderKey = 'geocode_last_provider';
  static const String _diagAddressKey = 'geocode_last_address';
  static const String _diagTimeKey = 'geocode_last_time';

  /// 获取当前位置（仅在求助触发时调用，降低系统定位/编码消耗）
  /// ⚠️ 重要：此方法不再内部调用 request()！
  /// 权限必须由 UI 层（如 help_page 的引导页）先请求好，这里只负责获取位置。
  /// 原因：在获取位置时偷偷 request() 会导致 iOS 系统在不合适的时机吞掉权限弹窗，
  ///       造成 App 永远不出现在位置服务列表中的死锁问题。
  static Future<LocationResult> getCurrentLocation() async {
    try {
      if (kDebugMode) debugPrint('[LocationService] 开始获取位置...');

      // 纯检查权限（不触发弹窗）
      final hasPerm = await hasPermission();
      if (!hasPerm) {
        if (kDebugMode) debugPrint('[LocationService] 位置权限未授权，无法获取位置');
        return LocationResult.error(tr.z0300);
      }

      // 检查定位服务
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (kDebugMode) debugPrint('[LocationService] 定位服务未开启');
        return LocationResult.error(tr.z0301);
      }

      if (kDebugMode) debugPrint('[LocationService] 权限已授权，获取位置中...');
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );

      if (kDebugMode) {
        debugPrint(
          '[LocationService] 位置获取成功: ${position.latitude}, ${position.longitude}');
      }

      final coordStr =
          '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
      final mapsUrl =
          'https://maps.apple.com/?ll=${position.latitude},${position.longitude}';
      // 【海外去高德】统一使用 Google Maps 全球通用链接（q=纬度,经度）
      final mapUrl =
          'https://www.google.com/maps?q=${position.latitude},${position.longitude}';

      if (kDebugMode) debugPrint('[LocationService] 坐标: $coordStr');
      if (kDebugMode) debugPrint('[LocationService] Apple Maps URL: $mapsUrl');
      if (kDebugMode) debugPrint('[LocationService] Google Maps URL: $mapUrl');

      // 逆地理编码
      String? address;
      try {
        address = await reverseGeocode(position.latitude, position.longitude);
        if (kDebugMode) debugPrint('[LocationService] 逆地理编码地址: $address');
      } catch (e) {
        if (kDebugMode) debugPrint('[LocationService] 逆地理编码失败（非致命）: $e');
      }

      return LocationResult.success(
        latitude: position.latitude,
        longitude: position.longitude,
        coordString: coordStr,
        mapsUrl: mapsUrl,
        mapUrl: mapUrl,
        address: address,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[LocationService] 位置获取失败: $e');
      return LocationResult.error(tr.z0302);
    }
  }

  /// 检查位置权限状态（纯检查，不触发任何弹窗）
  /// iOS: isGranted(完全授权) + isLimited(精确定位) 都算通过
  /// Android: isGranted 算通过
  /// 
  /// ⚠️ 双重校验：同时使用 permission_handler 和 geolocator 检测，
  ///     任一返回 granted 即视为已授权（防止某一 SDK 状态不同步）
  static Future<bool> hasPermission() async {
    try {
      // 方式1：优先用 geolocator 直接问 iOS CLLocationManager（避免 permission_handler 缓存问题）
      try {
        final geoPerm = await Geolocator.checkPermission();
        if (kDebugMode) debugPrint('[LocationService] hasPermission - geolocator: $geoPerm');
        if (geoPerm == LocationPermission.whileInUse || 
            geoPerm == LocationPermission.always) {
          if (kDebugMode) debugPrint('[LocationService] hasPermission → true (via geolocator)');
          return true;
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[LocationService] geolocator 检查失败（非致命）: $e');
      }

      // 方式2：permission_handler 兜底检查
      final phWhenInUse = await Permission.locationWhenInUse.status;
      final phAlways = await Permission.locationAlways.status;
      if (kDebugMode) debugPrint('[LocationService] hasPermission - whenInUse: $phWhenInUse, always: $phAlways');

      if (phWhenInUse.isGranted || phWhenInUse.isLimited ||
          phAlways.isGranted || phAlways.isLimited) {
        if (kDebugMode) debugPrint('[LocationService] hasPermission → true (via permission_handler)');
        return true;
      }

      // 两者都没通过
      if (kDebugMode) debugPrint('[LocationService] hasPermission → false');
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('[LocationService] 检查权限失败: $e');
      return false;
    }
  }

  /// 显式请求位置权限（由用户交互触发，如点击按钮）
  /// ⚠️ 重要：使用 geolocator 原生的 requestPermission() 而不是 permission_handler！
  /// 原因：permission_handler 在 iOS 上有复杂的策略层（见 LocationPermissionStrategy.m），
  ///       会将 NotDetermined 转为 Denied，在某些情况下导致弹窗被吞掉。
  ///       geolocator 直接调用 CLLocationManager.requestWhenInUseAuthorization()，
  ///       更可靠地触发 iOS 系统权限对话框。
  static Future<PermissionStatus> requestPermission() async {
    if (kDebugMode) debugPrint('[LocationService] requestPermission: 使用 geolocator 原生方式请求位置权限...');

    try {
      // 方式1：优先使用 geolocator 原生方法
      final locationPermission = await Geolocator.requestPermission();
      if (kDebugMode) debugPrint('[LocationService] geolocator.requestPermission 结果: $locationPermission');

      // 将 geolocator 的 LocationPermission 转换为 permission_handler 的 PermissionStatus
      switch (locationPermission) {
        case LocationPermission.whileInUse:
        case LocationPermission.always:
          return PermissionStatus.granted;
        case LocationPermission.denied:
        case LocationPermission.deniedForever:
          // 再用 permission_handler 检查是否是永久拒绝
          final phStatus = await Permission.locationWhenInUse.status;
          if (kDebugMode) debugPrint('[LocationService] permission_handler 复核状态: $phStatus');
          return phStatus;
        case LocationPermission.unableToDetermine:
          return PermissionStatus.denied;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[LocationService] geolocator.requestPermission 异常: $e');
      // 降级到 permission_handler
      if (kDebugMode) debugPrint('[LocationService] 降级使用 permission_handler...');
      final status = await Permission.locationWhenInUse.request();
      if (kDebugMode) debugPrint('[LocationService] permission_handler.requestPermission 结果: $status');
      return status;
    }
  }

  /// 逆地理编码：经纬度 → 可读地址
  /// 【v1.97.8 海外去高德】统一走系统原生（iOS CLGeocoder / Android Geocoder）：
  /// 全球可用、零 Key、零外依赖；失败时返回 null（调用方以坐标 + 地图链接兜底）。
  /// 清洗地址中的特殊字符（地址可能自带 '+' 或全角'＋'，
  /// 会污染 SOS 短信模板与地图链接；同时归一化空白）
  static String? _cleanAddress(String? addr) {
    if (addr == null) return null;
    // 【v1.95.0+115 修复】用正则一网打尽所有"加号类"Unicode 字符：
    // \u002B ASCII +  / \uFF0B 全角＋ / \u207A 上标⁺
    // \u208B 下标₊    / \u2795 粗体➕ / \uFB29 希伯来字母 alef+footnote
    // 根除高德地址中未被半角/全角替换覆盖的"伪加号"，彻底杜绝 SOS 短信地址带 +
    return addr
        .replaceAll(RegExp(r'[\u002B\uFF0B\u207A\u208B\u2795\uFB29]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static Future<String?> reverseGeocode(double latitude, double longitude) async {
    try {
      final nativeAddr = await _reverseGeocodeNative(latitude, longitude);
      await _storeGeocodeDiag(
        provider: (nativeAddr != null && nativeAddr.trim().isNotEmpty) ? 'native' : 'none',
        address: nativeAddr?.trim(),
      );
      return _cleanAddress(nativeAddr);
    } catch (e, st) {
      if (kDebugMode) debugPrint('[LocationService] 💥 逆地理编码未捕获异常: $e\n$st');
      await _storeGeocodeDiag(provider: 'none', address: null);
      return null;
    }
  }

  static Future<void> _storeGeocodeDiag({
    required String provider,
    required String? address,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_diagProviderKey, provider);
      await prefs.setString(_diagTimeKey, DateTime.now().toIso8601String());
      if (address != null) {
        await prefs.setString(_diagAddressKey, address);
      } else {
        await prefs.remove(_diagAddressKey);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[LocationService] ⚠️ 写入逆地理诊断失败: $e');
    }
  }

  static Future<String?> _reverseGeocodeNative(double latitude, double longitude) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      ).timeout(const Duration(seconds: 6));

      if (placemarks.isEmpty) return null;
      final p = placemarks.first;
      final parts = <String>[];

      final country = (p.country ?? '').trim();
      final admin = (p.administrativeArea ?? '').trim();
      final locality = (p.locality ?? '').trim();
      final subLocality = (p.subLocality ?? '').trim();
      final thoroughfare = (p.thoroughfare ?? '').trim();
      final subThoroughfare = (p.subThoroughfare ?? '').trim();
      final name = (p.name ?? '').trim();

      if (admin.isNotEmpty) parts.add(admin);
      if (locality.isNotEmpty && locality != admin) parts.add(locality);
      if (subLocality.isNotEmpty) parts.add(subLocality);
      if (thoroughfare.isNotEmpty) parts.add(thoroughfare);
      if (subThoroughfare.isNotEmpty) parts.add(subThoroughfare);
      if (name.isNotEmpty && !parts.join('').contains(name)) parts.add(name);
      // 国家殿后：中文地址「大→小」习惯不受影响；海外地址补上 "United States" 才完整
      if (country.isNotEmpty && !parts.join('').contains(country)) parts.add(country);

      // 【v1.97.8】西式地址必须以「, 」分隔——"CaliforniaSan Francisco" 对海外
      // 接收人不可读；SOS 短信面向全球，统一用国际通用分隔
      final result = parts.join(', ');
      if (result.isEmpty) return null;
      if (kDebugMode) debugPrint('[LocationService] ✅ 系统逆地理成功: $result');
      return result;
    } catch (e) {
      if (kDebugMode) debugPrint('[LocationService] ⚠️ 系统逆地理失败: $e');
      return null;
    }
  }
}

/// 位置获取结果
class LocationResult {
  final bool isSuccess;
  final double? latitude;
  final double? longitude;
  final String? coordString;    // 十进制度数坐标 "lat, lng"
  final String? mapsUrl;        // Apple Maps URL
  final String? mapUrl;         // Google Maps URL（海外通用）
  final String? address;        // 逆地理编码地址（如：北京市朝阳区xx路xx号）
  final String? errorMessage;

  LocationResult._({
    required this.isSuccess,
    this.latitude,
    this.longitude,
    this.coordString,
    this.mapsUrl,
    this.mapUrl,
    this.address,
    this.errorMessage,
  });

  factory LocationResult.success({
    required double latitude,
    required double longitude,
    required String coordString,
    required String mapsUrl,
    String? mapUrl,
    String? address,
  }) {
    return LocationResult._(
      isSuccess: true,
      latitude: latitude,
      longitude: longitude,
      coordString: coordString,
      mapsUrl: mapsUrl,
      mapUrl: mapUrl,
      address: address,
    );
  }

  factory LocationResult.error(String message) {
    return LocationResult._(
      isSuccess: false,
      errorMessage: message,
    );
  }
}
