// lib/services/api_service.dart
// 底层 HTTP 封装 (v1.4 新增, v1.6 完善异常处理)

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../data/app_constants.dart';

/// 安全存储实例（用于 Token）
const _secureStorage = FlutterSecureStorage(
  iOptions: IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  ),
);

class ApiService {
  static final String _baseUrl = AppConstants.backendBaseUrl;
  // 阿里云FC冷启动约3-4秒，弱网环境下需预留更多缓冲
  static const Duration _timeout = Duration(seconds: 8);
  // 冷启动最多额外重试 2 次（间隔 2s、4s），总计最多 3 次尝试
  static const int _maxRetries = 2;
  static const Duration _retryDelay = Duration(seconds: 2);

  /// 带冷启动自动重试的请求执行器
  /// 仅在超时/网络类错误时重试，HTTP 4xx/5xx 业务错误不重试
  static Future<Map<String, dynamic>> _withRetry(
    Future<Map<String, dynamic>> Function() request,
    String method,
    String path,
  ) async {
    Exception? lastException;
    for (int attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        if (attempt > 0) {
          if (kDebugMode) {
            if (kDebugMode) debugPrint('[ApiService] 🔄 $method $path 第${attempt + 1}次尝试（冷启动重试）...');
          }
        }
        final result = await request();
        // HTTP 业务错误不重试（4xx/5xx）
        if (result['success'] == false && result['offline'] != true) {
          return result;
        }
        return result;
      } on TimeoutException catch (e) {
        lastException = e;
        if (attempt < _maxRetries) {
          if (kDebugMode) {
            if (kDebugMode) debugPrint('[ApiService] ⏳ $method $path 超时，${_retryDelay.inMilliseconds * (attempt + 1)}ms 后重试');
          }
          await Future.delayed(_retryDelay * (attempt + 1));
          continue;
        }
        break;
      } on SocketException catch (e) {
        lastException = e;
        if (attempt < _maxRetries) {
          if (kDebugMode) {
            if (kDebugMode) debugPrint('[ApiService] 🌐 $method $path 网络连接失败，重试中...');
          }
          await Future.delayed(_retryDelay * (attempt + 1));
          continue;
        }
        break;
      } on Exception catch (e) {
        lastException = e;
        final errorStr = e.toString().toLowerCase();
        final isTimeout = errorStr.contains('timeout') ||
            errorStr.contains('deadline exceeded') ||
            errorStr.contains('connection');
        if (isTimeout && attempt < _maxRetries) {
          if (kDebugMode) {
            if (kDebugMode) debugPrint('[ApiService] ⏳ $method $path 超时，${_retryDelay.inMilliseconds * (attempt + 1)}ms 后重试');
          }
          await Future.delayed(_retryDelay * (attempt + 1));
          continue;
        }
        break;
      }
    }
    if (kDebugMode) {
      if (kDebugMode) debugPrint('ApiService $method $path error: $lastException');
    }
    return {'success': false, 'error': lastException.toString(), 'offline': true};
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
    return _withRetry(() async {
      final response = await http
          .get(
            Uri.parse('$_baseUrl$path'),
            headers: await _headers(auth: auth),
          )
          .timeout(_timeout);
      return _parse(response);
    }, 'GET', path);
  }

  // POST 请求（含冷启动重试）
  static Future<Map<String, dynamic>> post(String path,
      {Map<String, dynamic>? body, bool auth = true}) async {
    return _withRetry(() async {
      final response = await http
          .post(
            Uri.parse('$_baseUrl$path'),
            headers: await _headers(auth: auth),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(_timeout);
      return _parse(response);
    }, 'POST', path);
  }

  // PUT 请求（含冷启动重试）
  static Future<Map<String, dynamic>> put(String path,
      {Map<String, dynamic>? body, bool auth = true}) async {
    return _withRetry(() async {
      final response = await http
          .put(
            Uri.parse('$_baseUrl$path'),
            headers: await _headers(auth: auth),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(_timeout);
      return _parse(response);
    }, 'PUT', path);
  }

  // 生成 SOS 短链（无需认证，紧急场景必须可用）
  static Future<Map<String, dynamic>> createSosLink({
    required double lat,
    required double lng,
    String address = '',
    String userName = '',
    String userPhone = '',
  }) async {
    return post('/api/sos/link', body: {
      'lat': lat,
      'lng': lng,
      'address': address,
      'user_name': userName,
      'user_phone': userPhone,
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
    return _withRetry(() async {
      final response = await http
          .delete(
            Uri.parse('$_baseUrl$path'),
            headers: await _headers(auth: auth),
          )
          .timeout(_timeout);
      return _parse(response);
    }, 'DELETE', path);
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
