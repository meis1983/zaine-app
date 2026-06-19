import 'package:flutter/material.dart';
import '../theme/theme_helper.dart';
import '../services/social/guardian_message_service.dart';
import '../widgets/guardian_message_board.dart';
import '../widgets/emoji_interaction_picker.dart';
import '../widgets/guardian_achievement_badge.dart';

/// 社交互动页面
///
/// 整合留言板、表情互动、成就系统
class SocialPage extends StatefulWidget {
  final String currentUserId;
  final String currentUserName;

  const SocialPage({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
  });

  @override
  State<SocialPage> createState() => _SocialPageState();
}

class _SocialPageState extends State<SocialPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SocialService _socialService = SocialService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZaiNeColors.scaffoldBg(),
      appBar: AppBar(
        title: const Text('社交互动'),
        backgroundColor: ZaiNeColors.cardBg(),
        foregroundColor: ZaiNeColors.textPrimary(),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Theme.of(context).primaryColor,
          tabs: const [
            Tab(icon: Icon(Icons.chat_bubble_outline), text: '消息'),
            Tab(icon: Icon(Icons.emoji_emotions), text: '表情'),
            Tab(icon: Icon(Icons.emoji_events), text: '成就'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 消息列表
          _MessagesTab(
            socialService: _socialService,
            currentUserId: widget.currentUserId,
            currentUserName: widget.currentUserName,
          ),
          // 表情历史
          _EmojisTab(
            socialService: _socialService,
            userId: widget.currentUserId,
          ),
          // 成就页面
          GuardianAchievementsPage(
            userId: widget.currentUserId,
            socialService: _socialService,
          ),
        ],
      ),
    );
  }
}

/// 消息列表 Tab
class _MessagesTab extends StatefulWidget {
  final SocialService socialService;
  final String currentUserId;
  final String currentUserName;

  const _MessagesTab({
    required this.socialService,
    required this.currentUserId,
    required this.currentUserName,
  });

  @override
  State<_MessagesTab> createState() => _MessagesTabState();
}

class _MessagesTabState extends State<_MessagesTab> {
  List<GuardianMessage> _messages = [];
  bool _isLoading = true;

  // 模拟守护对象数据
  final List<Map<String, String>> _guardians = [
    {'id': 'guardian_1', 'name': '妈妈'},
    {'id': 'guardian_2', 'name': '爸爸'},
    {'id': 'guardian_3', 'name': '闺蜜小美'},
  ];

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    
    // 加载所有守护对象的消息
    final allMessages = <GuardianMessage>[];
    for (final guardian in _guardians) {
      final messages = await widget.socialService.getMessagesForGuardian(guardian['id']!);
      allMessages.addAll(messages);
    }
    
    // 按时间排序
    allMessages.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    
    setState(() {
      _messages = allMessages;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _messages.isEmpty
            ? _buildEmptyState()
            : RefreshIndicator(
                onRefresh: _loadMessages,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: ZaiNeSpacing.sm),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    return _buildMessageListItem(message);
                  },
                ),
              );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 80,
            color: ZaiNeColors.textHint(),
          ),
          const SizedBox(height: ZaiNeSpacing.xl),
          Text(
            '暂无消息',
            style: TextStyle(
              fontSize: ZaiNeFontSize.subtitle,
              color: ZaiNeColors.textSecondary(),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: ZaiNeSpacing.sm),
          Text(
            '开始和守护你的人互动吧~',
            style: TextStyle(
              fontSize: ZaiNeFontSize.bodySm,
              color: ZaiNeColors.textHint(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageListItem(GuardianMessage message) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.lg, vertical: ZaiNeSpacing.sm),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ZaiNeRadius.card),
        side: BorderSide(color: ZaiNeColors.borderColor()),
      ),
      child: InkWell(
        onTap: () => _openMessageBoard(message.senderId, message.senderName),
        borderRadius: BorderRadius.circular(ZaiNeRadius.card),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 头像
              _buildAvatar(message),
              const SizedBox(width: ZaiNeSpacing.md),
              // 内容
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            message.senderName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: ZaiNeFontSize.body,
                            ),
                          ),
                        ),
                        Text(
                          _formatTime(message.createdAt),
                          style: TextStyle(
                            fontSize: ZaiNeFontSize.caption,
                            color: ZaiNeColors.textHint(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: ZaiNeSpacing.xs),
                    Text(
                      _getMessagePreview(message),
                      style: TextStyle(
                        fontSize: ZaiNeFontSize.caption,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: ZaiNeSpacing.sm),
              // 未读标记
              if (!message.isRead)
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(GuardianMessage message) {
    IconData icon;
    Color color;

    switch (message.type) {
      case MessageType.text:
        icon = Icons.chat_bubble;
        color = Colors.blue;
        break;
      case MessageType.emoji:
        icon = Icons.emoji_emotions;
        color = Colors.orange;
        break;
      case MessageType.checkin:
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case MessageType.sos:
        icon = Icons.warning;
        color = Colors.red;
        break;
      case MessageType.milestone:
        icon = Icons.emoji_events;
        color = Colors.amber;
        break;
    }

    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(ZaiNeRadius.card),
      
        boxShadow: ZaiNeShadows.card,),
      child: Center(
        child: message.type == MessageType.emoji && message.emojiCode != null
            ? Text(
                message.emojiCode!,
                style: const TextStyle(fontSize: ZaiNeFontSize.title),
              )
            : Icon(icon, color: color, size: 24),
      ),
    );
  }

  String _getMessagePreview(GuardianMessage message) {
    switch (message.type) {
      case MessageType.text:
        return message.content ?? '';
      case MessageType.emoji:
        return '发送了一个表情';
      case MessageType.checkin:
        return '已签到平安';
      case MessageType.sos:
        return '发送了紧急求助';
      case MessageType.milestone:
        return '解锁了新成就';
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${time.month}/${time.day}';
  }

  void _openMessageBoard(String guardianId, String guardianName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text(guardianName),
            actions: [
              IconButton(
                icon: const Icon(Icons.emoji_emotions),
                onPressed: () => _showEmojiPicker(guardianId, guardianName),
              ),
            ],
          ),
          body: GuardianMessageBoard(
            guardianId: guardianId,
            guardianName: guardianName,
            currentUserId: widget.currentUserId,
            currentUserName: widget.currentUserName,
          ),
        ),
      ),
    );
  }

  void _showEmojiPicker(String guardianId, String guardianName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EmojiPicker(
        socialService: widget.socialService,
        receiverId: guardianId,
        receiverName: guardianName,
        senderId: widget.currentUserId,
        senderName: widget.currentUserName,
      ),
    );
  }
}

/// 表情 Tab
class _EmojisTab extends StatefulWidget {
  final SocialService socialService;
  final String userId;

  const _EmojisTab({
    required this.socialService,
    required this.userId,
  });

  @override
  State<_EmojisTab> createState() => _EmojisTabState();
}

class _EmojisTabState extends State<_EmojisTab> {
  List<EmojiInteraction> _receivedEmojis = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEmojis();
  }

  Future<void> _loadEmojis() async {
    setState(() => _isLoading = true);
    _receivedEmojis = await widget.socialService.getReceivedEmojis(widget.userId);
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_receivedEmojis.isEmpty) {
      return _buildEmptyState();
    }

    // 按日期分组
    final grouped = _groupByDate(_receivedEmojis);

    return RefreshIndicator(
      onRefresh: _loadEmojis,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: grouped.length,
        itemBuilder: (context, index) {
          final entry = grouped.entries.elementAt(index);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (index > 0) const SizedBox(height: ZaiNeSpacing.lg),
              // 日期标题
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  entry.key,
                  style: TextStyle(
                    fontSize: ZaiNeFontSize.bodySm,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
              // 表情卡片网格
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: entry.value.map((emoji) {
                  return _buildEmojiCard(emoji);
                }).toList(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.emoji_emotions_outlined,
            size: 80,
            color: ZaiNeColors.textHint(),
          ),
          const SizedBox(height: ZaiNeSpacing.xl),
          Text(
            '还没有收到表情',
            style: TextStyle(
              fontSize: ZaiNeFontSize.subtitle,
              color: ZaiNeColors.textSecondary(),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: ZaiNeSpacing.sm),
          Text(
            '守护你的人会发送表情给你~',
            style: TextStyle(
              fontSize: ZaiNeFontSize.bodySm,
              color: ZaiNeColors.textHint(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmojiCard(EmojiInteraction emoji) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ZaiNeRadius.card),
        border: Border.all(color: ZaiNeColors.borderColor()),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            emoji.emojiCode,
            style: const TextStyle(fontSize: ZaiNeFontSize.title),
          ),
          const SizedBox(height: ZaiNeSpacing.sm),
          Text(
            emoji.senderName,
            style: TextStyle(
              fontSize: ZaiNeFontSize.caption,
              color: Colors.grey.shade600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            _formatTime(emoji.createdAt),
            style: TextStyle(
              fontSize: ZaiNeFontSize.micro,
              color: ZaiNeColors.textHint(),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, List<EmojiInteraction>> _groupByDate(List<EmojiInteraction> emojis) {
    final grouped = <String, List<EmojiInteraction>>{};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (final emoji in emojis) {
      final date = DateTime(
        emoji.createdAt.year,
        emoji.createdAt.month,
        emoji.createdAt.day,
      );

      String key;
      if (date == today) {
        key = '今天';
      } else if (date == yesterday) {
        key = '昨天';
      } else if (now.difference(date).inDays < 7) {
        key = '本周';
      } else {
        key = '${date.month}月${date.day}日';
      }

      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(emoji);
    }

    return grouped;
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
