// lib/services/push_service.dart
// 【v1.98.0】APNs 推送：令牌注册与上传
// 新定位「让牵挂有回音」的到达通道——守护人收到「TA 刚刚报了平安 / 今天还没报平安」
// 设计：原生 AppDelegate 负责 权限/注册/token 回调（MethodChannel 'zaine/push'）；
//       Dart 负责登录态判断与 token 上传（/api/devices/register，幂等 upsert）。
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'api_service.dart';
import 'api/auth_service.dart';

class PushService {
  PushService._();
  static final PushService instance = PushService._();

  static const MethodChannel _channel = MethodChannel('zaine/push');
  bool _uploading = false;

  /// App 启动时调用：注册原生回调；若原生已缓存 token 且已登录 → 静默补传。
  /// 权限申请不在这里弹（避免冷启动打扰），登录成功后走 promptAndRegister()。
  Future<void> init() async {
    if (!Platform.isIOS) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onToken') {
        final token = call.arguments as String?;
        if (token != null && token.isNotEmpty) {
          await _uploadToken(token);
        }
      }
    });

    try {
      final cached = await _channel.invokeMethod<String>('getCachedToken');
      if (cached != null && cached.isNotEmpty) {
        await _uploadToken(cached);
      }
    } on PlatformException catch (e) {
      debugPrint('[Push] init 读取缓存 token 失败: ${e.code}');
    }
  }

  /// 登录成功后调用：请求通知权限（首次弹系统框）+ 注册远程推送。
  /// token 异步到达时走原生 onToken 回调 → _uploadToken。
  Future<void> promptAndRegister() async {
    if (!Platform.isIOS) return;
    try {
      final granted =
          await _channel.invokeMethod<bool>('requestPermission');
      debugPrint('[Push] 通知权限 granted=$granted');
      if (granted != true) return;
      await _channel.invokeMethod('registerRemote');
      // 竞态兜底：token 若在 registerRemote 前已注册过，缓存立即可用
      final cached = await _channel.invokeMethod<String>('getCachedToken');
      if (cached != null && cached.isNotEmpty) {
        await _uploadToken(cached);
      }
    } on PlatformException catch (e) {
      debugPrint('[Push] 注册失败: ${e.code} ${e.message}');
    }
  }

  Future<void> _uploadToken(String token) async {
    if (_uploading) return;
    // 未登录不传（后端要求 Bearer）；登录成功后 promptAndRegister/init 会补传
    final authToken = await AuthService.getToken();
    if (authToken == null || authToken.isEmpty) {
      debugPrint('[Push] 未登录，token 暂不上传');
      return;
    }
    _uploading = true;
    try {
      final res = await ApiService.post('/api/devices/register', body: {
        'token': token,
        'platform': 'ios',
        'tz_offset_minutes': DateTime.now().timeZoneOffset.inMinutes,
      });
      debugPrint('[Push] ✅ token 已上传: $res');
    } catch (e) {
      debugPrint('[Push] ⚠️ token 上传失败(下次启动重试): $e');
    } finally {
      _uploading = false;
    }
  }
}
