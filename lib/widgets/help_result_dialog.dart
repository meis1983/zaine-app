// lib/widgets/help_result_dialog.dart
// 紧急求助已触发结果弹窗 —— 从 help_page.dart 拆出的独立组件

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../pages/subscription_page.dart';
import '../theme/theme_helper.dart';

/// 求助触发时的数据快照（用于解耦弹窗组件与 HelpPage 父组件）
class HelpDataSnapshot {
  final String userName;
  final String? myPhone;
  final int userAge;
  final String bloodType;
  final String disease;
  final String medicine;
  final String allergy;
  final String? address;
  final String? coordLat;
  final String? coordLng;
  final bool calledContact;
  final bool smsSent;
  final bool locationObtained;

  const HelpDataSnapshot({
    required this.userName,
    this.myPhone,
    required this.userAge,
    required this.bloodType,
    required this.disease,
    required this.medicine,
    required this.allergy,
    this.address,
    this.coordLat,
    this.coordLng,
    required this.calledContact,
    required this.smsSent,
    required this.locationObtained,
  });
}

/// 求助触发后的结果弹窗内容组件
class HelpResultDialog extends StatefulWidget {
  final List<Map<String, dynamic>> contacts;
  final int contactCount;
  final String firstContactName;
  final String firstContactPhone;
  final String Function(Map<String, dynamic>) smsContentBuilder;
  final VoidCallback onSendSMS;
  final VoidCallback onCallContact;
  final VoidCallback onCall120;
  final VoidCallback onCancel;
  final HelpDataSnapshot data;
  /// 当弹窗内更新了某个状态时回调给父组件
  final ValueChanged<String> onStatusChanged;
    /// 当前会员等级的通知上限（体验版=1，智能版=3）
  final int autoCallLimit;
    /// 是否为智能版会员（已升级则不显示升级提示）
    final bool isPremium;

    const HelpResultDialog({
      super.key,
      required this.contacts,
      required this.contactCount,
      required this.firstContactName,
      required this.firstContactPhone,
      required this.smsContentBuilder,
      required this.onSendSMS,
      required this.onCallContact,
      required this.onCall120,
      required this.onCancel,
      required this.data,
      required this.onStatusChanged,
      this.autoCallLimit = 1, // 默认体验版
      this.isPremium = false, // 默认非会员
    });

  @override
  State<HelpResultDialog> createState() => _HelpResultDialogState();
}

class _HelpResultDialogState extends State<HelpResultDialog> with WidgetsBindingObserver {
  bool _infoExpanded = false;
  int _currentSmsIndex = 0;
  int _currentCallIndex = 0;

  /// 标记用户是否刚跳转到外部 App（短信/电话）
  bool _justLaunchedExternal = false;
  /// 标记跳转类型：'sms' 或 'call'
  String? _launchedType;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 监听 App 生命周期：用户从短信/电话 App 返回时自动刷新状态
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _justLaunchedExternal) {
      _justLaunchedExternal = false;
      final autoNotify = _getAutoNotifyContacts();
      if (_launchedType == 'sms') {
        setState(() {
          if (_currentSmsIndex < autoNotify.length) {
            _currentSmsIndex++;
            if (_currentSmsIndex >= autoNotify.length) {
              widget.onStatusChanged('smsSent');
            }
          }
        });
      } else if (_launchedType == 'call') {
        setState(() {
          if (_currentCallIndex < autoNotify.length) {
            _currentCallIndex++;
            if (_currentCallIndex >= autoNotify.length) {
              widget.onStatusChanged('calledContact');
            }
          }
        });
      }
      _launchedType = null;
    }
  }

  /// 获取可通知的联系人（前 autoCallLimit 位有效联系人）
  List<Map<String, dynamic>> _getAutoNotifyContacts() {
    return widget.contacts
        .where((c) => (c['phone']?.toString() ?? '').isNotEmpty)
        .take(widget.autoCallLimit)
        .toList();
  }

  /// 获取超出通知上限的锁定联系人
  List<Map<String, dynamic>> _getLockedContacts() {
    final validContacts = widget.contacts
        .where((c) => (c['phone']?.toString() ?? '').isNotEmpty)
        .toList();
    if (validContacts.length <= widget.autoCallLimit) return [];
    return validContacts.sublist(widget.autoCallLimit);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.grey.shade100,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxHeight: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ========== 1. ⚠️ 标题栏 ==========
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 12, 6),
              child: Row(children: [
                Icon(Icons.warning_rounded, color: Colors.red.shade700, size: 24),
                const SizedBox(width: 8),
                const Text('紧急求助已触发', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ]),
            ),

            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildSMSSection(),
                    const SizedBox(height: 10),
                    _buildInfoPreviewSection(),
                    const SizedBox(height: 12),
                    _buildActionStatusSection(),
                    const SizedBox(height: 12),
                    _buildCall120Button(),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ),

            // ========== 6. 底部「我没事了」直接退出（无二次确认） ==========
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
              child: TextButton(
                onPressed: widget.onCancel,
                child: Text('我没事了', style: TextStyle(fontSize: 15, color: ZaiNeColors.textSecondary())),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ===== 发送求救短信模块 =====
  Widget _buildSMSSection() {
    final autoNotify = _getAutoNotifyContacts();
    final lockedContacts = _getLockedContacts();
    final isAllSent = _currentSmsIndex >= autoNotify.length;
    final currentSmsContact = isAllSent ? null : autoNotify[_currentSmsIndex];
    final currentSmsName = currentSmsContact?['name']?.toString() ?? '联系人';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZaiNeSpacing.md),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.shade200.withValues(alpha: 0.5)),
      
        boxShadow: ZaiNeShadows.card,),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- 标题行 ----
          Row(children: [
            const Text('➤', style: TextStyle(fontSize: 14, color: Colors.orange)),
            const SizedBox(width: 4),
            const Text('📨', style: TextStyle(fontSize: 13)),
            const SizedBox(width: 4),
            Expanded(child: Text(
              isAllSent
                ? '✅ 已发送给全部 ${autoNotify.length} 位守护人'
                : '📨 发送求救短信给第 ${_currentSmsIndex + 1}/${autoNotify.length} 位：$currentSmsName',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isAllSent ? Colors.green.shade700 : Colors.orange.shade800))),
          ]),

          const SizedBox(height: 10),

          // ---- 通知联系人进度条 ----
          if (autoNotify.isNotEmpty) ...[
            ...autoNotify.asMap().entries.map((entry) {
              final idx = entry.key;
              final contact = entry.value;
              final name = contact['name']?.toString() ?? '联系人';
              final relation = contact['relation']?.toString() ?? '';
              final isSmsDone = idx < _currentSmsIndex;
              final isCallDone = idx < _currentCallIndex;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(children: [
                  if (isSmsDone)
                    Icon(Icons.check_circle, size: 16, color: Colors.green.shade600)
                  else if (idx == _currentSmsIndex && !isAllSent)
                    Icon(Icons.radio_button_checked, size: 16, color: Colors.orange.shade700)
                  else
                    Icon(Icons.circle_outlined, size: 16, color: ZaiNeColors.textSecondary()),
                  const SizedBox(width: 6),
                  Expanded(child: Text(
                    '$name${relation.isNotEmpty ? '（$relation）' : ''}',
                    style: TextStyle(fontSize: 12.5, color: isSmsDone ? ZaiNeColors.textSecondary() : ZaiNeColors.textPrimary()),
                  )),
                  if (isCallDone)
                    Icon(Icons.phone_in_talk, size: 13, color: Colors.blue.shade400),
                ]),
              );
            }),
            const SizedBox(height: 8),
          ],

          // ---- 锁定联系人分区（非会员时显示升级提示）---
          if (!widget.isPremium && lockedContacts.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                Expanded(child: Divider(color: Colors.orange.shade200, thickness: 1)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text('更多守护人',
                    style: TextStyle(fontSize: 11, color: ZaiNeColors.textSecondary())),
                ),
                Expanded(child: Divider(color: Colors.orange.shade200, thickness: 1)),
              ]),
            ),
            ...lockedContacts.map((contact) {
              final name = contact['name']?.toString() ?? '联系人';
              final relation = contact['relation']?.toString() ?? '';
              return Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200.withValues(alpha: 0.4)),
                  
                    boxShadow: ZaiNeShadows.card,),
                  child: Row(children: [
                    Icon(Icons.lock_outline, size: 13, color: ZaiNeColors.textSecondary()),
                    const SizedBox(width: 5),
                    Expanded(child: Text(
                      '$name${relation.isNotEmpty ? '（$relation）' : ''}',
                      style: TextStyle(fontSize: 12, color: ZaiNeColors.textSecondary()),
                    )),
                  ]),
                ),
              );
            }),
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 2),
              child: GestureDetector(
                onTap: () {
                  // 跳转会员升级页
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SubscriptionPage()),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade200.withValues(alpha: 0.4)),
                  
                    boxShadow: ZaiNeShadows.card,),
                  child: Row(children: [
                    Icon(Icons.workspace_premium_rounded, size: 15, color: Colors.amber.shade700),
                    const SizedBox(width: 6),
                    Text('升级智能版，解锁全部守护人通知',
                      style: TextStyle(fontSize: 12, color: Colors.amber.shade800, fontWeight: FontWeight.w500)),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // ---- 发送短信按钮 ----
          if (!isAllSent && autoNotify.isNotEmpty) ...[
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: _sendCurrentSMS,
                icon: const Text('📧', style: TextStyle(fontSize: 15)),
                label: Text('发送短信给 $currentSmsName',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shadowColor: Colors.orange.withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // ---- 拨打联系人电话按钮 ----
          if (autoNotify.isNotEmpty)
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: () => _callCurrentContact(),
                icon: const Text('📞', style: TextStyle(fontSize: 17)),
                label: Text('📞 拨打 ${_getCurrentCallName()} 电话',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  elevation: 3,
                  shadowColor: Colors.blue.withValues(alpha: 0.35),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ==================== SMS 编码辅助 ====================
  /// 在传给 Uri.queryParameters 之前，先做【字符替换】
  /// （Uri 构造器会自动做 percent-encoding，这里只需处理「语义冲突」的字符）
  String _safeSmsBody(String body) {
    return body
        .replaceAll('【', '[')
        .replaceAll('】', ']')
        .replaceAll('─', '-')       // 特殊横线 → 普通横线
        .replaceAll('…', '...')     // 省略号 → 三个点
        .replaceAll('\r', '')       // 去掉 \r，防止编码出 %0D
        .trim();
  }

  Future<void> _sendCurrentSMS() async {
    final autoNotify = _getAutoNotifyContacts();
    if (_currentSmsIndex >= autoNotify.length) return;

    final contact = autoNotify[_currentSmsIndex];
    final phone = contact['phone']?.toString() ?? '';
    if (phone.isEmpty) {
      setState(() => _currentSmsIndex++);
      return;
    }

    try {
      // 【v1.16.0 修复】使用 Uri 构造器替代 Uri.parse + encodeComponent
      //
      // 旧方案问题：
      //   Uri.parse('sms:$phone?body=${Uri.encodeComponent(body)}')
      //   → encodeComponent 把空格变成 +，iOS 收到后 + 变空格，URL 可能被截断
      //   → 手动拼接字符串容易出各种编码问题
      //
      // 新方案（Dart 标准库，RFC 3986 标准）：
      //   Uri(scheme:'sms', path: phone, queryParameters: {'body': body})
      //   → 自动编码 ? & = + % 空格 换行
      //   → https:// 中的 : / 保持原样（query value 内的 / 不需要编码）
      //   → iOS 收到后自动解码，Data Detector 能识别完整 URL → 可点击！
      // 【一条短信】发送完整求助短信（健康信息 + 苹果/高德两条短链），
      // 短链为纯 ASCII 且独占末尾行，iPhone→安卓 跨平台接收方数据检测器必能识别为可点链接。
      final body = widget.smsContentBuilder(contact);
      final safeBody = _safeSmsBody(body);
      final uri = Uri(
        scheme: 'sms',
        path: phone,
        queryParameters: {'body': safeBody},
      );

      if (kDebugMode) debugPrint('[Help] SMS URI: $uri');

      if (await canLaunchUrl(uri)) {
        _justLaunchedExternal = true;
        _launchedType = 'sms';
        await launchUrl(uri);
        HapticFeedback.mediumImpact();
        // 【v1.95.4 加固】把带链接的完整短信复制到剪贴板，若对方（安卓）收不到可点链接可手动补发，
        // 确保求助链接永不真正丢失（iOS→安卓 MMS 偶发丢链的安全网）。
        try {
          await Clipboard.setData(ClipboardData(text: safeBody));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('短信已打开，完整链接已复制。若对方收不到链接可长按粘贴补发'),
                duration: Duration(seconds: 4),
              ),
            );
          }
        } catch (_) {}
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Help] 发送短信失败: $e');
    }
  }

  String _getCurrentCallName() {
    final autoNotify = _getAutoNotifyContacts();
    if (_currentCallIndex >= autoNotify.length) return '（已完成）';
    return autoNotify[_currentCallIndex]['name']?.toString() ?? '紧急联系人';
  }

  Future<void> _callCurrentContact() async {
    final autoNotify = _getAutoNotifyContacts();
    if (_currentCallIndex >= autoNotify.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已完成所有联系人的电话拨打'), duration: Duration(seconds: 2)));
      return;
    }

    final contact = autoNotify[_currentCallIndex];
    final phone = contact['phone']?.toString() ?? '';

    if (phone.isEmpty) {
      setState(() => _currentCallIndex++);
      return;
    }

    try {
      final telUri = Uri(scheme: 'tel', path: phone);
      if (await canLaunchUrl(telUri)) {
        _justLaunchedExternal = true;
        _launchedType = 'call';
        await launchUrl(telUri);
        HapticFeedback.heavyImpact();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Help] 拨打电话失败: $e');
    }
  }

  /// ===== 求救信息预览 =====
  Widget _buildInfoPreviewSection() {
    final d = widget.data;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: ZaiNeColors.cardBg(),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200.withValues(alpha: 0.4)),
      
        boxShadow: ZaiNeShadows.card,),
      child: Theme(
        data: ThemeData().copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: _infoExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          expandedAlignment: Alignment.topLeft,
          title: Row(children: [
            const Text('📄', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 4),
            const Text('📄', style: TextStyle(fontSize: 13)),
            const SizedBox(width: 4),
            Text(_infoExpanded ? '求救信息（点击收起）' : '求救信息预览（点击展开）',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.blue.shade800)),
            const Spacer(),
            Icon(_infoExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                 color: Colors.grey.shade500, size: 22),
          ]),
          onExpansionChanged: (v) => setState(() => _infoExpanded = v),
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              padding: const EdgeInsets.all(ZaiNeSpacing.md),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
              
                boxShadow: ZaiNeShadows.card,),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Text('📱', style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 4),
                  Text('【在呢 紧急求助】', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.red.shade700)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      final auto = _getAutoNotifyContacts();
                      final cur = (_currentSmsIndex < auto.length)
                          ? auto[_currentSmsIndex]
                          : (auto.isNotEmpty ? auto.first : const <String, dynamic>{});
                      // 【修复 v1.95-F6】复制按钮与发送路径一致，走 _safeSmsBody 清理特殊字符
                      Clipboard.setData(ClipboardData(text: _safeSmsBody(widget.smsContentBuilder(cur))));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('已复制到剪贴板'), duration: Duration(seconds: 1)));
                    },
                    child: const Icon(Icons.content_copy_outlined, size: 17, color: Colors.blue),
                  ),
                ]),
                Padding(
                  padding: const EdgeInsets.only(left: 2, top: 2, bottom: 6),
                  child: Row(children: [
                    const Text('🕐', style: TextStyle(fontSize: 11.5, color: Colors.red)),
                    const SizedBox(width: 4),
                    Text(DateTime.now().toString().substring(0, 16),
                         style: TextStyle(fontSize: 11.5, color: Colors.red.shade400)),
                  ]),
                ),
                _oldStyleInfoRow('👤', '求救人', d.userName.isNotEmpty ? d.userName : '未知'),
                _oldStyleInfoRow('📱', '手机号', (d.myPhone ?? '').isNotEmpty ? d.myPhone! : '未设置'),
                if (d.userAge > 0) _oldStyleInfoRow('🎂', '年龄', '${d.userAge}岁'),
                _oldStyleInfoRow('🩸', '血型', d.bloodType),
                if (d.disease.isNotEmpty) _oldStyleInfoRow('🏥', '病史', d.disease),
                if (d.medicine.isNotEmpty) _oldStyleInfoRow('💊', '药物', d.medicine),
                if (d.allergy.isNotEmpty) _oldStyleInfoRow('⚠️', '过敏', d.allergy),
                Center(child: Text('━━━━━━━━ 求助者位置信息 ━━━━━━━━',
                    style: TextStyle(fontSize: 11, color: ZaiNeColors.textSecondary(), letterSpacing: 0.5, fontWeight: FontWeight.w500))),
                const SizedBox(height: 4),
                _locationInfoRowOld('', '地址', d.address ?? '未知地址'),
                _coordInfoRowOld('🧭', d.coordLat, d.coordLng),
                const SizedBox(height: 2),
                _mapLinkRowOld('', '苹果地图', _buildAppleMapsUrl(d.coordLat, d.coordLng), isBlue: true),
                _mapLinkRowOld('', '高德地图', _buildAmapUrl(d.coordLat, d.coordLng), isBlue: true),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('请立即联系我或拨打120！\n在呢 - 独居守护App',
                      style: TextStyle(fontSize: 11.5, color: ZaiNeColors.textSecondary(), height: 1.35)),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _oldStyleInfoRow(String emoji, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2.5),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(emoji, style: const TextStyle(fontSize: 12.5)),
      const SizedBox(width: 6),
      Text('$label：', style: TextStyle(fontSize: 12, color: ZaiNeColors.textSecondary(), fontWeight: FontWeight.w500)),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 12, height: 1.3))),
    ]),
  );

  Widget _locationInfoRowOld(String emoji, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2.5),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(emoji, style: const TextStyle(fontSize: 12.5)),
      const SizedBox(width: 6),
      Text('$label：', style: TextStyle(fontSize: 12, color: ZaiNeColors.textSecondary(), fontWeight: FontWeight.w500)),
      Expanded(child: Text(value,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
            color: value == '未知地址' ? Colors.red : null, height: 1.3))),
    ]),
  );

  Widget _coordInfoRowOld(String emoji, String? latStr, String? lngStr) {
    final coordText = (latStr != null && lngStr != null)
        ? '${latStr.replaceAll('北纬 ', '').replaceAll('\u00b0', '')}, ${lngStr.replaceAll('东经 ', '').replaceAll('\u00b0', '')}'
        : '未知';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(children: [
        Text(emoji, style: const TextStyle(fontSize: 12.5)),
        const SizedBox(width: 6),
        Text('坐标：', style: TextStyle(fontSize: 12, color: ZaiNeColors.textSecondary(), fontWeight: FontWeight.w500)),
        Flexible(child: Text(coordText, style: const TextStyle(fontSize: 11.5, fontFamily: 'monospace'))),
      ]),
    );
  }

  String _buildAppleMapsUrl(String? latStr, String? lngStr) {
    if (latStr == null || lngStr == null) return '（坐标未知）';
    final lat = latStr.replaceAll('北纬 ', '').replaceAll('°', '');
    final lng = lngStr.replaceAll('东经 ', '').replaceAll('°', '');
    // 【修复 v1.95-F5】预览与真实 SMS 一致：直接进入导航（从当前位置到求助位置）
    return 'https://maps.apple.com/?daddr=$lat,$lng&q=${Uri.encodeComponent('求助位置')}';
  }

  String _buildAmapUrl(String? latStr, String? lngStr) {
    if (latStr == null || lngStr == null) return '（坐标未知）';
    final lat = latStr.replaceAll('北纬 ', '').replaceAll('°', '');
    final lng = lngStr.replaceAll('东经 ', '').replaceAll('°', '');
    // 【修复 v1.95-F5】预览与真实 SMS 一致：直接进入导航
    return 'https://uri.amap.com/navigation?to=$lng,$lat&mode=car&src=zaine&coordinate=gaode&callnative=1';
  }

  Widget _mapLinkRowOld(String emoji, String label, String url, {bool isBlue = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2.5),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (emoji.isNotEmpty) ...[
        Text(emoji, style: const TextStyle(fontSize: 12.5)),
        const SizedBox(width: 6),
      ],
      Text('$label：', style: TextStyle(fontSize: 12, color: isBlue ? Colors.blue.shade700 : ZaiNeColors.textSecondary(), fontWeight: FontWeight.w500)),
      Expanded(child: Text(url,
        style: const TextStyle(fontSize: 9.5, fontFamily: 'monospace', color: Colors.blue),
        overflow: TextOverflow.ellipsis, maxLines: 2)),
    ]),
  );

  /// ===== 行动状态追踪（使用动态状态而非初始化快照）=====
  Widget _buildActionStatusSection() {
    final autoNotify = _getAutoNotifyContacts();
    final allSmsDone = _currentSmsIndex >= autoNotify.length;
    final allCallsDone = _currentCallIndex >= autoNotify.length;
    final d = widget.data;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text('正在采取以下行动：',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: ZaiNeColors.textPrimary())),
        ),
        // 紧急联系人电话 — 使用动态 _currentCallIndex 判断
        _buildDynamicStatusItem(
          emoji: '📞',
          label: '紧急联系人电话',
          isDone: allCallsDone,
          doneLabel: '已拨打',
          pendingLabel: '待拨打',
        ),
        const SizedBox(height: 7),
        // 短信通知 — 使用动态 _currentSmsIndex 判断
        _buildDynamicStatusItem(
          emoji: '📬',
          label: '短信通知',
          isDone: allSmsDone,
          doneLabel: '已发送',
          pendingLabel: '待发送',
        ),
        const SizedBox(height: 7),
        // 位置信息（仍使用原始数据，因为定位在进入弹窗前已完成）
        _buildDynamicStatusItem(
          emoji: '📍',
          label: '位置信息',
          isDone: d.locationObtained || (d.address != null && d.address!.isNotEmpty && d.address != '未知地址'),
          doneLabel: '已获取',
          pendingLabel: '获取中...',
        ),
      ],
    );
  }

  Widget _buildDynamicStatusItem({
    required String emoji,
    required String label,
    required bool isDone,
    required String pendingLabel,
    required String doneLabel,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: ZaiNeColors.cardBg(),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200.withValues(alpha: 0.5)),
      
        boxShadow: ZaiNeShadows.card,),
      child: Row(children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: TextStyle(fontSize: 13.5, color: ZaiNeColors.textPrimary()))),
        if (isDone)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.check_circle, size: 17, color: Colors.green.shade600),
            const SizedBox(width: 4),
            Text(doneLabel, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.green.shade700)),
          ])
        else
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.hourglass_empty, size: 15, color: Colors.orange.shade700),
            const SizedBox(width: 4),
            Text(pendingLabel, style: TextStyle(fontSize: 12.5, color: Colors.orange.shade700)),
          ]),
      ]),
    );
  }

  Widget _buildCall120Button() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: () { widget.onCall120(); HapticFeedback.heavyImpact(); },
        icon: const Text('🚑', style: TextStyle(fontSize: 18)),
        label: const Text('🚑 拨打 120 急救电话',
             style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          elevation: 3,
          shadowColor: Colors.red.withValues(alpha: 0.35),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}
