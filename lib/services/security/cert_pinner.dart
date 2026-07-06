// lib/services/security/cert_pinner.dart
// SSL 证书锁定（暂时返回普通客户端）

import 'package:http/http.dart' as http;

/// 创建具有证书锁定的 HTTP 客户端
/// 暂时返回普通客户端（后续可实现真正的证书锁定）
http.Client createPinnedClient() {
  return http.Client();
}
