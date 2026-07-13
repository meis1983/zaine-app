import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'dart:async';  // 新增：用于 Timer
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/guardian_card_service.dart';
import '../services/api/card_service.dart';
import '../services/api/auth_service.dart';
import '../theme/theme_helper.dart';
import '../utils/avatar_helper.dart';
import '../utils/wechat_helper.dart';
import '../widgets/guardian_card_painter.dart';
import '../data/app_constants.dart';

/// 守护卡页面 — 制作守护卡分享给在乎的人
///
/// 精简设计：称呼（纯装饰）+ 祝福语 + 系统分享 + 保存相册
/// 不再单独提供短信发送入口，由系统分享面板统一处理
class GuardianCardPage extends StatefulWidget {
  const GuardianCardPage({super.key});

  @override
  State<GuardianCardPage> createState() => _GuardianCardPageState();
}

class _GuardianCardPageState extends State<GuardianCardPage> {
  // 用户信息
  String _userName = '';
  String _userAvatar = '';  // 【修复 v1.9.8】用户头像URL
  String _recipientName = '';

  // 祝福语
  int _selectedMessageIndex = 0;
  final TextEditingController _customMsgController = TextEditingController();
  bool _isCustomMessage = false;

  // 额度（v2.0 单池模型：available_cards）
  int _availableCards = 0;

  // 当前卡片的裂变参数（后端发卡成功后更新）
  String _currentShareUrl = '';
  String _currentCardCode = '';  // 【新增 v1.9.78】当前守护卡安全码

  // 邀请统计（P4）
  int _invitedCount = 0;

  // 【新增】初始卡过期状态 & 签到解锁进度
  bool _initialCardsExpired = false;
  int? _initialRemainingDays;
  Map<String, dynamic>? _checkinProgress;
  int _totalRegistered = 0;

  // 【新增 v1.9.9】待注册卡片列表（含 expire_at，用于倒计时）
  List<Map<String, dynamic>> _pendingCards = [];

  // 状态
  bool _isSharing = false;
  bool _needsLogin = false;
  bool _isLoadingData = false;  // 【修复 v1.14.0】区分"加载中"和"真的待解锁"
  bool _syncFailed = false;  // 【新增 v1.84.0】后端同步失败标记
  bool _hasFailedCards = false;  // 【新增 v1.84.0】有发送失败的守护卡

  // 展开状态（方案C：显示待注册卡片列表）
  bool _isExpanded = false;

  // 倒计时定时器（方案C：实时刷新）
  Timer? _countdownTimer;

  // 卡片截图 key
  final GlobalKey _cardKey = GlobalKey();

  // 预设祝福语
  final List<String> _presetMessages = [
    '希望你每天都平安快乐 💙',
    '不管多远，我都在乎你 🌟',
    '照顾好自己，有需要随时找我 🤗',
    '你是我最在乎的人 💕',
    '平安是最好的消息，每天报个到吧 🏠',
    '无论何时，你不是一个人 ✨',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _customMsgController.dispose();
    _cancelCountdownTimer();
    super.dispose();
  }

  Future<void> _loadData() async {
    // 【修复 v1.14.0】标记加载状态，避免后端未返回时错误显示"待解锁"
    if (mounted) setState(() => _isLoadingData = true);
    final prefs = await SharedPreferences.getInstance();

    // 【修复 v1.75.0】先加载用户数据（不依赖 isLoggedIn() 结果）
    // 根因：如果 isLoggedIn() 误判为 false，后续代码不执行，_userName 永远为空
    //       导致 _shareCard() 里的兜底逻辑完全失效
    final userId = prefs.getString('user_id');
    final profileKey = (userId != null && userId.isNotEmpty)
        ? 'user_profile_$userId'
        : 'user_profile';
    final profileJson = prefs.getString(profileKey);
    if (profileJson != null) {
      try {
        final profile = jsonDecode(profileJson) as Map<String, dynamic>;
        _userName = profile['name']?.toString() ?? '';
        _userAvatar = profile['avatar']?.toString() ?? '';
      } catch (_) {}
    }
    final avatarPath = await AvatarHelper.getPath(prefs);
    if (avatarPath != null && avatarPath.isNotEmpty) {
      _userAvatar = avatarPath;
    }

    // 【修复 v1.9.7】统一使用 AuthService 判断登录状态，避免与首页标准不一致
    // 根因：首页用 is_logged_in 判断，守护卡页直接查 auth_token，两者可能不同步
    final isLoggedIn = await AuthService.isLoggedIn();

    // 【修复 v1.75.0】多重判断：isLoggedIn OR 有用户数据 → 认为已登录
    final hasUserData = _userName.isNotEmpty || (userId != null && userId.isNotEmpty);
    if (!isLoggedIn && !hasUserData) {
      if (kDebugMode) debugPrint('[GuardianCardPage] ⚠️ 用户未登录且无用户数据，标记需要登录');
      if (mounted) {
        setState(() {
          _needsLogin = true;
          _isLoadingData = false;
        });
      }
      return;
    }

    // 登录状态正常，确保 _needsLogin 为 false（防止页面复用保留旧状态）
    if (mounted) {
      setState(() => _needsLogin = false);
    }

    // 初始化赠送卡（如果是新用户）
    await GuardianCardService.initGiftCards();

    // 【性能优化 v1.9.12】页面加载时预加载头像到图片缓存
    // 根因：之前在 _shareCard() 点击发送时才 precacheImage，增加 0.5-1s 延迟
    // 修复：在 _loadData 阶段就预加载，发送时直接截取
    if (_userAvatar.isNotEmpty && mounted) {
      try {
        final ImageProvider avatarProvider = _userAvatar.startsWith('/') || _userAvatar.startsWith('file://')
            ? FileImage(File(_userAvatar))
            : NetworkImage(_userAvatar) as ImageProvider;
        await precacheImage(avatarProvider, context);
        if (kDebugMode) debugPrint('[GuardianCardPage] 头像预加载完成');
      } catch (e) {
        if (kDebugMode) debugPrint('[GuardianCardPage] 头像预加载失败(不影响): $e');
      }
    }

    // 【修复 2026-07-12】缓存优先 + 去重请求，根治「加载好几分钟 / 额度显示已用完」
    // 根因：原逻辑 forceSyncFromBackend() 内部串行调 listMyCards + getInviteStats（各 15s×3 冷启动重试），
    //       再 Future.wait 并行各调一次 → 同一接口被调两次，冷启动时叠加近 2.5 分钟；
    //       且同步失败回退到 0 → UI 显示「已用完」。
    // 新逻辑：进页先用本地缓存额度秒显并立即结束加载态，后台仅发 1 次 listMyCards + 1 次 getInviteStats 校正。
    final failedQueue = await GuardianCardService.getFailedQueue();
    if (kDebugMode) debugPrint('[GuardianCardPage] 重试队列: ${failedQueue.length}条');
    if (mounted) setState(() => _hasFailedCards = failedQueue.isNotEmpty);

    final cachedCards = await GuardianCardService.getGiftRemaining();
    if (kDebugMode) debugPrint('[GuardianCardPage] 本地缓存额度: $cachedCards 张');

    // 缓存优先：立即显示额度，用户永远看不到几分钟的转圈
    if (mounted) {
      setState(() {
        _availableCards = cachedCards;
        _isLoadingData = false;
      });
    }

    // 后台静默校正（不阻塞 UI，失败则继续使用本地缓存）
    try {
      final cardListRes = await CardService.listMyCards(); // 单次调用，同时作为配额 + 待注册卡数据源
      if (cardListRes['success'] == true) {
        final cards = cardListRes['cards'] as List<dynamic>? ?? [];
        if (kDebugMode) debugPrint('[GuardianCardPage] 🔍 listMyCards 原始返回: ${cards.length}张卡片');
        _pendingCards = cards
            .where((c) {
          final status = c['status'];
          final isFree = c['is_free'] == 1;
          // 支持整数 0 和字符串 'pending'，兼容不同后端版本
          final accepted = ((status is int && status == 0) ||
                  (status is String && status.toLowerCase() == 'pending')) &&
              !isFree;
          if (!accepted && kDebugMode) {
            debugPrint('  ⚠️ 卡片被过滤器丢弃: status=$status is_free=$isFree');
          }
          return accepted;
        })
            .map((c) {
          final expireAtStr = c['expire_at']?.toString() ?? '';
          DateTime? expireAt;
          if (expireAtStr.isNotEmpty) {
            String parseStr = expireAtStr;
            if (!parseStr.contains('T')) parseStr = parseStr.replaceAll(' ', 'T');
            if (!parseStr.endsWith('Z')) parseStr = '${parseStr}Z';
            expireAt = DateTime.tryParse(parseStr)?.toLocal();
          }
          return {
            'card_code': c['card_code']?.toString() ?? '',
            'receiver_name': c['receiver_name']?.toString() ?? '',
            'expire_at': expireAt,
          };
        }).toList();
        if (kDebugMode) debugPrint('[GuardianCardPage] 待注册卡片数: ${_pendingCards.length}');

        final stats = cardListRes['stats'] as Map<String, dynamic>?;
        if (stats != null) {
          _totalRegistered = (stats['total_registered'] as int?) ?? 0;
          _initialCardsExpired = stats['initial_cards_expired'] == true;
          _initialRemainingDays = stats['initial_remaining_days'] as int?;
          _checkinProgress = stats['checkin_progress'] as Map<String, dynamic>?;
          // 后端权威值覆盖本地缓存（清缓存场景也能纠正）
          final backendAvailable = (stats['available_cards'] as int?) ?? _availableCards;
          if (backendAvailable != _availableCards) {
            _availableCards = backendAvailable;
            await GuardianCardService.updateLocalCache(_availableCards);
          }
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[GuardianCardPage] 后台校正卡片列表失败(继续使用缓存): $e');
    }

    try {
      final statsRes = await CardService.getInviteStats(); // 单次调用
      if (statsRes['success'] == true) {
        _invitedCount = (statsRes['total_registered'] as int?) ?? 0;
      }
    } catch (_) {}

    // 同步失败标记（仅当本地与后端都为 0 时提示）
    _syncFailed = cachedCards == 0 && _availableCards == 0;

    if (mounted) setState(() {}); // 用校正后的数据刷新 UI
  }

  String get _currentMessage =>
      _isCustomMessage ? _customMsgController.text.trim() : _presetMessages[_selectedMessageIndex];

  /// 【优化 v1.19.3】备用链接改为 App Store 直链，未装 App 的用户直接跳转下载
  /// 已装 App 的用户通过 _currentShareUrl（Universal Link）直接打开 App
  String get _appStoreUrl => AppConstants.appStoreUrl;

  int get _totalAvailable => _availableCards;

  // ==================== 截图分享 ====================

  Future<void> _shareCard() async {
    // 【修复 v1.75.0】多重登录状态校验
    // 1. 标准检查：AuthService.isLoggedIn()
    // 2. 兜底检查：页面已有用户数据（避免 Keychain 读取偶发失败导致误判）
    final isLoggedIn = await AuthService.isLoggedIn();
    final hasUserData = _userName.isNotEmpty;

    if (!isLoggedIn && !hasUserData) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('请先登录后再发送守护卡'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    // 兜底生效时记录日志（便于排查 Keychain 读取问题）
    if (!isLoggedIn && hasUserData) {
      if (kDebugMode) debugPrint('[GuardianCardPage] ⚠️ isLoggedIn=false 但页面有用户数据，允许继续（兜底生效）');
    }

    // 不再验证祝福语是否为空——祝福语渲染在卡片图片上，微信发图即可看到
    // iOS 微信不支持通过分享 API 传递文本内容

    setState(() => _isSharing = true);
    HapticFeedback.mediumImpact();

    try {
      // ====== 第一步：编辑昵称（先让用户输入，再发卡） ======
      if (!mounted) return;
      
      final defaultRecipient = _recipientName.isNotEmpty ? _recipientName : '朋友';

      // 使用 TextEditingController 管理输入状态
      // 【修复 v1.9.11】不手动 dispose —— 由 Dart GC 自动回收
      // 原因：StatefulBuilder 的 setDlgState 会触发重建，TextField 在重建后
      // 仍引用已 dispose 的 controller 导致 "used after being disposed" 崩溃
      final senderController = TextEditingController(text: _userName.isNotEmpty ? _userName : '我');
      final recipientController = TextEditingController(text: defaultRecipient);

      // 显示昵称编辑对话框
      final confirmedResult = await showDialog<Map<String, String>?>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setDlgState) {
              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZaiNeRadius.card)),
                title: const Row(
                  children: [
                    Icon(Icons.edit_outlined, color: ZaiNeColors.brandOrange),
                    SizedBox(width: ZaiNeSpacing.sm),
                    Text('编辑称呼'),
                  ],
                ),
                // 【修复 v1.9.11】包 SingleChildScrollView 防止键盘弹出时 BOTTOM OVERFLOWED
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 接收者称谓 (P1: 关键字段，加大字号)
                      Container(
                        padding: const EdgeInsets.all(ZaiNeSpacing.md),
                        decoration: BoxDecoration(
                          color: ZaiNeColors.brandOrangeLight,
                          borderRadius: BorderRadius.circular(ZaiNeRadius.small),
                          border: Border.all(color: ZaiNeColors.brandOrange.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('对方称呼（必填）', style: TextStyle(fontSize: ZaiNeFontSize.caption, color: ZaiNeColors.brandOrange, fontWeight: FontWeight.bold)),
                            const SizedBox(height: ZaiNeSpacing.xs),
                            TextField(
                              controller: recipientController,
                              autofocus: true,
                              onChanged: (_) => setDlgState(() {}),
                              style: const TextStyle(fontSize: ZaiNeFontSize.subtitle, fontWeight: FontWeight.bold),
                              decoration: const InputDecoration(
                                hintText: '例如：小赵',
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: ZaiNeSpacing.lg),
                      // 发送者昵称
                      TextField(
                        controller: senderController,
                        onChanged: (_) => setDlgState(() {}),
                        decoration: InputDecoration(
                          labelText: '你的昵称',
                          prefixIcon: const Icon(Icons.person_outline, color: ZaiNeColors.brandOrange),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(ZaiNeRadius.small)),
                        ),
                      ),
                      const SizedBox(height: ZaiNeSpacing.md),
                      Text(
                        '让对方一眼就知道是你寄出的礼物 💌',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: ZaiNeFontSize.caption, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, null),
                    child: const Text('取消'),
                  ),
                  SizedBox(
                    width: 100,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () {
                        final finalSender = senderController.text.trim();
                        final finalRecipient = recipientController.text.trim();
                        if (finalRecipient.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('请输入对方的称呼')),
                          );
                          return;
                        }
                        Navigator.pop(ctx, {
                          'senderName': finalSender.isEmpty ? '我' : finalSender,
                          'recipientName': finalRecipient,
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ZaiNeColors.brandOrange,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZaiNeRadius.small)),
                      ),
                      child: const Text('生成守护卡', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
              );
            },
          );
        },
      );

      if (confirmedResult == null || !mounted) {
        setState(() => _isSharing = false);
        return;
      }

      // 用用户输入的昵称更新卡片显示
      final customSender = confirmedResult['senderName'] ?? '';
      final customRecipient = confirmedResult['recipientName'] ?? '';
      if (customSender.isNotEmpty && mounted) {
        setState(() {
          // 临时更新 _userName，让卡片预览显示用户输入的发送者昵称
          _userName = customSender;
          if (customRecipient.isNotEmpty) _recipientName = customRecipient;
        });
      }

      // ====== 第二步：调用后端发卡，获取安全码 ======
      final sendResult = await GuardianCardService.sendCardWithBackend(
        message: _currentMessage,
        recipientName: _recipientName.isNotEmpty ? _recipientName : null,
      );

      if (!sendResult['success']) {
        // 【修复 v1.84.0】发送失败保存到重试队列
        final err = sendResult['error'];
        final offline = sendResult['offline'] as bool?;
        if (offline == true || (err != null && !err.toString().contains('no_quota') && !err.toString().contains('not_logged_in'))) {
          // 网络错误或非逻辑错误，保存到重试队列
          await GuardianCardService.saveFailedCard({
            'message': _currentMessage,
            'recipientName': _recipientName.isNotEmpty ? _recipientName : null,
            'timestamp': DateTime.now().toIso8601String(),
          });
          if (kDebugMode) debugPrint('[GuardianCard] 发送失败，已保存到重试队列');
        }

        if (mounted) {
          setState(() => _isSharing = false);
          final statusCode = sendResult['statusCode'] as int?;
          String errMsg;
          if (offline == true) {
            errMsg = '网络连接失败，已保存到重试队列\n恢复网络后将自动重试';
          } else if (err == 'not_logged_in') {
            errMsg = '请先登录后再发送守护卡';
          } else if (statusCode == 401) {
            errMsg = '登录已失效，请退出后重新登录';
          } else if (err == 'no_quota' || err == 'no_available_cards') {
            errMsg = '没有可用的守护卡（可能已过期）\n请等待被邀请人注册后可获得新卡片';
          } else {
            errMsg = '发卡失败，已保存到重试队列\n点击"重试"按钮可重新发送';
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errMsg),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: '重试',
                onPressed: _retryFailedCards,
              ),
            ),
          );
        }
        if (kDebugMode) debugPrint('[GuardianCard] 发卡失败: $sendResult');
        return;
      }

      final cardCode = sendResult['cardCode']?.toString() ?? '';
      // 构建 landing 页 URL（扫码后打开精美H5落地页）
      final landingUrl = cardCode.isNotEmpty
          ? AppConstants.guardianCardUrl(cardCode)
          : AppConstants.landingBaseUrl;
      if (mounted) {
        setState(() {
          _currentShareUrl = landingUrl;
          _currentCardCode = cardCode;
          if (kDebugMode) debugPrint('[GuardianCard] 二维码URL已更新: $_currentShareUrl, 安全码: $_currentCardCode');
          final newAvailable = sendResult['available_cards'] as int?;
          if (newAvailable != null) _availableCards = newAvailable;
        });
      }

      // ====== 第三步：直接截图守护卡（不再展示信封动画——动画留给接收端H5落地页） ======
      // 给一帧让 setState 后的卡片重绘生效（使用新的 landing URL 作为二维码内容）
      await Future.delayed(const Duration(milliseconds: 100));

      // ====== 第四步：截图守护卡（用用户输入的昵称） ======
      final bytes = await _captureCard();
      if (bytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('卡片生成失败，请重试'), backgroundColor: Colors.red),
          );
          setState(() => _isSharing = false);
        }
        return;
      }

      // ====== 第四步：保存临时文件并调用系统分享 ======
      // 【修复】iOS 微信不支持通过分享 API 传递文本，只发图片
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/guardian_card_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);

      try {
        await Share.shareXFiles(
          [XFile(file.path)],
          subject: '守护卡 · 在呢',
        );
      } catch (e) {
        if (kDebugMode) debugPrint('[GuardianCard] 系统分享失败: $e');
        // 分享失败不影响发卡成功状态，给用户提示
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('守护卡已生成，但分享失败：$e'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }

      // 刷新额度显示（v2.0 单池）
      // 【修复 v1.9.6】从后端同步最新额度，避免本地缓存与后端不一致
      // 【修复 v1.9.8】开发者重置后发卡，必须清除 skipSync 标记并强制同步后端
      final prefs = await SharedPreferences.getInstance();
      final skipSyncAfterSend = prefs.getBool('guardian_card_skip_sync_once') ?? false;
      if (skipSyncAfterSend) {
        await prefs.remove('guardian_card_skip_sync_once');
        if (kDebugMode) debugPrint('[GuardianCardPage] 开发者重置标记已清除，强制同步后端额度');
      }
      // 【修复 v1.9.8】无论是否开发者重置，发卡后都强制同步后端权威值
      // 根因：sendCardWithBackend 已更新本地缓存，但后端可能有额外逻辑（如过期检查）
      _availableCards = await GuardianCardService.syncQuotaFromBackend();
      if (kDebugMode) debugPrint('[GuardianCardPage] 发卡后同步后端额度: $_availableCards 张');

      // 【修复 v1.19.1】立即刷新UI，确保额度显示即时更新（不用等后面待注册卡片刷新）
      if (mounted) setState(() {});

      // 标记新手任务：发送守护卡完成
      await prefs.setBool('newbie_card_sent', true);

      // 发卡后刷新待注册卡片列表，确保倒计时和折叠面板数据与后端一致
      try {
        final cardListRes = await CardService.listMyCards();
        if (cardListRes['success'] == true) {
          final cards = cardListRes['cards'] as List<dynamic>? ?? [];
          // 【诊断 v1.9.61】发卡后刷新：打印原始数据
          if (kDebugMode) debugPrint('[GuardianCardPage] 🔍 发卡后 listMyCards 原始返回: ${cards.length}张卡片');
          for (int i = 0; i < cards.length; i++) {
            final c = cards[i] as Map<String, dynamic>;
            if (kDebugMode) debugPrint('  卡片[$i] id=${c['id']} status=${c['status']} (type:${c['status'].runtimeType}) receiver=${c['receiver_name']} code=${c['card_code']?.toString().substring(0,6)}...');
          }
          _pendingCards = cards
              .where((c) {
            final status = c['status'];
            final isFree = c['is_free'] == 1;
            final accepted = ((status is int && status == 0) || (status is String && status.toLowerCase() == 'pending')) && !isFree;
            if (!accepted) {
              if (kDebugMode) debugPrint('  ⚠️ 发卡后被过滤器丢弃: status=$status is_free=$isFree');
            }
            return accepted;
          })
              .map((c) {
            final expireAtStr = c['expire_at']?.toString() ?? '';
            DateTime? expireAt;
            if (expireAtStr.isNotEmpty) {
              String parseStr = expireAtStr;
              if (!parseStr.contains('T')) parseStr = parseStr.replaceAll(' ', 'T');
              if (!parseStr.endsWith('Z')) parseStr = '${parseStr}Z';
              expireAt = DateTime.tryParse(parseStr)?.toLocal();
            }
            return {
              'card_code': c['card_code']?.toString() ?? '',
              'receiver_name': c['receiver_name']?.toString() ?? '',
              'expire_at': expireAt,
            };
          }).toList();
          if (kDebugMode) debugPrint('[GuardianCardPage] 发卡后刷新待注册卡片: ${_pendingCards.length}张');
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[GuardianCardPage] 发卡后刷新卡片列表失败: $e');
      }

      if (mounted) {
        setState(() {
          _isSharing = false;
          // 发卡后自动展开待注册卡片列表，让用户立即看到倒计时和提醒TA按钮
          if (_pendingCards.isNotEmpty) {
            _isExpanded = true;
            _startCountdownTimer();
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('守护卡已发送 💌'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[GuardianCard] 分享失败: $e');
      if (mounted) {
        setState(() => _isSharing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('分享失败，请重试'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<Uint8List?> _captureCard() async {
    try {
      // 【修复 v1.9.12】多重保护，防止截到红屏或空白帧
      final context = _cardKey.currentContext;
      if (context == null) {
        if (kDebugMode) debugPrint('[GuardianCard] 截图失败: currentContext 为 null');
        return null;
      }
      final boundary = context.findRenderObject();
      if (boundary == null || boundary is! RenderRepaintBoundary) {
        if (kDebugMode) debugPrint('[GuardianCard] 截图失败: boundary 类型异常 (${boundary.runtimeType})');
        return null;
      }
      // 等一帧，确保 widget 已渲染完成（非红屏状态）
      await Future.delayed(const Duration(milliseconds: 50));
      final image = await boundary.toImage(pixelRatio: 3.0);

      // 阶段①+②：GPU 加速 — 填粉底 + clipRRect 裁切
      const cornerRadius = 24.0 * 3.0; // UI borderRadius(24) × pixelRatio(3.0)
      final roundedImage = await _clipRoundedCorners(image, cornerRadius);

      // 阶段③：PNG → CPU 逐像素边缘采样填充四角 → 输出 JPEG
      final byteData = await roundedImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        if (kDebugMode) debugPrint('[GuardianCard] 截图失败: 生成的图像数据为空');
        return null;
      }
      var src = img.decodeImage(byteData.buffer.asUint8List());
      if (src == null) {
        if (kDebugMode) debugPrint('[GuardianCard] 截图失败: PNG解码失败');
        return null;
      }

      // 【关键】CPU 采样边缘色填充四角外侧像素，消除直角白/粉色边
      _fillRoundedCorners(src, cornerRadius);

      final bytes = Uint8List.fromList(img.encodeJpg(src, quality: 100));
      if (kDebugMode) debugPrint('[GuardianCard] 截图成功: ${bytes.length} bytes (含CPU圆角处理)');
      return bytes;
    } catch (e, st) {
      if (kDebugMode) debugPrint('[GuardianCard] 截图异常: $e\n$st');
      return null;
    }
  }

  /// Canvas GPU 阶段：填充粉色底 + clipRRect（消除透明区域）
  static Future<ui.Image> _clipRoundedCorners(ui.Image image, double radius) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final size = Size(image.width.toDouble(), image.height.toDouble());

    // 填充整个画布为粉色（匹配守护卡渐变主色调）—— 消除所有透明像素
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFFFF9A8B), // 暖橙粉，匹配渐变起点 #FF9A8B
    );

    // 裁切 + 绘制原图
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );
    canvas.clipRRect(rrect);
    canvas.drawImage(image, Offset.zero, Paint());

    final picture = recorder.endRecording();
    return picture.toImage(image.width, image.height);
  }

  /// CPU 阶段：逐像素采样圆边界最近颜色，填充四角外侧像素
  /// 让四角颜色与内容边缘自然过渡，彻底消灭直角视觉效果
  static void _fillRoundedCorners(img.Image image, double radius) {
    final r = radius.round();
    final w = image.width;
    final h = image.height;
    if (r <= 0) return;

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        num cx = 0, cy = 0;
        bool inCorner = false;

        if (x < r && y < r) { cx = r; cy = r; inCorner = true; }
        else if (x >= w - r && y < r) { cx = w - r; cy = r; inCorner = true; }
        else if (x < r && y >= h - r) { cx = r; cy = h - r; inCorner = true; }
        else if (x >= w - r && y >= h - r) { cx = w - r; cy = h - r; inCorner = true; }

        if (inCorner) {
          final dx = x - cx;
          final dy = y - cy;
          final dist = dx * dx + dy * dy;
          if (dist > r * r) {
            final scale = r / sqrt(dist);
            final bx = (cx + dx * scale).round().clamp(0, w - 1);
            final by = (cy + dy * scale).round().clamp(0, h - 1);
            final srcColor = image.getPixel(bx, by);
            image.setPixel(x, y, srcColor);
          }
        }
      }
    }
  }

  Future<void> _saveCard() async {
    // 保存到相册不需要祝福语验证——祝福语已渲染在卡片图片上

    setState(() => _isSharing = true);
    try {
      // 【优化 v1.9.12】头像已在 _loadData 阶段预加载，仅需等一帧
      await Future.delayed(const Duration(milliseconds: 100));
      final bytes = await _captureCard();
      if (bytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('保存失败，请重试'), backgroundColor: Colors.red),
          );
        }
        return;
      }

      final success = await ImageGallerySaver.saveImage(bytes, quality: 100, name: 'zaine_guardian_card');

      if (mounted) {
        setState(() => _isSharing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success != null && success['isSuccess'] == true ? '已保存到相册 📷' : '保存失败'),
            backgroundColor: success != null && success['isSuccess'] == true ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSharing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存失败'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// 【新增 v1.84.0】后端同步失败提示横幅（清除缓存后网络不可用时显示）
  Widget _buildSyncFailedBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: ZaiNeSpacing.md),
      padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.lg, vertical: ZaiNeSpacing.md),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(ZaiNeRadius.small),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off, color: Colors.red.shade700, size: 20),
          const SizedBox(width: ZaiNeSpacing.md),
          Expanded(
            child: Text(
              '无法同步守护卡额度，请检查网络后重试',
              style: TextStyle(fontSize: ZaiNeFontSize.caption, color: Colors.red.shade800, fontWeight: FontWeight.w500),
            ),
          ),
          TextButton(
            onPressed: () async {
              // 重新同步
              if (kDebugMode) debugPrint('[GuardianCardPage] 用户点击重试同步');
              setState(() => _syncFailed = false);
              final result = await GuardianCardService.forceSyncFromBackend();
              if (mounted) {
                setState(() {
                  _availableCards = result;
                  _syncFailed = result == 0;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result > 0 ? '同步成功，剩余 $_availableCards 张守护卡' : '同步失败，请稍后重试'),
                    backgroundColor: result > 0 ? Colors.green : Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: Text('重试', style: TextStyle(color: Colors.red.shade800, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// 【新增 v1.84.0】发送失败的守护卡重试横幅
  Widget _buildFailedCardsBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: ZaiNeSpacing.md),
      padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.lg, vertical: ZaiNeSpacing.md),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(ZaiNeRadius.small),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.orange.shade700, size: 20),
          const SizedBox(width: ZaiNeSpacing.md),
          Expanded(
            child: Text(
              '有守护卡发送失败，可重试',
              style: TextStyle(fontSize: ZaiNeFontSize.caption, color: Colors.orange.shade800, fontWeight: FontWeight.w500),
            ),
          ),
          TextButton(
            onPressed: _isSharing ? null : _retryFailedCards,
            child: _isSharing
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : Text('重试', style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// 未登录提示横幅
  Widget _buildLoginBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: ZaiNeSpacing.md),
      padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.lg, vertical: ZaiNeSpacing.md),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(ZaiNeRadius.small),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
          const SizedBox(width: ZaiNeSpacing.md),
          Expanded(
            child: Text(
              '您尚未登录，发送守护卡需要登录账号',
              style: TextStyle(fontSize: ZaiNeFontSize.caption, color: Colors.orange.shade800, fontWeight: FontWeight.w500),
            ),
          ),
          TextButton(
            onPressed: () {
              // 退出当前页，回到首页后会显示引导页（未登录状态下）
              Navigator.of(context).pop();
            },
            child: Text('去登录', style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ==================== UI 构建 ====================

  @override
  Widget build(BuildContext context) {
    // Android 端显示"即将上线"占位界面
    if (Platform.isAndroid) {
      return _buildComingSoonPage(context);
    }

    // iOS 端正常显示守护卡编辑器
    return Scaffold(
      backgroundColor: ZaiNeColors.scaffoldBg(),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: ZaiNeColors.textPrimary()),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('发送守护卡', style: TextStyle(color: ZaiNeColors.textPrimary(), fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: SafeArea(
        bottom: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.xl, vertical: ZaiNeSpacing.md),
          child: Column(
                children: [
                  // 【修复 v1.84.0】同步失败提示横幅（清除缓存后网络不可用时显示）
                  if (_syncFailed) _buildSyncFailedBanner(),

                  // 【新增 v1.84.0】有发送失败的守护卡时显示重试横幅
                  if (_hasFailedCards) _buildFailedCardsBanner(),

                  // 【修复】未登录提示横幅
                  if (_needsLogin) _buildLoginBanner(),

                  // 额度信息
                  _buildQuotaBar(),

                  // 方案C：待注册卡片列表（独立于配额栏，有卡就始终可展开）
                  if (_pendingCards.isNotEmpty) ...[
                    const SizedBox(height: ZaiNeSpacing.sm),
                    _buildPendingSection(),
                  ],

                  // P4: 邀请统计（仅在有邀请记录时显示）
                  const SizedBox(height: ZaiNeSpacing.sm),
                  if (_invitedCount > 0) _buildInviteStatsBar(),

                  const SizedBox(height: ZaiNeSpacing.xl),

                  // 守护卡预览（v2.1 裂变传播版）
                  RepaintBoundary(
                    key: _cardKey,
                    child: GuardianCardPainter.buildCard(
                      senderName: _userName,
                      senderAvatar: _userAvatar,  // 【修复 v1.9.8】传递头像
                      message: _currentMessage,
                      recipientName: _recipientName.isNotEmpty ? _recipientName : null,
                      totalGuardians: _totalRegistered > 0 ? _totalRegistered : null,
                      // 优先使用裂变 URL，无则降级为 App Store 直链
                      appStoreUrl: _currentShareUrl.isNotEmpty
                          ? _currentShareUrl
                          : _appStoreUrl,
                    ),
                  ),

                  const SizedBox(height: ZaiNeSpacing.xl),

                  // 收件人称呼（纯装饰，显示在卡片上）
                  _buildRecipientInput(),

                  const SizedBox(height: ZaiNeSpacing.lg),

                  // 祝福语选择
                  _buildMessageSelector(),

                  const SizedBox(height: ZaiNeSpacing.lg),

                  // 自定义祝福语输入
                  _buildCustomMessageInput(),

                  const SizedBox(height: ZaiNeSpacing.xl),

                  // 操作按钮
                  _buildActionButtons(),

                  const SizedBox(height: ZaiNeSpacing.xxl),
                ],
              ),
            ),
            ),
    );
  }

  /// Android 端"即将上线"占位页面
  Widget _buildComingSoonPage(BuildContext context) {
    return Scaffold(
      backgroundColor: ZaiNeColors.scaffoldBg(),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: ZaiNeColors.textPrimary()),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          // 背景渐变装饰
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFF9A8B).withValues(alpha: 0.05),
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.xxl, vertical: ZaiNeSpacing.xxl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 动画图标
                  _buildAnimatedComingSoonIcon(),

                  const SizedBox(height: ZaiNeSpacing.xxl),

                  Text(
                    '守护卡即将上线',
                    style: TextStyle(
                      fontSize: ZaiNeFontSize.title,
                      fontWeight: FontWeight.bold,
                      color: ZaiNeColors.textPrimary(),
                      letterSpacing: 1.2,
                    ),
                  ),

                  const SizedBox(height: ZaiNeSpacing.lg),

                  Text(
                    '给在乎的人发一张守护卡\n让他们感受到跨越距离的关心',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: ZaiNeFontSize.body,
                      color: ZaiNeColors.textSecondary(),
                      height: 1.6,
                    ),
                  ),

                  const SizedBox(height: ZaiNeSpacing.xxl),

                  // 功能预告卡片
                  Container(
                    padding: const EdgeInsets.all(ZaiNeSpacing.xl),
                    decoration: BoxDecoration(
                      color: ZaiNeColors.cardBg(),
                      borderRadius: BorderRadius.circular(ZaiNeRadius.card),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildComingSoonFeature(Icons.brush_rounded, '精美守护卡', '多款温暖设计的卡片模板'),
                        const SizedBox(height: ZaiNeSpacing.xl),
                        _buildComingSoonFeature(Icons.auto_awesome_rounded, '3D 仪式感', '沉浸式信封开封动画体验'),
                        const SizedBox(height: ZaiNeSpacing.xl),
                        _buildComingSoonFeature(Icons.qr_code_2_rounded, '情感裂变', '通过守护卡建立真实的联系'),
                      ],
                    ),
                  ),

                  const SizedBox(height: ZaiNeSpacing.xxl),

                  // 按钮提示
                  Container(
                    width: double.infinity,
                    height: 54,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF9A8B), Color(0xFFFF6A88)],
                      ),
                      borderRadius: BorderRadius.circular(ZaiNeRadius.card),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF6A88).withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'Android 敬请期待',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: ZaiNeFontSize.body,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: ZaiNeSpacing.xl),

                  Text(
                    'Android 版本正在全速开发中\n我们希望能为你带来最极致的守护体验',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: ZaiNeFontSize.caption,
                      color: Colors.grey[400],
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建带有动画感的图标
  Widget _buildAnimatedComingSoonIcon() {
    return SizedBox(
      width: 130,
      height: 130,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 外圈光晕
          Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFF9A8B).withValues(alpha: 0.1),
            ),
          ),
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFF9A8B).withValues(alpha: 0.15),
            ),
          ),
          // 核心图标
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFF9A8B), Color(0xFFFF6A88)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF6A88).withValues(alpha: 0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.card_giftcard_rounded,
              size: 40,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// "即将上线"功能预告项
  Widget _buildComingSoonFeature(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(ZaiNeRadius.small),
          ),
          child: Icon(icon, color: Colors.orange, size: 20),
        ),
        const SizedBox(width: ZaiNeSpacing.lg),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: ZaiNeFontSize.bodySm, fontWeight: FontWeight.w600)),
            Text(subtitle, style: TextStyle(fontSize: ZaiNeFontSize.caption, color: Colors.grey[500])),
          ],
        ),
      ],
    );
  }

  /// 额度信息栏（v2.1 分层显示 + 方案C 展开列表）
  ///
  /// 根据用户状态显示不同内容：
  /// 1. 有初始卡未发 → 显示剩余有效期
  /// 2. 卡都发出去了 → 显示等待注册进度（可展开查看详情）
  /// 3. 无卡且过期 → 显示签到解锁进度
  /// 4. 已进入循环 → 只显示卡池状态
  Widget _buildQuotaBar() {
    final bool hasCards = _availableCards > 0;
    // 【修复 v1.9.10】直接用已解析的待注册卡片列表判断，而非用邀请统计字段反推
    final bool hasPendingCards = !hasCards && _pendingCards.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.lg, vertical: ZaiNeSpacing.md),
      decoration: BoxDecoration(
        color: ZaiNeColors.cardBg(),
        borderRadius: BorderRadius.circular(ZaiNeRadius.card),
        border: Border.all(
          color: hasCards
              ? ZaiNeColors.brandOrange.withValues(alpha: 0.2)
              : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 主行：图标 + 标题 + 状态标签 + 展开箭头（方案C）
          GestureDetector(
            onTap: _pendingCards.isNotEmpty
                ? () {
                    final newExpanded = !_isExpanded;
                    setState(() => _isExpanded = newExpanded);
                    if (newExpanded) {
                      _startCountdownTimer();
                    } else {
                      _cancelCountdownTimer();
                    }
                  }
                : null,
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Icon(
                  Icons.card_giftcard,
                  color: hasCards ? ZaiNeColors.brandOrange : Colors.grey[400],
                  size: 20,
                ),
                const SizedBox(width: ZaiNeSpacing.sm),
                Expanded(
                  child: _buildQuotaTitle(hasCards, hasPendingCards),
                ),
                _buildQuotaBadge(hasCards, hasPendingCards),
                // 方案C：展开箭头（仅有待注册卡片时显示）
                if (_pendingCards.isNotEmpty) ...[
                  const SizedBox(width: ZaiNeSpacing.sm),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.expand_more,
                      size: 20,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // 副行：根据状态显示详细信息
          if (_buildQuotaSubtitle() != null) ...[
            const SizedBox(height: ZaiNeSpacing.sm),
            _buildQuotaSubtitle()!,
          ],
        ],
      ),
    );
  }

  /// 额度栏标题文本
  Widget _buildQuotaTitle(bool hasCards, bool hasPendingCards) {
    String title;
    Color color;

    if (hasCards) {
      // 有卡可用
      title = '剩余守护卡: $_availableCards 张';
      color = ZaiNeColors.textPrimary();
    } else if (hasPendingCards) {
      // 卡都发出去了，等待注册
      title = '等待收卡人注册...';
      color = Colors.orange.shade700;
    } else if (_initialCardsExpired && _totalRegistered == 0) {
      // 无卡可用，初始卡已过期，从未有人注册
      title = '守护卡已过期 — 签到解锁新卡';
      color = Colors.grey.shade600;
    } else if (_totalRegistered > 0) {
      // 已进入裂变循环
      title = '守护卡已用完 — 邀请好友注册解锁';
      color = Colors.grey.shade500;
    } else {
      title = '守护卡已用完';
      color = Colors.grey.shade500;
    }

    return Text(
      title,
      style: TextStyle(
        fontSize: ZaiNeFontSize.caption,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    );
  }

  /// 额度栏状态标签
  Widget _buildQuotaBadge(bool hasCards, bool hasPendingCards) {
    if (hasCards) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.md, vertical: ZaiNeSpacing.xs),
        decoration: BoxDecoration(
          color: ZaiNeColors.brandOrange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(ZaiNeRadius.small),
          border: Border.all(
            color: ZaiNeColors.brandOrange.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.favorite, size: 10, color: ZaiNeColors.brandOrange),
            const SizedBox(width: ZaiNeSpacing.xs),
            Text(
              '$_availableCards 张',
              style: const TextStyle(
                fontSize: ZaiNeFontSize.caption,
                fontWeight: FontWeight.w600,
                color: ZaiNeColors.brandOrange,
              ),
            ),
          ],
        ),
      );
    } else if (hasPendingCards) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.md, vertical: ZaiNeSpacing.xs),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(ZaiNeRadius.small),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hourglass_top, size: 10, color: Colors.orange.shade700),
            const SizedBox(width: ZaiNeSpacing.xs),
            Text(
              '24h内注册',
              style: TextStyle(
                fontSize: ZaiNeFontSize.micro,
                fontWeight: FontWeight.w600,
                color: Colors.orange.shade700,
              ),
            ),
          ],
        ),
      );
    } else if (_initialCardsExpired && _totalRegistered == 0 && _checkinProgress != null) {
      // 签到解锁进度标签
      final nextUnlock = _checkinProgress!['next_unlock'] as Map<String, dynamic>?;
      final remainingDays = nextUnlock?['remaining'] as int? ?? 0;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.md, vertical: ZaiNeSpacing.xs),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(ZaiNeRadius.small),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_open, size: 10, color: Colors.blue.shade700),
            const SizedBox(width: ZaiNeSpacing.xs),
            Text(
              remainingDays > 0 ? '再签$remainingDays天' : '可解锁',
              style: TextStyle(
                fontSize: ZaiNeFontSize.micro,
                fontWeight: FontWeight.w600,
                color: Colors.blue.shade700,
              ),
            ),
          ],
        ),
      );
    } else if (_isLoadingData) {
      // 【修复 v1.14.0】后端数据加载中，不应显示"待解锁"
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.md, vertical: ZaiNeSpacing.xs),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(ZaiNeRadius.small),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 8,
              height: 8,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(width: ZaiNeSpacing.xs),
            Text(
              '加载中',
              style: TextStyle(
                fontSize: ZaiNeFontSize.micro,
                color: Colors.grey[400],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    } else if (_availableCards == 0) {
      // 【修复 v1.14.0】只有真正无卡时才显示待解锁
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.md, vertical: ZaiNeSpacing.xs),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(ZaiNeRadius.small),
        ),
        child: Text(
          '待解锁',
          style: TextStyle(
            fontSize: ZaiNeFontSize.micro,
            color: Colors.grey[500],
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    } else {
      // 有卡但数据不完整（边缘情况），显示剩余数量兜底
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.md, vertical: ZaiNeSpacing.xs),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(ZaiNeRadius.small),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 10, color: Colors.green.shade700),
            const SizedBox(width: ZaiNeSpacing.xs),
            Text(
              '$_availableCards 张可用',
              style: TextStyle(
                fontSize: ZaiNeFontSize.micro,
                color: Colors.green.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }
  }

  /// 额度栏副标题（详细信息）
  Widget? _buildQuotaSubtitle() {
    // 1. 有初始卡未发 → 显示剩余有效期
    if (_availableCards > 0 &&
        _initialRemainingDays != null &&
        !_initialCardsExpired &&
        (_invitedCount == 0 || _totalRegistered == 0)) {
      return Row(
        children: [
          Icon(Icons.access_time, size: 12, color: Colors.orange.shade600),
          const SizedBox(width: ZaiNeSpacing.xs),
          Text(
            '初始卡剩余有效期: $_initialRemainingDays 天',
            style: TextStyle(
              fontSize: ZaiNeFontSize.micro,
              color: Colors.orange.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    // 2. 卡都发出去了，等待注册 → 显示24小时返回提示
    if (_availableCards == 0 &&
        _invitedCount > 0 &&
        _totalRegistered == 0) {
      return Row(
        children: [
          Icon(Icons.info_outline, size: 12, color: Colors.orange.shade500),
          const SizedBox(width: ZaiNeSpacing.xs),
          Text(
            '24小时内未注册将自动返回',
            style: TextStyle(
              fontSize: ZaiNeFontSize.micro,
              color: Colors.orange.shade500,
            ),
          ),
        ],
      );
    }

    // 3. 无卡且过期，从未有人注册 → 显示签到解锁进度条
    if (_initialCardsExpired &&
        _totalRegistered == 0 &&
        _checkinProgress != null) {
      final totalDays = (_checkinProgress!['total_days'] as int?) ?? 0;
      final nextUnlock = _checkinProgress!['next_unlock'] as Map<String, dynamic>?;
      final targetDays = nextUnlock?['days'] as int? ?? 3;
      final progress = totalDays / targetDays;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today, size: 12, color: Colors.blue.shade600),
              const SizedBox(width: ZaiNeSpacing.xs),
              Text(
                '累计签到 $totalDays 天 — 签到 $targetDays 天解锁 1 张守护卡',
                style: TextStyle(
                  fontSize: ZaiNeFontSize.micro,
                  color: Colors.blue.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: ZaiNeSpacing.xs),
              // 【P2 优化】添加"规则说明"按钮
              GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('📖 签到解锁规则'),
                      content: const Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('• 累计签到（不是连续！）', style: TextStyle(fontWeight: FontWeight.w600)),
                          Text('• 断签不会清空累计天数'),
                          Text('• 解锁档位：3/7/14/30 天'),
                          SizedBox(height: 8),
                          Text('💡 放心签到，断签也不怕！', style: TextStyle(color: Colors.blue)),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('知道了'),
                        ),
                      ],
                    ),
                  );
                },
                child: Icon(Icons.help_outline, size: 14, color: Colors.blue.shade400),
              ),
            ],
          ),
          const SizedBox(height: ZaiNeSpacing.sm),
          // 进度条
          ClipRRect(
            borderRadius: BorderRadius.circular(ZaiNeRadius.small),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: Colors.blue.shade100,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade400),
              minHeight: 6,
            ),
          ),
        ],
      );
    }

    // 4. 已进入裂变循环 → 显示裂变状态
    if (_totalRegistered > 0) {
      return Row(
        children: [
          Icon(Icons.people, size: 12, color: Colors.green.shade600),
          const SizedBox(width: ZaiNeSpacing.xs),
          Text(
            '已守护 $_totalRegistered 人 — 继续邀请获得更多守护卡',
            style: TextStyle(
              fontSize: ZaiNeFontSize.micro,
              color: Colors.green.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    return null;
  }

  /// 方案C：待注册卡片列表（展开后显示，精致UI）
  /// 待注册卡片区域（独立包装，含展开/折叠）
  Widget _buildPendingSection() {
    // 防御：截取当前卡片列表快照，防止异步修改导致的竞态
    final cards = List<Map<String, dynamic>>.from(_pendingCards);
    if (cards.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: ZaiNeColors.cardBg(),
        borderRadius: BorderRadius.circular(ZaiNeRadius.card),
        border: Border.all(color: ZaiNeColors.borderColor()),
      ),
      child: Column(
        children: [
          // 点击标题行展开/折叠
          InkWell(
            onTap: () {
              final newExpanded = !_isExpanded;
              setState(() => _isExpanded = newExpanded);
              if (newExpanded) {
                _startCountdownTimer();
              } else {
                _cancelCountdownTimer();
              }
            },
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.lg, vertical: ZaiNeSpacing.md),
              child: Row(
                children: [
                  Icon(Icons.schedule_send, size: 20, color: Colors.grey[600]),
                  const SizedBox(width: ZaiNeSpacing.sm),
                  Expanded(
                    child: Text(
                      '已发出 ${cards.length} 张卡',
                      style: const TextStyle(fontSize: ZaiNeFontSize.bodySm, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    _isExpanded ? '收起' : '展开',
                    style: TextStyle(fontSize: ZaiNeFontSize.caption, color: Colors.grey[500]),
                  ),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.expand_more, size: 20, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),

          // 展开后显示卡片列表
          if (_isExpanded) ...[
            Divider(color: Colors.grey.shade200, height: 1, indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: _buildPendingCardsList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPendingCardsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题行
        Padding(
          padding: const EdgeInsets.only(left: 2),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(ZaiNeSpacing.xs),
                decoration: BoxDecoration(
                  color: ZaiNeColors.brandOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(ZaiNeRadius.small),
                ),
                child: const Icon(Icons.favorite_border, size: 12, color: ZaiNeColors.brandOrange),
              ),
              const SizedBox(width: ZaiNeSpacing.sm),
              Text(
                '他们还没来（${_pendingCards.length}）',
                style: TextStyle(
                  fontSize: ZaiNeFontSize.caption,
                  fontWeight: FontWeight.w600,
                  color: ZaiNeColors.textSecondary(),
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZaiNeSpacing.md),
        // 卡片列表
        ...List.generate(_pendingCards.length, (index) {
          final card = _pendingCards[index];
          final receiverName = card['receiver_name'] as String? ?? '朋友';
          final expireAt = card['expire_at'] as DateTime?;
          final cardCode = card['card_code'] as String? ?? '';

          // 计算剩余时间
          String timeLeft = '已过期';
          Color timeColor = Colors.grey.shade400;
          bool isExpired = true;
          bool isUrgent = false;

          if (expireAt != null) {
            final now = DateTime.now();
            final difference = expireAt.difference(now);
            if (difference.isNegative) {
              timeLeft = '已过期';
              timeColor = Colors.grey.shade400;
              isExpired = true;
            } else if (difference.inHours >= 1) {
              final h = difference.inHours;
              final m = difference.inMinutes % 60;
              timeLeft = '剩 $h 小时 $m 分';
              timeColor = ZaiNeColors.brandOrange;
              isExpired = false;
              isUrgent = h < 6;
            } else {
              final m = difference.inMinutes;
              final s = difference.inSeconds % 60;
              timeLeft = '剩 $m 分 $s 秒';
              timeColor = const Color(0xFFE74C3C);
              isExpired = false;
              isUrgent = true;
            }
          }

          // 头像背景色：根据名字 hash 选色，让每个人颜色不同
          final colors = [
            const Color(0xFFFFE0D6), // 珊瑚粉
            const Color(0xFFD6EDFF), // 天空蓝
            const Color(0xFFE0F5D6), // 薄荷绿
            const Color(0xFFF5E6D6), // 杏仁橙
            const Color(0xFFE8D6F5), // 薰衣紫
            const Color(0xFFFFF3D6), // 柠檬黄
          ];
          final avatarBg = colors[receiverName.hashCode.abs() % colors.length];
          final avatarFg = colors[receiverName.hashCode.abs() % colors.length] == const Color(0xFFFFE0D6)
              ? const Color(0xFFE8654A)
              : colors[receiverName.hashCode.abs() % colors.length] == const Color(0xFFD6EDFF)
              ? const Color(0xFF3B82C4)
              : colors[receiverName.hashCode.abs() % colors.length] == const Color(0xFFE0F5D6)
              ? const Color(0xFF3D9B50)
              : colors[receiverName.hashCode.abs() % colors.length] == const Color(0xFFF5E6D6)
              ? const Color(0xFFC47A3B)
              : colors[receiverName.hashCode.abs() % colors.length] == const Color(0xFFE8D6F5)
              ? const Color(0xFF8B5CF6)
              : const Color(0xFFD4970A);

          return Container(
            margin: const EdgeInsets.only(bottom: ZaiNeSpacing.cardXs),
            padding: const EdgeInsets.all(ZaiNeSpacing.cardSm),
            decoration: BoxDecoration(
              color: isExpired
                  ? ZaiNeColors.cardBg()
                  : isUrgent
                      ? ZaiNeColors.brandOrange.withValues(alpha: 0.04)
                      : ZaiNeColors.cardBg(),
              borderRadius: BorderRadius.circular(ZaiNeRadius.card),
              border: Border.all(
                color: isExpired
                    ? Colors.grey.shade200
                    : isUrgent
                        ? ZaiNeColors.brandOrange.withValues(alpha: 0.2)
                        : ZaiNeColors.brandOrange.withValues(alpha: 0.1),
              ),
              boxShadow: isUrgent && !isExpired
                  ? [
                      BoxShadow(
                        color: ZaiNeColors.brandOrange.withValues(alpha: 0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                // 接收人头像（彩色圆圈 + 首字）
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: avatarBg,
                    borderRadius: BorderRadius.circular(ZaiNeRadius.small),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    receiverName.isNotEmpty ? receiverName[0] : '?',
                    style: TextStyle(
                      fontSize: ZaiNeFontSize.body,
                      fontWeight: FontWeight.w700,
                      color: avatarFg,
                    ),
                  ),
                ),
                const SizedBox(width: ZaiNeSpacing.md),
                // 名称 + 状态
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        receiverName,
                        style: TextStyle(
                          fontSize: ZaiNeFontSize.bodySm,
                          fontWeight: FontWeight.w600,
                          color: ZaiNeColors.textPrimary(),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: ZaiNeSpacing.xs),
                      Row(
                        children: [
                          if (isExpired) ...[
                            Icon(Icons.info_outline_rounded, size: 12, color: timeColor),
                            const SizedBox(width: ZaiNeSpacing.xs),
                            Text(
                              '卡片已自动退回',
                              style: TextStyle(
                                fontSize: ZaiNeFontSize.micro,
                                color: timeColor,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ] else ...[
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: isUrgent ? const Color(0xFFE74C3C) : ZaiNeColors.brandOrange,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: ZaiNeSpacing.xs),
                            Text(
                              timeLeft,
                              style: TextStyle(
                                fontSize: ZaiNeFontSize.micro,
                                color: timeColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (isUrgent) ...[
                              const SizedBox(width: ZaiNeSpacing.sm),
                              Text(
                                '即将过期',
                                style: TextStyle(
                                  fontSize: ZaiNeFontSize.micro,
                                  color: Colors.red.shade400,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                      // 【新增 v1.9.78】安全码持久化显示：退出发送页后仍可找到
                      if (!isExpired && cardCode.isNotEmpty) ...[
                        const SizedBox(height: ZaiNeSpacing.sm),
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: cardCode));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('安全码已复制'),
                                backgroundColor: ZaiNeColors.brandOrange,
                                behavior: SnackBarBehavior.floating,
                                duration: Duration(seconds: 2),
                              ),
                            );
                            HapticFeedback.lightImpact();
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.sm, vertical: ZaiNeSpacing.xs),
                            decoration: BoxDecoration(
                              color: ZaiNeColors.brandOrange.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(ZaiNeRadius.small),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.vpn_key, size: 12, color: ZaiNeColors.brandOrange.withValues(alpha: 0.6)),
                                const SizedBox(width: ZaiNeSpacing.sm),
                                Text(
                                  cardCode.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: ZaiNeFontSize.bodySm,
                                    color: ZaiNeColors.brandOrange,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                const SizedBox(width: ZaiNeSpacing.sm),
                                Icon(Icons.copy_rounded, size: 14, color: ZaiNeColors.brandOrange.withValues(alpha: 0.4)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: ZaiNeSpacing.sm),
                // 温柔提醒按钮（方案C：促进裂变）
                if (!isExpired) ...[
                  GestureDetector(
                    onTap: () => _remindViaWeChat(receiverName, cardCode),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.lg, vertical: ZaiNeSpacing.sm),
                      decoration: BoxDecoration(
                        gradient: isUrgent
                            ? const LinearGradient(
                                colors: [ZaiNeColors.brandOrange, Color(0xFFFF6A6A)],
                              )
                            : const LinearGradient(
                                colors: [ZaiNeColors.brandOrange, Color(0xFFFFAB91)],
                              ),
                        borderRadius: BorderRadius.circular(ZaiNeRadius.card),
                        boxShadow: [
                          BoxShadow(
                            color: ZaiNeColors.brandOrange.withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 13,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                          const SizedBox(width: ZaiNeSpacing.xs),
                          Text(
                            '提醒TA',
                            style: TextStyle(
                              fontSize: ZaiNeFontSize.caption,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.95),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
        // 底部温馨提示
        const SizedBox(height: ZaiNeSpacing.xs),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: ZaiNeSpacing.xs),
            child: Text(
              '点击「提醒TA」选择一句关心的话，复制后去微信粘贴发送',
              style: TextStyle(
                fontSize: ZaiNeFontSize.micro,
                color: ZaiNeColors.textHint(),
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 温柔提醒：底部弹窗选择文案，复制后打开微信粘贴发送
  /// 【v1.9.63】默认方案A + "换一句"循环切换，减少用户决策负担
  /// 【修复 v1.9.78】ICP 备案完成前改用 App Store 直链，备案通过后恢复 landing 页链接
  void _remindViaWeChat(String receiverName, String cardCode) async {
    // 【修复 v1.16.0】统一使用 landing 页链接，不再使用 App Store 直链
    // 根因：ICP 备案已完成，应引导接收者先看到精美 H5 落地页，再决定是否下载
    final shareUrl = cardCode.isNotEmpty
        ? AppConstants.guardianCardUrl(cardCode)
        : AppConstants.landingBaseUrl;

    // 4种文案模板 —— 默认展示方案A（温柔关切）
    final messageTemplates = [
      '我发了一张守护卡给你，还没收到吗？\n👇 点击链接接受我的守护\n$shareUrl',
      '给你发的守护卡快过期啦～\n点击链接让我知道你在呢 💛\n$shareUrl',
      '守护卡都要过期了，你人呢？😂\n赶紧点击链接，让我继续守护你！\n$shareUrl',
      '我发了一张守护卡给你 👇\n点击链接领取\n$shareUrl',
    ];

    if (!mounted) return;

    int currentIndex = 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final currentMessage = messageTemplates[currentIndex];

            return Container(
              margin: const EdgeInsets.all(ZaiNeSpacing.lg),
              decoration: BoxDecoration(
                color: ZaiNeColors.cardBg(),
                borderRadius: BorderRadius.circular(ZaiNeRadius.card),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(ZaiNeSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 标题
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.favorite, color: Colors.red.shade300, size: 20),
                        const SizedBox(width: ZaiNeSpacing.sm),
                        Text(
                          '把关心发给TA',
                          style: TextStyle(
                            fontSize: ZaiNeFontSize.subtitle,
                            fontWeight: FontWeight.w700,
                            color: ZaiNeColors.textPrimary(),
                          ),
                        ),
                        const SizedBox(width: ZaiNeSpacing.xs),
                        const Text('💬', style: TextStyle(fontSize: ZaiNeFontSize.subtitle)),
                      ],
                    ),
                    const SizedBox(height: ZaiNeSpacing.xl),

                    // 文案预览卡片
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(ZaiNeSpacing.lg),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FE),
                        borderRadius: BorderRadius.circular(ZaiNeRadius.card),
                        border: Border.all(
                          color: const Color(0xFFE8EAF6),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        currentMessage,
                        style: TextStyle(
                          fontSize: ZaiNeFontSize.body,
                          height: 1.6,
                          color: ZaiNeColors.textPrimary(),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    const SizedBox(height: ZaiNeSpacing.lg),

                    // 换一句按钮
                    GestureDetector(
                      onTap: () {
                        setModalState(() {
                          currentIndex = (currentIndex + 1) % messageTemplates.length;
                        });
                        HapticFeedback.lightImpact();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.lg, vertical: ZaiNeSpacing.sm),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F0F0),
                          borderRadius: BorderRadius.circular(ZaiNeRadius.card),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.refresh,
                              size: 16,
                              color: ZaiNeColors.textSecondary(),
                            ),
                            const SizedBox(width: ZaiNeSpacing.sm),
                            Text(
                              '换一句',
                              style: TextStyle(
                                fontSize: ZaiNeFontSize.caption,
                                color: ZaiNeColors.textSecondary(),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: ZaiNeSpacing.xl),

                    // 复制并打开微信按钮
                    GestureDetector(
                      onTap: () async {
                        final msg = currentMessage;
                        // 关闭弹窗
                        if (ctx.mounted) Navigator.pop(ctx);
                        // 复制 + 打开微信（不可用时自动降级到系统分享面板）
                        await copyAndOpenWeChat(context, msg);
                        if (kDebugMode) debugPrint('[GuardianCard] 提醒TA文案已复制: 方案${currentIndex + 1}');
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: ZaiNeSpacing.lg),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                          ),
                          borderRadius: BorderRadius.circular(ZaiNeRadius.card),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF667EEA).withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.copy, color: Colors.white, size: 18),
                            SizedBox(width: ZaiNeSpacing.sm),
                            Text(
                              '复制并打开微信',
                              style: TextStyle(
                                fontSize: ZaiNeFontSize.body,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// 启动倒计时定时器（方案C：实时刷新）
  void _startCountdownTimer() {
    _cancelCountdownTimer(); // 先取消旧定时器

    // 计算刷新间隔：如果有卡剩余时间 < 1小时，每秒刷新；否则每分钟刷新
    bool hasLessThanOneHour = false;
    for (final card in _pendingCards) {
      final expireAt = card['expire_at'] as DateTime?;
      if (expireAt != null) {
        final difference = expireAt.difference(DateTime.now());
        if (!difference.isNegative && difference.inHours < 1) {
          hasLessThanOneHour = true;
          break;
        }
      }
    }

    final duration = hasLessThanOneHour
        ? const Duration(seconds: 1)
        : const Duration(minutes: 1);

    _countdownTimer = Timer.periodic(duration, (timer) {
      if (mounted) {
        setState(() {
          // 检查是否还有需要倒计时的卡
          bool hasActiveCountdown = false;
          for (final card in _pendingCards) {
            final expireAt = card['expire_at'] as DateTime?;
            if (expireAt != null) {
              final difference = expireAt.difference(DateTime.now());
              if (!difference.isNegative) {
                hasActiveCountdown = true;
                break;
              }
            }
          }
          if (!hasActiveCountdown) {
            _cancelCountdownTimer();
          }
        });
      }
    });
  }

  /// 【新增 v1.84.0】重试发送失败的守护卡
  Future<void> _retryFailedCards() async {
    if (kDebugMode) debugPrint('[GuardianCardPage] 开始重试发送失败的守护卡...');
    setState(() => _isSharing = true);
    try {
      final result = await GuardianCardService.retryFailedCards();
      if (result['success'] == true) {
        final retried = result['retried'] as int? ?? 0;
        final succeeded = result['succeeded'] as int? ?? 0;
        final remaining = result['remaining'] as int? ?? 0;
        if (mounted) {
          setState(() => _isSharing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('重试完成：成功$succeeded/$retried 条${remaining > 0 ? '，剩余$remaining条' : ''}'),
              backgroundColor: succeeded > 0 ? Colors.green : Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
          // 刷新页面数据
          _loadData();
        }
      } else {
        if (mounted) {
          setState(() => _isSharing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('重试失败，请稍后重试'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSharing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('重试异常：$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// 取消倒计时定时器
  void _cancelCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  /// P4 邀请统计条（有邀请记录时显示）
  Widget _buildInviteStatsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.lg, vertical: ZaiNeSpacing.md),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(ZaiNeRadius.small),
        border: Border.all(color: Colors.green.shade200.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.people_alt_rounded, color: Colors.green.shade600, size: 18),
          const SizedBox(width: ZaiNeSpacing.sm),
          Text(
            '已邀请 $_invitedCount 人加入',
            style: TextStyle(
              fontSize: ZaiNeFontSize.caption,
              color: Colors.green.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          // 【修复 v1.9.x】"获赠"改为显示已成功邀请注册的人数
          if (_invitedCount > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.sm, vertical: ZaiNeSpacing.xs),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(ZaiNeRadius.small),
              ),
              child: Text(
                '获赠 $_invitedCount 张',
                style: TextStyle(
                  fontSize: ZaiNeFontSize.micro,
                  color: Colors.green.shade800,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 收件人称呼（纯装饰，会显示在守护卡上，如"妈妈，希望你每天平安"）
  Widget _buildRecipientInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.lg, vertical: ZaiNeSpacing.lg),
      decoration: BoxDecoration(
        color: ZaiNeColors.cardBg(),
        borderRadius: BorderRadius.circular(ZaiNeRadius.card),
        border: Border.all(color: ZaiNeColors.borderColor()),
      ),
      child: Row(
        children: [
          Icon(Icons.favorite_border, size: 18, color: ZaiNeColors.textSecondary()),
          const SizedBox(width: ZaiNeSpacing.md),
          Expanded(
            child: TextField(
              onChanged: (v) => setState(() => _recipientName = v.trim()),
              decoration: InputDecoration(
                hintText: '对方的称呼（选填），如"妈妈"',
                hintStyle: TextStyle(fontSize: ZaiNeFontSize.caption, color: Colors.grey[400]),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 祝福语选择
  Widget _buildMessageSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text('选择祝福语', style: TextStyle(fontSize: ZaiNeFontSize.caption, fontWeight: FontWeight.w600, color: ZaiNeColors.textPrimary())),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(_presetMessages.length, (index) {
            final isSelected = !_isCustomMessage && _selectedMessageIndex == index;
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _isCustomMessage = false;
                  _selectedMessageIndex = index;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.md, vertical: ZaiNeSpacing.sm),
                decoration: BoxDecoration(
                  color: isSelected
                      ? ZaiNeColors.brandOrange.withValues(alpha: 0.12)
                      : ZaiNeColors.cardBg(),
                  borderRadius: BorderRadius.circular(ZaiNeRadius.card),
                  border: Border.all(
                    color: isSelected ? ZaiNeColors.brandOrange : Colors.grey.shade300,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  _presetMessages[index],
                  style: TextStyle(
                    fontSize: ZaiNeFontSize.caption,
                    color: isSelected ? ZaiNeColors.brandOrange : ZaiNeColors.textSecondary(),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  /// 自定义祝福语输入
  Widget _buildCustomMessageInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _isCustomMessage = true);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.md, vertical: ZaiNeSpacing.sm),
            decoration: BoxDecoration(
              color: _isCustomMessage ? ZaiNeColors.brandOrange.withValues(alpha: 0.08) : null,
              borderRadius: BorderRadius.circular(ZaiNeRadius.small),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.edit_outlined, size: 14, color: _isCustomMessage ? ZaiNeColors.brandOrange : Colors.grey[500]),
                const SizedBox(width: ZaiNeSpacing.xs),
                Text(
                  '自定义祝福语',
                  style: TextStyle(
                    fontSize: ZaiNeFontSize.caption,
                    color: _isCustomMessage ? ZaiNeColors.brandOrange : Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_isCustomMessage) ...[
          const SizedBox(height: ZaiNeSpacing.sm),
          TextField(
            controller: _customMsgController,
            maxLength: 50,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: '写下你想说的话...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(ZaiNeRadius.small)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(ZaiNeRadius.small),
                borderSide: BorderSide(color: ZaiNeColors.borderColor()),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(ZaiNeRadius.small),
                borderSide: const BorderSide(color: ZaiNeColors.brandOrange, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.lg, vertical: ZaiNeSpacing.lg),
              counterText: '${_customMsgController.text.length}/50',
            ),
          ),
        ],
      ],
    );
  }

  /// 操作按钮
  Widget _buildActionButtons() {
    final canShare = _totalAvailable > 0 && _currentMessage.isNotEmpty;

    return Column(
      children: [
        // 发送守护卡（主按钮 — 系统分享面板，可选微信/短信/等）
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isSharing ? null : _shareCard,
            style: ElevatedButton.styleFrom(
              backgroundColor: canShare ? ZaiNeColors.brandOrange : Colors.grey.shade300,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZaiNeRadius.card)),
              elevation: canShare ? 4 : 0,
            ),
            child: _isSharing
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.share, size: 18),
                      const SizedBox(width: ZaiNeSpacing.sm),
                      Text(
                        _totalAvailable <= 0 ? '守护卡已用完' : '发送守护卡',
                        style: const TextStyle(fontSize: ZaiNeFontSize.body, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
          ),
        ),

        const SizedBox(height: ZaiNeSpacing.md),

        // 保存到相册
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton.icon(
            onPressed: _isSharing ? null : _saveCard,
            style: OutlinedButton.styleFrom(
              foregroundColor: ZaiNeColors.textSecondary(),
              side: BorderSide(color: ZaiNeColors.borderColor()),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZaiNeRadius.card)),
            ),
            icon: const Icon(Icons.save_alt, size: 16),
            label: const Text('保存到相册', style: TextStyle(fontSize: ZaiNeFontSize.caption)),
          ),
        ),
      ],
    );
  }
}
