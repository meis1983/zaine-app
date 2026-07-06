import 'package:flutter/material.dart';
import '../services/social/guardian_message_service.dart';
import 'package:intl/intl.dart';
import '../theme/theme_helper.dart';

/// 守护圈留言板组件
///
/// 展示与守护对象的消息互动
class GuardianMessageBoard extends StatefulWidget {
  final String guardianId;
  final String guardianName;
  final String? guardianAvatar;
  final String currentUserId;
  final String currentUserName;

  const GuardianMessageBoard({
    super.key,
    required this.guardianId,
    required this.guardianName,
    this.guardianAvatar,
    required this.currentUserId,
    required this.currentUserName,
  });

  @override
  State<GuardianMessageBoard> createState() => _GuardianMessageBoardState();
}

class _GuardianMessageBoardState extends State<GuardianMessageBoard> {
  final SocialService _socialService = SocialService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<GuardianMessage> _messages = [];
  bool _isLoading = true;
  bool _showEmojiPicker = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    _messages = await _socialService.getMessagesForGuardian(widget.guardianId);
    setState(() => _isLoading = false);
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    final success = await _socialService.sendMessage(
      senderId: widget.currentUserId,
      senderName: widget.currentUserName,
      receiverId: widget.guardianId,
      type: MessageType.text,
      content: content,
    );

    if (success) {
      _messageController.clear();
      await _loadMessages();
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 消息列表
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _messages.isEmpty
                  ? _buildEmptyState()
                  : _buildMessageList(),
        ),
        // 输入区域
        _buildInputArea(),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: ZaiNeColors.textHint(),
          ),
          const SizedBox(height: 16),
          Text(
            '还没有消息',
            style: TextStyle(
              fontSize: 16,
              color: ZaiNeColors.textSecondary(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '发送第一条消息吧~',
            style: TextStyle(
              fontSize: 14,
              color: ZaiNeColors.textHint(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return RefreshIndicator(
      onRefresh: _loadMessages,
      child: ListView.builder(
        controller: _scrollController,
        reverse: true,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          final message = _messages[index];
          final isMe = message.senderId == widget.currentUserId;
          return _buildMessageBubble(message, isMe);
        },
      ),
    );
  }

  Widget _buildMessageBubble(GuardianMessage message, bool isMe) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            _buildAvatar(message.senderAvatar, 32),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: Text(
                      message.senderName,
                      style: TextStyle(
                        fontSize: 12,
                        color: ZaiNeColors.textSecondary(),
                      ),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe ? Theme.of(context).primaryColor : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isMe ? 18 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        message.content ?? '',
                        style: TextStyle(
                          fontSize: 15,
                          color: isMe ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTime(message.createdAt),
                        style: TextStyle(
                          fontSize: 10,
                          color: isMe ? Colors.white70 : Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            _buildAvatar(null, 32), // 当前用户头像
          ],
        ],
      ),
    );
  }

  Widget _buildAvatar(String? avatarUrl, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
      ),
      child: Center(
        child: Icon(
          Icons.person,
          size: size * 0.6,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return DateFormat('MM/dd').format(time);
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(ZaiNeSpacing.md),
      decoration: BoxDecoration(
        color: ZaiNeColors.cardBg(),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // 表情按钮
            IconButton(
              icon: Icon(
                Icons.emoji_emotions_outlined,
                color: _showEmojiPicker ? Theme.of(context).primaryColor : Colors.grey,
              ),
              onPressed: () {
                setState(() => _showEmojiPicker = !_showEmojiPicker);
              },
            ),
            // 文字输入框
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    hintText: '发送消息...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  maxLines: 1,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // 发送按钮
            IconButton(
              icon: Icon(
                Icons.send_rounded,
                color: Theme.of(context).primaryColor,
              ),
              onPressed: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }
}

/// 消息卡片 - 用于在列表中显示单条消息
class MessageCard extends StatelessWidget {
  final GuardianMessage message;
  final bool isMe;
  final VoidCallback? onTap;

  const MessageCard({
    super.key,
    required this.message,
    required this.isMe,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: ZaiNeColors.borderColor()),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(ZaiNeSpacing.md),
          child: Row(
            children: [
              _buildTypeIcon(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getTypeTitle(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message.content ?? _getTypeSubtitle(),
                      style: TextStyle(
                        color: ZaiNeColors.textSecondary(),
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (!message.isRead)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    _formatDate(message.createdAt),
                    style: TextStyle(
                      color: ZaiNeColors.textHint(),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeIcon() {
    IconData icon;
    Color color;

    switch (message.type) {
      case MessageType.text:
        icon = Icons.chat_bubble_outline;
        color = Colors.blue;
        break;
      case MessageType.emoji:
        icon = Icons.emoji_emotions;
        color = Colors.orange;
        break;
      case MessageType.checkin:
        icon = Icons.check_circle_outline;
        color = Colors.green;
        break;
      case MessageType.sos:
        icon = Icons.warning_amber_rounded;
        color = Colors.red;
        break;
      case MessageType.milestone:
        icon = Icons.emoji_events;
        color = Colors.amber;
        break;
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }

  String _getTypeTitle() {
    switch (message.type) {
      case MessageType.text:
        return message.senderName;
      case MessageType.emoji:
        return '${message.senderName} 发送了表情';
      case MessageType.checkin:
        return '签到提醒';
      case MessageType.sos:
        return '紧急求助';
      case MessageType.milestone:
        return '成就解锁';
    }
  }

  String _getTypeSubtitle() {
    switch (message.type) {
      case MessageType.text:
        return '点击查看详情';
      case MessageType.emoji:
        return message.emojiCode ?? '😊';
      case MessageType.checkin:
        return '守护对象已签到';
      case MessageType.sos:
        return '查看详情';
      case MessageType.milestone:
        return message.content ?? '恭喜！';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return DateFormat('MM/dd').format(date);
  }
}
