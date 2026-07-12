// lib/services/api/card_service.dart
// 守护卡 API 封装（v1.9.2）
// 对应后端路由：/api/card/send、/api/card/list、/api/card/check、/api/invite/stats

import '../api_service.dart';

class CardService {
  /// 发送守护卡
  ///
  /// 返回示例（成功）：
  /// {
  ///   "success": true,
  ///   "card_id": 123,
  ///   "card_code": "abc123xyz",
  ///   "share_url": "https://zaine.love/landing/abc123xyz",
  ///   "landing_url": "https://zaine.love/landing/abc123xyz"
  /// }
  static Future<Map<String, dynamic>> sendCard({
    required String message,
    String? recipientName,
  }) async {
    return await ApiService.post('/api/card/send', body: {
      'message': message,
      if (recipientName != null && recipientName.isNotEmpty)
        'receiver_name': recipientName,
    });
  }

  /// 获取我发出的守护卡列表
  ///
  /// 返回示例（成功）：
  /// {
  ///   "success": true,
  ///   "cards": [
  ///     {
  ///       "id": 123,
  ///       "card_code": "abc123xyz",
  ///       "message": "希望你平安",
  ///       "status": "pending",  // pending / activated / expired
  ///       "recipient_name": "妈妈",
  ///       "share_url": "https://zaine.love/landing/abc123xyz",
  ///       "created_at": "2026-04-29T10:00:00"
  ///     }
  ///   ],
  ///   "total": 5
  /// }
  static Future<Map<String, dynamic>> listMyCards() async {
    return await ApiService.get('/api/card/list');
  }

  /// 核销守护卡（被邀请人注册后调用，通常由 deep link 流程触发）
  ///
  /// [cardCode] 守护卡唯一码（来自落地页 URL 参数）
  static Future<Map<String, dynamic>> checkCard(String cardCode) async {
    final code = cardCode.trim().replaceAll(' ', '');
    return await ApiService.get('/api/card/check/$code', auth: false);
  }

  /// 获取邀请统计
  ///
  /// 返回示例（成功）：
  /// {
  ///   "success": true,
  ///   "invited_count": 3,       // 邀请成功人数
  ///   "earned_cards": 3,        // 获赠守护卡总数
  ///   "pending_cards": 1        // 等待对方注册的卡
  /// }
  static Future<Map<String, dynamic>> getInviteStats() async {
    return await ApiService.get('/api/invite/stats');
  }

  /// 领取邀请奖励
  static Future<Map<String, dynamic>> claimInviteReward() async {
    return await ApiService.post('/api/invite/claim');
  }

  /// 创建免费守护卡（不消耗额度）
  /// 用于：添加紧急联系人后的短信邀请、守护圈"邀请注册"
  ///
  /// 返回示例（成功）：
  /// {
  ///   "success": true,
  ///   "card_id": 123,
  ///   "card_code": "abc123",
  ///   "share_url": "https://zaine.love/landing/abc123",
  ///   "expire_at": "2026-05-15T13:58:21"
  /// }
  static Future<Map<String, dynamic>> createFreeCard({
    required String receiverPhone,
    required String receiverName,
  }) async {
    return await ApiService.post('/api/card/create-free', body: {
      'receiver_phone': receiverPhone,
      'receiver_name': receiverName,
    });
  }

  /// 【新增 v1.9.78】使用安全码兑换守护卡
  /// 用于：B 下载 App 后手动输入安全码，完成守护关系绑定
  ///
  /// 返回示例（成功）：
  /// {
  ///   "success": true,
  ///   "sender_id": 123,
  ///   "sender_name": "张三",
  ///   "sender_avatar": "base64...",
  ///   "receiver_name": "妈妈"
  /// }
  static Future<Map<String, dynamic>> redeemCard({
    required String cardCode,
  }) async {
    return await ApiService.post('/api/card/redeem', body: {
      'card_code': cardCode,
    });
  }

  /// 【新增 v1.9.95】查询「我作为收卡人、已建立(status=1)的守护关系」
  /// 用于登录/首启后主动检测是否有未见证的新守护关系，触发接收方欢迎仪式。
  /// 覆盖网页注册绑定（无 App 内 pending_card_code）等链路断点。
  ///
  /// 返回示例（成功）：
  /// {
  ///   "success": true,
  ///   "guardians": [
  ///     {
  ///       "guardian_card_id": 123,
  ///       "card_code": "ABC123",
  ///       "peer_id": 11,
  ///       "peer_name": "张三",
  ///       "peer_avatar": "base64...",
  ///       "role": "receiver",
  ///       "message": "想和你建立守护关系",
  ///       "card_type": 0,
  ///       "bound_at": "2026-07-11T10:00:00"
  ///     }
  ///   ]
  /// }
  ///
  /// [role]：receiver=我是收卡人（返回发卡人信息）；sender=我是发卡人（返回接收人信息，用于「守护成功」飞轮）
  static Future<Map<String, dynamic>> welcomePending({String role = 'receiver'}) async {
    return await ApiService.get('/api/card/welcome-pending?role=$role');
  }

  /// 【2026-07-12】标记某守护关系的欢迎仪式已见证（服务端去重，防跨设备/重装重复弹）
  /// [role]：receiver=我是收卡人；sender=我是发卡人
  static Future<Map<String, dynamic>> welcomeAck({
    required String cardCode,
    required String role,
  }) async {
    return await ApiService.post('/api/card/welcome-ack', body: {
      'card_code': cardCode,
      'role': role,
    });
  }

  /// 【2026-07-12 议题B】我守护的人：我发出的已绑定普通守护卡（无人数上限），含收卡人每日签到状态
  static Future<Map<String, dynamic>> getGuardedByMe() async {
    try {
      final res = await ApiService.get('/api/card/guarded-by-me');
      return res;
    } catch (e) {
      return {'success': false, 'guarded': <dynamic>[], 'count': 0};
    }
  }
}
