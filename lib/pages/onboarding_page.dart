import 'dart:async';
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
import '../services/deep_link_service.dart'; // [v1.76.0] 紧急联系人邀请
import '../services/api/card_service.dart'; // 新增
import '../widgets/guardian_card_envelope.dart'; // 新增

/// 开机引导页 — 5页专业引导
/// 核心定位：这不是签到App，这是危急时刻能救命的应急救援工具
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

  @override
  void initState() {
    super.initState();
    _checkPendingCard();
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
                padding: const EdgeInsets.all(8),
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
            '开始使用',
            style: TextStyle(
                fontSize: ZaiNeFontSize.title,
                fontWeight: FontWeight.bold,
                color: ZaiNeColors.textPrimary()),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: ZaiNeSpacing.md),

          // 副标题
          Text(
            '输入手机号，即刻开启安全守护',
            style: TextStyle(fontSize: ZaiNeFontSize.bodySm, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),

          // 提示标签
          const SizedBox(height: ZaiNeSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.lg, vertical: ZaiNeSpacing.sm),
            decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(ZaiNeRadius.card),
            
              boxShadow: ZaiNeShadows.card,),
            child: const Text(
              '手机号登录，即刻开启',
              style: TextStyle(
                  fontSize: ZaiNeFontSize.caption,
                  fontWeight: FontWeight.w700,
                  color: Colors.purple),
            ),
          ),

          const SizedBox(height: ZaiNeSpacing.xl),

          // 国际手机号输入框
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
              child: InternationalPhoneNumberInput(
                onInputChanged: (PhoneNumber number) {
                  widget.onPhoneChanged?.call();
                },
                selectorConfig: const SelectorConfig(
                  selectorType: PhoneInputSelectorType.BOTTOM_SHEET,
                  showFlags: true,
                  useEmoji: true,
                ),
                ignoreBlank: false,
                autoValidateMode: AutovalidateMode.disabled,
                selectorTextStyle: TextStyle(
                    fontSize: ZaiNeFontSize.body,
                    color: ZaiNeColors.textPrimary()),
                textFieldController: widget.phoneController,
                formatInput: true,
                keyboardType: TextInputType.phone,
                inputBorder: InputBorder.none,
                hintText: '请输入手机号',
                maxLength: 15,
                countries: const ['CN', 'US', 'JP', 'KR', 'SG', 'HK', 'TW', 'MO'],
                initialValue: PhoneNumber(isoCode: 'CN'),
              ),
            ),
          ),

          // 提示文字
          const SizedBox(height: ZaiNeSpacing.sm),
          Text(
            '支持全球手机号注册登录',
            style: TextStyle(
                fontSize: ZaiNeFontSize.caption,
                color: ZaiNeColors.textHint()),
            textAlign: TextAlign.center,
          ),

          // Apple ID 登录按钮
          SignInWithAppleButton(
            onPressed: widget.isLoggingIn
                ? () {}
                : () {
                    // 异步执行，不阻塞 UI
                    _handleAppleSignIn();
                  },
            style: SignInWithAppleButtonStyle.black,
            height: 50,
            borderRadius: BorderRadius.circular(ZaiNeRadius.card),
          ),

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
          if (!_isCheckingPending && !_hasPendingCard) ...[
            GestureDetector(
              onTap: _showCardCodeInput,
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.lg, vertical: ZaiNeSpacing.lg),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFF5F0), Color(0xFFFFF0E8)],
                  ),
                  borderRadius: BorderRadius.circular(ZaiNeRadius.card),
                  border: Border.all(
                      color: const Color(0xFFFF7F50).withValues(alpha: 0.2)),
                
                  boxShadow: ZaiNeShadows.card,),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF7F50).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(ZaiNeRadius.small),
                      
                        boxShadow: ZaiNeShadows.card,),
                      child: const Icon(Icons.card_giftcard,
                          color: Color(0xFFFF7F50), size: 18),
                    ),
                    const SizedBox(width: ZaiNeSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '有人给你发了守护卡？',
                            style: TextStyle(
                                fontSize: ZaiNeFontSize.bodySm,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade800),
                          ),
                          const SizedBox(height: ZaiNeSpacing.xs),
                          const Text(
                            '输入安全码，一键完成绑定 →',
                            style: TextStyle(
                                fontSize: ZaiNeFontSize.caption, color: Color(0xFFFF7F50)),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right,
                        color: Color(0xFFFF7F50), size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: ZaiNeSpacing.lg),
          ],

          // 底部提示
          Container(
            padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.lg, vertical: ZaiNeSpacing.md),
            decoration: BoxDecoration(
              color: Colors.grey.shade100.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(ZaiNeRadius.small),
            
              boxShadow: ZaiNeShadows.card,),
            child: Text(
              '在呢，守护独居的你',
              style: TextStyle(fontSize: ZaiNeFontSize.caption, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: ZaiNeSpacing.xl),
        ],
      ),
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
                              color: const Color(0xFFFFF5F0),
                              borderRadius: BorderRadius.circular(ZaiNeRadius.small)
                          ),
                          child: const Icon(Icons.vpn_key,
                              color: Color(0xFFFF7F50), size: 20),
                        ),
                        const SizedBox(width: ZaiNeSpacing.md),
                        const Expanded(
                          child: Text(
                            '输入守护安全码',
                            style: TextStyle(
                                fontSize: ZaiNeFontSize.subtitle, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: ZaiNeSpacing.sm),
                    Text(
                      '安全码由发卡人提供，输入后即可与对方建立守护关系',
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
                        hintText: '例如: TFABT4',
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
                              const BorderSide(color: Color(0xFFFF7F50)),
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
                            setSheetState(() => errorText = '请输入安全码');
                            return;
                          }
                          if (code.length < 4) {
                            setSheetState(() => errorText = '安全码至少4位');
                            return;
                          }
                          // 验证安全码是否有效
                          setSheetState(() => errorText = null);
                          try {
                            final checkRes = await CardService.checkCard(code);
                            if (checkRes['success'] != true) {
                              setSheetState(() =>
                                  errorText = checkRes['message'] ?? '无效的安全码');
                              return;
                            }
                          } catch (e) {
                            setSheetState(() => errorText = '验证失败，请检查网络');
                            return;
                          }

                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setString('pending_card_code', code);
                          await prefs.setString('pending-card-code', code);
                          if (kDebugMode) debugPrint('[Onboarding] 暂存安全码: $code');

                          if (mounted && ctx.mounted) {
                            setState(() => _hasPendingCard = true);
                            Navigator.pop(ctx);
                          }
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('✅ 安全码已保存，登录后将自动绑定'),
                                backgroundColor: Color(0xFFFF7F50),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF7F50),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: ZaiNeSpacing.lg),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZaiNeRadius.card)),
                        ),
                        child: const Text('确认',
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

  /// Apple Sign In 处理逻辑
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
        debugPrint('[Apple Sign In] identityToken: ${credential.identityToken}');
        debugPrint('[Apple Sign In] authorizationCode: ${credential.authorizationCode}');
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
        // 登录失败
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Apple 登录失败: ${res['message'] ?? '未知错误'}'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Apple Sign In] 错误: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Apple 登录失败: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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
          'title': '独居生活的贴心守护者',
          'subtitle': '每一个独居的夜晚\n你并不孤单',
          'highlight': '守护你的每个夜晚',
          'desc': [
            {'icon': '🛡️', 'text': '紧急情况一键通知守护者'},
            {'icon': '📍', 'text': '实时定位，守护者即刻响应'},
            {'icon': '🤝', 'text': '让爱你的人不再提心吊胆'},
          ],
          'footer': '在呢 — 让在乎你的人知道你很好',
        },
        {
          'icon': Icons.medical_information_rounded,
          'iconBg': Colors.blue,
          'gradient': [const Color(0xFF4FACFE), const Color(0xFF00F2FE)],
          'title': '完善你的健康档案',
          'subtitle': '让救援人员在第一时间了解你的情况',
          'highlight': '关键信息，精准守护',
          'desc': [
            {'icon': '🩸', 'text': '血型 —— 输血时救命'},
            {'icon': '💊', 'text': '药物过敏 —— 避免二次伤害'},
            {'icon': '📋', 'text': '病史备注 —— 帮助医生判断'},
          ],
          'footer': '这些信息只在求助触发时发送',
        },
        {
          'icon': Icons.people_alt_rounded,
          'iconBg': Colors.orange,
          'gradient': [
            const Color(0xFFFF7F50),
            const Color(0xFFFFB347),
            const Color(0xFFFF7F50)
          ],
          'title': '添加你的守护者',
          'subtitle': '紧急联系人 = 你的安全网',
          'highlight': '至少添加1位家人或朋友',
          'desc': [
            {'icon': '👨‍👩‍👧', 'text': '求助时按优先顺序通知'},
            {'icon': '📱', 'text': '自动发送求救短信+位置'},
            {'icon': '↔️', 'text': '可拖动调整优先级'},
          ],
          'footer': '他们会在你最需要的时候收到消息',
        },
        {
          'icon': Icons.location_on_rounded,
          'iconBg': Colors.green,
          'gradient': [const Color(0xFF11998E), const Color(0xFF38EF7D)],
          'title': '开启位置权限',
          'subtitle': '我们承诺：绝不监控你的日常位置',
          'highlight': '只在求助时获取一次位置',
          'desc': [
            {'icon': '🔒', 'text': '平时不追踪、不监控、不上传'},
            {'icon': '⚡', 'text': '只有你主动触发求助才定位'},
            {'icon': '🗺️', 'text': '精确到米级，附带地图链接'},
          ],
          'footer': '你的隐私，我们用生命捍卫',
        },
        {
          'icon': Icons.phone_android_rounded,
          'iconBg': Colors.purple,
          'gradient': [
            const Color(0xFF7C4DFF),
            const Color(0xFF9C27B0),
            const Color(0xFFE040FB)
          ],
          'title': '开始使用',
          'subtitle': '输入手机号，即刻开启安全守护',
          'highlight': '手机号登录，即刻开启',
          'desc': [
            {'icon': '📱', 'text': '紧急求助短信将包含您的手机号'},
            {'icon': '🔐', 'text': '您的信息仅用于紧急救援'},
            {'icon': '⚡', 'text': '未注册手机号将自动创建账号'},
          ],
          'footer': '在呢，守护独居的你',
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

    final confirmed = await _showLocationPermissionGuide();
    if (confirmed != true) {
      if (kDebugMode) debugPrint('[Onboarding] 用户选择稍后再说');
      return;
    }

    if (!mounted) return;

    if (kDebugMode) debugPrint('[Onboarding] 用户确认，开始请求系统位置权限...');
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

  Future<bool?> _showLocationPermissionGuide() async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZaiNeRadius.card)),
        title: const Row(
          children: [
            Icon(Icons.location_on, color: Color(0xFF11998E)),
            SizedBox(width: ZaiNeSpacing.sm),
            Text('开启位置权限'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '为了在你触发求助时，守护者能第一时间知道你的准确位置，我们需要获取位置权限。',
              style: TextStyle(fontSize: ZaiNeFontSize.bodySm),
            ),
            const SizedBox(height: ZaiNeSpacing.lg),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF11998E).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(ZaiNeRadius.small),
              
                boxShadow: ZaiNeShadows.card,),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lock, size: 16, color: Color(0xFF11998E)),
                      SizedBox(width: ZaiNeSpacing.sm),
                      Text(
                        '我们承诺：',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: ZaiNeFontSize.caption),
                      ),
                    ],
                  ),
                  SizedBox(height: ZaiNeSpacing.sm),
                  Text('• 平时不追踪、不监控、不上传你的位置', style: TextStyle(fontSize: ZaiNeFontSize.caption)),
                  Text('• 只有你主动触发求助时才获取一次位置', style: TextStyle(fontSize: ZaiNeFontSize.caption)),
                  Text('• 你的隐私，我们用生命捍卫', style: TextStyle(fontSize: ZaiNeFontSize.caption)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('稍后再说', style: TextStyle(color: Colors.grey[500])),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.location_on, size: 18),
            label: const Text('确认开启'),
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
                                    ? const Color(0xFFFF7F50)
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
                                          Color(0xFFFF7F50),
                                          Color(0xFFFFB347)
                                        ]),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                              color: const Color(0xFFFF7F50)
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
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
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
            canLogin ? const Color(0xFFFF7F50) : Colors.grey.shade400,
        disabledBackgroundColor: Colors.grey.shade400,
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white70,
        padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.xl, vertical: ZaiNeSpacing.lg),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZaiNeRadius.card)),
        elevation: 0,
      ),
      child: _isLoggingIn
          ? const Row(
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
                Text('登录中...',
                    style: TextStyle(
                        fontSize: ZaiNeFontSize.body,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ],
            )
          : const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_outline_rounded, size: 18),
                SizedBox(width: ZaiNeSpacing.sm),
                Text('登录 / 注册',
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

    final phone = _phoneController.text.trim();
    // 【v1.9.78】支持国际手机号（最少6位，最长15位）
    if (phone.isEmpty || phone.replaceAll(RegExp(r'[^0-9]'), '').length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('请输入有效的手机号码'), backgroundColor: Colors.orange),
      );
      return;
    }

    _phoneFocusNode.unfocus();
    setState(() => _isLoggingIn = true);

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
      final res = await AuthService.quickLogin(
        phone,
        cardId: _pendingCardCode,
        invitePhone: pendingInvitePhone,
        enableBidirectional: enableBidirectional,
      )
          .timeout(const Duration(seconds: 55), onTimeout: () {
        return {'success': false, 'error': '网络连接超时，请检查网络后重试'};
      });

      if (res['success'] == true) {
        if (kDebugMode) debugPrint('[Onboarding] quickLogin 成功, userId=${res['userId']}');

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
          await SyncService.pullFromServer();

          if (!mounted) return;

          // 展示精美 3D 动画
          await showGeneralDialog(
            context: context,
            barrierDismissible: false,
            barrierColor: Colors.black.withValues(alpha: 0.92),
            transitionDuration: const Duration(milliseconds: 800),
            pageBuilder: (ctx, anim1, anim2) {
              return Scaffold(
                backgroundColor: Colors.transparent,
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FadeTransition(
                        opacity: anim1,
                        child: const Text(
                          '开启你的守护礼',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: ZaiNeFontSize.subtitle,
                              letterSpacing: 4,
                              fontWeight: FontWeight.w300),
                        ),
                      ),
                      const SizedBox(height: ZaiNeSpacing.xxl),
                      GuardianCardEnvelope(
                        senderName: cardData['sender_name'] ?? '你的好友',
                        senderAvatar: cardData['sender_avatar'],
                        message: cardData['message'] ?? '想和你建立守护关系',
                        cardCode: cardData['card_code'] ?? '',
                        appStoreUrl: '',
                        isWelcomeMode: true, // 【修复 v1.17.1】收卡人登录后展示欢迎卡
                        onComplete: () {
                          // 【修复 v1.76.0】清理 pending_card_code 避免重复弹出
                          Future.delayed(const Duration(milliseconds: 3500), () async {
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              // 清理 pending 状态（两种 key 格式都清理）
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.remove('pending_card_code');
                              await prefs.remove('pending-card-code');
                            }
                          });
                        },
                      ),
                    ],
                  ),
                ),
              );
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

            await SyncService.pullFromServer();
            if (!mounted) return;

            await showGeneralDialog(
              context: context,
              barrierDismissible: false,
              barrierColor: Colors.black.withValues(alpha: 0.92),
              transitionDuration: const Duration(milliseconds: 800),
              pageBuilder: (ctx, anim1, anim2) {
                return Scaffold(
                  backgroundColor: Colors.transparent,
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FadeTransition(
                          opacity: anim1,
                          child: const Text(
                            '开启你的守护礼',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: ZaiNeFontSize.subtitle,
                                letterSpacing: 4,
                                fontWeight: FontWeight.w300),
                          ),
                        ),
                        const SizedBox(height: ZaiNeSpacing.xxl),
                        GuardianCardEnvelope(
                          senderName: cardData['sender_name'] ?? '你的好友',
                          senderAvatar: cardData['sender_avatar'],
                          message: cardData['message'] ?? '想和你建立守护关系',
                          cardCode: _pendingCardCode!,
                          appStoreUrl: '',
                          isWelcomeMode: true, // 【修复 v1.17.1】收卡人登录后展示欢迎卡
                          onComplete: () {
                            // 【修复 v1.76.0】清理 pending_card_code 避免重复弹出
                            Future.delayed(const Duration(milliseconds: 3500), () async {
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                                // 清理 pending 状态（两种 key 格式都清理）
                                final prefs = await SharedPreferences.getInstance();
                                await prefs.remove('pending_card_code');
                                await prefs.remove('pending-card-code');
                              }
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
        } catch (e) {
          if (kDebugMode) debugPrint('[Onboarding] 守护礼动画失败（DeepLink）: $e');
        }
      } else {
        // 普通登录，直接拉取数据
        await SyncService.pullFromServer();
      }

        if (mounted) {
          _loginCompleted = true;
          await _completeOnboarding();
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

  static String _sanitizeErrorMessage(String raw) {
    final lower = raw.toLowerCase();
    // 网络层错误
    if (lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('network is unreachable') ||
        lower.contains('no route to host') ||
        lower.contains('connection refused')) {
      return '网络连接失败，请检查网络后重试';
    }
    if (lower.contains('connection timed out') ||
        lower.contains('timeout') ||
        lower.contains('deadline exceeded')) {
      return '网络请求超时，请检查网络后重试';
    }
    if (lower.contains('handshake') ||
        lower.contains('ssl') ||
        lower.contains('certificate')) {
      return '安全连接失败，请检查网络环境';
    }
    // 服务器层错误（阿里云 FC 502/504/503 等）
    if (lower.contains('服务器繁忙') ||
        lower.contains('服务器返回空响应') ||
        lower.contains('服务器响应异常') ||
        lower.contains('服务器响应格式错误')) {
      return raw; // 已经是友好的中文提示，直接返回
    }
    // 过长的原始错误信息，简化显示
    if (raw.length > 30) {
      return '登录失败，请稍后重试';
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
                color: const Color(0xFFFF7F50).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shield_outlined, color: Color(0xFFFF7F50), size: 24),
            ),
            const SizedBox(width: ZaiNeSpacing.md),
            const Expanded(
              child: Text('守护邀请', style: TextStyle(fontSize: ZaiNeFontSize.subtitle, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '手机号 $inviterPhone 的用户已将你设为紧急联系人',
              style: const TextStyle(fontSize: ZaiNeFontSize.body, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: ZaiNeSpacing.md),
            Text(
              '你是否也希望对方守护你？',
              style: TextStyle(fontSize: ZaiNeFontSize.bodySm, color: ZaiNeColors.textPrimary()),
            ),
            const SizedBox(height: ZaiNeSpacing.sm),
            Container(
              padding: const EdgeInsets.all(12),
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
                      const Expanded(
                        child: Text('互相守护', style: TextStyle(fontSize: ZaiNeFontSize.caption, fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ),
                  const SizedBox(height: ZaiNeSpacing.xs),
                  Text(
                    '  你们可以查看彼此的状态，遇到紧急情况互相帮助',
                    style: TextStyle(fontSize: ZaiNeFontSize.caption, color: ZaiNeColors.textSecondary()),
                  ),
                ],
              ),
            ),
            const SizedBox(height: ZaiNeSpacing.sm),
            Text(
              '你也可以选择"不用了"，仅作为对方的紧急联系人',
              style: TextStyle(fontSize: ZaiNeFontSize.caption, color: ZaiNeColors.textSecondary()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('不用了', style: TextStyle(color: ZaiNeColors.textSecondary(), fontSize: ZaiNeFontSize.body)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF7F50),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZaiNeRadius.small)),
              padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.xl, vertical: ZaiNeSpacing.md),
            ),
            child: const Text('互相守护', style: TextStyle(fontSize: ZaiNeFontSize.body, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    return result ?? false; // 默认拒绝（仅单向）
  }
}
