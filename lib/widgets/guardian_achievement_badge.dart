import 'package:flutter/material.dart';
import '../theme/theme_helper.dart';
import '../services/social/guardian_message_service.dart';
import 'package:intl/intl.dart';

/// 守护成就页面
///
/// 展示用户的所有成就和进度
class GuardianAchievementsPage extends StatefulWidget {
  final String userId;
  final SocialService socialService;

  const GuardianAchievementsPage({
    super.key,
    required this.userId,
    required this.socialService,
  });

  @override
  State<GuardianAchievementsPage> createState() => _GuardianAchievementsPageState();
}

class _GuardianAchievementsPageState extends State<GuardianAchievementsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<GuardianAchievement> _achievements = [];
  bool _isLoading = true;
  int _unlockedCount = 0;
  int _totalCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAchievements();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAchievements() async {
    setState(() => _isLoading = true);
    // 🔴【v1.97.3 修复 Bug 3 + Bug 6】主动刷新全部 11 个成就进度
    // 原因：getUserAchievements 只读 SharedPreferences 已存值，不主动从真实数据源刷新——
    // 导致进度条恒显 0/7、0/30、0/100，且关怀/里程碑两类从未接入过任何更新流。
    _achievements = await widget.socialService.refreshAllAchievements(widget.userId);
    _unlockedCount = _achievements.where((a) => a.isUnlocked).length;
    _totalCount = _achievements.length;
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZaiNeColors.scaffoldBg(),
      appBar: AppBar(
        title: const Text('守护成就'),
        backgroundColor: ZaiNeColors.cardBg(),
        foregroundColor: ZaiNeColors.textPrimary(),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: ZaiNeColors.textHint(),
          indicatorColor: Theme.of(context).primaryColor,
          tabs: const [
            Tab(text: '全部'),
            Tab(text: '签到'),
            Tab(text: '关怀'),
            Tab(text: '里程碑'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 成就统计卡片
                _buildStatsCard(),
                // 成就列表
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildAchievementList(null),
                      _buildAchievementList('checkin'),
                      _buildAchievementList('care'),
                      _buildAchievementList('milestone'),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatsCard() {
    final progress = _totalCount > 0 ? _unlockedCount / _totalCount : 0.0;

    return Container(
      margin: const EdgeInsets.all(ZaiNeSpacing.lg),
      padding: const EdgeInsets.all(ZaiNeSpacing.section),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // 成就徽章
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    _unlockedCount > 0 ? '🎖️' : '🏅',
                    style: const TextStyle(fontSize: 36),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '已解锁 $_unlockedCount / $_totalCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getMotivationalText(),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 进度条
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withValues(alpha: 0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  String _getMotivationalText() {
    if (_unlockedCount == 0) return '开始你的守护之旅吧！';
    if (_unlockedCount < _totalCount * 0.3) return '继续加油！';
    if (_unlockedCount < _totalCount * 0.6) return '表现不错！';
    if (_unlockedCount < _totalCount) return '接近目标了！';
    return '太棒了！全部解锁！';
  }

  Widget _buildAchievementList(String? category) {
    final filtered = category == null
        ? _achievements
        : _achievements.where((a) => a.category == category).toList();

    return RefreshIndicator(
      onRefresh: _loadAchievements,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          return AchievementCard(achievement: filtered[index]);
        },
      ),
    );
  }
}

/// 成就卡片组件
class AchievementCard extends StatelessWidget {
  final GuardianAchievement achievement;
  final VoidCallback? onTap;

  const AchievementCard({
    super.key,
    required this.achievement,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: achievement.isUnlocked
              ? Theme.of(context).primaryColor.withValues(alpha: 0.3)
              : Colors.grey.shade200,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(ZaiNeSpacing.lg),
          child: Row(
            children: [
              // 成就图标
              _buildIcon(),
              const SizedBox(width: 16),
              // 成就信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            achievement.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: achievement.isUnlocked
                                  ? Colors.black87
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ),
                        if (achievement.isUnlocked)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade100,
                              borderRadius: BorderRadius.circular(8),
                            
                              boxShadow: ZaiNeShadows.card,),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  size: 14,
                                  color: Colors.amber.shade700,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '已解锁',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.amber.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      achievement.description,
                      style: TextStyle(
                        fontSize: 13,
                        color: ZaiNeColors.textSecondary(),
                      ),
                    ),
                    if (!achievement.isUnlocked) ...[
                      const SizedBox(height: 12),
                      // 进度条
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: achievement.progress,
                                backgroundColor: Colors.grey.shade200,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _getCategoryColor(),
                                ),
                                minHeight: 6,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${achievement.currentValue}/${achievement.requiredValue}',
                            style: TextStyle(
                              fontSize: 12,
                              color: ZaiNeColors.textSecondary(),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (achievement.isUnlocked && achievement.unlockedAt != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        '解锁于 ${DateFormat('yyyy/MM/dd').format(achievement.unlockedAt!)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: ZaiNeColors.textHint(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: achievement.isUnlocked
            ? _getCategoryColor().withValues(alpha: 0.15)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      
        boxShadow: ZaiNeShadows.card,),
      child: Center(
        child: achievement.isUnlocked
            ? Text(
                achievement.icon,
                style: const TextStyle(fontSize: 32),
              )
            : Icon(
                Icons.lock_outline,
                size: 28,
                color: ZaiNeColors.textSecondary(),
              ),
      ),
    );
  }

  Color _getCategoryColor() {
    switch (achievement.category) {
      case 'checkin':
        return Colors.green;
      case 'care':
        return Colors.pink;
      case 'emergency':
        return Colors.orange;
      case 'milestone':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}

/// 成就徽章组件 - 用于在其他页面显示
class AchievementBadge extends StatelessWidget {
  final String icon;
  final bool isUnlocked;
  final double size;

  const AchievementBadge({
    super.key,
    required this.icon,
    this.isUnlocked = true,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isUnlocked
            ? Colors.amber.shade100
            : Colors.grey.shade200,
        shape: BoxShape.circle,
        border: isUnlocked
            ? Border.all(color: Colors.amber.shade300, width: 2)
            : null,
        boxShadow: isUnlocked
            ? [
                BoxShadow(
                  color: Colors.amber.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Center(
        child: Text(
          icon,
          style: TextStyle(fontSize: size * 0.5),
        ),
      ),
    );
  }
}

/// 解锁动画对话框
class AchievementUnlockDialog extends StatefulWidget {
  final GuardianAchievement achievement;

  const AchievementUnlockDialog({
    super.key,
    required this.achievement,
  });

  @override
  State<AchievementUnlockDialog> createState() => _AchievementUnlockDialogState();
}

class _AchievementUnlockDialogState extends State<AchievementUnlockDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.3),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.3, end: 1.0),
        weight: 50,
      ),
    ]).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _rotateAnimation = Tween<double>(
      begin: 0.0,
      end: 0.1,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Transform.rotate(
              angle: _rotateAnimation.value,
              child: child,
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(ZaiNeSpacing.xl),
          decoration: BoxDecoration(
            color: ZaiNeColors.cardBg(),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.amber.withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 庆祝图标
              const Text(
                '🎉',
                style: TextStyle(fontSize: 64),
              ),
              const SizedBox(height: 16),
              // 成就标题
              const Text(
                '成就解锁！',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              // 成就图标
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.amber.shade300, width: 3),
                ),
                child: Center(
                  child: Text(
                    widget.achievement.icon,
                    style: const TextStyle(fontSize: 40),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // 成就名称
              Text(
                widget.achievement.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              // 成就描述
              Text(
                widget.achievement.description,
                style: TextStyle(
                  fontSize: 14,
                  color: ZaiNeColors.textSecondary(),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // 关闭按钮
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: const Text('太棒了！'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
