import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/social/guardian_message_service.dart';
import '../theme/theme_helper.dart';

/// 表情选择器组件
///
/// 用于选择并发送表情给守护对象
class EmojiPicker extends StatefulWidget {
  final SocialService socialService;
  final String receiverId;
  final String receiverName;
  final String senderId;
  final String senderName;
  final Function(String emojiCode)? onEmojiSent;

  const EmojiPicker({
    super.key,
    required this.socialService,
    required this.receiverId,
    required this.receiverName,
    required this.senderId,
    required this.senderName,
    this.onEmojiSent,
  });

  @override
  State<EmojiPicker> createState() => _EmojiPickerState();
}

class _EmojiPickerState extends State<EmojiPicker> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Map<String, List<Map<String, String>>> _categorizedEmojis = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _categorizeEmojis();
  }

  void _categorizeEmojis() {
    final emojis = widget.socialService.getAvailableEmojis();
    _categorizedEmojis['emotion'] = emojis.where((e) => e['category'] == 'emotion').toList();
    _categorizedEmojis['nature'] = emojis.where((e) => e['category'] == 'nature').toList();
    _categorizedEmojis['action'] = emojis.where((e) => e['category'] == 'action').toList();
    _categorizedEmojis['social'] = emojis.where((e) => e['category'] == 'social').toList();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          // 拖动指示条
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            
              boxShadow: ZaiNeShadows.card,),
          ),
          // 标题
          Padding(
            padding: const EdgeInsets.all(ZaiNeSpacing.lg),
            child: Row(
              children: [
                Text(
                  '发送给 ${widget.receiverName}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // 分类 Tab
          TabBar(
            controller: _tabController,
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Theme.of(context).primaryColor,
            tabs: const [
              Tab(text: '情感'),
              Tab(text: '自然'),
              Tab(text: '动作'),
              Tab(text: '社交'),
            ],
          ),
          // 表情网格
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildEmojiGrid('emotion'),
                _buildEmojiGrid('nature'),
                _buildEmojiGrid('action'),
                _buildEmojiGrid('social'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmojiGrid(String category) {
    final emojis = _categorizedEmojis[category] ?? [];
    
    return GridView.builder(
      padding: const EdgeInsets.all(ZaiNeSpacing.lg),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 1,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: emojis.length,
      itemBuilder: (context, index) {
        final emoji = emojis[index];
        return _buildEmojiButton(emoji);
      },
    );
  }

  Widget _buildEmojiButton(Map<String, String> emoji) {
    return Material(
      color: Colors.grey.shade100,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _sendEmoji(emoji['code']!),
        borderRadius: BorderRadius.circular(12),
        child: Center(
          child: Text(
            emoji['code']!,
            style: const TextStyle(fontSize: 28),
          ),
        ),
      ),
    );
  }

  Future<void> _sendEmoji(String emojiCode) async {
    HapticFeedback.mediumImpact();
    
    final success = await widget.socialService.sendEmoji(
      senderId: widget.senderId,
      senderName: widget.senderName,
      receiverId: widget.receiverId,
      emojiCode: emojiCode,
    );

    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Text(emojiCode, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                const Text('已发送'),
              ],
            ),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
        widget.onEmojiSent?.call(emojiCode);
        Navigator.pop(context);
      }
    }
  }
}

/// 表情气泡 - 显示收到的表情动画
class EmojiBubble extends StatefulWidget {
  final String emojiCode;
  final String senderName;
  final DateTime timestamp;
  final bool showAnimation;

  const EmojiBubble({
    super.key,
    required this.emojiCode,
    required this.senderName,
    required this.timestamp,
    this.showAnimation = true,
  });

  @override
  State<EmojiBubble> createState() => _EmojiBubbleState();
}

class _EmojiBubbleState extends State<EmojiBubble> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.2),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.2, end: 1.0),
        weight: 50,
      ),
    ]).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _bounceAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: -20.0),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -20.0, end: 0.0),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: -10.0),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -10.0, end: 0.0),
        weight: 25,
      ),
    ]).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    if (widget.showAnimation) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _bounceAnimation.value),
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).primaryColor.withValues(alpha: 0.1),
              Colors.white,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.emojiCode,
              style: const TextStyle(fontSize: 48),
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.senderName} 送给你',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 快速表情按钮
class QuickEmojiButton extends StatelessWidget {
  final String emojiCode;
  final VoidCallback onTap;
  final bool isSelected;

  const QuickEmojiButton({
    super.key,
    required this.emojiCode,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? Theme.of(context).primaryColor.withValues(alpha: 0.2)
          : Colors.grey.shade100,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(color: Theme.of(context).primaryColor, width: 2)
                : null,
          
            boxShadow: ZaiNeShadows.card,),
          child: Center(
            child: Text(
              emojiCode,
              style: const TextStyle(fontSize: 24),
            ),
          ),
        ),
      ),
    );
  }
}

/// 表情历史记录
class EmojiHistoryList extends StatelessWidget {
  final List<EmojiInteraction> interactions;
  final VoidCallback? onRefresh;

  const EmojiHistoryList({
    super.key,
    required this.interactions,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (interactions.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () async => onRefresh?.call(),
      child: ListView.builder(
        padding: const EdgeInsets.all(ZaiNeSpacing.lg),
        itemCount: interactions.length,
        itemBuilder: (context, index) {
          final interaction = interactions[index];
          return _buildEmojiHistoryItem(context, interaction);
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
            size: 64,
            color: ZaiNeColors.textHint(),
          ),
          const SizedBox(height: 16),
          Text(
            '还没有收到表情',
            style: TextStyle(
              fontSize: 16,
              color: ZaiNeColors.textSecondary(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '守护你的人会发送表情给你~',
            style: TextStyle(
              fontSize: 14,
              color: ZaiNeColors.textHint(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmojiHistoryItem(BuildContext context, EmojiInteraction interaction) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: ZaiNeColors.borderColor()),
      ),
      child: Padding(
        padding: const EdgeInsets.all(ZaiNeSpacing.md),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              
                boxShadow: ZaiNeShadows.card,),
              child: Center(
                child: Text(
                  interaction.emojiCode,
                  style: const TextStyle(fontSize: 32),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    interaction.senderName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(interaction.createdAt),
                    style: TextStyle(
                      color: ZaiNeColors.textSecondary(),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
    return '${time.month}/${time.day}';
  }
}
