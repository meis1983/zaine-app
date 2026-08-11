import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'theme/theme_helper.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pages/home_page.dart';
import 'pages/guardian_page.dart';
import 'pages/help_page.dart';
import 'pages/profile_page.dart';
import 'pages/onboarding_page.dart';
import 'services/deep_link_service.dart';
import 'services/silent_login_service.dart';
import 'services/membership_service.dart';
import 'services/api/auth_service.dart';
import 'services/platform/health_service.dart'; // 【v1.91.0】Watch 签到通道
import 'services/platform/watch_data_service.dart'; // 【修复】Watch 健康数据推送初始化
import 'data/app_constants.dart';
// import 'config/feature_flags.dart';  // 暂时未使用，保留以备后续功能开发

// 主题模式枚举
// 0 = 浅色（默认）, 1 = 深色, 2 = 柔光
enum ZaiNeThemeMode { light, dark, soft }

/// 全局主题变更通知器
class ThemeNotifier extends ChangeNotifier {
  ZaiNeThemeMode _mode = ZaiNeThemeMode.light;

  ZaiNeThemeMode get mode => _mode;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final idx = prefs.getInt('theme_mode') ?? 0;
    _mode = ZaiNeThemeMode.values[idx.clamp(0, 2)];
    notifyListeners();
  }

  Future<void> setMode(ZaiNeThemeMode mode) async {
    _mode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_mode', mode.index);
    notifyListeners();
  }
}

final ThemeNotifier themeNotifier = ThemeNotifier();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  // 从 pubspec.yaml 读取版本号（根治版本号不一致问题）
  await AppConstants.initVersion();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  await themeNotifier.load();

  // 【v1.91.0】初始化 Watch MethodChannel — AppDelegate 收到 Watch 签到后立即通知 Flutter
  HealthService.initWatchChannel();

  // 【修复】初始化 Watch 数据推送通道 — 否则 _isPaired 恒 false，手表健康速览永远空白。
  // 加超时保护，避免 watch_connectivity 在异常环境下阻塞 App 启动。
  try {
    await WatchDataService().init().timeout(const Duration(seconds: 3));
  } catch (e) {
    if (kDebugMode) debugPrint('[Main] WatchDataService.init 超时/失败(忽略): $e');
  }

  // 【修复 v1.77.0】迁移敏感信息从 SP 到 Keychain（安全）
  await _migrateSensitiveDataToKeychain();

  // 初始化 Deep Link 监听（守护卡裂变落地页）
  await DeepLinkService.init();

  // 全局捕获 Flutter framework 级别的渲染错误（防止 release 模式下白屏无提示）
  FlutterError.onError = (FlutterErrorDetails details) {
    if (kDebugMode) debugPrint('[FlutterError] ⚠️ ${details.exception}');
    if (kDebugMode) debugPrint('[FlutterError] 堆栈: ${details.stack}');
  };

  runApp(const ZaiNeApp());
}

/// 【修复 v1.77.0】迁移敏感信息从 SP 到 Keychain
Future<void> _migrateSensitiveDataToKeychain() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    const secureStorage = FlutterSecureStorage();

    // 1. 迁移 auth_token
    final spToken = prefs.getString('auth_token') ?? prefs.getString('auth_token_sp');
    if (spToken != null && spToken.isNotEmpty) {
      final keychainToken = await secureStorage.read(key: 'auth_token');
      if (keychainToken == null || keychainToken.isEmpty) {
        // Keychain 中没有 token，从 SP 迁移
        await secureStorage.write(key: 'auth_token', value: spToken);
        if (kDebugMode) debugPrint('[Main] ✅ 迁移 auth_token 到 Keychain');
      }
      // 迁移后删除 SP 中的备份（不安全）
      await prefs.remove('auth_token');
      await prefs.remove('auth_token_sp');
    }

    // 2. 迁移 user_id
    final spUserId = prefs.getString('user_id');
    if (spUserId != null && spUserId.isNotEmpty) {
      final keychainUserId = await secureStorage.read(key: 'user_id');
      if (keychainUserId == null || keychainUserId.isEmpty) {
        await secureStorage.write(key: 'user_id', value: spUserId);
        if (kDebugMode) debugPrint('[Main] ✅ 迁移 user_id 到 Keychain');
      }
      // 注意：暂时保留 SP 中的 user_id（为了兼容性，后续版本将移除）
    }

    // 3. 迁移 user_phone
    final spPhone = prefs.getString('user_phone');
    if (spPhone != null && spPhone.isNotEmpty) {
      final keychainPhone = await secureStorage.read(key: 'user_phone');
      if (keychainPhone == null || keychainPhone.isEmpty) {
        await secureStorage.write(key: 'user_phone', value: spPhone);
        if (kDebugMode) debugPrint('[Main] ✅ 迁移 user_phone 到 Keychain');
      }
      // 注意：暂时保留 SP 中的 user_phone（为了兼容性，后续版本将移除）
    }

    if (kDebugMode) debugPrint('[Main] ✅ 敏感信息迁移完成');
  } catch (e) {
    if (kDebugMode) debugPrint('[Main] ⚠️ 敏感信息迁移失败: $e');
  }
}

class ZaiNeApp extends StatefulWidget {
  const ZaiNeApp({super.key});

  @override
  State<ZaiNeApp> createState() => _ZaiNeAppState();
}

class _ZaiNeAppState extends State<ZaiNeApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    themeNotifier.addListener(_onThemeChanged);
    // 🔴【v1.97.3 (162) 修复 Bug 5】监听 App 前后台切换：回到前台时刷新 Watch 配对状态，
    // 让冷启动阶段 _isPaired 尚未就绪时，下次健康数据推送能拿到正确的配对状态。
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    themeNotifier.removeListener(_onThemeChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // 回到前台：刷新 Watch 连接状态（配对/可达），供后续推送使用
      unawaited(WatchDataService().refreshWatchState());
    }
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  ThemeData _buildTheme(ZaiNeThemeMode mode) {
    final isDark = mode == ZaiNeThemeMode.dark;
    final isSoft = mode == ZaiNeThemeMode.soft;
    
    // 基础颜色配置
    final bgColor = isDark ? const Color(0xFF121212) : (isSoft ? const Color(0xFFF2EDE8) : const Color(0xFFFFF8F0));
    final cardColor = isDark ? const Color(0xFF1E1E1E) : (isSoft ? const Color(0xFFE5DFD8) : Colors.white);
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor = isDark ? Colors.white70 : Colors.black54;

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: ZaiNeColors.brandOrange,
        brightness: isDark ? Brightness.dark : Brightness.light,
      ),
      scaffoldBackgroundColor: bgColor,
      cardColor: cardColor,

      // ===== 统一文字主题 =====
      textTheme: TextTheme(
        displayLarge:  TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: textColor),
        displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textColor),
        displaySmall:  TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor),
        headlineLarge: TextStyle(fontSize: ZaiNeFontSize.title, fontWeight: FontWeight.bold, color: textColor),  // 20
        headlineMedium: TextStyle(fontSize: ZaiNeFontSize.subtitle, fontWeight: FontWeight.w600, color: textColor),  // 17
        headlineSmall:  TextStyle(fontSize: ZaiNeFontSize.body, fontWeight: FontWeight.w600, color: textColor),  // 15
        titleLarge:     TextStyle(fontSize: ZaiNeFontSize.body, fontWeight: FontWeight.w600, color: textColor),  // 15
        titleMedium:    TextStyle(fontSize: ZaiNeFontSize.bodySm, fontWeight: FontWeight.w500, color: textColor),  // 14
        titleSmall:     TextStyle(fontSize: ZaiNeFontSize.caption, fontWeight: FontWeight.w500, color: subtextColor),  // 13
        bodyLarge:     TextStyle(fontSize: ZaiNeFontSize.body, color: textColor),  // 15
        bodyMedium:    TextStyle(fontSize: ZaiNeFontSize.bodySm, color: textColor),  // 14
        bodySmall:     TextStyle(fontSize: ZaiNeFontSize.caption, color: subtextColor),  // 13
        labelLarge:     TextStyle(fontSize: ZaiNeFontSize.bodySm, fontWeight: FontWeight.w500, color: textColor),  // 14
        labelMedium:   TextStyle(fontSize: ZaiNeFontSize.caption, color: subtextColor),  // 13
        labelSmall:    TextStyle(fontSize: ZaiNeFontSize.micro, color: subtextColor),  // 12
      ),

      // ===== 统一 AppBar 主题 =====
      appBarTheme: AppBarTheme(
        backgroundColor: bgColor,
        foregroundColor: textColor,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(fontSize: ZaiNeFontSize.subtitle, fontWeight: FontWeight.w600, color: textColor),  // 17
      ),

      // ===== 统一按钮主题 =====
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ZaiNeColors.brandOrange,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZaiNeRadius.button)),  // 8
          textStyle: const TextStyle(fontSize: ZaiNeFontSize.bodySm, fontWeight: FontWeight.w600),  // 14
          padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.lg, vertical: ZaiNeSpacing.sm),  // 16, 8
        ),
      ),

      // ===== 统一卡片主题 =====
      cardTheme: CardThemeData(
        color: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZaiNeRadius.card)),  // 16
        elevation: 0,
        margin: const EdgeInsets.all(ZaiNeSpacing.sm),  // 8
      ),

      // ===== 统一对话框主题 =====
      dialogTheme: DialogThemeData(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZaiNeRadius.card)),  // 16
        titleTextStyle: TextStyle(fontSize: ZaiNeFontSize.subtitle, fontWeight: FontWeight.w600, color: textColor),  // 17
        contentTextStyle: TextStyle(fontSize: ZaiNeFontSize.bodySm, color: subtextColor),  // 14
      ),

      // ===== 统一输入框主题 =====
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(ZaiNeRadius.small)),  // 12
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ZaiNeRadius.small),
          borderSide: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ZaiNeRadius.small),
          borderSide: const BorderSide(color: ZaiNeColors.brandOrange),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.lg, vertical: ZaiNeSpacing.sm),  // 16, 8
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '在呢',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(themeNotifier.mode),
      home: const SplashScreen(),
    );
  }
}

/// 启动页 - 酷炫动画
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoFadeAnimation;
  late Animation<double> _appnameSlideAnimation;
  late Animation<double> _appnameFadeAnimation;
  late Animation<double> _sloganFadeAnimation;
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();

    // 主时间线 5 秒（延长 slogan 展示时间）
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    );

    // Logo 爆闪缩放（0-0.35s，大弹性）
    _logoScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.35, curve: Curves.elasticOut),
      ),
    );

    // Logo 淡入（0-0.25s）
    _logoFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.25, curve: Curves.easeOut),
      ),
    );

    // APP名称从下滑入（0.25-0.5s）
    _appnameSlideAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.25, 0.5, curve: Curves.easeOutCubic),
      ),
    );

    // APP名称淡入
    _appnameFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.25, 0.5, curve: Curves.easeOut),
      ),
    );

    // Slogan 淡入（0.4-0.7s，在5秒时间线中约2s出现，停留更久）
    _sloganFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.4, 0.7, curve: Curves.easeIn),
      ),
    );

    // 光环脉冲（无限循环）
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _glowController.repeat(reverse: true);

    _mainController.forward();

    // 加载会员信息（不阻塞启动动画）
    MembershipService.loadFromLocal();

    // 5秒后跳转
    Future.delayed(const Duration(milliseconds: 5000), () async {
      if (!mounted) return;

      // ====== 【新增 v1.9.x】静默登录检查 ======
      // 检查是否有待处理的下载链接登录
      final pendingLogin = await SilentLoginService.hasPendingLogin();
      if (pendingLogin) {
        if (kDebugMode) debugPrint('[Splash] 发现待处理登录凭证，执行静默登录...');
        final success = await SilentLoginService.performSilentLogin();
        if (success) {
          // 静默登录成功，先核销 pending card_code（裂变注册奖励）
          final prefs = await SharedPreferences.getInstance();
          final phone = prefs.getString('user_phone');
          if (phone != null && phone.isNotEmpty) {
            await DeepLinkService.processPendingCardCode(phone);
          }
          // 进入首页
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const MainNavigation()),
            );
          }
          return;
        }
      }

      // ====== 原有逻辑 ======
      // 检查是否已完成引导
      final prefs = await SharedPreferences.getInstance();
      final onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;
      // 【修复 v1.77.0】从 Keychain 读取 token（安全，不再从 SP 读取明文 token）
      const secureStorage = FlutterSecureStorage();
      final authToken = await secureStorage.read(key: 'auth_token');
      final isLoggedIn = prefs.getBool('is_logged_in') ?? false;

      // 【修复 v1.9.6】数据一致性检查：引导已完成但无有效token → 视为未登录，回到引导页
      if (onboardingCompleted && (authToken == null || authToken.isEmpty) && !isLoggedIn) {
        if (kDebugMode) debugPrint('[Splash] ⚠️ 引导已完成但无token，清除状态回到引导页');
        await prefs.remove('onboarding_completed');
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const OnboardingPage()),
          );
        }
        return;
      }

      if (onboardingCompleted) {
        // token 已在上面从 Keychain 读取
        // 检查是否已完成引导
        if (authToken != null && authToken.isNotEmpty && isLoggedIn) {
          // 【修复 v1.19.3】已登录用户：先处理待定守护卡（Universal Link 冷启动场景）
          final prefs = await SharedPreferences.getInstance();
          final pendingCode = prefs.getString('pending_card_code') ?? prefs.getString('pending-card-code');
          if (pendingCode != null && pendingCode.isNotEmpty) {
            final phone = await AuthService.getUserPhone();
            if (phone != null && phone.isNotEmpty) {
              if (kDebugMode) debugPrint('[Splash] 已登录用户，处理待定守护卡: $pendingCode');
              await DeepLinkService.processPendingCardCode(phone);
            }
          }

          // 已登录 → 直接到主界面
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const MainNavigation()),
            );
          }
        } else {
          // 未登录 → 回到引导页（触发登录流程）
          if (kDebugMode) debugPrint('[Splash] ⚠️ 引导已完成但无token，回到引导页');
          await prefs.remove('onboarding_completed');
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const OnboardingPage()),
            );
          }
        }
      } else {
        // 首次启动 → 显示引导页
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const OnboardingPage()),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _mainController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1565C0),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0D47A1), // 更深蓝
              Color(0xFF1565C0), // 深蓝
              Color(0xFF0288D1), // 中蓝
              Color(0xFF26C6DA), // 青绿
            ],
          ),
        ),
        child: Column(
          children: [
            const Spacer(flex: 3),

            // ====== Logo：爆闪 + 光环脉冲 ======
            FadeTransition(
              opacity: _logoFadeAnimation,
              child: ScaleTransition(
                scale: _logoScaleAnimation,
                child: AnimatedBuilder(
                  animation: _glowController,
                  builder: (context, child) {
                    final glowValue = _glowController.value;
                    return Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.1 + glowValue * 0.08),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white
                                .withValues(alpha: 0.15 + glowValue * 0.15),
                            blurRadius: 30 + glowValue * 20,
                            spreadRadius: 5 + glowValue * 10,
                          ),
                          BoxShadow(
                            color: const Color(0xFF26C6DA)
                                .withValues(alpha: 0.1 + glowValue * 0.1),
                            blurRadius: 50 + glowValue * 15,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/zaine_logo_home.png',
                          width: 130,
                          height: 130,
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 32),

            // ====== APP名称：从下滑入 + 淡入 ======
            FadeTransition(
              opacity: _appnameFadeAnimation,
              child: AnimatedBuilder(
                animation: _appnameSlideAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _appnameSlideAnimation.value),
                    child: child,
                  );
                },
                child: const Text(
                  '在呢',
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 10,
                    shadows: [
                      Shadow(
                        color: Color(0x44000000),
                        blurRadius: 12,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // ====== Slogan：延迟淡入 ======
            FadeTransition(
              opacity: _sloganFadeAnimation,
              child: const Text(
                '让在乎你的人，时刻知道你在',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xCCFFFFFF),
                  letterSpacing: 1.5,
                ),
              ),
            ),

            const Spacer(flex: 2),

            // 底部加载指示器（最后出现）
            FadeTransition(
              opacity: _sloganFadeAnimation,
              child: const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Color(0x99FFFFFF),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}

/// 底部导航页
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  // 按需创建页面，根据 Feature Flag 控制显隐
  late final List<Widget> _pages = [
    const HomePage(),
    const GuardianPage(),
    const HelpPage(),
    const ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    // 【v1.93.0 修复】Watch SOS → 自动切换到求助 Tab
    HealthService.watchSOSSignal.addListener(_onWatchSOS);
  }

  @override
  void dispose() {
    HealthService.watchSOSSignal.removeListener(_onWatchSOS);
    super.dispose();
  }

  /// 【v1.93.0 修复】收到 Watch SOS 信号时切换到求助页面
  void _onWatchSOS() {
    if (mounted) {
      if (kDebugMode) debugPrint('[MainNavigation] 🚨 Watch SOS → 自动切换到求助页面');
      setState(() => _currentIndex = 2); // 切换到求助 Tab
    }
  }

  @override
  Widget build(BuildContext context) {
    // 根据主题模式获取 Tab 栏背景色
    Color navBgColor;
    switch (themeNotifier.mode) {
      case ZaiNeThemeMode.dark:
        navBgColor = const Color(0xFF1E1E1E);
        break;
      case ZaiNeThemeMode.soft:
        navBgColor = const Color(0xFFF2EDE8);
        break;
      default: // light
        navBgColor = Colors.white;
    }

    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: navBgColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: NavigationBar(
          backgroundColor: navBgColor,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          height: 64,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() => _currentIndex = index);
            if (kDebugMode) debugPrint('[MainNavigation] 切换到底部导航: index=$index');
            // 切换到求助时给一个触觉反馈
            if (index == 2) { // 求助(SOS) tab
              HapticFeedback.mediumImpact();
            }
          },
          animationDuration: const Duration(milliseconds: 400),
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.home_outlined, size: 22),
              selectedIcon: Icon(Icons.home, size: 24),
              label: '首页',
            ),
            NavigationDestination(
              icon: _buildGuardianIcon(isSelected: false),
              selectedIcon: _buildGuardianIcon(isSelected: true),
              label: '守护圈',
            ),
            NavigationDestination(
              icon: _buildHelpIcon(isSelected: false),
              selectedIcon: _buildHelpIcon(isSelected: true),
              label: '求助',
            ),
            const NavigationDestination(
              icon: Icon(Icons.person_outline_rounded, size: 22),
              selectedIcon: Icon(Icons.person_rounded, size: 24),
              label: '我的',
            ),
          ],
        ),
      ),
    );
  }

  /// 求助 Tab 图标 — 医疗急救箱风格（红色圆底 + 白色十字）
  Widget _buildHelpIcon({required bool isSelected}) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isSelected
              ? [const Color(0xFFFF5252), const Color(0xFFD32F2F)]
              : [Colors.red.shade300, Colors.red.shade400],
        ),
        shape: BoxShape.circle,
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: Colors.red.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: const Icon(
        Icons.medical_services,
        color: Colors.white,
        size: 18,
      ),
    );
  }

  /// 守护圈 Tab 图标 — 绿色圆底 + 白色盾牌（守护+安全感）
  Widget _buildGuardianIcon({required bool isSelected}) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isSelected
              ? [const Color(0xFF4CAF50), const Color(0xFF2E7D32)]
              : [Colors.green.shade300, Colors.green.shade400],
        ),
        shape: BoxShape.circle,
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: Colors.green.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: const Icon(
        Icons.shield,
        color: Colors.white,
        size: 18,
      ),
    );
  }
}
