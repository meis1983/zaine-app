import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pages/home_page.dart';
import 'pages/guardian_page.dart';
import 'pages/help_page.dart';
import 'pages/profile_page.dart';
import 'pages/onboarding_page.dart';
import 'pages/statistics_page.dart';
import 'pages/safety_settings_page.dart';
import 'services/deep_link_service.dart';
import 'services/silent_login_service.dart';
import 'services/membership_service.dart';
import 'data/app_constants.dart';

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

  // 初始化 Deep Link 监听（守护卡裂变落地页）
  await DeepLinkService.init();

  // 全局捕获 Flutter framework 级别的渲染错误（防止 release 模式下白屏无提示）
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('[FlutterError] ⚠️ ${details.exception}');
    debugPrint('[FlutterError] 堆栈: ${details.stack}');
  };

  runApp(const ZaiNeApp());
}

class ZaiNeApp extends StatefulWidget {
  const ZaiNeApp({super.key});

  @override
  State<ZaiNeApp> createState() => _ZaiNeAppState();
}

class _ZaiNeAppState extends State<ZaiNeApp> {
  @override
  void initState() {
    super.initState();
    themeNotifier.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    themeNotifier.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  ThemeData _buildTheme(ZaiNeThemeMode mode) {
    switch (mode) {
      case ZaiNeThemeMode.dark:
        return ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFFF7F50),
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: const Color(0xFF121212),
          cardColor: const Color(0xFF1E1E1E),
          useMaterial3: true,
        );
      case ZaiNeThemeMode.soft:
        return ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFFF7F50),
            brightness: Brightness.light,
          ),
          scaffoldBackgroundColor: const Color(0xFFF2EDE8),
          cardColor: const Color(0xFFE5DFD8),
          useMaterial3: true,
        );
      case ZaiNeThemeMode.light:
        return ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFFF7F50),
            brightness: Brightness.light,
          ),
          scaffoldBackgroundColor: const Color(0xFFFFF8F0),
          cardColor: Colors.white,
          useMaterial3: true,
        );
    }
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
        debugPrint('[Splash] 发现待处理登录凭证，执行静默登录...');
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
      final authToken = prefs.getString('auth_token');
      final isLoggedIn = prefs.getBool('is_logged_in') ?? false;

      // 【修复 v1.9.6】数据一致性检查：引导已完成但无有效token → 视为未登录，回到引导页
      // 根因：用户退出登录后 onboarding_completed=true 但 auth_token 被清除，
      //       导致下次启动直接进入首页，处于"看得见首页但没登录"的异常状态
      if (onboardingCompleted && (authToken == null || authToken.isEmpty) && !isLoggedIn) {
        debugPrint('[Splash] ⚠️ 引导已完成但无token，清除状态回到引导页');
        await prefs.remove('onboarding_completed');
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const OnboardingPage()),
          );
        }
        return;
      }

      if (onboardingCompleted) {
        // 已完成引导 → 直接到主界面
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MainNavigation()),
          );
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
                        color: Colors.white.withOpacity(0.1 + glowValue * 0.08),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white
                                .withOpacity(0.15 + glowValue * 0.15),
                            blurRadius: 30 + glowValue * 20,
                            spreadRadius: 5 + glowValue * 10,
                          ),
                          BoxShadow(
                            color: const Color(0xFF26C6DA)
                                .withOpacity(0.1 + glowValue * 0.1),
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

  // 按需创建页面，避免 const 导致状态丢失和黑屏
  late final List<Widget> _pages = [
    HomePage(),
    GuardianPage(),
    const StatisticsPage(),
    const SafetySettingsPage(),
    const HelpPage(),
    ProfilePage(),
  ];

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
              color: Colors.black.withOpacity(0.06),
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
            debugPrint('[MainNavigation] 切换到底部导航: index=$index');
            // 切换到求助时给一个触觉反馈
            if (index == 3) { // 求助 tab
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
            const NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined, size: 22),
              selectedIcon: Icon(Icons.bar_chart, size: 24),
              label: '统计',
            ),
            const NavigationDestination(
              icon: Icon(Icons.security_outlined, size: 22),
              selectedIcon: Icon(Icons.security, size: 24),
              label: '安全',
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
                  color: Colors.red.withOpacity(0.35),
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
                  color: Colors.green.withOpacity(0.35),
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
