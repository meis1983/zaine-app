// integration_test/screenshot_test.dart
//
// 在呢+ / Zaine 自动化截图脚本（iOS 模拟器）。
// 按 --dart-define=SHOT_LOCALE=en|zh-CN|zh-TW 强制语言，捕获 4 张核心界面截图
// （首页/守护圈/健康/我的）。SOS 页因模拟器无法稳定获取位置，由真机截图单独提供。
//
// ✅ 已支持「自动登录」：登录页有 ValueKey('quick_login')，手机号直接登录（quickLogin，无验证码），
//    脚本会自动填测试号并点登录，无需手动操作模拟器（模拟器窗口也无需可见）。
//
// 运行（需先 boot 模拟器）：
//   flutter test integration_test/screenshot_test.dart --dart-define=SHOT_LOCALE=en
//   flutter test integration_test/screenshot_test.dart --dart-define=SHOT_LOCALE=zh-CN
//   flutter test integration_test/screenshot_test.dart --dart-define=SHOT_LOCALE=zh-TW
//
// 截图默认输出到 build/integration_test/screenshots/。
// 跑完用 find . -name '0*.png' 定位，再按语言归类到 screenshots/<语言>/。

import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zaine/main.dart' as app;

/// 截图用的演示账号（手机号直接登录，无验证码）。
/// ⚠️ 严禁使用真实手机号！App Store 截图是公开的，真实号会泄露你与守护人的真实信息。
/// 默认是一个明显虚构的演示号；可用 --dart-define=SHOT_PHONE=13800001234 覆盖。
/// 演示号需在模拟器里先 quickLogin 建号、并手动添加 2-3 个假守护人，截图内容才饱满。
const String _testPhone =
    String.fromEnvironment('SHOT_PHONE', defaultValue: '13800001234');

/// 点击底部导航第 index 个目标（语言无关，按 NavigationDestination 顺序）。
/// 0=首页 1=守护圈 2=求助(SOS) 3=我的
Future<void> _tapNav(WidgetTester tester, int index) async {
  final nav = find.byType(NavigationDestination);
  if (nav.evaluate().length <= index) {
    debugPrint('[Shot] 导航目标 index=$index 不存在，跳过');
    return;
  }
  await tester.tap(nav.at(index), warnIfMissed: false);
  await tester.pumpAndSettle().catchError((_) {});
  await Future.delayed(const Duration(milliseconds: 600));
}

/// 点击页面内图标（体征卡、联系人等），找不到则跳过。
Future<void> _tapIcon(
  WidgetTester tester,
  IconData icon, {
  Duration settle = const Duration(milliseconds: 700),
}) async {
  final finder = find.byIcon(icon);
  if (finder.evaluate().isEmpty) {
    debugPrint('[Shot] 未找到图标 $icon，跳过该步');
    return;
  }
  await tester.tap(finder.first, warnIfMissed: false);
  await tester.pumpAndSettle().catchError((_) {});
  await Future.delayed(settle);
}

/// 截一张图（先 pump 稳定，留 300ms 帧缓冲）。
Future<void> _shot(
  WidgetTester tester,
  IntegrationTestWidgetsFlutterBinding binding,
  String name,
) async {
  await tester.pumpAndSettle().catchError((_) {});
  await Future.delayed(const Duration(milliseconds: 300));
  await binding.takeScreenshot(name);
  await Future.delayed(const Duration(milliseconds: 300));
}

/// 若 SOS 页位置获取失败（出现重试文字），自动点击重试。
/// 位置源已用移动路线激活，首次请求超时后第二次通常能拿到。
/// 重试后重新截取 03_sos（覆盖旧图）。
Future<void> _retryLocationIfFailed(
  WidgetTester tester,
  IntegrationTestWidgetsFlutterBinding binding,
) async {
  // App 的重试按钮是文字（"Tap to refresh and retry" / "点击重试"），不是 tooltip
  final retry = find.textContaining(
    RegExp(r'retry|重试|refresh', caseSensitive: false),
    findRichText: true,
  );
  if (retry.evaluate().isEmpty) {
    debugPrint('[Shot] 未检测到重试按钮，位置应已正常');
    return;
  }
  debugPrint('[Shot] 检测到位置失败，自动点击重试…');
  await tester.tap(retry.first, warnIfMissed: false);
  await tester.pumpAndSettle().catchError((_) {});
  // 给 App 内 getCurrentPosition 的 8s timeLimit 充足时间
  await Future.delayed(const Duration(seconds: 11));
  await tester.pumpAndSettle().catchError((_) {});
  await _shot(tester, binding, '03_sos'); // 覆盖旧图
  debugPrint('[Shot] 已重试位置并重新截取 03_sos');
}

/// 自动登录：填手机号 → 点 quick_login → 等主界面（NavigationBar）出现。
/// 返回 true 表示已进入主界面。
Future<bool> _autoLogin(WidgetTester tester, String phone) async {
  final loginBtn = find.byKey(const ValueKey('quick_login'));
  if (loginBtn.evaluate().isEmpty) {
    debugPrint('[Shot] 未找到 quick_login 按钮，可能已登录或不在登录页');
    return find.byType(NavigationBar).evaluate().isNotEmpty;
  }

  for (var attempt = 0; attempt < 2; attempt++) {
    // 手机号输入框（InternationalPhoneNumberInput 内部 EditableText）
    final field = find.byType(EditableText);
    if (field.evaluate().isNotEmpty) {
      await tester.tap(field.first, warnIfMissed: false);
      await tester.pumpAndSettle().catchError((_) {});
      await tester.enterText(field.first, phone);
      await tester.pumpAndSettle().catchError((_) {});
      await Future.delayed(const Duration(milliseconds: 300));
      debugPrint('[Shot] 已填入手机号 $phone');
    } else {
      debugPrint('[Shot] 未找到手机号输入框');
    }

    await tester.tap(loginBtn.first, warnIfMissed: false);
    debugPrint('[Shot] 已点击登录，等待主界面…');

    // 等待登录 + 数据拉取(pullFromServer) + 仪式感动画
    for (var i = 0; i < 80; i++) {
      await tester.pumpAndSettle().catchError((_) {});
      if (find.byType(NavigationBar).evaluate().isNotEmpty) {
        debugPrint('[Shot] ✅ 已登录，进入主界面');
        return true;
      }
      await Future.delayed(const Duration(milliseconds: 500));
    }

    // 若仍停在登录页，重试一次（可能首次点击时按钮尚未启用）
    if (find.byKey(const ValueKey('quick_login')).evaluate().isEmpty) break;
    debugPrint('[Shot] 首次登录未生效，重试…');
  }
  return find.byType(NavigationBar).evaluate().isNotEmpty;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture_zaine_screenshots', (tester) async {
    // 1. 强制语言（覆盖设备系统语言）
    final prefs = await SharedPreferences.getInstance();
    const locale = String.fromEnvironment('SHOT_LOCALE', defaultValue: 'en');
    await prefs.setString('app_language', locale);

    // 2. 启动 App（Splash 约 5s 后跳登录页 / 主界面）
    app.main();
    await Future.delayed(const Duration(seconds: 6));
    await tester.pumpAndSettle().catchError((_) {});
    await Future.delayed(const Duration(seconds: 1));
    await tester.pumpAndSettle().catchError((_) {});

    final binding = IntegrationTestWidgetsFlutterBinding.instance;

    // 3. 自动登录（若停在登录页）
    final loggedIn = await _autoLogin(tester, _testPhone);

    if (!loggedIn) {
      await binding.takeScreenshot('00_need_login');
      debugPrint('[Shot] ⚠️ 未能进入主界面（自动登录失败或网络不可达）。'
          '已截 00_need_login.png 供核对。请检查模拟器网络 / 测试号。');
      return;
    }

    // 4. 首页（确保在 tab 0）
    await _tapNav(tester, 0);
    await _shot(tester, binding, '01_home');

    // 5. 守护圈（tab 1）
    await _tapNav(tester, 1);
    await _shot(tester, binding, '02_guardian');

    // 6. 求助 / SOS（tab 2）—— 模拟器无法稳定获取位置，SOS 页改用真机截图，
    //    由用户手动提供（桌面 微信图片...png），脚本不再捕获此页。
    //    （如需恢复脚本截图：删掉下面这行注释并接回 _tapNav(tester,2) 那段。）

    // 7. 体征概览：回守护圈 → 点体征卡（health_and_safety_outlined）→ 截图 → 返回
    await _tapNav(tester, 1);
    await _tapIcon(tester, Icons.health_and_safety_outlined);
    await _shot(tester, binding, '04_health');
    await tester.pageBack().catchError((_) {});
    await tester.pumpAndSettle().catchError((_) {});
    await Future.delayed(const Duration(milliseconds: 500));

    // 8. 我的（tab 3）
    await _tapNav(tester, 3);
    await _shot(tester, binding, '05_profile');

    // 9. 联系人页（06_contacts）按要求不纳入本套截图，故跳过。

    debugPrint('[Shot] ✅ 完成 locale=$locale（产出 01_home/02_guardian/04_health/05_profile 共 4 张，SOS 由真机提供）');
  });
}
