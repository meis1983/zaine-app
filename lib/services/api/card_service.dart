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
}
