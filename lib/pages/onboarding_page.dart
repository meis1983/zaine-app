import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import '../main.dart';
import '../theme/theme_helper.dart';
import '../services/api/sync_service.dart';
import '../services/platform/location_service.dart';
import '../services/api/auth_service.dart';
import '../services/api_service.dart';
import '../l10n/i18n.dart';
import '../config/app_config.dart';
import '../services/deep_link_service.dart'; // [v1.76.0] 紧急联系人邀请
import '../services/push_service.dart'; // 【v1.98.0】APNs 推送注册（登录成功后请求权限）
import '../services/api/card_service.dart'; // 新增
import '../widgets/guardian_ritual.dart'; // 【修复 v1.9.95】统一守护仪式封装
import 'scan_guardian_code_page.dart'; // 【CN 179】登录页渐进披露：扫码填守护码
import '../widgets/guardian_consent_dialog.dart'; // 【CN 179】共享合规同意弹窗

/// 开机引导页 — 5页专业引导
/// 核心定位：这不是签到App，这是日常平安守护与亲友互助工具
///
/// 【MVP】手机号直接登录（quickLogin），待营业执照下发后切换回验证码登录
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

/// 登录页独立组件 —— 使用 AutomaticKeepAliveClientMixin 保持状态，
/// 避免每次切换回登录页时反复重建整个 UI（导致4→5页卡顿）
class _LoginPage extends StatefulWidget {
  final TextEditingController phoneController;
  final FocusNode phoneFocusNode;
  final FocusNode codeFocusNode; // 保留用于 unfocus，兼容父组件
  final bool isLoggingIn;
  final String loginError; // 内联错误提示
  final VoidCallback? onPhoneChanged;
  final VoidCallback onLogin;
  final VoidCallback onBack;
  final VoidCallback? onAppleLoginSuccess; // 【新增 v1.9.78】Apple 登录成功回调
  final ValueChanged<String>? onAppleLoginError; // 【修复 v1.81.0】Apple 登录失败回调（内联显示）
  // 【CN 179】渐进披露守护码：用户在登录页填了码并通过「单独同意」后，
  //   把码回传给父组件暂存为"绑定意愿"；父组件在登录成功后再真正调用 redeemCard。
  //   —— 之所以不能在这里直接绑定：redeemCard 走 ApiService.post 默认 auth:true，
  //      登录前调用必回 401。
  final ValueChanged<String>? onGuardianCodeAccepted;
  // 【CN 179】用户清空/改动守护码时通知父组件作废暂存
  final VoidCallback? onGuardianCodeCleared;

  const _LoginPage({
    required this.phoneController,
    required this.phoneFocusNode,
    required this.codeFocusNode,
    required this.isLoggingIn,
    this.loginError = '', // 默认为空
    this.onPhoneChanged,
    required this.onLogin,
    required this.onBack,
    this.onAppleLoginSuccess, // 【新增】
    this.onAppleLoginError, // 【修复 v1.81.0】Apple 登录失败回调
    this.onGuardianCodeAccepted, // 【CN 179】
    this.onGuardianCodeCleared, // 【CN 179】
  });

  @override
  State<_LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<_LoginPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _hasPendingCard = false; // 是否有 deep link 带来的 pending card
  bool _isCheckingPending = true; // 正在检测中

  // 【修复 v1.83.0】记录用户选择的国家/地区，避免选择后仍显示 +86
  PhoneNumber _selectedNumber = PhoneNumber(isoCode: 'CN', dialCode: '+86');

  // ===== 【CN 179】渐进披露守护码入口 =====
  // 设计目标：默认只占一行 18px 浅灰文字，不跳转、不弹窗、不挡手机号输入；
  // 用户主动点开才展开输入框；填码后立刻走「单独同意」（checkCard 免鉴权，登录前可查）；
  // 同意只代表"记下意愿"，真正的 redeemCard 由父组件在登录成功后静默发起。
  final TextEditingController _guardianCodeController = TextEditingController();
  final FocusNode _guardianCodeFocusNode = FocusNode();
  bool _guardianCodeExpanded = false;
  bool _guardianCodeChecking = false;
  String? _guardianCodeError;
  String? _guardianCodeAcceptedName; // 已通过单独同意的对方昵称

  @override
  void initState() {
    super.initState();
    _checkPendingCard();
  }

  @override
  void dispose() {
    _guardianCodeController.dispose();
    _guardianCodeFocusNode.dispose();
    super.dispose();
  }

  /// 【CN 179】校验守护码 → 查卡 → 单独同意 → 记下意愿
  Future<void> _resolveGuardianCode() async {
    final code = _guardianCodeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _guardianCodeError = tr.s1186);
      return;
    }
    if (code.length < 4) {
      setState(() => _guardianCodeError = tr.s939);
      return;
    }

    // 收起键盘，避免弹窗被键盘顶住
    _guardianCodeFocusNode.unfocus();

    setState(() {
      _guardianCodeChecking = true;
      _guardianCodeError = null;
    });

    try {
      // checkCard 是免鉴权接口（auth:false），登录前可安全调用
      final check = await CardService.checkCard(code);
      if (!mounted) return;
      if (check['success'] != true) {
        setState(() {
          _guardianCodeError =
              check['message']?.toString() ?? tr.s1187;
          _guardianCodeAcceptedName = null;
        });
        widget.onGuardianCodeCleared?.call();
        return;
      }

      final senderName = check['sender_name']?.toString() ?? 'TA';
      // 【CN 合规】个保法第29条：建立守护关系前必须取得单独同意
      final agreed = await showGuardianConsentDialog(context, senderName);
      if (!mounted) return;

      if (!agreed) {
        setState(() {
          _guardianCodeAcceptedName = null;
          _guardianCodeError = '您已拒绝，未建立守护关系';
        });
        widget.onGuardianCodeCleared?.call();
        return;
      }

      setState(() => _guardianCodeAcceptedName = senderName);
      widget.onGuardianCodeAccepted?.call(code);
    } catch (e) {
      if (mounted) setState(() => _guardianCodeError = tr.s1188);
    } finally {
      if (mounted) setState(() => _guardianCodeChecking = false);
    }
  }

  /// 【CN 179】扫码填守护码：扫到即回填并走同一套校验/同意流程
  Future<void> _scanGuardianCode() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ScanGuardianCodePage()),
    );
    if (!mounted || result == null || result.isEmpty) return;
    _guardianCodeController.text = result.toUpperCase();
    widget.onGuardianCodeCleared?.call();
    setState(() {
      _guardianCodeAcceptedName = null;
      _guardianCodeError = null;
    });
    await _resolveGuardianCode();
  }

  /// 检测是否已有 deep link 带来的 pending card code
  /// 有 → 隐藏"输入守护码"入口（无感绑定会自动处理）
  /// 无 → 显示入口（用户可能从 App Store 直接下载）
  Future<void> _checkPendingCard() async {
    final prefs = await SharedPreferences.getInstance();
    final cardCode = prefs.getString('pending_card_code') ??
        prefs.getString('pending-card-code');
    if ((prefs.getString('pending_card_code') == null ||
            prefs.getString('pending_card_code')!.isEmpty) &&
        cardCode != null &&
        cardCode.isNotEmpty) {
      await prefs.setString('pending_card_code', cardCode);
    }
    if (mounted) {
      setState(() {
        _hasPendingCard = cardCode != null && cardCode.isNotEmpty;
        _isCheckingPending = false;
      });
    }
  }

  // 不在此处自动聚焦，由父组件的 onPageChanged 延迟触发，
  // 避免键盘弹出动画与 PageView 滚动动画同时运行导致掉帧

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin 必须调用

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          28, 12, 28, 24 + bottomInset + (bottomPadding > 0 ? 0 : 16)),
      child: Column(
        children: [
          const SizedBox(height: ZaiNeSpacing.md),

          // 返回上一页按钮
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: () {
                widget.phoneFocusNode.unfocus();
                widget.codeFocusNode.unfocus();
                widget.onBack();
              },
              child: Container(
                padding: const EdgeInsets.all(ZaiNeSpacing.sm),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.arrow_back_ios_new,
                    size: 16, color: Colors.grey.shade600),
              ),
            ),
          ),

          const SizedBox(height: ZaiNeSpacing.xl),

          // 图标区域
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF7C4DFF),
                  Color(0xFF9C27B0),
                  Color(0xFFE040FB)
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7C4DFF).withValues(alpha: 0.3),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Center(
              child: Icon(Icons.phone_android_rounded,
                  size: 56, color: Colors.white),
            ),
          ),

          const SizedBox(height: ZaiNeSpacing.xxl),

          // 标题
          Text(
            tr.s928,
            style: TextStyle(
                fontSize: ZaiNeFontSize.title,
                fontWeight: FontWeight.bold,
                color: ZaiNeColors.textPrimary()),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: ZaiNeSpacing.md),

          // 副标题
          Text(
            tr.s929,
            style: TextStyle(fontSize: ZaiNeFontSize.bodySm, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),

          // 提示标签
          const SizedBox(height: ZaiNeSpacing.xxl),  // 【修复 v1.81.0】增加间距，避免拥挤
          Container(
            padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.lg, vertical: ZaiNeSpacing.sm),
            decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(ZaiNeRadius.card),
            
              boxShadow: ZaiNeShadows.card,),
            child:  Text(
              tr.s930,
              style: TextStyle(
                  fontSize: ZaiNeFontSize.caption,
                  fontWeight: FontWeight.w700,
                  color: Colors.purple),
            ),
          ),

          const SizedBox(height: ZaiNeSpacing.xl),

          // 国际手机号输入框（v1.83.0 优化：选择生效 + 视觉优化）
          Listener(
            onPointerDown: (_) {
              widget.onPhoneChanged?.call();
            },
            child: Container(
              decoration: BoxDecoration(
                color: ZaiNeColors.cardBg(),
                borderRadius: BorderRadius.circular(ZaiNeRadius.card),
                border: Border.all(color: ZaiNeColors.borderColor()),
                boxShadow: [
                  BoxShadow(
                      color: Colors.grey.shade100,
                      blurRadius: 8,
                      offset: const Offset(0, 2)),
                ],
              ),
              // 【v1.83.0】Stack 叠加下拉箭头，让用户一眼看出可选择国家
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  // 主输入框（含国旗+区号）—— 撑满容器，不截断（v1.87.0 修复右侧被截断问题）
                  Padding(
                    padding: EdgeInsets.zero,
                    child: InternationalPhoneNumberInput(
                      onInputChanged: (PhoneNumber number) {
                        // 【修复 v1.83.0】保存用户选择到 state，选择后正确回显
                        setState(() => _selectedNumber = number);
                        widget.onPhoneChanged?.call();
                      },
                      selectorConfig: kIsChinaBuild
                          ? const SelectorConfig(
                              // 【CN 178 修复】intl_phone_number_input 0.7.5 的 PhoneInputSelectorType
                              //   只有 DROPDOWN/BOTTOM_SHEET/DIALOG 三值，原代码误用 PHONE_INPUT_WITH_FLAG
                              //   → Dart 编译阶段报错 → kernel_snapshot_program 抛 Exception。
                              //   改 DROPDOWN + countries:['CN']：UI 上只显示 🇨🇳 +86，且 selector
                              //   点开只有 1 项不可用，从 UX 上等同于「删除国家选项只留 +86」。
                              selectorType: PhoneInputSelectorType.DROPDOWN,
                              showFlags: true,
                              useEmoji: true,
                              leadingPadding: 12,
                              trailingSpace: false,
                            )
                          : const SelectorConfig(
                              selectorType: PhoneInputSelectorType.DIALOG,
                              showFlags: true,
                              useEmoji: true,
                              leadingPadding: 12,
                              trailingSpace: true,
                            ),
                      ignoreBlank: false,
                      autoValidateMode: AutovalidateMode.disabled,
                      initialValue: _selectedNumber,  // 【修复】state 驱动，选择即生效
                      textFieldController: widget.phoneController,
                      formatInput: true,
                      keyboardType: TextInputType.phone,
                      inputBorder: InputBorder.none,
                      hintText: tr.s931,
                      maxLength: 15,
                      countries: kIsChinaBuild
                          ? const ['CN']
                          : const [
                              'CN', 'US', 'JP', 'KR', 'SG', 'HK', 'TW', 'MO',
                              'GB', 'DE', 'FR', 'IT', 'ES', 'PT', 'NL', 'SE', 'NO', 'DK',
                              'AU', 'NZ', 'CA', 'MY', 'TH', 'VN', 'PH', 'ID', 'IN',
                              'BR', 'MX', 'AR', 'CL', 'CO', 'PE', 'ZA', 'EG', 'NG',
                            ],
                    ),
                  ),
                  // 下拉箭头 ▼（叠加在区号右侧）—— 仅海外版显示；CN 版锁定 +86 不提供国家选择
                  if (!kIsChinaBuild)
                    const Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      // 让点击穿透到下面的 selector 按钮
                      child: Padding(
                        // 【v1.91.0 微调】跟随选择器宽度，稍微左移让输入框更宽
                        padding: EdgeInsets.only(left: 70, right: 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Icon(
                            Icons.keyboard_arrow_down,
                            size: 22,
                            color: ZaiNeColors.brandOrange,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // 【CN 178 锁 +86·UX】CN 版在 selector 区（约左 100px）盖透明 AbsorbPointer，
                  //   让点 selector 没反应；国际版（下）不受影响。
                  //   注：IgnorePointer 是「穿透到下方」——会让 selector 仍接收 tap；
                  //        AbsorbPointer 是「吸收」——tap 被吞、不穿透。
                  //   SizedBox.shrink() 是 const factory 0x0 占位；不要用 SizedBox.expand()，
                  //   那个是 static const 实例而不是 const constructor，在 const 上下文编译失败。
                  if (kIsChinaBuild)
                    const Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: 100, // leadingPadding(12) + emoji旗(~28) + 间距 + "+86"字(~40) + 右 padding
                      child: AbsorbPointer(absorbing: true, child: SizedBox.shrink()),
                    ),
                ],
              ),
            ),
          ),

          // 【v1.83.0 已移除】提示文字——国旗旁已加 ▼ 箭头，用户一目了然

          // 【暂隐 v1.82.0】Apple ID 登录按钮（等 Sign In with Apple 能力配置好后再启用）
          const SizedBox(height: ZaiNeSpacing.xl),

          // 内联错误提示（取代 SnackBar，避免跨导航残留）
          if (widget.loginError.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.md, vertical: ZaiNeSpacing.sm),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(ZaiNeRadius.small),
                border: Border.all(color: Colors.red.shade200),
              
                boxShadow: ZaiNeShadows.card,),
              child: Row(
                children: [
                  Icon(Icons.error_outline,
                      size: 16, color: Colors.red.shade400),
                  const SizedBox(width: ZaiNeSpacing.sm),
                  Expanded(
                    child: Text(
                      widget.loginError,
                      style:
                          TextStyle(fontSize: ZaiNeFontSize.caption, color: Colors.red.shade700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: ZaiNeSpacing.md),
          ],

          // 【新增 v1.9.78】条件显示：输入守护码入口
          // 仅在无 deep link pending card 时显示（直接从 App Store 下载的场景）
          // 【CN 合规】CN 版隐藏此入口：原逻辑依赖登录后"静默自动绑定"（processPendingCardCode），
          //   该路径在 CN 已被禁用（需用户经 RedeemCardPage 单独同意）。隐藏可避免"虚假绑定成功"。
          //   CN 用户改走「我的 → 输入守护码」(RedeemCardPage，带单独同意)。
          if (!kIsChinaBuild && !_isCheckingPending && !_hasPendingCard) ...[
            GestureDetector(
              onTap: _showCardCodeInput,
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.lg, vertical: ZaiNeSpacing.lg),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [ZaiNeColors.brandOrangeLight, Color(0xFFFFF0E8)],
                  ),
                  borderRadius: BorderRadius.circular(ZaiNeRadius.card),
                  border: Border.all(
                      color: ZaiNeColors.brandOrange.withValues(alpha: 0.2)),
                
                  boxShadow: ZaiNeShadows.card,),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: ZaiNeColors.brandOrange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(ZaiNeRadius.small),
                      
                        boxShadow: ZaiNeShadows.card,),
                      child: const Icon(Icons.card_giftcard,
                          color: ZaiNeColors.brandOrange, size: 18),
                    ),
                    const SizedBox(width: ZaiNeSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr.s932,
                            style: TextStyle(
                                fontSize: ZaiNeFontSize.bodySm,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade800),
                          ),
                          const SizedBox(height: ZaiNeSpacing.xs),
                           Text(
                            tr.s933,
                            style: TextStyle(
                                fontSize: ZaiNeFontSize.caption, color: ZaiNeColors.brandOrange),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right,
                        color: ZaiNeColors.brandOrange, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: ZaiNeSpacing.lg),
          ],

          // 【CN 179】渐进披露守护码入口（替代 178 的橙色大卡片）
          //   默认：一行浅灰文字「我有守护码 ⌄」，高约 24px，不跳转、不挡手机号
          //   展开：守护码输入框 + 扫码按钮；填完当场走单独同意，登录成功后自动兑现
          if (kIsChinaBuild) _buildGuardianCodeEntry(),

          // 底部提示
          Container(
            padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.lg, vertical: ZaiNeSpacing.md),
            decoration: BoxDecoration(
              color: Colors.grey.shade100.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(ZaiNeRadius.small),
            
              boxShadow: ZaiNeShadows.card,),
            child: Text(
              tr.s934,
              style: TextStyle(fontSize: ZaiNeFontSize.caption, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: ZaiNeSpacing.xl),
        ],
      ),
    );
  }

  /// ===== 【CN 179】渐进披露守护码入口 =====
  /// 折叠态：一行浅灰文字「我有守护码 ⌄」，不跳转、不弹窗、不占视觉重心
  /// 展开态：守护码输入框 + 扫码按钮；填完当场查卡并走「单独同意」，
  ///         同意后只是"记下意愿"（回传给父组件），真正的绑定等登录成功后自动兑现
  Widget _buildGuardianCodeEntry() {
    final hasAccepted = _guardianCodeAcceptedName != null;
    final accent = hasAccepted ? Colors.green.shade600 : Colors.grey.shade500;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: ZaiNeSpacing.md),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            final willExpand = !_guardianCodeExpanded;
            setState(() => _guardianCodeExpanded = willExpand);
            if (willExpand) {
              // 展开后聚焦守护码输入框：Flutter 会自动把聚焦控件滚进可视区，
              // 顺带解决"键盘弹起把输入框挡住"的老问题
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _guardianCodeFocusNode.requestFocus();
              });
            } else {
              _guardianCodeFocusNode.unfocus();
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: ZaiNeSpacing.xs),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasAccepted)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(Icons.check_circle, size: 14, color: accent),
                  ),
                Text(
                  hasAccepted ? tr.s1182 : tr.s1181,
                  style: TextStyle(
                    fontSize: ZaiNeFontSize.bodySm,
                    color: accent,
                    fontWeight: hasAccepted ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                AnimatedRotation(
                  turns: _guardianCodeExpanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.keyboard_arrow_down, size: 16, color: accent),
                ),
              ],
            ),
          ),
        ),
        if (_guardianCodeExpanded) ...[
          const SizedBox(height: ZaiNeSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _guardianCodeController,
                  focusNode: _guardianCodeFocusNode,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 16,
                  enabled: !_guardianCodeChecking,
                  style: TextStyle(
                    fontSize: ZaiNeFontSize.body,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                    color: ZaiNeColors.textPrimary(),
                  ),
                  decoration: InputDecoration(
                    hintText: tr.s1183,
                    hintStyle: TextStyle(
                      fontSize: ZaiNeFontSize.bodySm,
                      color: ZaiNeColors.textHint(),
                      letterSpacing: 0,
                      fontWeight: FontWeight.normal,
                    ),
                    filled: true,
                    fillColor: ZaiNeColors.cardBg(),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(ZaiNeRadius.card),
                      borderSide: BorderSide(color: ZaiNeColors.borderColor()),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(ZaiNeRadius.card),
                      borderSide: BorderSide(color: ZaiNeColors.borderColor()),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(ZaiNeRadius.card),
                      borderSide: const BorderSide(color: ZaiNeColors.brandOrange, width: 1.5),
                    ),
                    counterText: '',
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: ZaiNeSpacing.lg, vertical: ZaiNeSpacing.md),
                  ),
                  onChanged: (_) {
                    // 码一改动，之前记下的"意愿"就失效，避免用旧码去绑定
                    if (_guardianCodeAcceptedName != null ||
                        _guardianCodeError != null) {
                      setState(() {
                        _guardianCodeAcceptedName = null;
                        _guardianCodeError = null;
                      });
                    }
                    widget.onGuardianCodeCleared?.call();
                  },
                  onSubmitted: (_) => _resolveGuardianCode(),
                ),
              ),
              const SizedBox(width: ZaiNeSpacing.sm),
              // 扫码入口：扫到即回填并走同一套校验/同意
              SizedBox(
                height: 48,
                width: 48,
                child: OutlinedButton(
                  onPressed: _guardianCodeChecking ? null : _scanGuardianCode,
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    foregroundColor: ZaiNeColors.brandOrange,
                    side: BorderSide(
                        color: ZaiNeColors.brandOrange.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(ZaiNeRadius.card)),
                  ),
                  child: _guardianCodeChecking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.qr_code_scanner, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: ZaiNeSpacing.xs),
          if (_guardianCodeError != null)
            Padding(
              padding: const EdgeInsets.only(top: ZaiNeSpacing.xs),
              child: Text(
                _guardianCodeError!,
                style: TextStyle(
                    fontSize: ZaiNeFontSize.caption, color: Colors.red.shade600),
              ),
            )
          else if (hasAccepted)
            Text(
              tr.s1185(_guardianCodeAcceptedName!),
              style: TextStyle(
                  fontSize: ZaiNeFontSize.caption, color: Colors.green.shade600),
            )
          else
            Text(
              tr.s1184,
              style: TextStyle(
                  fontSize: ZaiNeFontSize.caption, color: Colors.grey.shade500),
            ),
        ],
        const SizedBox(height: ZaiNeSpacing.lg),
      ],
    );
  }

  /// 【新增 v1.9.78】输入守护码 BottomSheet
  /// 用户输入后存入 pending-card-code，登录时自动携带并绑定
  void _showCardCodeInput() {
    final controller = TextEditingController();
    String? errorText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Container(
                decoration: BoxDecoration(
                  color: ZaiNeColors.cardBg(),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                
                  boxShadow: ZaiNeShadows.card,),
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(ZaiNeRadius.small)
                      ),
                      ),
                    ),
                    const SizedBox(height: ZaiNeSpacing.xl),
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                              color: ZaiNeColors.brandOrangeLight,
                              borderRadius: BorderRadius.circular(ZaiNeRadius.small)
                          ),
                          child: const Icon(Icons.vpn_key,
                              color: ZaiNeColors.brandOrange, size: 20),
                        ),
                        const SizedBox(width: ZaiNeSpacing.md),
                         Expanded(
                          child: Text(
                            tr.s935,
                            style: TextStyle(
                                fontSize: ZaiNeFontSize.subtitle, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: ZaiNeSpacing.sm),
                    Text(
                      tr.s936,
                      style:
                          TextStyle(fontSize: ZaiNeFontSize.caption, color: ZaiNeColors.textSecondary()),
                    ),
                    const SizedBox(height: ZaiNeSpacing.xl),
                    TextField(
                      controller: controller,
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 16,
                      style: const TextStyle(
                          fontSize: ZaiNeFontSize.subtitle,
                          letterSpacing: 3,
                          fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        hintText: tr.s937,
                        hintStyle: TextStyle(
                            fontSize: ZaiNeFontSize.body,
                            color: ZaiNeColors.textHint(),
                            letterSpacing: 2),
                        errorText: errorText,
                        counterText: '',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(ZaiNeRadius.small),
                          borderSide: BorderSide(color: ZaiNeColors.borderColor()),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(ZaiNeRadius.small),
                          borderSide: BorderSide(color: ZaiNeColors.borderColor()),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(ZaiNeRadius.small),
                          borderSide:
                              const BorderSide(color: ZaiNeColors.brandOrange),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.lg, vertical: ZaiNeSpacing.lg),
                      ),
                    ),
                    const SizedBox(height: ZaiNeSpacing.xl),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final code = controller.text
                              .trim()
                              .toUpperCase()
                              .replaceAll(' ', '');
                          if (code.isEmpty) {
                            setSheetState(() => errorText = tr.s938);
                            return;
                          }
                          if (code.length < 4) {
                            setSheetState(() => errorText = tr.s939);
                            return;
                          }
                          // 验证守护码是否有效
                          setSheetState(() => errorText = null);
                          try {
                            final checkRes = await CardService.checkCard(code);
                            if (checkRes['success'] != true) {
                              setSheetState(() =>
                                  errorText = checkRes['message'] ?? tr.s940);
                              return;
                            }
                          } catch (e) {
                            setSheetState(() => errorText = tr.s941);
                            return;
                          }

                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setString('pending_card_code', code);
                          await prefs.setString('pending-card-code', code);
                          if (kDebugMode) debugPrint('[Onboarding] 暂存守护码: $code');

                          if (mounted && ctx.mounted) {
                            setState(() => _hasPendingCard = true);
                            Navigator.pop(ctx);
                          }
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                               SnackBar(
                                content: Text(tr.s942),
                                backgroundColor: ZaiNeColors.brandOrange,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ZaiNeColors.brandOrange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: ZaiNeSpacing.lg),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZaiNeRadius.card)),
                        ),
                        child:  Text(tr.s943,
                            style: TextStyle(
                                fontSize: ZaiNeFontSize.body, fontWeight: FontWeight.bold)),
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

  // 【暂隐 v1.82.0】Apple Sign In 处理逻辑（等能力配置好后再启用）
  // ignore: unused_element
  Future<void> _handleAppleSignIn() async {
    try {
      if (kDebugMode) debugPrint('[Apple Sign In] 开始...');
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      if (kDebugMode) {
        // 【v1.93.7 安全修复】避免敏感 token 完整输出到日志
        final idToken = credential.identityToken;
        final authCode = credential.authorizationCode;
        final maskedId = (idToken != null && idToken.isNotEmpty)
            ? '${idToken.substring(0, idToken.length > 10 ? 10 : idToken.length)}...'
            : '(empty)';
        final maskedAuth = (authCode?.isNotEmpty == true)
            ? '${authCode!.substring(0, authCode.length > 10 ? 10 : authCode.length)}...'
            : '(empty)';
        debugPrint('[Apple Sign In] identityToken: $maskedId');
        debugPrint('[Apple Sign In] authorizationCode: $maskedAuth');
      }

      // 【v1.9.78】调用后端接口，用 Apple credential 登录
      final identityToken = credential.identityToken ?? '';
      final authorizationCode = credential.authorizationCode; // 可能为 null

      // 提取用户信息（Apple 只在首次授权时返回）
      String? email;
      String? givenName;
      String? familyName;

      final res = await AuthService.appleLogin(
        identityToken: identityToken,
        authorizationCode: authorizationCode, // 直接传递，后端会处理 null
        userId: null, // 由后端从 identityToken 解码
        email: email,
        givenName: givenName,
        familyName: familyName,
      );

      if (res['success'] == true) {
        if (kDebugMode) debugPrint('[Apple Sign In] 登录成功');
        // 登录成功，通知父组件
        widget.onAppleLoginSuccess?.call();
      } else {
        // 登录失败 → 通过回调显示内联错误（不用 SnackBar）
        final msg = tr.s944(res['message'] ?? '未知错误');
        if (kDebugMode) debugPrint('[Apple Sign In] $msg');
        widget.onAppleLoginError?.call(msg);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Apple Sign In] 错误: $e');
      // 异常 → 通过回调显示内联错误
      final msg = tr.s945(e);
      widget.onAppleLoginError?.call(msg);
    }
  }
}

/// Wrapper：让当前活跃页面保持状态，避免滑动时反复重建
class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _totalPages = 5;

  // 手机号输入控制器
  final _phoneController = TextEditingController();
  final _phoneFocusNode = FocusNode();

  // 登录状态
  String? _pendingCardCode;
  bool _isLoggingIn = false;
  bool _loginCompleted = false; // 登录成功后置 true，屏蔽所有后续异常的错误提示
  String _loginError = ''; // 内联登录错误提示（取代 SnackBar，避免跨页面残留）

  // 【CN 179】登录页渐进披露守护码：用户在登录前填码并通过「单独同意」后，
  //   这里只暂存"绑定意愿"（码本身），登录成功后由 _redeemPendingGuardianCode 静默兑现。
  //   登录前不能直接调 redeemCard —— 它走 ApiService.post 默认 auth:true，必回 401。
  String? _loginGuardianCode;

  /// 用于取消登录请求的 controller
  bool _loginCancelled = false;

  /// 引导页数据
  List<Map<String, dynamic>> get _pages => [
        {
          'icon': Icons.shield_rounded,
          'iconBg': Colors.red,
          'gradient': [
            const Color(0xFFFF4757),
            const Color(0xFFFF6B81),
            const Color(0xFFFF4757)
          ],
          'title': tr.s946,
          'subtitle': tr.s947,
          'highlight': tr.s948,
          'desc': [
            {'icon': '🛡️', 'text': tr.s949},
            {'icon': '📍', 'text': tr.s950},
            {'icon': '🤝', 'text': tr.s951},
          ],
          'footer': tr.s952,
        },
        {
          'icon': Icons.medical_information_rounded,
          'iconBg': Colors.blue,
          'gradient': [const Color(0xFF4FACFE), const Color(0xFF00F2FE)],
          'title': tr.s953,
          'subtitle': tr.s954,
          'highlight': tr.s955,
          'desc': [
            {'icon': '🩸', 'text': tr.s956},
            {'icon': '💊', 'text': tr.s957},
            {'icon': '📋', 'text': tr.s958},
          ],
          'footer': tr.s959,
        },
        {
          'icon': Icons.people_alt_rounded,
          'iconBg': Colors.orange,
          'gradient': [
            ZaiNeColors.brandOrange,
            const Color(0xFFFFB347),
            ZaiNeColors.brandOrange
          ],
          'title': tr.s960,
          'subtitle': tr.s961,
          'highlight': tr.s962,
          'desc': [
            {'icon': '👨‍👩‍👧', 'text': tr.s963},
            {'icon': '📱', 'text': tr.s964},
            {'icon': '↔️', 'text': tr.s965},
          ],
          'footer': tr.s966,
        },
        {
          'icon': Icons.location_on_rounded,
          'iconBg': Colors.green,
          'gradient': [const Color(0xFF11998E), const Color(0xFF38EF7D)],
          'title': tr.s967,
          'subtitle': tr.s968,
          'highlight': tr.s969,
          'desc': [
            {'icon': '🔒', 'text': tr.s970},
            {'icon': '⚡', 'text': tr.s971},
            {'icon': '🗺️', 'text': tr.s972},
          ],
          'footer': tr.s973,
        },
        {
          'icon': Icons.phone_android_rounded,
          'iconBg': Colors.purple,
          'gradient': [
            const Color(0xFF7C4DFF),
            const Color(0xFF9C27B0),
            const Color(0xFFE040FB)
          ],
          'title': tr.s928,
          'subtitle': tr.s929,
          'highlight': tr.s930,
          'desc': [
            {'icon': '📱', 'text': tr.s974},
            {'icon': '🔐', 'text': tr.s975},
            {'icon': '⚡', 'text': tr.s976},
          ],
          'footer': tr.s934,
          'isLogin': true,
        },
      ];

  @override
  void dispose() {
    _pageController.dispose();
    _phoneController.dispose();
    _phoneFocusNode.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_completed', true);

      if (kDebugMode) debugPrint('[Onboarding] 开始请求位置权限（在页面跳转前）...');
      await _requestLocationPermissionBeforeTransition();

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainNavigation()),
      );
    } catch (e) {
      // 防止位置权限请求或导航中的异常传播到 _quickLogin 的 catch 块，
      // 导致登录成功后仍显示红色错误 SnackBar
      if (kDebugMode) debugPrint('[Onboarding] _completeOnboarding 异常（不影响登录）: $e');
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainNavigation()),
        );
      }
    }
  }

  Future<void> _requestLocationPermissionBeforeTransition() async {
    final hasPerm = await LocationService.hasPermission();
    if (hasPerm) {
      if (kDebugMode) debugPrint('[Onboarding] 位置权限已存在，无需请求');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('newbie_task_location', true);
      return;
    }

    if (kDebugMode) debugPrint('[Onboarding] 显示位置权限引导弹窗...');

    // Apple Guideline 5.1.1(iv): 自定义权限说明弹窗不得提供退出/跳过路径，
    // 按钮须用中性文案（Continue/Next），用户看完说明后必须直接进入系统权限弹窗。
    await _showLocationPermissionGuide();

    if (!mounted) return;

    if (kDebugMode) debugPrint('[Onboarding] 用户已查看说明，开始请求系统位置权限...');
    final status = await LocationService.requestPermission();
    if (kDebugMode) debugPrint('[Onboarding] 权限请求结果: $status');

    final prefs = await SharedPreferences.getInstance();
    if (status.isGranted || status.isLimited) {
      if (kDebugMode) debugPrint('[Onboarding] 位置权限获取成功！');
      await prefs.setBool('newbie_task_location', true);
    } else {
      if (kDebugMode) debugPrint('[Onboarding] 位置权限未授权，稍后可在 求助页面再次开启');
    }
  }

  Future<void> _showLocationPermissionGuide() async {
    // Apple Guideline 5.1.1(iv): 自定义说明弹窗只做告知，不提供退出/跳过路径，
    // 按钮须用中性文案（Continue/Next），点按后直接进入系统权限弹窗。
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZaiNeRadius.card)),
        title:  Row(
          children: [
            Icon(Icons.location_on, color: Color(0xFF11998E)),
            SizedBox(width: ZaiNeSpacing.sm),
            Text(tr.s967),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Text(
              tr.s977,
              style: TextStyle(fontSize: ZaiNeFontSize.bodySm),
            ),
            const SizedBox(height: ZaiNeSpacing.lg),
            Container(
              padding: const EdgeInsets.all(ZaiNeSpacing.md),
              decoration: BoxDecoration(
                color: const Color(0xFF11998E).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(ZaiNeRadius.small),

                boxShadow: ZaiNeShadows.card,),
              child:  Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lock, size: 16, color: Color(0xFF11998E)),
                      SizedBox(width: ZaiNeSpacing.sm),
                      Text(
                        tr.s978,
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: ZaiNeFontSize.caption),
                      ),
                    ],
                  ),
                  SizedBox(height: ZaiNeSpacing.sm),
                  Text(tr.s979, style: TextStyle(fontSize: ZaiNeFontSize.caption)),
                  Text(tr.s980, style: TextStyle(fontSize: ZaiNeFontSize.caption)),
                  Text(tr.s981, style: TextStyle(fontSize: ZaiNeFontSize.caption)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.location_on, size: 18),
            label:  Text(tr.s982),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF11998E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZaiNeRadius.small)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFFF8F9FA),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _totalPages,
                    physics: const BouncingScrollPhysics(),
                    onPageChanged: (index) {
                      setState(() => _currentPage = index);
                      if (index == _totalPages - 1) {
                        // 【性能优化】延迟600ms请求焦点，等PageView滚动动画完全结束后再弹出键盘。
                        // 键盘弹出动画约300ms，与滚动动画并行会导致掉帧。
                        Future.delayed(const Duration(milliseconds: 600), () {
                          if (mounted) _phoneFocusNode.requestFocus();
                        });
                      } else {
                        FocusScope.of(context).unfocus();
                        _phoneFocusNode.unfocus();
                      }
                    },
                    itemBuilder: (context, index) => _buildPage(index),
                  ),
                ),

                // 底部指示器 + 按钮
                Padding(
                  padding: const EdgeInsets.fromLTRB(30, 0, 30, 40),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: List.generate(_totalPages, (index) {
                            final isActive = index == _currentPage;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: isActive ? 24 : 8,
                              height: 8,
                              margin: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.xs),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? ZaiNeColors.brandOrange
                                    : Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(ZaiNeRadius.small),
                              
                                boxShadow: ZaiNeShadows.card,),
                            );
                          }),
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _loginCancelled
                            ? GestureDetector(
                                key: const ValueKey('cancelled'),
                                onTap: () {
                                  if (kDebugMode) debugPrint('[Onboarding] 用户取消操作');
                                  _loginCancelled = false;
                                  setState(() {});
                                },
                                child: Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade400,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.close,
                                        color: Colors.white, size: 24),
                                  ),
                                ),
                              )
                            : _currentPage == _totalPages - 1
                                ? _buildLoginBottomButton()
                                : GestureDetector(
                                    key: const ValueKey('next'),
                                    onTap: () {
                                      FocusScope.of(context).unfocus();
                                      _pageController.nextPage(
                                        duration:
                                            const Duration(milliseconds: 400),
                                        curve: Curves.easeInOut,
                                      );
                                    },
                                    child: Container(
                                      width: 52,
                                      height: 52,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(colors: [
                                          ZaiNeColors.brandOrange,
                                          Color(0xFFFFB347)
                                        ]),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                              color: ZaiNeColors.brandOrange
                                                  .withValues(alpha: 0.35),
                                              blurRadius: 12,
                                              offset: const Offset(0, 4)),
                                        ],
                                      ),
                                      child: const Icon(Icons.arrow_forward,
                                          color: Colors.white, size: 24),
                                    ),
                                  ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(int index) {
    final page = _pages[index];

    if (page['isLogin'] == true) {
      return _LoginPage(
        phoneController: _phoneController,
        phoneFocusNode: _phoneFocusNode,
        codeFocusNode: FocusNode(), // 兼容，实际不使用
        isLoggingIn: _isLoggingIn,
        loginError: _loginError,
        onPhoneChanged: () => setState(() {}), // 手机号变化时刷新底部按钮状态
        onLogin: _quickLogin,
        onAppleLoginSuccess: _completeOnboarding, // 【新增 v1.9.78】
        onAppleLoginError: (msg) {
          // 【修复 v1.81.0】Apple 登录失败，内联显示错误（不用 SnackBar）
          setState(() => _loginError = msg);
        },
        // 【CN 179】渐进披露守护码：只记意愿，不在此处绑定
        onGuardianCodeAccepted: (code) => _loginGuardianCode = code,
        onGuardianCodeCleared: () => _loginGuardianCode = null,
        onBack: () {
          _phoneFocusNode.unfocus();
          _pageController.previousPage(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.xl, vertical: ZaiNeSpacing.xl),
      child: Column(
        children: [
          const SizedBox(height: ZaiNeSpacing.xxl),
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: (page['gradient'] as List<Color>),
              ),
              boxShadow: [
                BoxShadow(
                  color:
                      (page['gradient'] as List<Color>).first.withValues(alpha: 0.3),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Center(
              child:
                  Icon(page['icon'] as IconData, size: 56, color: Colors.white),
            ),
          ),
          const SizedBox(height: ZaiNeSpacing.xxl),
          Text(
            page['title'] as String,
            style: TextStyle(
              fontSize: ZaiNeFontSize.title,
              fontWeight: FontWeight.bold,
              color: ZaiNeColors.textPrimary(),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: ZaiNeSpacing.md),
          Text(
            page['subtitle'] as String,
            style: TextStyle(fontSize: ZaiNeFontSize.bodySm, color: ZaiNeColors.textSecondary()),
            textAlign: TextAlign.center,
          ),
          if ((page['highlight'] as String).isNotEmpty) ...[
            const SizedBox(height: ZaiNeSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.lg, vertical: ZaiNeSpacing.sm),
              decoration: BoxDecoration(
                color: (page['iconBg'] as Color).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(ZaiNeRadius.card),
              
                boxShadow: ZaiNeShadows.card,),
              child: Text(
                page['highlight'] as String,
                style: TextStyle(
                  fontSize: ZaiNeFontSize.caption,
                  fontWeight: FontWeight.w700,
                  color: page['iconBg'] as Color,
                ),
              ),
            ),
          ],
          const SizedBox(height: ZaiNeSpacing.xl),
          ...((page['desc'] as List).map((item) => Padding(
                padding: const EdgeInsets.only(bottom: ZaiNeSpacing.cardXs),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(ZaiNeSpacing.md),
                  decoration: BoxDecoration(
                    color: ZaiNeColors.cardBg(),
                    borderRadius: BorderRadius.circular(ZaiNeRadius.card),
                    border: Border.all(
                        color: (page['iconBg'] as Color).withValues(alpha: 0.08)),
                  
                    boxShadow: ZaiNeShadows.card,),
                  child: Row(
                    children: [
                      Text(item['icon'] as String,
                          style: const TextStyle(fontSize: ZaiNeFontSize.title)),
                      const SizedBox(width: ZaiNeSpacing.md),
                      Expanded(
                          child: Text(item['text'] as String,
                              style: TextStyle(
                                  fontSize: ZaiNeFontSize.bodySm,
                                  color: Colors.grey[800],
                                  fontWeight: FontWeight.w500))),
                    ],
                  ),
                ),
              ))),
          const SizedBox(height: ZaiNeSpacing.xxl),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.lg, vertical: ZaiNeSpacing.md),
            decoration: BoxDecoration(
              color: Colors.grey.shade100.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(ZaiNeRadius.small),
            
              boxShadow: ZaiNeShadows.card,),
            child: Text(
              page['footer'] as String,
              style: TextStyle(fontSize: ZaiNeFontSize.caption, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: ZaiNeSpacing.lg),
        ],
      ),
    );
  }

  /// ===== 第5页底部按钮：手机号直接登录 =====
  Widget _buildLoginBottomButton() {
    final phoneValid = _phoneController.text.trim().length >= 11;
    final canLogin = phoneValid && !_isLoggingIn;

    return ElevatedButton(
      key: const ValueKey('quick_login'),
      onPressed: canLogin ? _quickLogin : null,
      style: ElevatedButton.styleFrom(
        backgroundColor:
            canLogin ? ZaiNeColors.brandOrange : Colors.grey.shade400,
        disabledBackgroundColor: Colors.grey.shade400,
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white70,
        padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.xl, vertical: ZaiNeSpacing.lg),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZaiNeRadius.card)),
        elevation: 0,
      ),
      child: _isLoggingIn
          ?  Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: ZaiNeSpacing.sm),
                Text(tr.s983,
                    style: TextStyle(
                        fontSize: ZaiNeFontSize.body,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ],
            )
          :  Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_outline_rounded, size: 18),
                SizedBox(width: ZaiNeSpacing.sm),
                Text(tr.s984,
                    style:
                        TextStyle(fontSize: ZaiNeFontSize.body, fontWeight: FontWeight.bold)),
              ],
            ),
    );
  }

  /// 手机号直接登录（MVP 阶段，quickLogin 无需验证码）
  Future<void> _quickLogin() async {
    if (_isLoggingIn) return;
    _loginCompleted = false;
    _loginError = ''; // 清除之前的错误提示

    var phone = _phoneController.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
    // 【v1.97.x 防幽灵账号】剥离 +86 国际前缀，与后端 normalize_phone 对齐，
    // 避免带空格/+86 的手机号被 quick_login 当成新账号静默创建
    if (phone.length == 13 && phone.startsWith('86')) {
      phone = phone.substring(2);
    }
    // 【v1.9.78】支持国际手机号（最少6位，最长15位）
    if (phone.isEmpty || phone.replaceAll(RegExp(r'[^0-9]'), '').length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
            content: Text(tr.s985), backgroundColor: Colors.orange),
      );
      return;
    }

    _phoneFocusNode.unfocus();
    setState(() => _isLoggingIn = true);

    // 【v1.97.4 / 188 修复】登录前强制重置全局串行请求队列，
    // 打断任何可能残留的挂起链，避免"登录中"永久转。
    ApiService.resetRequestChain();
    developer.log('[190 LOGIN] 入口: phone=$phone', name: 'zaine.login');

    try {
      HapticFeedback.mediumImpact();

      final prefs = await SharedPreferences.getInstance();
      _pendingCardCode = prefs.getString('pending_card_code') ??
          prefs.getString('pending-card-code');
      if ((prefs.getString('pending_card_code') == null ||
              prefs.getString('pending_card_code')!.isEmpty) &&
          _pendingCardCode != null &&
          _pendingCardCode!.isNotEmpty) {
        await prefs.setString('pending_card_code', _pendingCardCode!);
      }

      // [v1.76.0] 检查是否有紧急联系人邀请
      final pendingInvitePhone = await DeepLinkService.getPendingInvitePhone();
      bool enableBidirectional = false;

      if (pendingInvitePhone != null && pendingInvitePhone.isNotEmpty) {
        if (kDebugMode) debugPrint('[Onboarding] 发现紧急联系人邀请: phone=$pendingInvitePhone');
        // 显示授权对话框（方案A：显式授权）
        enableBidirectional = await _showInviteAuthDialog(pendingInvitePhone);
      }

      if (kDebugMode) debugPrint('[Onboarding] quickLogin: $phone, cardCode=$_pendingCardCode, invitePhone=$pendingInvitePhone, enableBidirectional=$enableBidirectional');

      // 包含冷启动重试
      developer.log('[190 LOGIN] 调用 AuthService.quickLogin 前', name: 'zaine.login');
      final res = await AuthService.quickLogin(
        phone,
        cardId: _pendingCardCode,
        invitePhone: pendingInvitePhone,
        enableBidirectional: enableBidirectional,
      )
          .timeout(const Duration(seconds: 30), onTimeout: () {
        developer.log('[190 LOGIN] quickLogin 30s 超时, 返回网络错误', name: 'zaine.login');
        return {'success': false, 'error': tr.s986};
      });
      developer.log('[190 LOGIN] quickLogin 返回: success=${res['success']}, hasToken=${res['token'] != null}', name: 'zaine.login');

      if (res['success'] == true) {
        if (kDebugMode) debugPrint('[Onboarding] quickLogin 成功, userId=${res['userId']}');
        // 在首个 await 前捕获 context，避免跨异步使用 BuildContext 的 lint / 隐患
        final ctx = context;

        // ====== 增强：仪式感动画展示 ======
      // 【修复 v1.17.1】优先使用 quickLogin 返回的 card_info（首次下载注册场景）
      // 兜底：_pendingCardCode（DeepLink 唤醒场景）
      final cardInfo = res['card_info'];
      if (cardInfo != null && cardInfo is Map) {
        // 场景A：H5注册后首次下载App，后端通过 quickLogin 返回卡片信息
        try {
          final cardData = cardInfo as Map<String, dynamic>;
          if (kDebugMode) debugPrint('[Onboarding] 展示守护礼动画（来自登录返回）');

          // 先执行拉取数据，让背景静默准备
          developer.log('[190 LOGIN] 开始 pullFromServer (场景A)', name: 'zaine.login');
          await SyncService.pullFromServer().timeout(
            const Duration(seconds: 25),
            onTimeout: () {
              developer.log('[190 LOGIN] pullFromServer 25s 超时, 降级跳过', name: 'zaine.login');
              return;
            },
          );

          if (!mounted) return;

          // 展示精美 3D 动画（统一封装，修复 ②+③）
          final aCode = cardData['card_code']?.toString() ?? '';
          await markRitualSeen(aCode); // 标记已见证，home 端不会重复弹
          await showGuardianWelcomeRitual(
            ctx,
            senderName: cardData['sender_name'] ?? tr.s138,
            senderAvatar: cardData['sender_avatar'],
            message: cardData['message'] ?? tr.s139,
            cardCode: aCode,
            onClosed: () async {
              // 清理 pending 状态（两种 key 格式都清理）
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('pending_card_code');
              await prefs.remove('pending-card-code');
              // 【修复 2026-07-12】服务端标记已见证（收卡人视角），防跨设备重弹
              if (aCode.isNotEmpty) {
                CardService.welcomeAck(cardCode: aCode, role: 'receiver').catchError((_) {});
              }
            },
          );
        } catch (e) {
          if (kDebugMode) debugPrint('[Onboarding] 守护礼动画失败（登录返回）: $e');
        }
      } else if (_pendingCardCode != null && _pendingCardCode!.isNotEmpty) {
        // 场景B：已装App，通过 DeepLink 唤醒（兜底逻辑）
        try {
          final cardRes = await CardService.checkCard(_pendingCardCode!);
          if (cardRes['success'] == true && mounted) {
            final cardData = cardRes;
            if (kDebugMode) debugPrint('[Onboarding] 展示守护礼动画（来自DeepLink）');

            developer.log('[190 LOGIN] 开始 pullFromServer (场景B)', name: 'zaine.login');
            await SyncService.pullFromServer().timeout(
              const Duration(seconds: 25),
              onTimeout: () {
                developer.log('[190 LOGIN] pullFromServer 25s 超时, 降级跳过', name: 'zaine.login');
                return;
              },
            );
            if (!mounted) return;

            // 展示精美 3D 动画（统一封装，修复 ②+③）
            final bCode = _pendingCardCode ?? '';
            await markRitualSeen(bCode); // 标记已见证，home 端不会重复弹
            await showGuardianWelcomeRitual(
              ctx,
              senderName: cardData['sender_name'] ?? tr.s138,
              senderAvatar: cardData['sender_avatar'],
              message: cardData['message'] ?? tr.s139,
              cardCode: bCode,
              onClosed: () async {
                // 清理 pending 状态（两种 key 格式都清理）
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('pending_card_code');
                await prefs.remove('pending-card-code');
                // 【修复 2026-07-12】服务端标记已见证（收卡人视角），防跨设备重弹
                final b = bCode ?? '';
                if (b.isNotEmpty) {
                  CardService.welcomeAck(cardCode: b, role: 'receiver').catchError((_) {});
                }
              },
            );
          }
        } catch (e) {
          if (kDebugMode) debugPrint('[Onboarding] 守护礼动画失败（DeepLink）: $e');
        }
      } else {
        // 普通登录，直接拉取数据
        developer.log('[190 LOGIN] 开始 pullFromServer (普通登录)', name: 'zaine.login');
        await SyncService.pullFromServer().timeout(
          const Duration(seconds: 25),
          onTimeout: () {
            developer.log('[190 LOGIN] pullFromServer 25s 超时, 降级跳过', name: 'zaine.login');
            return;
          },
        );
      }

        if (mounted) {
          _loginCompleted = true;

          // ===== 【CN 179】登录成功 → 静默兑现登录页填下的守护码 =====
          // 用户早在填码那一刻就完成了「单独同意」(个保法第29条)，
          // 这里只做最后的绑定动作：成功不弹窗直接进首页，
          // 仅失败才提示一次，且提示完照常进首页，绝不卡住登录。
          await _redeemPendingGuardianCode();

          developer.log('[190 LOGIN] 调用 _completeOnboarding (位置权限等)', name: 'zaine.login');
          await _completeOnboarding().timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              developer.log('[190 LOGIN] _completeOnboarding 15s 超时, 降级跳过', name: 'zaine.login');
              return;
            },
          );
          developer.log('[190 LOGIN] _completeOnboarding 完成', name: 'zaine.login');

          // 【v1.98.0】登录成功 → 请求通知权限并注册 APNs 推送
          // （守护人接收「报了平安/还没报平安」的到达通道；fire-and-forget 不阻塞进首页）
          PushService.instance.promptAndRegister().catchError((_) {});
        }
      } else {
        if (_loginCompleted) return;
        _showInlineError(
            res['error']?.toString() ?? res['message']?.toString() ?? '');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Onboarding] quickLogin 异常: $e');
      if (_loginCompleted || !mounted) return;
      _showInlineError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoggingIn = false);
    }
  }

  /// 【CN 179】兑现「登录页填下的守护码」
  /// 前置条件：用户已在登录前经 showGuardianConsentDialog 单独同意，此处不再重复征求。
  /// 现在已拿到登录态，redeemCard（auth:true）才不会被 401。
  /// 失败不阻断登录流程，只提示一次。
  Future<void> _redeemPendingGuardianCode() async {
    final code = _loginGuardianCode;
    _loginGuardianCode = null; // 只兑现一次，避免重复绑定
    if (code == null || code.isEmpty) return;

    try {
      developer.log('[190 LOGIN] 兑现登录页守护码: $code', name: 'zaine.login');
      final res = await CardService.redeemCard(
              cardCode: code, oneway: kIsChinaBuild)
          .timeout(const Duration(seconds: 12),
              onTimeout: () => <String, dynamic>{'success': false});

      // 无论成功失败都拉一次，保证进首页后守护圈立刻可见
      try {
        await SyncService.pullFromServer()
            .timeout(const Duration(seconds: 15), onTimeout: () {
          developer.log('[190 LOGIN] 守护码兑现后 pull 超时', name: 'zaine.login');
          return;
        });
      } catch (_) {}

      if (res['success'] == true) {
        developer.log('[190 LOGIN] 登录页守护码绑定成功', name: 'zaine.login');
        return;
      }

      // 绑定失败：告诉用户一次，然后照常进首页
      final msg = res['message']?.toString() ?? '';
      developer.log('[190 LOGIN] 登录页守护码绑定失败: $msg', name: 'zaine.login');
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(ZaiNeRadius.card)),
          title: const Text('守护码未能绑定'),
          content: Text(
            msg.isNotEmpty ? msg : '守护码无效或已失效，您可以在「我的 → 输入守护码」重新录入。',
            style: TextStyle(
                fontSize: ZaiNeFontSize.bodySm,
                color: ZaiNeColors.textSecondary(),
                height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
    } catch (e) {
      developer.log('[190 LOGIN] 守护码兑现异常（不影响登录）: $e', name: 'zaine.login');
    }
  }

  static String _sanitizeErrorMessage(String raw) {
    final lower = raw.toLowerCase();
    // 网络层错误
    if (lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('network is unreachable') ||
        lower.contains('no route to host') ||
        lower.contains('connection refused')) {
      return tr.s987;
    }
    if (lower.contains('connection timed out') ||
        lower.contains('timeout') ||
        lower.contains('deadline exceeded')) {
      return tr.s988;
    }
    if (lower.contains('handshake') ||
        lower.contains('ssl') ||
        lower.contains('certificate')) {
      return tr.s989;
    }
    // 服务器层错误（阿里云 FC 502/504/503 等）
    if (lower.contains(tr.s990) ||
        lower.contains(tr.s991) ||
        lower.contains(tr.s992) ||
        lower.contains(tr.s993)) {
      return raw; // 已经是友好的中文提示，直接返回
    }
    // 过长的原始错误信息，简化显示
    if (raw.length > 30) {
      return tr.s994;
    }
    return raw;
  }

  /// 显示内联登录错误（取代 SnackBar，避免导航页面残留）
  void _showInlineError(String raw) {
    if (!mounted || _loginCompleted) return;
    final msg = _sanitizeErrorMessage(raw);
    setState(() => _loginError = msg);
  }

  /// [v1.76.0] 显示紧急联系人邀请授权对话框（方案A：显式授权）
  ///
  /// 流程：
  /// 1. 用户点击邀请链接 → Deep Link 保存 pending_invite_phone
  /// 2. 用户注册登录后，检查是否有待处理邀请
  /// 3. 弹出此对话框，让用户选择是否建立双向守护
  ///
  /// 返回：
  /// - true：用户同意双向守护
  /// - false：用户拒绝（仅单向守护）
  Future<bool> _showInviteAuthDialog(String inviterPhone) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZaiNeRadius.card)),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: ZaiNeColors.brandOrange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shield_outlined, color: ZaiNeColors.brandOrange, size: 24),
            ),
            const SizedBox(width: ZaiNeSpacing.md),
             Expanded(
              child: Text(tr.s995, style: TextStyle(fontSize: ZaiNeFontSize.subtitle, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr.s996(inviterPhone),
              style: const TextStyle(fontSize: ZaiNeFontSize.body, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: ZaiNeSpacing.md),
            Text(
              tr.s997,
              style: TextStyle(fontSize: ZaiNeFontSize.bodySm, color: ZaiNeColors.textPrimary()),
            ),
            const SizedBox(height: ZaiNeSpacing.sm),
            Container(
              padding: const EdgeInsets.all(ZaiNeSpacing.md),
              decoration: BoxDecoration(
                color: ZaiNeColors.cardBg(),
                borderRadius: BorderRadius.circular(ZaiNeRadius.small),
                border: Border.all(color: ZaiNeColors.dividerColor()),
              
                boxShadow: ZaiNeShadows.card,),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle_outline, size: 16, color: Colors.green.shade600),
                      const SizedBox(width: ZaiNeSpacing.sm),
                       Expanded(
                        child: Text(tr.s998, style: TextStyle(fontSize: ZaiNeFontSize.caption, fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ),
                  const SizedBox(height: ZaiNeSpacing.xs),
                  Text(
                    tr.s999,
                    style: TextStyle(fontSize: ZaiNeFontSize.caption, color: ZaiNeColors.textSecondary()),
                  ),
                ],
              ),
            ),
            const SizedBox(height: ZaiNeSpacing.sm),
            Text(
              tr.s1000,
              style: TextStyle(fontSize: ZaiNeFontSize.caption, color: ZaiNeColors.textSecondary()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr.s1001, style: TextStyle(color: ZaiNeColors.textSecondary(), fontSize: ZaiNeFontSize.body)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ZaiNeColors.brandOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZaiNeRadius.small)),
              padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.xl, vertical: ZaiNeSpacing.md),
            ),
            child:  Text(tr.s998, style: TextStyle(fontSize: ZaiNeFontSize.body, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    return result ?? false; // 默认拒绝（仅单向）
  }
}
