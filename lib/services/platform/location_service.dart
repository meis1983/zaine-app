// lib/services/platform/location_service.dart
// 位置服务（v1.7: 新增逆地理编码）

import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/app_constants.dart';

class LocationService {
  static const String _diagProviderKey = 'geocode_last_provider';
  static const String _diagAddressKey = 'geocode_last_address';
  static const String _diagTimeKey = 'geocode_last_time';
  static const String _diagAmapInfoKey = 'geocode_last_amap_info';
  static const String _diagAmapInfoCodeKey = 'geocode_last_amap_infocode';

  /// 获取当前位置（仅在求助触发时调用，降低高德API消耗）
  /// ⚠️ 重要：此方法不再内部调用 request()！
  /// 权限必须由 UI 层（如 help_page 的引导页）先请求好，这里只负责获取位置。
  /// 原因：在获取位置时偷偷 request() 会导致 iOS 系统在不合适的时机吞掉权限弹窗，
  ///       造成 App 永远不出现在位置服务列表中的死锁问题。
  static Future<LocationResult> getCurrentLocation() async {
    try {
      debugPrint('[LocationService] 开始获取位置...');

      // 纯检查权限（不触发弹窗）
      final hasPerm = await hasPermission();
      if (!hasPerm) {
        debugPrint('[LocationService] 位置权限未授权，无法获取位置');
        return LocationResult.error('位置权限未开启，请先在求助页面开启位置权限');
      }

      // 检查定位服务
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[LocationService] 定位服务未开启');
        return LocationResult.error('定位服务未开启，请在系统设置中开启');
      }

      debugPrint('[LocationService] 权限已授权，获取位置中...');
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );

      debugPrint(
          '[LocationService] 位置获取成功: ${position.latitude}, ${position.longitude}');

      final coordStr =
          '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
      final mapsUrl =
          'https://maps.apple.com/?ll=${position.latitude},${position.longitude}';
      final amapUrl =
          'https://uri.amap.com/marker?position=${position.longitude},${position.latitude}';

      debugPrint('[LocationService] 坐标: $coordStr');
      debugPrint('[LocationService] Apple Maps URL: $mapsUrl');
      debugPrint('[LocationService] 高德 URL: $amapUrl');

      // 逆地理编码
      String? address;
      try {
        address = await reverseGeocode(position.latitude, position.longitude);
        debugPrint('[LocationService] 逆地理编码地址: $address');
      } catch (e) {
        debugPrint('[LocationService] 逆地理编码失败（非致命）: $e');
      }

      return LocationResult.success(
        latitude: position.latitude,
        longitude: position.longitude,
        coordString: coordStr,
        mapsUrl: mapsUrl,
        amapUrl: amapUrl,
        address: address,
      );
    } catch (e) {
      debugPrint('[LocationService] 位置获取失败: $e');
      return LocationResult.error('位置获取失败，请手动告知位置');
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
        debugPrint('[LocationService] hasPermission - geolocator: $geoPerm');
        if (geoPerm == LocationPermission.whileInUse || 
            geoPerm == LocationPermission.always) {
          debugPrint('[LocationService] hasPermission → true (via geolocator)');
          return true;
        }
      } catch (e) {
        debugPrint('[LocationService] geolocator 检查失败（非致命）: $e');
      }

      // 方式2：permission_handler 兜底检查
      final phWhenInUse = await Permission.locationWhenInUse.status;
      final phAlways = await Permission.locationAlways.status;
      debugPrint('[LocationService] hasPermission - whenInUse: $phWhenInUse, always: $phAlways');

      if (phWhenInUse.isGranted || phWhenInUse.isLimited ||
          phAlways.isGranted || phAlways.isLimited) {
        debugPrint('[LocationService] hasPermission → true (via permission_handler)');
        return true;
      }

      // 两者都没通过
      debugPrint('[LocationService] hasPermission → false');
      return false;
    } catch (e) {
      debugPrint('[LocationService] 检查权限失败: $e');
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
    debugPrint('[LocationService] requestPermission: 使用 geolocator 原生方式请求位置权限...');

    try {
      // 方式1：优先使用 geolocator 原生方法
      final locationPermission = await Geolocator.requestPermission();
      debugPrint('[LocationService] geolocator.requestPermission 结果: $locationPermission');

      // 将 geolocator 的 LocationPermission 转换为 permission_handler 的 PermissionStatus
      switch (locationPermission) {
        case LocationPermission.whileInUse:
        case LocationPermission.always:
          return PermissionStatus.granted;
        case LocationPermission.denied:
        case LocationPermission.deniedForever:
          // 再用 permission_handler 检查是否是永久拒绝
          final phStatus = await Permission.locationWhenInUse.status;
          debugPrint('[LocationService] permission_handler 复核状态: $phStatus');
          return phStatus;
        case LocationPermission.unableToDetermine:
          return PermissionStatus.denied;
      }
    } catch (e) {
      debugPrint('[LocationService] geolocator.requestPermission 异常: $e');
      // 降级到 permission_handler
      debugPrint('[LocationService] 降级使用 permission_handler...');
      final status = await Permission.locationWhenInUse.request();
      debugPrint('[LocationService] permission_handler.requestPermission 结果: $status');
      return status;
    }
  }

  /// 逆地理编码：经纬度 → 可读地址
  /// 使用高德 Web 服务 API (REST)
  /// 返回格式化地址，失败时返回 null
  static Future<String?> reverseGeocode(double latitude, double longitude) async {
    try {
      final String? amapAddr = await _reverseGeocodeAmap(latitude, longitude);
      if (amapAddr != null && amapAddr.trim().isNotEmpty) {
        await _storeGeocodeDiag(provider: 'amap', address: amapAddr.trim());
        return amapAddr.trim();
      }
      final nativeAddr = await _reverseGeocodeNative(latitude, longitude);
      await _storeGeocodeDiag(
        provider: (nativeAddr != null && nativeAddr.trim().isNotEmpty) ? 'native' : 'none',
        address: nativeAddr?.trim(),
      );
      return nativeAddr;
    } catch (e, st) {
      debugPrint('[LocationService] 💥 逆地理编码未捕获异常: $e\n$st');
      await _storeGeocodeDiag(provider: 'none', address: null);
      return null;
    }
  }

  static Future<void> _storeGeocodeDiag({
    required String provider,
    required String? address,
    String? amapInfo,
    String? amapInfoCode,
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
      if (amapInfo != null) {
        await prefs.setString(_diagAmapInfoKey, amapInfo);
      }
      if (amapInfoCode != null) {
        await prefs.setString(_diagAmapInfoCodeKey, amapInfoCode);
      }
    } catch (e) {
      debugPrint('[LocationService] ⚠️ 写入逆地理诊断失败: $e');
    }
  }

  static Future<String?> _reverseGeocodeAmap(double latitude, double longitude) async {
    final key = AppConstants.amapApiKey;
    if (key.isEmpty) {
      debugPrint('[LocationService] ⚠️ 高德 API Key 未配置，跳过高德逆地理编码');
      await _storeGeocodeDiag(provider: 'amap_failed', address: null, amapInfo: 'KEY_EMPTY');
      return null;
    }

    final url = 'https://restapi.amap.com/v3/geocode/regeo'
        '?key=$key'
        '&location=$longitude,$latitude'
        '&extensions=base'
        '&output=JSON';

    debugPrint('[LocationService] 🔍 高德逆地理: lat=$latitude, lng=$longitude');

    final client = _AmapHttpClient();
    final responseBody = await client.get(url);

    if (responseBody == null || responseBody.isEmpty) {
      debugPrint('[LocationService] ❌ 高德逆地理: 空响应');
      return null;
    }

    final data = jsonDecode(responseBody);
    final status = data['status'];
    final info = data['info'];
    final infoCode = data['infocode'];

    if (status == '1' && data['regeocode'] != null) {
      final formattedAddr = data['regeocode']['formatted_address'] as String?;
      debugPrint('[LocationService] ✅ 高德逆地理成功');
      await _storeGeocodeDiag(
        provider: 'amap',
        address: formattedAddr?.trim(),
        amapInfo: info?.toString(),
        amapInfoCode: infoCode?.toString(),
      );
      return formattedAddr;
    }

    debugPrint('[LocationService] ❌ 高德逆地理失败: status=$status info=$info infocode=$infoCode');
    await _storeGeocodeDiag(
      provider: 'amap_failed',
      address: null,
      amapInfo: info?.toString(),
      amapInfoCode: infoCode?.toString(),
    );
    return null;
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

      final result = parts.join();
      if (result.isEmpty) return null;
      debugPrint('[LocationService] ✅ 系统逆地理成功');
      return result;
    } catch (e) {
      debugPrint('[LocationService] ⚠️ 系统逆地理失败: $e');
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
  final String? amapUrl;        // 高德地图 URL
  final String? address;        // 逆地理编码地址（如：北京市朝阳区xx路xx号）
  final String? errorMessage;

  LocationResult._({
    required this.isSuccess,
    this.latitude,
    this.longitude,
    this.coordString,
    this.mapsUrl,
    this.amapUrl,
    this.address,
    this.errorMessage,
  });

  factory LocationResult.success({
    required double latitude,
    required double longitude,
    required String coordString,
    required String mapsUrl,
    String? amapUrl,
    String? address,
  }) {
    return LocationResult._(
      isSuccess: true,
      latitude: latitude,
      longitude: longitude,
      coordString: coordString,
      mapsUrl: mapsUrl,
      amapUrl: amapUrl,
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

/// 轻量级 HTTP Client（用于逆地理编码等简单 GET 请求，避免引入 http 包）
class _AmapHttpClient {
  Future<String?> get(String url) async {
    try {
      final uri = Uri.parse(url);
      final client = io.HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      final request = await client.getUrl(uri);
      request.headers.set('User-Agent', 'ZaineApp/1.9.0');
      final response = await request.close().timeout(const Duration(seconds: 15));
      debugPrint('[AmapHttpClient] HTTP status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        debugPrint('[AmapHttpClient] response length: ${body.length}');
        client.close();
        return body;
      }
      debugPrint('[AmapHttpClient] 非200状态码: ${response.statusCode}');
      client.close();
      return null;
    } on io.SocketException catch (e) {
      debugPrint('[AmapHttpClient] 网络连接失败(SocketException): $e');
      return null;
    } on io.HttpException catch (e) {
      debugPrint('[AmapHttpClient] HTTP异常: $e');
      return null;
    } on TimeoutException catch (e) {
      debugPrint('[AmapHttpClient] 请求超时(15s): $e');
      return null;
    } catch (e) {
      debugPrint('_AmapHttpClient error: $e');
      return null;
    }
  }
}
