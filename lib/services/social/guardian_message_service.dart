/// 守护圈社交服务
///
/// 提供守护圈动态、留言板、表情互动、成就系统等功能
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 留言类型
enum MessageType {
  text,      // 文字留言
  emoji,     // 表情
  checkin,   // 签到提醒
  sos,       // SOS 事件
  milestone, // 里程碑事件
}

/// 留言数据模型
class GuardianMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String? senderAvatar;
  final String receiverId;
  final MessageType type;
  final String? content;
  final String? emojiCode;
  final DateTime createdAt;
  final bool isRead;
  final String? relatedEventId;

  GuardianMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    required this.receiverId,
    required this.type,
    this.content,
    this.emojiCode,
    required this.createdAt,
    this.isRead = false,
    this.relatedEventId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'sender_id': senderId,
        'sender_name': senderName,
        'sender_avatar': senderAvatar,
        'receiver_id': receiverId,
        'type': type.name,
        'content': content,
        'emoji_code': emojiCode,
        'created_at': createdAt.toIso8601String(),
        'is_read': isRead,
        'related_event_id': relatedEventId,
      };

  factory GuardianMessage.fromJson(Map<String, dynamic> json) {
    return GuardianMessage(
      id: json['id'] as String,
      senderId: json['sender_id'] as String,
      senderName: json['sender_name'] as String,
      senderAvatar: json['sender_avatar'] as String?,
      receiverId: json['receiver_id'] as String,
      type: MessageType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => MessageType.text,
      ),
      content: json['content'] as String?,
      emojiCode: json['emoji_code'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      isRead: json['is_read'] as bool? ?? false,
      relatedEventId: json['related_event_id'] as String?,
    );
  }

  GuardianMessage copyWith({
    String? id,
    String? senderId,
    String? senderName,
    String? senderAvatar,
    String? receiverId,
    MessageType? type,
    String? content,
    String? emojiCode,
    DateTime? createdAt,
    bool? isRead,
    String? relatedEventId,
  }) {
    return GuardianMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      receiverId: receiverId ?? this.receiverId,
      type: type ?? this.type,
      content: content ?? this.content,
      emojiCode: emojiCode ?? this.emojiCode,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      relatedEventId: relatedEventId ?? this.relatedEventId,
    );
  }
}

/// 守护成就数据模型
class GuardianAchievement {
  final String id;
  final String title;
  final String description;
  final String icon;
  final String category; // 'checkin', 'care', 'emergency', 'milestone'
  final int requiredValue;
  final int currentValue;
  final DateTime? unlockedAt;
  final bool isUnlocked;

  GuardianAchievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.category,
    required this.requiredValue,
    this.currentValue = 0,
    this.unlockedAt,
    this.isUnlocked = false,
  });

  double get progress => requiredValue > 0 ? (currentValue / requiredValue).clamp(0.0, 1.0) : 0.0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'icon': icon,
        'category': category,
        'required_value': requiredValue,
        'current_value': currentValue,
        'unlocked_at': unlockedAt?.toIso8601String(),
        'is_unlocked': isUnlocked,
      };

  factory GuardianAchievement.fromJson(Map<String, dynamic> json) {
    return GuardianAchievement(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      icon: json['icon'] as String,
      category: json['category'] as String,
      requiredValue: json['required_value'] as int,
      currentValue: json['current_value'] as int? ?? 0,
      unlockedAt: json['unlocked_at'] != null
          ? DateTime.parse(json['unlocked_at'] as String)
          : null,
      isUnlocked: json['is_unlocked'] as bool? ?? false,
    );
  }

  GuardianAchievement copyWith({
    String? id,
    String? title,
    String? description,
    String? icon,
    String? category,
    int? requiredValue,
    int? currentValue,
    DateTime? unlockedAt,
    bool? isUnlocked,
  }) {
    return GuardianAchievement(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      category: category ?? this.category,
      requiredValue: requiredValue ?? this.requiredValue,
      currentValue: currentValue ?? this.currentValue,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      isUnlocked: isUnlocked ?? this.isUnlocked,
    );
  }
}

/// 表情数据模型
class EmojiInteraction {
  final String id;
  final String senderId;
  final String senderName;
  final String receiverId;
  final String emojiCode;
  final DateTime createdAt;
  final bool isAnimating;

  EmojiInteraction({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.receiverId,
    required this.emojiCode,
    required this.createdAt,
    this.isAnimating = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'sender_id': senderId,
        'sender_name': senderName,
        'receiver_id': receiverId,
        'emoji_code': emojiCode,
        'created_at': createdAt.toIso8601String(),
      };

  factory EmojiInteraction.fromJson(Map<String, dynamic> json) {
    return EmojiInteraction(
      id: json['id'] as String,
      senderId: json['sender_id'] as String,
      senderName: json['sender_name'] as String,
      receiverId: json['receiver_id'] as String,
      emojiCode: json['emoji_code'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// 社交服务 - 管理守护圈留言板和表情互动
class SocialService {
  static const String _messagesKey = 'guardian_messages';
  static const String _achievementsKey = 'guardian_achievements';
  static const String _emojiInteractionsKey = 'emoji_interactions';

  SharedPreferences? _prefs;

  Future<void> _ensureInitialized() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // ==================== 留言板功能 ====================

  /// 获取与某位守护对象的所有留言
  Future<List<GuardianMessage>> getMessagesForGuardian(String guardianId) async {
    await _ensureInitialized();
    final jsonStr = _prefs!.getString('${_messagesKey}_$guardianId');
    if (jsonStr == null) return [];

    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list
          .map((json) => GuardianMessage.fromJson(json as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      if (kDebugMode) debugPrint('[Social] 解析留言失败: $e');
      return [];
    }
  }

  /// 发送留言
  Future<bool> sendMessage({
    required String senderId,
    required String senderName,
    String? senderAvatar,
    required String receiverId,
    required MessageType type,
    String? content,
    String? emojiCode,
  }) async {
    await _ensureInitialized();

    final message = GuardianMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: senderId,
      senderName: senderName,
      senderAvatar: senderAvatar,
      receiverId: receiverId,
      type: type,
      content: content,
      emojiCode: emojiCode,
      createdAt: DateTime.now(),
    );

    final messages = await getMessagesForGuardian(receiverId);
    messages.insert(0, message);

    try {
      await _prefs!.setString(
        '${_messagesKey}_$receiverId',
        jsonEncode(messages.map((m) => m.toJson()).toList()),
      );
      if (kDebugMode) debugPrint('[Social] 留言发送成功: ${message.id}');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[Social] 保存留言失败: $e');
      return false;
    }
  }

  /// 标记留言为已读
  Future<void> markMessageAsRead(String guardianId, String messageId) async {
    final messages = await getMessagesForGuardian(guardianId);
    final index = messages.indexWhere((m) => m.id == messageId);
    if (index != -1) {
      messages[index] = messages[index].copyWith(isRead: true);
      await _prefs!.setString(
        '${_messagesKey}_$guardianId',
        jsonEncode(messages.map((m) => m.toJson()).toList()),
      );
    }
  }

  /// 获取未读留言数量
  Future<int> getUnreadCount(String guardianId) async {
    final messages = await getMessagesForGuardian(guardianId);
    return messages.where((m) => !m.isRead).length;
  }

  // ==================== 表情互动功能 ====================

  /// 获取可发送的表情列表
  List<Map<String, String>> getAvailableEmojis() {
    return [
      {'code': '❤️', 'name': '爱心', 'category': 'emotion'},
      {'code': '😊', 'name': '开心', 'category': 'emotion'},
      {'code': '🌸', 'name': '花朵', 'category': 'nature'},
      {'code': '☀️', 'name': '阳光', 'category': 'nature'},
      {'code': '🌙', 'name': '月亮', 'category': 'nature'},
      {'code': '🍀', 'name': '幸运草', 'category': 'nature'},
      {'code': '💪', 'name': '加油', 'category': 'action'},
      {'code': '🙏', 'name': '祈福', 'category': 'action'},
      {'code': '🎉', 'name': '庆祝', 'category': 'action'},
      {'code': '🤗', 'name': '拥抱', 'category': 'action'},
      {'code': '👍', 'name': '点赞', 'category': 'social'},
      {'code': '✌️', 'name': '胜利', 'category': 'social'},
      {'code': '🌈', 'name': '彩虹', 'category': 'nature'},
      {'code': '🦋', 'name': '蝴蝶', 'category': 'nature'},
      {'code': '🎵', 'name': '音乐', 'category': 'activity'},
      {'code': '☕', 'name': '咖啡', 'category': 'activity'},
    ];
  }

  /// 发送表情
  Future<bool> sendEmoji({
    required String senderId,
    required String senderName,
    required String receiverId,
    required String emojiCode,
  }) async {
    await _ensureInitialized();

    final interaction = EmojiInteraction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: senderId,
      senderName: senderName,
      receiverId: receiverId,
      emojiCode: emojiCode,
      createdAt: DateTime.now(),
    );

    try {
      // 保存到发送者记录
      final sentKey = '${_emojiInteractionsKey}_sent_$senderId';
      final sentJson = _prefs!.getString(sentKey);
      final sentList = sentJson != null
          ? jsonDecode(sentJson) as List<dynamic>
          : <dynamic>[];
      sentList.insert(0, interaction.toJson());
      await _prefs!.setString(sentKey, jsonEncode(sentList));

      // 保存到接收者记录
      final receivedKey = '${_emojiInteractionsKey}_received_$receiverId';
      final receivedJson = _prefs!.getString(receivedKey);
      final receivedList = receivedJson != null
          ? jsonDecode(receivedJson) as List<dynamic>
          : <dynamic>[];
      receivedList.insert(0, interaction.toJson());
      await _prefs!.setString(receivedKey, jsonEncode(receivedList));

      if (kDebugMode) debugPrint('[Social] 表情发送成功: $emojiCode');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[Social] 保存表情失败: $e');
      return false;
    }
  }

  /// 获取收到的表情
  Future<List<EmojiInteraction>> getReceivedEmojis(String userId) async {
    await _ensureInitialized();
    final jsonStr = _prefs!.getString('${_emojiInteractionsKey}_received_$userId');
    if (jsonStr == null) return [];

    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list
          .map((json) => EmojiInteraction.fromJson(json as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      if (kDebugMode) debugPrint('[Social] 解析表情失败: $e');
      return [];
    }
  }

  // ==================== 成就系统功能 ====================

  /// 获取所有成就定义
  List<GuardianAchievement> getAllAchievements() {
    return [
      // 签到类成就
      GuardianAchievement(
        id: 'checkin_7',
        title: '连续7天签到',
        description: '连续签到7天，展现你的坚持',
        icon: '🔥',
        category: 'checkin',
        requiredValue: 7,
      ),
      GuardianAchievement(
        id: 'checkin_30',
        title: '连续30天签到',
        description: '连续签到一个月，守护之心不变',
        icon: '💎',
        category: 'checkin',
        requiredValue: 30,
      ),
      GuardianAchievement(
        id: 'checkin_100',
        title: '签到大师',
        description: '累计签到100天，成为守护达人',
        icon: '👑',
        category: 'checkin',
        requiredValue: 100,
      ),
      // 关怀类成就
      GuardianAchievement(
        id: 'care_first',
        title: '初次关怀',
        description: '第一次向守护对象发送表情',
        icon: '🌟',
        category: 'care',
        requiredValue: 1,
      ),
      GuardianAchievement(
        id: 'care_10',
        title: '温暖传递',
        description: '累计发送10次表情关怀',
        icon: '💝',
        category: 'care',
        requiredValue: 10,
      ),
      GuardianAchievement(
        id: 'care_50',
        title: '爱心大使',
        description: '累计发送50次表情关怀',
        icon: '🎀',
        category: 'care',
        requiredValue: 50,
      ),
      // 紧急类成就
      GuardianAchievement(
        id: 'emergency_prepared',
        title: '防患未然',
        description: '设置好紧急联系人信息',
        icon: '🛡️',
        category: 'emergency',
        requiredValue: 1,
      ),
      GuardianAchievement(
        id: 'emergency_tested',
        title: '未雨绸缪',
        description: '测试一次SOS紧急求助功能',
        icon: '🔔',
        category: 'emergency',
        requiredValue: 1,
      ),
      // 里程碑成就
      GuardianAchievement(
        id: 'milestone_guardians_3',
        title: '三人守护',
        description: '拥有3位守护人',
        icon: '👥',
        category: 'milestone',
        requiredValue: 3,
      ),
      GuardianAchievement(
        id: 'milestone_guardians_5',
        title: '守护联盟',
        description: '拥有5位守护人',
        icon: '🎖️',
        category: 'milestone',
        requiredValue: 5,
      ),
      GuardianAchievement(
        id: 'milestone_guardian_count_10',
        title: '守护10人',
        description: '守护10位亲友',
        icon: '🫂',
        category: 'milestone',
        requiredValue: 10,
      ),
    ];
  }

  /// 获取用户成就进度
  Future<List<GuardianAchievement>> getUserAchievements(String userId) async {
    await _ensureInitialized();

    final achievements = getAllAchievements();
    final jsonStr = _prefs!.getString('${_achievementsKey}_$userId');

    if (jsonStr == null) return achievements;

    try {
      final savedData = jsonDecode(jsonStr) as Map<String, dynamic>;
      return achievements.map((a) {
        if (savedData.containsKey(a.id)) {
          final saved = savedData[a.id] as Map<String, dynamic>;
          return a.copyWith(
            currentValue: saved['current_value'] as int? ?? 0,
            isUnlocked: saved['is_unlocked'] as bool? ?? false,
            unlockedAt: saved['unlocked_at'] != null
                ? DateTime.parse(saved['unlocked_at'] as String)
                : null,
          );
        }
        return a;
      }).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('[Social] 解析成就失败: $e');
      return achievements;
    }
  }

  /// 更新成就进度
  Future<void> updateAchievementProgress(
    String userId,
    String achievementId,
    int newValue,
  ) async {
    await _ensureInitialized();

    final achievements = await getUserAchievements(userId);
    final index = achievements.indexWhere((a) => a.id == achievementId);
    if (index == -1) return;

    final achievement = achievements[index];
    final updated = achievement.copyWith(
      currentValue: newValue,
      isUnlocked: newValue >= achievement.requiredValue,
      unlockedAt: newValue >= achievement.requiredValue && !achievement.isUnlocked
          ? DateTime.now()
          : achievement.unlockedAt,
    );
    achievements[index] = updated;

    // 保存
    final savedData = <String, dynamic>{};
    for (final a in achievements) {
      savedData[a.id] = a.toJson();
    }
    await _prefs!.setString('${_achievementsKey}_$userId', jsonEncode(savedData));

    if (kDebugMode) debugPrint('[Social] 成就进度更新: $achievementId = $newValue');
  }

  /// 批量更新成就进度
  Future<void> updateAchievementsBatch(
    String userId,
    Map<String, int> progress,
  ) async {
    for (final entry in progress.entries) {
      await updateAchievementProgress(userId, entry.key, entry.value);
    }
  }

  /// 获取已解锁的成就数量
  Future<int> getUnlockedCount(String userId) async {
    final achievements = await getUserAchievements(userId);
    return achievements.where((a) => a.isUnlocked).length;
  }
}
