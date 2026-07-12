// lib/widgets/guardian_ritual.dart
// 守护卡欢迎仪式（3D 信封动画）统一封装 + 去重标记
//
// 动机（修复 ②+③）：原庆祝逻辑分散在 home_page / onboarding 三处，且用 bool 防重入，
// 导致「网页注册用户收不到动画(②)」「App 后台被 DeepLink 唤起不弹 / 切后台永久跳过(③)」。
// 这里把弹窗抽成统一函数，并用「按 card_code 去重的 seen 集合（持久化到 SharedPreferences）」
// 作为单一真相源，home 与 onboarding 共享，杜绝重复弹与漏弹。

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'guardian_card_envelope.dart';

const String _seenRitualPrefKey = 'seen_guardian_ritual_keys';

/// 读取已见证过的守护仪式 key 集合（持久化）
Future<Set<String>> loadSeenRitualKeys() async {
  final prefs = await SharedPreferences.getInstance();
  return (prefs.getStringList(_seenRitualPrefKey) ?? []).toSet();
}

/// 标记某 card_code 的仪式已展示（持久化），后续不再重复弹
Future<void> markRitualSeen(String cardCode) async {
  final prefs = await SharedPreferences.getInstance();
  final set = (prefs.getStringList(_seenRitualPrefKey) ?? []).toSet();
  set.add(_ritualKey(cardCode));
  await prefs.setStringList(_seenRitualPrefKey, set.toList());
}

/// 是否已展示过该 card_code 的仪式
bool isRitualSeen(Set<String> seen, String cardCode) =>
    seen.contains(_ritualKey(cardCode));

String _ritualKey(String cardCode) => 'code:${cardCode.trim().toUpperCase()}';

/// 统一展示「守护卡仪式」3D 信封动画。
///
/// [mode]：
///  - 'welcome'（默认）：接收方视角「开启你的守护礼」（对方想和你建立守护关系）
///  - 'success'：发卡方视角「守护成功 🎉」（对方已成为你的守护人，正向激励飞轮）
///
/// [onClosed] 在动画播放完毕、弹窗关闭后回调（用于刷新邀请统计等）。
/// 视觉与 onboarding 原实现保持一致。
Future<void> showGuardianWelcomeRitual(
  BuildContext context, {
  required String senderName,
  String? senderAvatar,
  String message = '想和你建立守护关系',
  String? cardCode,
  String mode = 'welcome',
  required VoidCallback onClosed,
}) async {
  final dialogCtx = context;
  final bool isSuccess = mode == 'success';
  final String title = isSuccess ? '守护成功 🎉' : '开启你的守护礼';
  final String defaultMsg =
      isSuccess ? '已成为你的守护人' : '想和你建立守护关系';
  await showGeneralDialog(
    context: dialogCtx,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.9),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (ctx, anim1, anim2) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FadeTransition(
                opacity: anim1,
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isSuccess ? 22 : 18,
                    letterSpacing: isSuccess ? 2 : 4,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              GuardianCardEnvelope(
                senderName: senderName,
                senderAvatar: senderAvatar,
                message: message.isNotEmpty ? message : defaultMsg,
                appStoreUrl: '',
                cardCode: cardCode,
                isWelcomeMode: true,
                onComplete: () {
                  // 动画播完后延迟关闭，给足沉浸感
                  Future.delayed(const Duration(milliseconds: 3500), () {
                    if (ctx.mounted) Navigator.pop(ctx);
                    onClosed();
                  });
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}
