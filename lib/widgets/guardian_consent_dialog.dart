// lib/widgets/guardian_consent_dialog.dart
// 【CN 合规】守护关系「单独同意」弹窗（个保法第29条：敏感个人信息需单独同意）
//
// 为什么抽成共享组件：
//   同一个合规门禁此前在 redeem_card_page（我的 → 输入守护码）里有一份私有实现。
//   登录页渐进披露入口需要在「登录前」也走同一门禁，若再抄一份，
//   两处文案/判定迟早走偏——合规弹窗走偏就是实质风险。
//   因此抽成本文件，两处调用同一实现，行为逐字一致。
//
// 返回 true = 用户同意并继续绑定；false = 拒绝，调用方不得发起 redeemCard。

import 'package:flutter/material.dart';
import '../theme/theme_helper.dart';

/// 展示「单独同意」弹窗。
/// [senderName] 发码方昵称（由 CardService.checkCard 返回，无需登录）。
Future<bool> showGuardianConsentDialog(
  BuildContext context,
  String senderName,
) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ZaiNeRadius.card)),
      title: const Row(
        children: [
          Icon(Icons.shield_outlined, color: ZaiNeColors.brandOrange),
          SizedBox(width: ZaiNeSpacing.sm),
          Text('确认建立守护关系'),
        ],
      ),
      content: Text(
        '$senderName 希望成为您的守护者。\n\n'
        '对方可以在你发起主动求助后，查看你的当前位置。\n\n'
        '请确认您已知晓并同意上述信息共享。',
        style: TextStyle(
          fontSize: ZaiNeFontSize.bodySm,
          height: 1.6,
          color: ZaiNeColors.textSecondary(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('拒绝'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: ZaiNeColors.brandOrange,
            foregroundColor: Colors.white,
          ),
          child: const Text('同意并绑定'),
        ),
      ],
    ),
  );
  return result ?? false;
}
