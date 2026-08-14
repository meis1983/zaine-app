// lib/services/api_service.dart
// 底层 HTTP 封装 (v1.4 新增, v1.6 完善异常处理)

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../data/app_constants.dart';
import 'security/cert_pinner.dart' as security;

/// 安全存储实例（用于 Token）
const _secureStorage = FlutterSecureStorage(
  iOptions: IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  ),
);

class ApiService {
  static final String _baseUrl = AppConstants.backendBaseUrl;

  /// 带证书锁定的 HTTP Client（单例）
  /// 【P1 安全加固 v1.93.8】所有请求经过证书锁定验证
  static final http.Client _pinnedClient = security.createPinnedClient();
  // 阿里云FC冷启动约3-4秒，弱网环境下需预留更多缓冲
  // 【优化 v1.93.8】超时从 8s 增加到 15s，适配弱网和冷启动场景
  static const Duration _timeout = Duration(seconds: 15);
  // 冷启动最多额外重试 2 次（间隔 2s、4s），总计最多 3 次尝试
  static const int _maxRetries = 2;
  // 【优化 v1.93.8】指数退避：2s, 4s → 改为 1.5s, 3s（减少总等待时间）
  static const Duration _retryBaseDelay = Duration(milliseconds: 1500);

  /// 计算第 N 次重试的延迟（指数退避）
  /// attempt=0 → 1.5s, attempt=1 → 3s
  static Duration _retryDelayFor(int attempt) {
    return _retryBaseDelay * (attempt + 1);
  }

  /// 带冷启动自动重试的请求执行器
  /// 仅在超时/网络类错误时重试，HTTP 4xx/5xx 业务错误不重试
  static Future<Map<String, dynamic>> _withRetry(
    Future<Map<String, dynamic>> Function() request,
    String method,
    String path,
  ) async {
    developer.log('[189 NET OUT] $method $path', name: 'zaine.net');
    Exception? lastException;
    for (int attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        if (attempt > 0 && kDebugMode) {
          debugPrint('[ApiService] 🔄 $method $path 第${attempt + 1}次尝试（冷启动重试）...');
        }
        final result = await request();
        developer.log('[189 NET IN] $method $path => success=${result['success']}', name: 'zaine.net');
        // 【优化 v1.96.x】429 限流：退避重试，消除并发请求触发 0.5req/s 限流的雪崩
        if (result['success'] == false &&
            result['statusCode'] == 429 &&
            attempt < _maxRetries) {
          final delay = _retryDelayFor(attempt);
          if (kDebugMode) {
            debugPrint('[ApiService] ⏳ $method $path 触发限流(429)，${delay.inMilliseconds}ms 后退避重试');
          }
          await Future.delayed(delay);
          continue;
        }
        // 其他 HTTP 业务错误不重试（4xx/5xx）
        if (result['success'] == false && result['offline'] != true) {
          return result;
        }
        return result;
      } on TimeoutException catch (e) {
        lastException = e;
        developer.log('[189 NET ERR] $method $path TimeoutException: $e', name: 'zaine.net', error: e);
        if (attempt < _maxRetries) {
          final delay = _retryDelayFor(attempt);
          if (kDebugMode) debugPrint('[ApiService] ⏳ $method $path 超时，${delay.inMilliseconds}ms 后重试');
          await Future.delayed(delay);
          continue;
        }
        break;
      } on SocketException catch (e) {
        lastException = e;
        developer.log('[189 NET ERR] $method $path SocketException: $e', name: 'zaine.net', error: e);
        if (attempt < _maxRetries) {
          final delay = _retryDelayFor(attempt);
          if (kDebugMode) debugPrint('[ApiService] 🌐 $method $path 网络连接失败，重试中...');
          await Future.delayed(delay);
          continue;
        }
        break;
      } on Exception catch (e) {
        lastException = e;
        developer.log('[189 NET ERR] $method $path Exception: $e', name: 'zaine.net', error: e);
        final errorStr = e.toString().toLowerCase();
        final isTimeout = errorStr.contains('timeout') ||
            errorStr.contains('deadline exceeded') ||
            errorStr.contains('connection');
        if (isTimeout && attempt < _maxRetries) {
          final delay = _retryDelayFor(attempt);
          if (kDebugMode) debugPrint('[ApiService] ⏳ $method $path 超时，${delay.inMilliseconds}ms 后重试');
          await Future.delayed(delay);
          continue;
        }
        break;
      }
    }
    developer.log('[189 NET ERR] $method $path 最终离线, error=$lastException', name: 'zaine.net', error: lastException);
    return {'success': false, 'error': lastException.toString(), 'offline': true};
  }

  /// 全局串行请求队列 + 限速整形
  /// 【性能优化 v1.96.x】相邻请求间隔 ≥300ms，消除并发请求互相碰撞导致的 429 / 冷启动雪崩
  /// 所有后端请求均经 ApiService 统一出口，故此处串行化即可覆盖全 App
  static Future<Map<String, dynamic>> _requestChain =
      Future<Map<String, dynamic>>.value(<String, dynamic>{});
  static DateTime _lastRequestStart = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _minRequestInterval = Duration(milliseconds: 300);

  /// 【v1.97.4 / 188 修复】重置全局串行请求队列
  /// 用于登录/冷启动等关键时刻，打断任何可能已"毒化"的挂起链，
  /// 防止个别请求异常导致后续所有请求（含登录）永远 pending。
  static void resetRequestChain() {
    _requestChain = Future<Map<String, dynamic>>.value(<String, dynamic>{});
    _lastRequestStart = DateTime.fromMillisecondsSinceEpoch(0);
    developer.log('[189 NET] resetRequestChain 已重置', name: 'zaine.net');
  }

  /// 将请求串行化并限速整形后执行
  static Future<Map<String, dynamic>> _enqueue(
    Future<Map<String, dynamic>> Function() task,
  ) async {
    // 1) 串行：等待队列中前一个请求完成（避免并发打满后端）
    final prev = _requestChain;
    _requestChain = Future.sync(() async {
      // 【188 修复】前序请求若异常落定，必须吞掉，绝不能让它毒化整条链
      try {
        await prev;
      } catch (_) {
        developer.log('[189 NET] 前序请求异常已隔离, 不阻塞新请求', name: 'zaine.net');
      }
      // 2) 限速整形：保证与上一次请求至少间隔 _minRequestInterval
      final elapsed = DateTime.now().difference(_lastRequestStart);
      if (elapsed < _minRequestInterval) {
        await Future.delayed(_minRequestInterval - elapsed);
      }
      _lastRequestStart = DateTime.now();
      developer.log('[189 NET] 开始执行新请求任务', name: 'zaine.net');
      return task();
    });
    return _requestChain;
  }

  // 获取 token（从安全存储读取）
  static Future<String?> _getToken() async {
    return await _secureStorage.read(key: 'auth_token');
  }

  // 构造请求头
  static Future<Map<String, String>> _headers({bool auth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (auth) {
      final token = await _getToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  // GET 请求（含冷启动重试）
  static Future<Map<String, dynamic>> get(String path,
      {bool auth = true}) async {
    return _enqueue(() => _withRetry(() async {
      final response = await _pinnedClient
          .get(
            Uri.parse('$_baseUrl$path'),
            headers: await _headers(auth: auth),
          )
          .timeout(_timeout);
      return _parse(response);
    }, 'GET', path));
  }

  // POST 请求（含冷启动重试）
  static Future<Map<String, dynamic>> post(String path,
      {Map<String, dynamic>? body, bool auth = true}) async {
    return _enqueue(() => _withRetry(() async {
      final response = await _pinnedClient
          .post(
            Uri.parse('$_baseUrl$path'),
            headers: await _headers(auth: auth),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(_timeout);
      return _parse(response);
    }, 'POST', path));
  }

  // PUT 请求（含冷启动重试）
  static Future<Map<String, dynamic>> put(String path,
      {Map<String, dynamic>? body, bool auth = true}) async {
    return _enqueue(() => _withRetry(() async {
      final response = await _pinnedClient
          .put(
            Uri.parse('$_baseUrl$path'),
            headers: await _headers(auth: auth),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(_timeout);
      return _parse(response);
    }, 'PUT', path));
  }

  // PATCH 请求（含冷启动重试）
  static Future<Map<String, dynamic>> patch(String path,
      {Map<String, dynamic>? body, bool auth = true}) async {
    return _enqueue(() => _withRetry(() async {
      final response = await _pinnedClient
          .patch(
            Uri.parse('$_baseUrl$path'),
            headers: await _headers(auth: auth),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(_timeout);
      return _parse(response);
    }, 'PATCH', path));
  }

  // 生成 SOS 短链（方案 C：存储健康快照，返回 zaine.love/sos/{token}）
  static Future<Map<String, dynamic>> createSosLink({
    required double lat,
    required double lng,
    String address = '',
    String userName = '',
    String userPhone = '',
    int? age,
    String gender = '',
    String bloodType = '',
    String disease = '',
    String medicine = '',
    String allergy = '',
    String message = '',
  }) async {
    return post('/api/sos/create', body: {
      'lat': lat,
      'lng': lng,
      'address': address,
      'user_name': userName,
      'user_phone': userPhone,
      'age': age,
      'gender': gender,
      'blood_type': bloodType,
      'disease': disease,
      'medicine': medicine,
      'allergy': allergy,
      'message': message,
    }, auth: true);
  }

  // 更新 SOS 实时位置（方案 B：SOS 持续期间每30s推送，H5 求助页轮询跟随）
  static Future<Map<String, dynamic>> updateSosLocation(
    String token,
    double lat,
    double lng, {
    String address = '',
  }) {
    return patch('/api/sos/$token/location', body: {
      'lat': lat,
      'lng': lng,
      'address': address,
    }, auth: true);
  }

  // 生成通用短链（邀请短信等场景）
  static Future<Map<String, dynamic>> createShortLink({
    required String targetUrl,
    String linkType = 'general',
    String meta = '',
  }) async {
    return post('/api/shortlink', body: {
      'target_url': targetUrl,
      'link_type': linkType,
      'meta': meta,
    }, auth: true);
  }

  // DELETE 请求（含冷启动重试）【P0修复 v1.9.83】
  static Future<Map<String, dynamic>> delete(String path,
      {bool auth = true}) async {
    return _enqueue(() => _withRetry(() async {
      final response = await _pinnedClient
          .delete(
            Uri.parse('$_baseUrl$path'),
            headers: await _headers(auth: auth),
          )
          .timeout(_timeout);
      return _parse(response);
    }, 'DELETE', path));
  }

  // 解析响应
  static Map<String, dynamic> _parse(http.Response response) {
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true, ...data};
      } else {
    if (kDebugMode) {
      if (kDebugMode) debugPrint('ApiService error ${response.statusCode}: ${response.body}');
    }
    return {'success': false, 'statusCode': response.statusCode, ...data};
      }
    } catch (e) {
      if (kDebugMode) debugPrint('ApiService parse error: $e, body: ${response.body}');
      final body = response.body.trim();
      String errorMsg;
      if (body.isEmpty) {
        errorMsg = '服务器返回空响应 (HTTP ${response.statusCode})';
      } else if (body.startsWith('<')) {
        // 后端返回了 HTML 错误页面（如 502/504 Gateway Error）
        if (response.statusCode >= 500) {
          errorMsg = '服务器繁忙，请稍后重试';
        } else if (response.statusCode == 429) {
          errorMsg = '请求过于频繁，请稍后再试';
        } else {
          errorMsg = '服务器响应异常 (HTTP ${response.statusCode})';
        }
      } else {
        errorMsg = '服务器响应格式错误 (HTTP ${response.statusCode})';
      }
      return {
        'success': false,
        'error': errorMsg,
        'statusCode': response.statusCode,
      };
    }
  }
}
