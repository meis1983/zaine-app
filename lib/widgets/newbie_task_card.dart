import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme/theme_helper.dart';

/// 新手守护任务清单卡片（v1.1）
/// 5个核心引导任务，降低用户流失，提升首周完成率
/// 更新：连续签到放最后 + 生命周期监听权限刷新 + 全完成后自动折叠
class NewbieTaskCard extends StatefulWidget {
  final bool isLoggedIn;
  final int continuousDays;
  final int guardianCount;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenGuardian;
  final VoidCallback onOpenCard;
  final VoidCallback? onAllTasksCompleted;

  const NewbieTaskCard({
    super.key,
    required this.isLoggedIn,
    required this.continuousDays,
    required this.guardianCount,
    required this.onOpenProfile,
    required this.onOpenGuardian,
    required this.onOpenCard,
    this.onAllTasksCompleted,
  });

  @override
  State<NewbieTaskCard> createState() => _NewbieTaskCardState();
}

class _NewbieTaskCardState extends State<NewbieTaskCard>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  bool _isExpanded = true;
  bool _cardSent = false;
  bool _locationGranted = false;
  bool _locationGuideCompleted = false;
  bool _allCompletedPreviously = false;
  bool _profileCompleted = false;
  late AnimationController _animController;
  late Animation<double> _rotateAnim;

  // SP key
  static const String _spKeyCollapsed = 'newbie_tasks_collapsed';
  static const String _spKeyAllDone = 'newbie_tasks_all_done_shown';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _animController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _rotateAnim = Tween<double>(begin: 0, end: 0.5).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
    _loadState();
  }

  @override
  void didUpdateWidget(covariant NewbieTaskCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 外部状态变化时，刷新内部状态
    if (oldWidget.isLoggedIn != widget.isLoggedIn ||
        oldWidget.continuousDays != widget.continuousDays ||
        oldWidget.guardianCount != widget.guardianCount) {
      _loadState();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animController.dispose();
    super.dispose();
  }

  /// 监听 App 生命周期 —— 用户从系统设置返回后刷新权限状态
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkLocationPermission();
    }
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final collapsed = prefs.getBool(_spKeyCollapsed) ?? false;
    final cardSent = prefs.getBool('newbie_card_sent') ?? false;
    final allDoneShown = prefs.getBool(_spKeyAllDone) ?? false;

    // 检查位置权限（系统权限 + 引导弹窗完成标记）
    // 【修复 v1.9.5】统一使用 locationWhenInUse，与 LocationService/引导页保持一致
    final locStatus = await Permission.locationWhenInUse.status;
    final locGuideDone = prefs.getBool('newbie_task_location') ?? false;

    // 【修复 v1.9.7】检查健康档案是否已填写（user_profile 存在且任一关键字段有值即算完成）
    // 根因：原代码存在 null 安全问题 — profile['name']?.toString() 为 null 时，
    //       .isNotEmpty 会抛 NoSuchMethodError，被 catch 捕获后 profileDone 恒为 false
    final profileJson = prefs.getString('user_profile');
    bool profileDone = false;
    if (profileJson != null && profileJson.isNotEmpty) {
      try {
        final profile = jsonDecode(profileJson) as Map<String, dynamic>;
        // 安全提取字段值，避免 null 调用方法
        final name = profile['name']?.toString();
        final bloodType = profile['bloodType']?.toString();
        final allergy = profile['allergy']?.toString();
        final disease = profile['disease']?.toString();
        final medicine = profile['medicine']?.toString();
        final emergencyNote = profile['emergencyNote']?.toString();
        final ageRaw = profile['age'];
        final age = ageRaw is int
            ? ageRaw
            : int.tryParse(ageRaw?.toString() ?? '');

        // 任一关键字段有实际内容即视为已完善
        profileDone = (name != null && name.isNotEmpty) ||
            (bloodType != null && bloodType.isNotEmpty && bloodType != '未知') ||
            (allergy != null && allergy.isNotEmpty) ||
            (disease != null && disease.isNotEmpty) ||
            (medicine != null && medicine.isNotEmpty) ||
            (emergencyNote != null && emergencyNote.isNotEmpty) ||
            (age != null && age > 0);
      } catch (e) {
        debugPrint('[NewbieTask] 解析 user_profile 失败: $e');
      }
    }

    if (!mounted) return;

    // 判断是否全部完成
    final bool wasAllDone = _allCompleted;

    // ★ 关键修复：如果曾经全部完成，但现在连续签到断签导致不再全部完成，
    //   必须清除 _allCompletedPreviously 标记，否则会错误显示简化版小卡片
    bool effectiveAllDoneShown = allDoneShown;
    if (allDoneShown && !_allCompleted) {
      effectiveAllDoneShown = false;
      await prefs.setBool(_spKeyAllDone, false);
    }

    setState(() {
      _isExpanded = !collapsed;
      _cardSent = cardSent;
      _locationGranted = locStatus.isGranted;
      _locationGuideCompleted = locGuideDone;
      _allCompletedPreviously = effectiveAllDoneShown;
      _profileCompleted = profileDone;
    });

    if (collapsed) {
      _animController.value = 0.5;
    }

    // 如果刚刚完成全部任务，自动折叠 + 触发庆祝
    if (_allCompleted && !wasAllDone && !effectiveAllDoneShown) {
      await prefs.setBool(_spKeyAllDone, true);
      await prefs.setBool(_spKeyCollapsed, true);
      if (mounted) {
        setState(() {
          _isExpanded = false;
          _allCompletedPreviously = true;
        });
        _animController.forward();
        HapticFeedback.mediumImpact();
      }
      widget.onAllTasksCompleted?.call();
    }
  }

  /// 任务完成度 [0-5]
  /// 顺序：完善档案 → 添加守护人 → 发送守护卡 → 开启位置权限 → 连续签到3天
  int get _completedCount {
    int count = 0;
    // 【修复 v1.9.5】完善健康档案：只检查本地档案数据，登录≠填了档案
    if (_profileCompleted) count++;
    if (widget.guardianCount > 0) count++;
    if (_cardSent) count++;
    // 位置权限：系统已授权 或 引导弹窗已点确认
    if (_locationGranted || _locationGuideCompleted) count++;
    if (widget.continuousDays >= 3) count++;
    return count;
  }

  bool get _allCompleted => _completedCount >= 5;

  double get _progress => _completedCount / 5.0;

  Future<void> _toggleExpand() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isExpanded = !_isExpanded;
    });
    await prefs.setBool(_spKeyCollapsed, !_isExpanded);
    if (_isExpanded) {
      _animController.reverse();
    } else {
      _animController.forward();
    }
  }

  Future<void> _checkLocationPermission() async {
    // 【修复 v1.9.5】统一使用 locationWhenInUse，与引导页/LocationService 保持一致
    final status = await Permission.locationWhenInUse.status;
    final wasGranted = _locationGranted;
    setState(() => _locationGranted = status.isGranted);
    // 如果刚刚开启权限，检查是否触发全部完成
    if (!wasGranted && status.isGranted) {
      _loadState();
    }
  }

  @override
  Widget build(BuildContext context) {
    // 全部完成且之前已展示过庆祝，则显示简化版卡片
    if (_allCompleted && _allCompletedPreviously) {
      return _buildCompletedMiniCard();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: ZaiNeColors.cardBg(),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _allCompleted
              ? Colors.green.withOpacity(0.3)
              : const Color(0xFFFF7F50).withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ====== 头部（始终可见） ======
          _buildHeader(),

          // ====== 展开内容 ======
          AnimatedCrossFade(
            firstChild: _buildTaskList(),
            secondChild: const SizedBox.shrink(),
            crossFadeState: _isExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final bool allDone = _allCompleted;
    final int done = _completedCount;

    return InkWell(
      onTap: _toggleExpand,
      borderRadius: BorderRadius.vertical(
        top: const Radius.circular(16),
        bottom: _isExpanded ? Radius.zero : const Radius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // 图标
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: allDone
                    ? Colors.green.withOpacity(0.1)
                    : const Color(0xFFFF7F50).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                allDone ? Icons.emoji_events : Icons.shield_outlined,
                size: 20,
                color: allDone ? Colors.green : const Color(0xFFFF7F50),
              ),
            ),
            const SizedBox(width: 12),

            // 标题 + 进度
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    allDone ? '新手任务全部完成！' : '新手守护任务',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: ZaiNeColors.textPrimary(),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _progress,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              allDone ? Colors.green : const Color(0xFFFF7F50),
                            ),
                            minHeight: 6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$done/5',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: allDone ? Colors.green : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 展开/折叠箭头
            RotationTransition(
              turns: _rotateAnim,
              child: Icon(
                Icons.keyboard_arrow_down,
                size: 22,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskList() {
    final tasks = <Map<String, dynamic>>[
      {
        'id': 'profile',
        'icon': Icons.assignment_ind,
        'title': '完善健康档案',
        'subtitle': '填写关键健康信息，紧急时刻能救命',
        // 【修复】使用 _profileCompleted 而非仅 isLoggedIn
        'done': _profileCompleted || widget.isLoggedIn,
        'action': widget.onOpenProfile,
        'btnText': '去填写',
      },
      {
        'id': 'guardian',
        'icon': Icons.people_alt,
        'title': '添加 1 位守护者',
        'subtitle': '紧急联系人会自动成为你的守护者',
        'done': widget.guardianCount > 0,
        'action': widget.onOpenGuardian,
        'btnText': '去添加',
      },
      {
        'id': 'card',
        'icon': Icons.card_giftcard,
        'title': '发送 1 张守护卡',
        'subtitle': '邀请在乎的人，让他们也受到保护',
        'done': _cardSent,
        'action': () {
          widget.onOpenCard();
          // 【修复 v1.9.5】删除3秒自动标记，守护卡发送成功后的标记
          // 只由 guardian_card_page.dart 在真正发送成功后写入 SP，避免"还没发就显示已完成"
        },
        'btnText': '去发送',
      },
      {
        'id': 'location',
        'icon': Icons.location_on,
        'title': '开启位置权限',
        'subtitle': _locationGranted
            ? '位置权限已开启，求助时可发送准确位置'
            : '求助时才能发送准确位置给守护者',
        'done': _locationGranted || _locationGuideCompleted,
        'action': _locationGranted
            ? null
            : () async {
                await openAppSettings();
              },
        'btnText': _locationGranted ? null : '去开启',
      },
      {
        'id': 'checkin3',
        'icon': Icons.local_fire_department,
        'title': '连续签到 3 天',
        'subtitle': widget.continuousDays >= 3
            ? '已完成！继续打卡解锁更多徽章 🏆'
            : widget.continuousDays > 0
                ? '已连续签到 ${widget.continuousDays} 天，再坚持 ${3 - widget.continuousDays} 天 💪'
                : '每天签到，让守护者知道你平安',
        'done': widget.continuousDays >= 3,
        'inProgress': widget.continuousDays > 0 && widget.continuousDays < 3,
        'action': null, // 签到按钮在首页其他地方
        'btnText': null,
      },
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Divider(height: 1, color: ZaiNeColors.dividerColor()),
          const SizedBox(height: 12),

          // 任务列表
          ...tasks.map((task) => _buildTaskItem(task)),

          // 全部完成后的徽章
          if (_allCompleted) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.verified, size: 18, color: Colors.green),
                  const SizedBox(width: 6),
                  Text(
                    '解锁徽章：守护先锋',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.green[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTaskItem(Map<String, dynamic> task) {
    final bool done = task['done'] as bool;
    final bool inProgress = task['inProgress'] as bool? ?? false;
    final VoidCallback? action = task['action'] as VoidCallback?;
    final String? btnText = task['btnText'] as String?;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 状态圈：已完成=绿色✓ / 进行中=橙色火焰 / 未开始=灰色图标
          Container(
            width: 24,
            height: 24,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: done
                  ? Colors.green.withOpacity(0.1)
                  : inProgress
                      ? Colors.orange.withOpacity(0.1)
                      : Colors.grey[200],
              shape: BoxShape.circle,
              border: done
                  ? Border.all(color: Colors.green.withOpacity(0.3))
                  : inProgress
                      ? Border.all(color: Colors.orange.withOpacity(0.4))
                      : Border.all(color: Colors.grey[300]!),
            ),
            child: done
                ? Icon(Icons.check, size: 14, color: Colors.green[600])
                : inProgress
                    ? Center(
                        child: Text(
                          '${_getTaskProgress(task)}',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[700],
                          ),
                        ),
                      )
                    : Icon(
                        task['icon'] as IconData,
                        size: 12,
                        color: Colors.grey[500],
                      ),
          ),
          const SizedBox(width: 12),

          // 文字内容
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      task['title'] as String,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: done
                            ? Colors.grey[500]
                            : inProgress
                                ? ZaiNeColors.textPrimary()
                                : ZaiNeColors.textPrimary(),
                        decoration: done ? TextDecoration.lineThrough : null,
                        decorationColor: Colors.grey[400],
                      ),
                    ),
                    if (inProgress) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '进行中',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange[700],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  task['subtitle'] as String,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),

          // 操作按钮
          if (!done && !inProgress && btnText != null && action != null)
            GestureDetector(
              onTap: action,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF7F50).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: const Color(0xFFFF7F50).withOpacity(0.3)),
                ),
                child: Text(
                  btnText,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFF7F50),
                  ),
                ),
              ),
            )
          else if (done)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                '已完成',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.green[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 计算签到任务的进度文字（如 "1/3"）
  String _getTaskProgress(Map<String, dynamic> task) {
    if (task['id'] == 'checkin3') {
      return '${widget.continuousDays.clamp(0, 3)}/3';
    }
    return '';
  }

  /// 全部完成后的简化版小卡片
  Widget _buildCompletedMiniCard() {
    return GestureDetector(
      onTap: _toggleExpand,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Icon(Icons.verified, size: 18, color: Colors.green[600]),
            const SizedBox(width: 8),
            Text(
              '守护先锋 · 新手任务全部完成',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.green[700],
              ),
            ),
            const Spacer(),
            Icon(Icons.keyboard_arrow_down,
                size: 18, color: Colors.green.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }
}
