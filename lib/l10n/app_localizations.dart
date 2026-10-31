import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of S
/// returned by `S.of(context)`.
///
/// Applications need to include `S.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: S.localizationsDelegates,
///   supportedLocales: S.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the S.supportedLocales
/// property.
abstract class S {
  S(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static S? of(BuildContext context) {
    return Localizations.of<S>(context, S);
  }

  static const LocalizationsDelegate<S> delegate = _SDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
    Locale('zh', 'CN'),
    Locale('zh', 'HK'),
    Locale('zh', 'TW')
  ];

  /// App 名称
  ///
  /// In zh_CN, this message translates to:
  /// **'在呢+'**
  String get appTitle;

  /// 签到按钮：今日已签到状态文案
  ///
  /// In zh_CN, this message translates to:
  /// **'今日已签到'**
  String get signInButtonCheckedIn;

  /// 签到按钮：未签到时的引导文案
  ///
  /// In zh_CN, this message translates to:
  /// **'点击签到'**
  String get signInButtonTapToCheckIn;

  /// 签到按钮：连续签到天数
  ///
  /// In zh_CN, this message translates to:
  /// **'连续 {count} 天'**
  String continuousDays(int count);

  /// No description provided for @s003.
  ///
  /// In zh_CN, this message translates to:
  /// **'请到系统设置中允许通知权限，以便接收签到提醒'**
  String get s003;

  /// No description provided for @s004.
  ///
  /// In zh_CN, this message translates to:
  /// **'断签预警'**
  String get s004;

  /// No description provided for @s005.
  ///
  /// In zh_CN, this message translates to:
  /// **'连续未签到时的递进提醒'**
  String get s005;

  /// No description provided for @s006.
  ///
  /// In zh_CN, this message translates to:
  /// **'今天还没签到哦'**
  String get s006;

  /// No description provided for @s007.
  ///
  /// In zh_CN, this message translates to:
  /// **'花3秒钟打开「在呢」签到，让守护者知道你在 💙'**
  String get s007;

  /// No description provided for @s008.
  ///
  /// In zh_CN, this message translates to:
  /// **'连续2天没签到了'**
  String get s008;

  /// No description provided for @s009.
  ///
  /// In zh_CN, this message translates to:
  /// **'你的守护者可能有点担心你，报个平安吧 🏠'**
  String get s009;

  /// No description provided for @s011.
  ///
  /// In zh_CN, this message translates to:
  /// **'今天花3秒打开「在呢」签到，给自己一个安心 ❤️'**
  String get s011;

  /// No description provided for @s012.
  ///
  /// In zh_CN, this message translates to:
  /// **'系统提醒已开启，当天未签到时将发送额外提醒'**
  String get s012;

  /// No description provided for @s013.
  ///
  /// In zh_CN, this message translates to:
  /// **'未知'**
  String get s013;

  /// No description provided for @s014.
  ///
  /// In zh_CN, this message translates to:
  /// **'退出登录'**
  String get s014;

  /// No description provided for @s015.
  ///
  /// In zh_CN, this message translates to:
  /// **'退出后将清除本地数据并回到登录页，下次使用需要重新输入手机号登录。\n\n是否确认退出？'**
  String get s015;

  /// No description provided for @s016.
  ///
  /// In zh_CN, this message translates to:
  /// **'取消'**
  String get s016;

  /// No description provided for @s017.
  ///
  /// In zh_CN, this message translates to:
  /// **'退出'**
  String get s017;

  /// No description provided for @s018.
  ///
  /// In zh_CN, this message translates to:
  /// **'已退出登录'**
  String get s018;

  /// No description provided for @s019.
  ///
  /// In zh_CN, this message translates to:
  /// **'选择主题'**
  String get s019;

  /// No description provided for @s020.
  ///
  /// In zh_CN, this message translates to:
  /// **'浅色模式'**
  String get s020;

  /// No description provided for @s021.
  ///
  /// In zh_CN, this message translates to:
  /// **'清爽明亮，温柔暖白'**
  String get s021;

  /// No description provided for @s022.
  ///
  /// In zh_CN, this message translates to:
  /// **'深色模式'**
  String get s022;

  /// No description provided for @s023.
  ///
  /// In zh_CN, this message translates to:
  /// **'护眼夜用，深邃静谧'**
  String get s023;

  /// No description provided for @s024.
  ///
  /// In zh_CN, this message translates to:
  /// **'柔光模式'**
  String get s024;

  /// No description provided for @s025.
  ///
  /// In zh_CN, this message translates to:
  /// **'温暖米白，舒适柔和'**
  String get s025;

  /// No description provided for @s026.
  ///
  /// In zh_CN, this message translates to:
  /// **'无法打开隐私政策页面'**
  String get s026;

  /// No description provided for @s027.
  ///
  /// In zh_CN, this message translates to:
  /// **'删除账号'**
  String get s027;

  /// No description provided for @s028.
  ///
  /// In zh_CN, this message translates to:
  /// **'此操作将永久删除您的账号及所有数据：'**
  String get s028;

  /// No description provided for @s029.
  ///
  /// In zh_CN, this message translates to:
  /// **'• 个人资料和健康档案'**
  String get s029;

  /// No description provided for @s030.
  ///
  /// In zh_CN, this message translates to:
  /// **'• 签到记录和守护关系'**
  String get s030;

  /// No description provided for @s031.
  ///
  /// In zh_CN, this message translates to:
  /// **'• 紧急联系人列表'**
  String get s031;

  /// No description provided for @s032.
  ///
  /// In zh_CN, this message translates to:
  /// **'• 会员订阅记录'**
  String get s032;

  /// No description provided for @s033.
  ///
  /// In zh_CN, this message translates to:
  /// **'此操作不可恢复！'**
  String get s033;

  /// No description provided for @s034.
  ///
  /// In zh_CN, this message translates to:
  /// **'确认删除'**
  String get s034;

  /// No description provided for @s035.
  ///
  /// In zh_CN, this message translates to:
  /// **'最终确认'**
  String get s035;

  /// No description provided for @s036.
  ///
  /// In zh_CN, this message translates to:
  /// **'请输入「删除」以确认删除账号：'**
  String get s036;

  /// No description provided for @s037.
  ///
  /// In zh_CN, this message translates to:
  /// **'输入\"删除\"'**
  String get s037;

  /// No description provided for @s038.
  ///
  /// In zh_CN, this message translates to:
  /// **'删除'**
  String get s038;

  /// No description provided for @s039.
  ///
  /// In zh_CN, this message translates to:
  /// **'彻底删除'**
  String get s039;

  /// No description provided for @s040.
  ///
  /// In zh_CN, this message translates to:
  /// **'账号已删除'**
  String get s040;

  /// No description provided for @s041.
  ///
  /// In zh_CN, this message translates to:
  /// **'您的账号及所有数据已彻底删除。App 将退出，请重新打开。'**
  String get s041;

  /// No description provided for @s042.
  ///
  /// In zh_CN, this message translates to:
  /// **'确定'**
  String get s042;

  /// No description provided for @s043.
  ///
  /// In zh_CN, this message translates to:
  /// **'删除失败'**
  String get s043;

  /// No description provided for @s045.
  ///
  /// In zh_CN, this message translates to:
  /// **'守护每一次签到，守护每一份牵挂。'**
  String get s045;

  /// No description provided for @s046.
  ///
  /// In zh_CN, this message translates to:
  /// **'\"在呢\"是一款专为城市独居青年打造的守护应用。每天签到报平安，紧急时刻一键呼救，让在乎你的人安心。'**
  String get s046;

  /// No description provided for @s047.
  ///
  /// In zh_CN, this message translates to:
  /// **'检查更新'**
  String get s047;

  /// No description provided for @s048.
  ///
  /// In zh_CN, this message translates to:
  /// **'关闭'**
  String get s048;

  /// No description provided for @s050.
  ///
  /// In zh_CN, this message translates to:
  /// **'已经是最新版本！'**
  String get s050;

  /// No description provided for @s051.
  ///
  /// In zh_CN, this message translates to:
  /// **'感谢你使用「在呢」❤️'**
  String get s051;

  /// No description provided for @s052.
  ///
  /// In zh_CN, this message translates to:
  /// **'好的'**
  String get s052;

  /// No description provided for @s053.
  ///
  /// In zh_CN, this message translates to:
  /// **'深色'**
  String get s053;

  /// No description provided for @s054.
  ///
  /// In zh_CN, this message translates to:
  /// **'柔光'**
  String get s054;

  /// No description provided for @s055.
  ///
  /// In zh_CN, this message translates to:
  /// **'浅色'**
  String get s055;

  /// No description provided for @s056.
  ///
  /// In zh_CN, this message translates to:
  /// **'设置'**
  String get s056;

  /// No description provided for @s057.
  ///
  /// In zh_CN, this message translates to:
  /// **'在呢用户'**
  String get s057;

  /// No description provided for @s058.
  ///
  /// In zh_CN, this message translates to:
  /// **'健康档案已完善'**
  String get s058;

  /// No description provided for @s059.
  ///
  /// In zh_CN, this message translates to:
  /// **'请完善您的健康档案'**
  String get s059;

  /// No description provided for @s060.
  ///
  /// In zh_CN, this message translates to:
  /// **'完善档案后解锁完整求助功能'**
  String get s060;

  /// No description provided for @s061.
  ///
  /// In zh_CN, this message translates to:
  /// **'去填写'**
  String get s061;

  /// No description provided for @s062.
  ///
  /// In zh_CN, this message translates to:
  /// **'外观'**
  String get s062;

  /// No description provided for @s063.
  ///
  /// In zh_CN, this message translates to:
  /// **'主题模式'**
  String get s063;

  /// No description provided for @s065.
  ///
  /// In zh_CN, this message translates to:
  /// **'签到提醒'**
  String get s065;

  /// No description provided for @s066.
  ///
  /// In zh_CN, this message translates to:
  /// **'每日提醒'**
  String get s066;

  /// No description provided for @s067.
  ///
  /// In zh_CN, this message translates to:
  /// **'提醒你进行每日签到'**
  String get s067;

  /// No description provided for @s068.
  ///
  /// In zh_CN, this message translates to:
  /// **'提醒时间'**
  String get s068;

  /// No description provided for @s069.
  ///
  /// In zh_CN, this message translates to:
  /// **'系统提醒'**
  String get s069;

  /// No description provided for @s070.
  ///
  /// In zh_CN, this message translates to:
  /// **'当天未签到时，系统将发送额外提醒'**
  String get s070;

  /// No description provided for @s071.
  ///
  /// In zh_CN, this message translates to:
  /// **'求助设置'**
  String get s071;

  /// No description provided for @s072.
  ///
  /// In zh_CN, this message translates to:
  /// **'紧急拨打{num}'**
  String s072(Object num);

  /// No description provided for @s073.
  ///
  /// In zh_CN, this message translates to:
  /// **'请前往求助页面使用此功能'**
  String get s073;

  /// No description provided for @s074.
  ///
  /// In zh_CN, this message translates to:
  /// **'会员'**
  String get s074;

  /// No description provided for @s075.
  ///
  /// In zh_CN, this message translates to:
  /// **'在呢智能版'**
  String get s075;

  /// No description provided for @s076.
  ///
  /// In zh_CN, this message translates to:
  /// **'解锁更多守护能力'**
  String get s076;

  /// No description provided for @s077.
  ///
  /// In zh_CN, this message translates to:
  /// **'已订阅'**
  String get s077;

  /// No description provided for @s078.
  ///
  /// In zh_CN, this message translates to:
  /// **'升级'**
  String get s078;

  /// No description provided for @s079.
  ///
  /// In zh_CN, this message translates to:
  /// **'账号'**
  String get s079;

  /// No description provided for @s080.
  ///
  /// In zh_CN, this message translates to:
  /// **'彻底删除所有数据，不可恢复'**
  String get s080;

  /// No description provided for @s081.
  ///
  /// In zh_CN, this message translates to:
  /// **'隐私与数据'**
  String get s081;

  /// No description provided for @s082.
  ///
  /// In zh_CN, this message translates to:
  /// **'隐私政策'**
  String get s082;

  /// No description provided for @s083.
  ///
  /// In zh_CN, this message translates to:
  /// **'数据安全'**
  String get s083;

  /// No description provided for @s084.
  ///
  /// In zh_CN, this message translates to:
  /// **'云端同步存储，换设备不丢失'**
  String get s084;

  /// No description provided for @s085.
  ///
  /// In zh_CN, this message translates to:
  /// **'数据安全保障'**
  String get s085;

  /// No description provided for @s086.
  ///
  /// In zh_CN, this message translates to:
  /// **'您的健康档案、紧急联系人和签到记录均已加密同步到云端服务器，换设备登录后数据自动恢复。\n\n我们承诺：\n• 采用行业标准的加密技术保护数据传输和存储\n• 不会将您的信息用于任何商业目的\n• 不会向第三方透露您的隐私\n• 您可以随时在健康档案页面或设置中删除所有数据'**
  String get s086;

  /// No description provided for @s087.
  ///
  /// In zh_CN, this message translates to:
  /// **'知道了'**
  String get s087;

  /// No description provided for @s088.
  ///
  /// In zh_CN, this message translates to:
  /// **'存储管理'**
  String get s088;

  /// No description provided for @s089.
  ///
  /// In zh_CN, this message translates to:
  /// **'清除缓存'**
  String get s089;

  /// No description provided for @s090.
  ///
  /// In zh_CN, this message translates to:
  /// **'清理临时文件和图片缓存'**
  String get s090;

  /// No description provided for @s091.
  ///
  /// In zh_CN, this message translates to:
  /// **'重置所有数据'**
  String get s091;

  /// No description provided for @s092.
  ///
  /// In zh_CN, this message translates to:
  /// **'清除所有本地数据（签到、档案、联系人）'**
  String get s092;

  /// No description provided for @s093.
  ///
  /// In zh_CN, this message translates to:
  /// **'关于'**
  String get s093;

  /// No description provided for @s094.
  ///
  /// In zh_CN, this message translates to:
  /// **'关于「在呢」'**
  String get s094;

  /// No description provided for @s095.
  ///
  /// In zh_CN, this message translates to:
  /// **'版本'**
  String get s095;

  /// No description provided for @s096.
  ///
  /// In zh_CN, this message translates to:
  /// **'开发者模式 ✅'**
  String get s096;

  /// No description provided for @s098.
  ///
  /// In zh_CN, this message translates to:
  /// **'让在乎你的人安心'**
  String get s098;

  /// No description provided for @s099.
  ///
  /// In zh_CN, this message translates to:
  /// **'将清除图片缓存和临时文件，不会影响您的签到数据和健康档案。'**
  String get s099;

  /// No description provided for @s100.
  ///
  /// In zh_CN, this message translates to:
  /// **'清除'**
  String get s100;

  /// No description provided for @s101.
  ///
  /// In zh_CN, this message translates to:
  /// **'缓存已清除 ✓'**
  String get s101;

  /// No description provided for @s102.
  ///
  /// In zh_CN, this message translates to:
  /// **'⚠️ 危险操作'**
  String get s102;

  /// No description provided for @s103.
  ///
  /// In zh_CN, this message translates to:
  /// **'此操作将永久删除以下所有数据：'**
  String get s103;

  /// No description provided for @s104.
  ///
  /// In zh_CN, this message translates to:
  /// **'• 签到记录和连续天数'**
  String get s104;

  /// No description provided for @s105.
  ///
  /// In zh_CN, this message translates to:
  /// **'• 健康档案信息'**
  String get s105;

  /// No description provided for @s106.
  ///
  /// In zh_CN, this message translates to:
  /// **'• 登录状态'**
  String get s106;

  /// No description provided for @s107.
  ///
  /// In zh_CN, this message translates to:
  /// **'• 主题偏好设置'**
  String get s107;

  /// No description provided for @s108.
  ///
  /// In zh_CN, this message translates to:
  /// **'注意：仅清除本机数据，云端账号与服务器数据不受影响。'**
  String get s108;

  /// No description provided for @s109.
  ///
  /// In zh_CN, this message translates to:
  /// **'如需彻底删除云端账号与所有数据，请使用下方「删除账号」。'**
  String get s109;

  /// No description provided for @s110.
  ///
  /// In zh_CN, this message translates to:
  /// **'确认重置'**
  String get s110;

  /// No description provided for @s111.
  ///
  /// In zh_CN, this message translates to:
  /// **'所有数据已重置 ✓ App 将重新启动...'**
  String get s111;

  /// No description provided for @s113.
  ///
  /// In zh_CN, this message translates to:
  /// **'🔒 最终确认'**
  String get s113;

  /// No description provided for @s114.
  ///
  /// In zh_CN, this message translates to:
  /// **'请输入「重置」以确认删除所有数据：'**
  String get s114;

  /// No description provided for @s115.
  ///
  /// In zh_CN, this message translates to:
  /// **'输入\"重置\"'**
  String get s115;

  /// No description provided for @s116.
  ///
  /// In zh_CN, this message translates to:
  /// **'重置'**
  String get s116;

  /// No description provided for @s125.
  ///
  /// In zh_CN, this message translates to:
  /// **'已设置每天 {p1} 提醒签到'**
  String s125(Object? p1);

  /// No description provided for @s126.
  ///
  /// In zh_CN, this message translates to:
  /// **'签到提醒已开启，每天 {p1}'**
  String s126(Object? p1);

  /// No description provided for @s127.
  ///
  /// In zh_CN, this message translates to:
  /// **'【提醒】连续{daysSinceLastCheckIn}天没签到了'**
  String s127(Object? daysSinceLastCheckIn);

  /// No description provided for @s128.
  ///
  /// In zh_CN, this message translates to:
  /// **'删除失败：{e}'**
  String s128(Object? e);

  /// No description provided for @s129.
  ///
  /// In zh_CN, this message translates to:
  /// **'当前版本 v{p1} (Build {p2})'**
  String s129(Object? p1, Object? p2);

  /// No description provided for @s130.
  ///
  /// In zh_CN, this message translates to:
  /// **'当前：{p1}'**
  String s130(Object? p1);

  /// No description provided for @s131.
  ///
  /// In zh_CN, this message translates to:
  /// **'再点 {p1} 次激活'**
  String s131(Object? p1);

  /// No description provided for @s132.
  ///
  /// In zh_CN, this message translates to:
  /// **'重置失败：{e}'**
  String s132(Object? e);

  /// No description provided for @s133.
  ///
  /// In zh_CN, this message translates to:
  /// **'💓 手表检测到你，已记录签到'**
  String get s133;

  /// No description provided for @s134.
  ///
  /// In zh_CN, this message translates to:
  /// **'⌚ Apple Watch 签到成功'**
  String get s134;

  /// No description provided for @s135.
  ///
  /// In zh_CN, this message translates to:
  /// **'签到成功'**
  String get s135;

  /// No description provided for @s136.
  ///
  /// In zh_CN, this message translates to:
  /// **'安心守护 · 连续 {streak} 天'**
  String s136(Object? streak);

  /// No description provided for @s137.
  ///
  /// In zh_CN, this message translates to:
  /// **'🔥 连续 {streak} 天 · 累计 {total} 天'**
  String s137(Object? streak, Object? total);

  /// No description provided for @s138.
  ///
  /// In zh_CN, this message translates to:
  /// **'你的好友'**
  String get s138;

  /// No description provided for @s139.
  ///
  /// In zh_CN, this message translates to:
  /// **'想和你建立守护关系'**
  String get s139;

  /// No description provided for @s140.
  ///
  /// In zh_CN, this message translates to:
  /// **'已确认平安 ❤️'**
  String get s140;

  /// No description provided for @s141.
  ///
  /// In zh_CN, this message translates to:
  /// **'{_entryTag} 入口 _isLoggedIn={_isLoggedIn} _checkedInToday={_checkedInToday}'**
  String s141(Object? _entryTag, Object? _isLoggedIn, Object? _checkedInToday);

  /// No description provided for @s142.
  ///
  /// In zh_CN, this message translates to:
  /// **'入口 _isLoggedIn={_isLoggedIn} _checkedInToday={_checkedInToday}'**
  String s142(Object? _isLoggedIn, Object? _checkedInToday);

  /// No description provided for @s143.
  ///
  /// In zh_CN, this message translates to:
  /// **'请先登录后再签到'**
  String get s143;

  /// No description provided for @s144.
  ///
  /// In zh_CN, this message translates to:
  /// **'无user_id'**
  String get s144;

  /// No description provided for @s145.
  ///
  /// In zh_CN, this message translates to:
  /// **'无token'**
  String get s145;

  /// No description provided for @s146.
  ///
  /// In zh_CN, this message translates to:
  /// **'解码异常:{e}'**
  String s146(Object? e);

  /// No description provided for @s147.
  ///
  /// In zh_CN, this message translates to:
  /// **'签到前 uid(本地)={p1} tokenUid(后端将认)={_tokenUid}'**
  String s147(Object? p1, Object? _tokenUid);

  /// No description provided for @s148.
  ///
  /// In zh_CN, this message translates to:
  /// **'调用 do_checkin date={today} uid={uid}'**
  String s148(Object? today, Object? uid);

  /// No description provided for @s149.
  ///
  /// In zh_CN, this message translates to:
  /// **'do_checkin 响应: {res}'**
  String s149(Object? res);

  /// No description provided for @s150.
  ///
  /// In zh_CN, this message translates to:
  /// **'do_checkin 成功 res={res}'**
  String s150(Object? res);

  /// No description provided for @s151.
  ///
  /// In zh_CN, this message translates to:
  /// **'☀️ 签到已同步'**
  String get s151;

  /// No description provided for @s152.
  ///
  /// In zh_CN, this message translates to:
  /// **'业务错误: {errorMsg}'**
  String s152(Object? errorMsg);

  /// No description provided for @s153.
  ///
  /// In zh_CN, this message translates to:
  /// **'☀️ 今日已签到'**
  String get s153;

  /// No description provided for @s154.
  ///
  /// In zh_CN, this message translates to:
  /// **'签到已记录，云端同步失败: {errorMsg}'**
  String s154(Object? errorMsg);

  /// No description provided for @s155.
  ///
  /// In zh_CN, this message translates to:
  /// **'异常: {e}'**
  String s155(Object? e);

  /// No description provided for @s156.
  ///
  /// In zh_CN, this message translates to:
  /// **'签到已记录，已保存到离线队列，联网后自动同步 ☁️'**
  String get s156;

  /// No description provided for @s157.
  ///
  /// In zh_CN, this message translates to:
  /// **'请先完善信息'**
  String get s157;

  /// No description provided for @s158.
  ///
  /// In zh_CN, this message translates to:
  /// **'使用紧急求助功能前，请先填写您的健康档案和紧急联系人信息。\n\n这确保在紧急情况下，救援人员能获取您的关键健康信息。'**
  String get s158;

  /// No description provided for @s159.
  ///
  /// In zh_CN, this message translates to:
  /// **'稍后'**
  String get s159;

  /// No description provided for @s160.
  ///
  /// In zh_CN, this message translates to:
  /// **'升级到智能版'**
  String get s160;

  /// No description provided for @s161.
  ///
  /// In zh_CN, this message translates to:
  /// **'解锁全部功能'**
  String get s161;

  /// No description provided for @s162.
  ///
  /// In zh_CN, this message translates to:
  /// **'{p1}年{p2}月'**
  String s162(Object? p1, Object? p2);

  /// No description provided for @s163.
  ///
  /// In zh_CN, this message translates to:
  /// **'{monthCheckInCount}/{daysInMonth} 天已签'**
  String s163(Object? monthCheckInCount, Object? daysInMonth);

  /// No description provided for @s164.
  ///
  /// In zh_CN, this message translates to:
  /// **'今天'**
  String get s164;

  /// No description provided for @s165.
  ///
  /// In zh_CN, this message translates to:
  /// **'今月'**
  String get s165;

  /// No description provided for @s166.
  ///
  /// In zh_CN, this message translates to:
  /// **'一'**
  String get s166;

  /// No description provided for @s167.
  ///
  /// In zh_CN, this message translates to:
  /// **'二'**
  String get s167;

  /// No description provided for @s168.
  ///
  /// In zh_CN, this message translates to:
  /// **'三'**
  String get s168;

  /// No description provided for @s169.
  ///
  /// In zh_CN, this message translates to:
  /// **'四'**
  String get s169;

  /// No description provided for @s170.
  ///
  /// In zh_CN, this message translates to:
  /// **'五'**
  String get s170;

  /// No description provided for @s171.
  ///
  /// In zh_CN, this message translates to:
  /// **'六'**
  String get s171;

  /// No description provided for @s172.
  ///
  /// In zh_CN, this message translates to:
  /// **'日'**
  String get s172;

  /// No description provided for @s173.
  ///
  /// In zh_CN, this message translates to:
  /// **'少'**
  String get s173;

  /// No description provided for @s174.
  ///
  /// In zh_CN, this message translates to:
  /// **'  多'**
  String get s174;

  /// No description provided for @s175.
  ///
  /// In zh_CN, this message translates to:
  /// **'{dateStr} {p1}'**
  String s175(Object? dateStr, Object? p1);

  /// No description provided for @s176.
  ///
  /// In zh_CN, this message translates to:
  /// **'选择月份'**
  String get s176;

  /// No description provided for @s177.
  ///
  /// In zh_CN, this message translates to:
  /// **'{selectedYear}年'**
  String s177(Object? selectedYear);

  /// No description provided for @s178.
  ///
  /// In zh_CN, this message translates to:
  /// **'{month}月'**
  String s178(Object? month);

  /// No description provided for @s179.
  ///
  /// In zh_CN, this message translates to:
  /// **'男'**
  String get s179;

  /// No description provided for @s180.
  ///
  /// In zh_CN, this message translates to:
  /// **'A型'**
  String get s180;

  /// No description provided for @s181.
  ///
  /// In zh_CN, this message translates to:
  /// **'B型'**
  String get s181;

  /// No description provided for @s182.
  ///
  /// In zh_CN, this message translates to:
  /// **'O型'**
  String get s182;

  /// No description provided for @s183.
  ///
  /// In zh_CN, this message translates to:
  /// **'AB型'**
  String get s183;

  /// No description provided for @s184.
  ///
  /// In zh_CN, this message translates to:
  /// **'其他'**
  String get s184;

  /// No description provided for @s185.
  ///
  /// In zh_CN, this message translates to:
  /// **'头像保存失败，请重试'**
  String get s185;

  /// No description provided for @s186.
  ///
  /// In zh_CN, this message translates to:
  /// **'头像已同步到云端 ✓'**
  String get s186;

  /// No description provided for @s187.
  ///
  /// In zh_CN, this message translates to:
  /// **'头像同步失败，请稍后重试'**
  String get s187;

  /// No description provided for @s188.
  ///
  /// In zh_CN, this message translates to:
  /// **'头像保存失败: {e}'**
  String s188(Object? e);

  /// No description provided for @s189.
  ///
  /// In zh_CN, this message translates to:
  /// **'健康档案保存成功！'**
  String get s189;

  /// No description provided for @s190.
  ///
  /// In zh_CN, this message translates to:
  /// **'本地保存成功，云端同步失败，请检查网络'**
  String get s190;

  /// No description provided for @s191.
  ///
  /// In zh_CN, this message translates to:
  /// **'主题设置'**
  String get s191;

  /// No description provided for @s192.
  ///
  /// In zh_CN, this message translates to:
  /// **'问题反馈'**
  String get s192;

  /// No description provided for @s193.
  ///
  /// In zh_CN, this message translates to:
  /// **'您的反馈对我们非常重要，我们会尽快处理。'**
  String get s193;

  /// No description provided for @s194.
  ///
  /// In zh_CN, this message translates to:
  /// **'请描述您遇到的问题或建议...'**
  String get s194;

  /// No description provided for @s195.
  ///
  /// In zh_CN, this message translates to:
  /// **'感谢您的反馈，我们会尽快处理！✓'**
  String get s195;

  /// No description provided for @s196.
  ///
  /// In zh_CN, this message translates to:
  /// **'提交反馈'**
  String get s196;

  /// No description provided for @s197.
  ///
  /// In zh_CN, this message translates to:
  /// **'暂无反馈记录'**
  String get s197;

  /// No description provided for @s198.
  ///
  /// In zh_CN, this message translates to:
  /// **'用户反馈 ({p1}条)'**
  String s198(Object? p1);

  /// No description provided for @s199.
  ///
  /// In zh_CN, this message translates to:
  /// **'确认清空'**
  String get s199;

  /// No description provided for @s200.
  ///
  /// In zh_CN, this message translates to:
  /// **'确定要删除所有反馈记录吗？此操作不可恢复。'**
  String get s200;

  /// No description provided for @s201.
  ///
  /// In zh_CN, this message translates to:
  /// **'反馈记录已清空'**
  String get s201;

  /// No description provided for @s202.
  ///
  /// In zh_CN, this message translates to:
  /// **'清空'**
  String get s202;

  /// No description provided for @s203.
  ///
  /// In zh_CN, this message translates to:
  /// **'未知时间'**
  String get s203;

  /// No description provided for @s204.
  ///
  /// In zh_CN, this message translates to:
  /// **'守护关系'**
  String get s204;

  /// No description provided for @s205.
  ///
  /// In zh_CN, this message translates to:
  /// **'输入守护码'**
  String get s205;

  /// No description provided for @s206.
  ///
  /// In zh_CN, this message translates to:
  /// **'手动输入守护码，与对方建立守护关系'**
  String get s206;

  /// No description provided for @s207.
  ///
  /// In zh_CN, this message translates to:
  /// **'开发者模式'**
  String get s207;

  /// No description provided for @s208.
  ///
  /// In zh_CN, this message translates to:
  /// **'未登录'**
  String get s208;

  /// No description provided for @s209.
  ///
  /// In zh_CN, this message translates to:
  /// **'USER-ID 已复制到剪贴板'**
  String get s209;

  /// No description provided for @s210.
  ///
  /// In zh_CN, this message translates to:
  /// **'复制'**
  String get s210;

  /// No description provided for @s211.
  ///
  /// In zh_CN, this message translates to:
  /// **'无'**
  String get s211;

  /// No description provided for @s212.
  ///
  /// In zh_CN, this message translates to:
  /// **'签到模拟器'**
  String get s212;

  /// No description provided for @s213.
  ///
  /// In zh_CN, this message translates to:
  /// **'设置连续签到天数，测试徽章和里程碑弹窗'**
  String get s213;

  /// No description provided for @s214.
  ///
  /// In zh_CN, this message translates to:
  /// **'重置守护关系'**
  String get s214;

  /// No description provided for @s215.
  ///
  /// In zh_CN, this message translates to:
  /// **'恢复为初始3张卡状态，方便测试发卡全链路'**
  String get s215;

  /// No description provided for @s216.
  ///
  /// In zh_CN, this message translates to:
  /// **'重新显示引导页'**
  String get s216;

  /// No description provided for @s217.
  ///
  /// In zh_CN, this message translates to:
  /// **'下次启动App时再次显示开机引导'**
  String get s217;

  /// No description provided for @s218.
  ///
  /// In zh_CN, this message translates to:
  /// **'已设置，下次启动将显示引导页 ✓'**
  String get s218;

  /// No description provided for @s219.
  ///
  /// In zh_CN, this message translates to:
  /// **'重置新手任务'**
  String get s219;

  /// No description provided for @s220.
  ///
  /// In zh_CN, this message translates to:
  /// **'清除新手任务完成状态，重新体验5步引导'**
  String get s220;

  /// No description provided for @s221.
  ///
  /// In zh_CN, this message translates to:
  /// **'新手任务已重置，返回首页即可重新体验 ✓'**
  String get s221;

  /// No description provided for @s222.
  ///
  /// In zh_CN, this message translates to:
  /// **'切换会员等级'**
  String get s222;

  /// No description provided for @s223.
  ///
  /// In zh_CN, this message translates to:
  /// **'体验版 ↔ 智能版，测试会员权益差异'**
  String get s223;

  /// No description provided for @s224.
  ///
  /// In zh_CN, this message translates to:
  /// **'模拟会员过期降级'**
  String get s224;

  /// No description provided for @s225.
  ///
  /// In zh_CN, this message translates to:
  /// **'智能版 → 体验版，联系人保留但锁定'**
  String get s225;

  /// No description provided for @s226.
  ///
  /// In zh_CN, this message translates to:
  /// **'查看用户反馈'**
  String get s226;

  /// No description provided for @s227.
  ///
  /// In zh_CN, this message translates to:
  /// **'查看所有已提交的反馈内容'**
  String get s227;

  /// No description provided for @s228.
  ///
  /// In zh_CN, this message translates to:
  /// **'健康档案'**
  String get s228;

  /// No description provided for @s229.
  ///
  /// In zh_CN, this message translates to:
  /// **'点击头像设置'**
  String get s229;

  /// No description provided for @s230.
  ///
  /// In zh_CN, this message translates to:
  /// **'点击头像更换照片'**
  String get s230;

  /// No description provided for @s231.
  ///
  /// In zh_CN, this message translates to:
  /// **'档案已完善'**
  String get s231;

  /// No description provided for @s232.
  ///
  /// In zh_CN, this message translates to:
  /// **'请完善健康档案'**
  String get s232;

  /// No description provided for @s233.
  ///
  /// In zh_CN, this message translates to:
  /// **'求助功能已解锁，保护自己从现在开始'**
  String get s233;

  /// No description provided for @s234.
  ///
  /// In zh_CN, this message translates to:
  /// **'紧急求助需要您的健康信息'**
  String get s234;

  /// No description provided for @s235.
  ///
  /// In zh_CN, this message translates to:
  /// **'安全中心'**
  String get s235;

  /// No description provided for @s236.
  ///
  /// In zh_CN, this message translates to:
  /// **'定时平安确认 · 位置共享 · 跌倒检测'**
  String get s236;

  /// No description provided for @s237.
  ///
  /// In zh_CN, this message translates to:
  /// **'数据统计'**
  String get s237;

  /// No description provided for @s238.
  ///
  /// In zh_CN, this message translates to:
  /// **'签到日历 · 健康趋势 · 经期周期'**
  String get s238;

  /// No description provided for @s239.
  ///
  /// In zh_CN, this message translates to:
  /// **'我的成就'**
  String get s239;

  /// No description provided for @s240.
  ///
  /// In zh_CN, this message translates to:
  /// **'连续签到 · 关怀 · 里程碑'**
  String get s240;

  /// No description provided for @s241.
  ///
  /// In zh_CN, this message translates to:
  /// **'医疗急救卡 ✓ 已设置'**
  String get s241;

  /// No description provided for @s242.
  ///
  /// In zh_CN, this message translates to:
  /// **'医疗急救卡'**
  String get s242;

  /// No description provided for @s243.
  ///
  /// In zh_CN, this message translates to:
  /// **'iOS 原生'**
  String get s243;

  /// No description provided for @s244.
  ///
  /// In zh_CN, this message translates to:
  /// **'锁屏可查看 · 无需解锁手机'**
  String get s244;

  /// No description provided for @s245.
  ///
  /// In zh_CN, this message translates to:
  /// **'医疗急救卡设置引导'**
  String get s245;

  /// No description provided for @s246.
  ///
  /// In zh_CN, this message translates to:
  /// **'什么是医疗急救卡？'**
  String get s246;

  /// No description provided for @s247.
  ///
  /// In zh_CN, this message translates to:
  /// **'医疗急救卡是 iPhone 系统级功能，在锁屏状态下，任何人都可以查看你的紧急医疗信息，而无需解锁手机。'**
  String get s247;

  /// No description provided for @s248.
  ///
  /// In zh_CN, this message translates to:
  /// **'设置步骤（共 4 步）'**
  String get s248;

  /// No description provided for @s249.
  ///
  /// In zh_CN, this message translates to:
  /// **'打开\"健康\" App'**
  String get s249;

  /// No description provided for @s250.
  ///
  /// In zh_CN, this message translates to:
  /// **'在 iPhone 上找到并打开\"健康\"App（绿色心形图标）'**
  String get s250;

  /// No description provided for @s251.
  ///
  /// In zh_CN, this message translates to:
  /// **'点击右上角头像'**
  String get s251;

  /// No description provided for @s252.
  ///
  /// In zh_CN, this message translates to:
  /// **'在\"摘要\"页面，点击右上角的头像进入个人资料'**
  String get s252;

  /// No description provided for @s253.
  ///
  /// In zh_CN, this message translates to:
  /// **'选择\"医疗急救卡\"'**
  String get s253;

  /// No description provided for @s254.
  ///
  /// In zh_CN, this message translates to:
  /// **'向下滑动，找到\"医疗急救卡\"选项，点击进入'**
  String get s254;

  /// No description provided for @s255.
  ///
  /// In zh_CN, this message translates to:
  /// **'填写并保存'**
  String get s255;

  /// No description provided for @s256.
  ///
  /// In zh_CN, this message translates to:
  /// **'填写姓名、血型、过敏信息、紧急联系人等，完成后点击\"完成\"'**
  String get s256;

  /// No description provided for @s257.
  ///
  /// In zh_CN, this message translates to:
  /// **'提示：设置完成后，在锁屏界面点击\"紧急\"→\"医疗急救卡\"即可查看'**
  String get s257;

  /// No description provided for @s258.
  ///
  /// In zh_CN, this message translates to:
  /// **'我已完成设置'**
  String get s258;

  /// No description provided for @s259.
  ///
  /// In zh_CN, this message translates to:
  /// **'请在 iPhone 上手动打开\"健康\"App 进行设置'**
  String get s259;

  /// No description provided for @s260.
  ///
  /// In zh_CN, this message translates to:
  /// **'无法打开健康App，请手动查找：{e}'**
  String s260(Object? e);

  /// No description provided for @s261.
  ///
  /// In zh_CN, this message translates to:
  /// **'去健康App设置'**
  String get s261;

  /// No description provided for @s262.
  ///
  /// In zh_CN, this message translates to:
  /// **'请在 iPhone 上手动打开\"健康\"App 进行修改'**
  String get s262;

  /// No description provided for @s263.
  ///
  /// In zh_CN, this message translates to:
  /// **'无法打开健康App：{e}'**
  String s263(Object? e);

  /// No description provided for @s264.
  ///
  /// In zh_CN, this message translates to:
  /// **'去健康App修改'**
  String get s264;

  /// No description provided for @s265.
  ///
  /// In zh_CN, this message translates to:
  /// **'确认完成设置'**
  String get s265;

  /// No description provided for @s266.
  ///
  /// In zh_CN, this message translates to:
  /// **'你确定已经在 iPhone \"健康\" App 中完成了医疗急救卡的填写和保存吗？'**
  String get s266;

  /// No description provided for @s267.
  ///
  /// In zh_CN, this message translates to:
  /// **'设置后可在锁屏界面通过\"紧急\"→\"医疗急救卡\"查看你的信息'**
  String get s267;

  /// No description provided for @s268.
  ///
  /// In zh_CN, this message translates to:
  /// **'再检查一下'**
  String get s268;

  /// No description provided for @s269.
  ///
  /// In zh_CN, this message translates to:
  /// **'✅ 医疗急救卡已标记为完成！'**
  String get s269;

  /// No description provided for @s270.
  ///
  /// In zh_CN, this message translates to:
  /// **'✅ 确定已完成'**
  String get s270;

  /// No description provided for @s271.
  ///
  /// In zh_CN, this message translates to:
  /// **'主题颜色'**
  String get s271;

  /// No description provided for @s272.
  ///
  /// In zh_CN, this message translates to:
  /// **'守护码'**
  String get s272;

  /// No description provided for @s273.
  ///
  /// In zh_CN, this message translates to:
  /// **'绑定守护码'**
  String get s273;

  /// No description provided for @s274.
  ///
  /// In zh_CN, this message translates to:
  /// **'告诉我们'**
  String get s274;

  /// No description provided for @s275.
  ///
  /// In zh_CN, this message translates to:
  /// **'基本信息'**
  String get s275;

  /// No description provided for @s276.
  ///
  /// In zh_CN, this message translates to:
  /// **'必填'**
  String get s276;

  /// No description provided for @s277.
  ///
  /// In zh_CN, this message translates to:
  /// **'姓名'**
  String get s277;

  /// No description provided for @s278.
  ///
  /// In zh_CN, this message translates to:
  /// **'请输入您的姓名'**
  String get s278;

  /// No description provided for @s279.
  ///
  /// In zh_CN, this message translates to:
  /// **'请输入姓名'**
  String get s279;

  /// No description provided for @s280.
  ///
  /// In zh_CN, this message translates to:
  /// **'年龄'**
  String get s280;

  /// No description provided for @s281.
  ///
  /// In zh_CN, this message translates to:
  /// **'请输入年龄'**
  String get s281;

  /// No description provided for @s282.
  ///
  /// In zh_CN, this message translates to:
  /// **'请输入有效年龄'**
  String get s282;

  /// No description provided for @s283.
  ///
  /// In zh_CN, this message translates to:
  /// **'性别'**
  String get s283;

  /// No description provided for @s284.
  ///
  /// In zh_CN, this message translates to:
  /// **'女'**
  String get s284;

  /// No description provided for @s285.
  ///
  /// In zh_CN, this message translates to:
  /// **'过敏史'**
  String get s285;

  /// No description provided for @s286.
  ///
  /// In zh_CN, this message translates to:
  /// **'如：青霉素、芒果、海鲜（无则填\"无\"）'**
  String get s286;

  /// No description provided for @s287.
  ///
  /// In zh_CN, this message translates to:
  /// **'请填写过敏史'**
  String get s287;

  /// No description provided for @s288.
  ///
  /// In zh_CN, this message translates to:
  /// **'健康信息'**
  String get s288;

  /// No description provided for @s289.
  ///
  /// In zh_CN, this message translates to:
  /// **'选填'**
  String get s289;

  /// No description provided for @s290.
  ///
  /// In zh_CN, this message translates to:
  /// **'既往病史'**
  String get s290;

  /// No description provided for @s291.
  ///
  /// In zh_CN, this message translates to:
  /// **'如：高血压、糖尿病等'**
  String get s291;

  /// No description provided for @s292.
  ///
  /// In zh_CN, this message translates to:
  /// **'常用药物'**
  String get s292;

  /// No description provided for @s293.
  ///
  /// In zh_CN, this message translates to:
  /// **'如：降压药、胰岛素等'**
  String get s293;

  /// No description provided for @s294.
  ///
  /// In zh_CN, this message translates to:
  /// **'紧急备注'**
  String get s294;

  /// No description provided for @s295.
  ///
  /// In zh_CN, this message translates to:
  /// **'救援人员需要知道的信息'**
  String get s295;

  /// No description provided for @s296.
  ///
  /// In zh_CN, this message translates to:
  /// **'更新档案'**
  String get s296;

  /// No description provided for @s297.
  ///
  /// In zh_CN, this message translates to:
  /// **'保存并启用求助'**
  String get s297;

  /// No description provided for @s298.
  ///
  /// In zh_CN, this message translates to:
  /// **'您的健康档案和紧急联系人信息已加密同步到云端，换设备登录后数据不会丢失。我们严格保护您的隐私安全。'**
  String get s298;

  /// No description provided for @s299.
  ///
  /// In zh_CN, this message translates to:
  /// **'家人'**
  String get s299;

  /// No description provided for @s300.
  ///
  /// In zh_CN, this message translates to:
  /// **'朋友'**
  String get s300;

  /// No description provided for @s301.
  ///
  /// In zh_CN, this message translates to:
  /// **'同事'**
  String get s301;

  /// No description provided for @s302.
  ///
  /// In zh_CN, this message translates to:
  /// **'父母'**
  String get s302;

  /// No description provided for @s303.
  ///
  /// In zh_CN, this message translates to:
  /// **'配偶'**
  String get s303;

  /// No description provided for @s304.
  ///
  /// In zh_CN, this message translates to:
  /// **'子女'**
  String get s304;

  /// No description provided for @s305.
  ///
  /// In zh_CN, this message translates to:
  /// **'守护人'**
  String get s305;

  /// No description provided for @s306.
  ///
  /// In zh_CN, this message translates to:
  /// **'自定义...'**
  String get s306;

  /// No description provided for @s307.
  ///
  /// In zh_CN, this message translates to:
  /// **'兄弟姐妹'**
  String get s307;

  /// No description provided for @s308.
  ///
  /// In zh_CN, this message translates to:
  /// **'智能版最多添加 {maxContacts} 位联系人'**
  String s308(Object? maxContacts);

  /// No description provided for @s309.
  ///
  /// In zh_CN, this message translates to:
  /// **'联系人已达上限'**
  String get s309;

  /// No description provided for @s310.
  ///
  /// In zh_CN, this message translates to:
  /// **'体验版最多可添加 {maxContacts} 位紧急联系人。'**
  String s310(Object? maxContacts);

  /// No description provided for @s311.
  ///
  /// In zh_CN, this message translates to:
  /// **'升级到智能版，你将获得：'**
  String get s311;

  /// No description provided for @s312.
  ///
  /// In zh_CN, this message translates to:
  /// **'紧急联系人 5位 → {p1}位'**
  String s312(Object? p1);

  /// No description provided for @s313.
  ///
  /// In zh_CN, this message translates to:
  /// **'紧急快捷拨打 1位 → {p1}位'**
  String s313(Object? p1);

  /// No description provided for @s314.
  ///
  /// In zh_CN, this message translates to:
  /// **'紧急快捷短信 1位 → {p1}位'**
  String s314(Object? p1);

  /// No description provided for @s315.
  ///
  /// In zh_CN, this message translates to:
  /// **'稍后再说'**
  String get s315;

  /// No description provided for @s316.
  ///
  /// In zh_CN, this message translates to:
  /// **'立即升级'**
  String get s316;

  /// No description provided for @s317.
  ///
  /// In zh_CN, this message translates to:
  /// **'{contactName} 已添加为守护者'**
  String s317(Object? contactName);

  /// No description provided for @s318.
  ///
  /// In zh_CN, this message translates to:
  /// **'升级智能版可添加更多联系人'**
  String get s318;

  /// No description provided for @s319.
  ///
  /// In zh_CN, this message translates to:
  /// **'去升级'**
  String get s319;

  /// No description provided for @s320.
  ///
  /// In zh_CN, this message translates to:
  /// **'我'**
  String get s320;

  /// No description provided for @s321.
  ///
  /// In zh_CN, this message translates to:
  /// **'【在呢】嗨 {p1}！我是{senderName}，刚把你设为我的紧急联系人 🛡️\n\n我在用「在呢」App 守护自己的安全——每天签到报平安，遇到紧急情况一键求助，可在确认后通知你我的实时位置。\n\n如果你也下载「在呢」，我们可以互相守护，让彼此都更安心。❤️\n\n点击链接接受邀请：{p2}'**
  String s321(Object? p1, Object? senderName, Object? p2);

  /// No description provided for @s322.
  ///
  /// In zh_CN, this message translates to:
  /// **'发送邀请短信'**
  String get s322;

  /// No description provided for @s323.
  ///
  /// In zh_CN, this message translates to:
  /// **'已为 {name} 设置为紧急联系人。'**
  String s323(Object? name);

  /// No description provided for @s324.
  ///
  /// In zh_CN, this message translates to:
  /// **'编辑短信内容（双方昵称可选）'**
  String get s324;

  /// No description provided for @s325.
  ///
  /// In zh_CN, this message translates to:
  /// **'你的昵称'**
  String get s325;

  /// No description provided for @s326.
  ///
  /// In zh_CN, this message translates to:
  /// **'发短信时显示你是谁'**
  String get s326;

  /// No description provided for @s327.
  ///
  /// In zh_CN, this message translates to:
  /// **'对方称呼'**
  String get s327;

  /// No description provided for @s328.
  ///
  /// In zh_CN, this message translates to:
  /// **'你想怎么称呼对方'**
  String get s328;

  /// No description provided for @s329.
  ///
  /// In zh_CN, this message translates to:
  /// **'短信预览：'**
  String get s329;

  /// No description provided for @s330.
  ///
  /// In zh_CN, this message translates to:
  /// **'【在呢】嗨 {recipientDisplayName}！我是{finalSender}，刚把你设为我的紧急联系人 🛡️\n\n有你在，我多一份安心。我每天在「在呢」报平安，遇急事会通知你。\n\n想看看我在用的守护App，点这里：\n{inviteShortUrl}'**
  String s330(Object? recipientDisplayName, Object? finalSender,
      Object? inviteShortUrl);

  /// No description provided for @s331.
  ///
  /// In zh_CN, this message translates to:
  /// **'发送短信'**
  String get s331;

  /// No description provided for @s332.
  ///
  /// In zh_CN, this message translates to:
  /// **'已在短信App中准备好给 {p1} 的邀请'**
  String s332(Object? p1);

  /// No description provided for @s333.
  ///
  /// In zh_CN, this message translates to:
  /// **'无法打开短信应用，请检查系统设置'**
  String get s333;

  /// No description provided for @s334.
  ///
  /// In zh_CN, this message translates to:
  /// **'短信发送失败: {e}'**
  String s334(Object? e);

  /// No description provided for @s335.
  ///
  /// In zh_CN, this message translates to:
  /// **'临时'**
  String get s335;

  /// No description provided for @s336.
  ///
  /// In zh_CN, this message translates to:
  /// **'保存失败: {p1}'**
  String s336(Object? p1);

  /// No description provided for @s337.
  ///
  /// In zh_CN, this message translates to:
  /// **'查看日志'**
  String get s337;

  /// No description provided for @s338.
  ///
  /// In zh_CN, this message translates to:
  /// **'保存异常: {e}'**
  String s338(Object? e);

  /// No description provided for @s339.
  ///
  /// In zh_CN, this message translates to:
  /// **'删除联系人'**
  String get s339;

  /// No description provided for @s340.
  ///
  /// In zh_CN, this message translates to:
  /// **'确定要删除 {p1} 吗？'**
  String s340(Object? p1);

  /// No description provided for @s341.
  ///
  /// In zh_CN, this message translates to:
  /// **'👑 优先'**
  String get s341;

  /// No description provided for @s342.
  ///
  /// In zh_CN, this message translates to:
  /// **'七'**
  String get s342;

  /// No description provided for @s343.
  ///
  /// In zh_CN, this message translates to:
  /// **'八'**
  String get s343;

  /// No description provided for @s344.
  ///
  /// In zh_CN, this message translates to:
  /// **'九'**
  String get s344;

  /// No description provided for @s345.
  ///
  /// In zh_CN, this message translates to:
  /// **'十'**
  String get s345;

  /// No description provided for @s346.
  ///
  /// In zh_CN, this message translates to:
  /// **'紧急联系人'**
  String get s346;

  /// No description provided for @s347.
  ///
  /// In zh_CN, this message translates to:
  /// **'添加联系人'**
  String get s347;

  /// No description provided for @s348.
  ///
  /// In zh_CN, this message translates to:
  /// **'求助时将按优先顺序拨打，拖动左侧☰调整排序'**
  String get s348;

  /// No description provided for @s349.
  ///
  /// In zh_CN, this message translates to:
  /// **'第一位联系人 = 第一紧急联系人（最优先）'**
  String get s349;

  /// No description provided for @s350.
  ///
  /// In zh_CN, this message translates to:
  /// **'编辑紧急联系人'**
  String get s350;

  /// No description provided for @s351.
  ///
  /// In zh_CN, this message translates to:
  /// **'添加紧急联系人'**
  String get s351;

  /// No description provided for @s352.
  ///
  /// In zh_CN, this message translates to:
  /// **'修改后将自动保存优先顺序'**
  String get s352;

  /// No description provided for @s353.
  ///
  /// In zh_CN, this message translates to:
  /// **'求助时将按优先顺序拨打'**
  String get s353;

  /// No description provided for @s354.
  ///
  /// In zh_CN, this message translates to:
  /// **'请输入联系人姓名'**
  String get s354;

  /// No description provided for @s355.
  ///
  /// In zh_CN, this message translates to:
  /// **'手机号码'**
  String get s355;

  /// No description provided for @s356.
  ///
  /// In zh_CN, this message translates to:
  /// **'请输入11位手机号'**
  String get s356;

  /// No description provided for @s357.
  ///
  /// In zh_CN, this message translates to:
  /// **'请输入手机号码'**
  String get s357;

  /// No description provided for @s358.
  ///
  /// In zh_CN, this message translates to:
  /// **'请输入正确的手机号'**
  String get s358;

  /// No description provided for @s359.
  ///
  /// In zh_CN, this message translates to:
  /// **'与您的关系'**
  String get s359;

  /// No description provided for @s360.
  ///
  /// In zh_CN, this message translates to:
  /// **'请选择关系'**
  String get s360;

  /// No description provided for @s361.
  ///
  /// In zh_CN, this message translates to:
  /// **'请输入自定义关系'**
  String get s361;

  /// No description provided for @s362.
  ///
  /// In zh_CN, this message translates to:
  /// **'例如：师兄、邻居、室友'**
  String get s362;

  /// No description provided for @s363.
  ///
  /// In zh_CN, this message translates to:
  /// **'保存修改'**
  String get s363;

  /// No description provided for @s364.
  ///
  /// In zh_CN, this message translates to:
  /// **'修改备注名'**
  String get s364;

  /// No description provided for @s365.
  ///
  /// In zh_CN, this message translates to:
  /// **'输入在「我守护的人」中显示的名字'**
  String get s365;

  /// No description provided for @s366.
  ///
  /// In zh_CN, this message translates to:
  /// **'保存'**
  String get s366;

  /// No description provided for @s367.
  ///
  /// In zh_CN, this message translates to:
  /// **'我守护的人'**
  String get s367;

  /// No description provided for @s369.
  ///
  /// In zh_CN, this message translates to:
  /// **'待激活'**
  String get s369;

  /// No description provided for @s370.
  ///
  /// In zh_CN, this message translates to:
  /// **'今日未签到'**
  String get s370;

  /// No description provided for @s371.
  ///
  /// In zh_CN, this message translates to:
  /// **'重新邀请'**
  String get s371;

  /// No description provided for @s372.
  ///
  /// In zh_CN, this message translates to:
  /// **'尚未检测'**
  String get s372;

  /// No description provided for @s373.
  ///
  /// In zh_CN, this message translates to:
  /// **'未命名'**
  String get s373;

  /// No description provided for @s374.
  ///
  /// In zh_CN, this message translates to:
  /// **'守护者'**
  String get s374;

  /// No description provided for @s379.
  ///
  /// In zh_CN, this message translates to:
  /// **'网络异常'**
  String get s379;

  /// No description provided for @s380.
  ///
  /// In zh_CN, this message translates to:
  /// **'查询失败'**
  String get s380;

  /// No description provided for @s384.
  ///
  /// In zh_CN, this message translates to:
  /// **'未注册'**
  String get s384;

  /// No description provided for @s386.
  ///
  /// In zh_CN, this message translates to:
  /// **'创建免费守护卡失败'**
  String get s386;

  /// No description provided for @s387.
  ///
  /// In zh_CN, this message translates to:
  /// **'网络异常，请稍后重试'**
  String get s387;

  /// No description provided for @s388.
  ///
  /// In zh_CN, this message translates to:
  /// **'无法生成专属邀请链接'**
  String get s388;

  /// No description provided for @s390.
  ///
  /// In zh_CN, this message translates to:
  /// **'短信已打开，完整链接已复制。若对方收不到链接可长按粘贴补发'**
  String get s390;

  /// No description provided for @s392.
  ///
  /// In zh_CN, this message translates to:
  /// **'提醒失败'**
  String get s392;

  /// No description provided for @s394.
  ///
  /// In zh_CN, this message translates to:
  /// **'我的守护圈'**
  String get s394;

  /// No description provided for @s396.
  ///
  /// In zh_CN, this message translates to:
  /// **'暂无守护者'**
  String get s396;

  /// No description provided for @s399.
  ///
  /// In zh_CN, this message translates to:
  /// **'正在同步守护圈状态…'**
  String get s399;

  /// No description provided for @s400.
  ///
  /// In zh_CN, this message translates to:
  /// **'紧急联系人自动成为你的守护者'**
  String get s400;

  /// No description provided for @s401.
  ///
  /// In zh_CN, this message translates to:
  /// **'添加紧急联系人，让他们守护你'**
  String get s401;

  /// No description provided for @s402.
  ///
  /// In zh_CN, this message translates to:
  /// **'消息'**
  String get s402;

  /// No description provided for @s403.
  ///
  /// In zh_CN, this message translates to:
  /// **'表情'**
  String get s403;

  /// No description provided for @s404.
  ///
  /// In zh_CN, this message translates to:
  /// **'成就'**
  String get s404;

  /// No description provided for @s405.
  ///
  /// In zh_CN, this message translates to:
  /// **'💌 发送守护卡'**
  String get s405;

  /// No description provided for @s406.
  ///
  /// In zh_CN, this message translates to:
  /// **'邀请在乎的人，让他们也受到保护'**
  String get s406;

  /// No description provided for @s408.
  ///
  /// In zh_CN, this message translates to:
  /// **'连续守护'**
  String get s408;

  /// No description provided for @s409.
  ///
  /// In zh_CN, this message translates to:
  /// **'已签到'**
  String get s409;

  /// No description provided for @s410.
  ///
  /// In zh_CN, this message translates to:
  /// **'未签到'**
  String get s410;

  /// No description provided for @s411.
  ///
  /// In zh_CN, this message translates to:
  /// **'今日状态'**
  String get s411;

  /// No description provided for @s413.
  ///
  /// In zh_CN, this message translates to:
  /// **'累计签到'**
  String get s413;

  /// No description provided for @s414.
  ///
  /// In zh_CN, this message translates to:
  /// **'还没有守护者'**
  String get s414;

  /// No description provided for @s415.
  ///
  /// In zh_CN, this message translates to:
  /// **'添加紧急联系人\n让他们成为你的守护者'**
  String get s415;

  /// No description provided for @s416.
  ///
  /// In zh_CN, this message translates to:
  /// **'添加守护者'**
  String get s416;

  /// No description provided for @s417.
  ///
  /// In zh_CN, this message translates to:
  /// **'常用功能'**
  String get s417;

  /// No description provided for @s418.
  ///
  /// In zh_CN, this message translates to:
  /// **'紧急联系人管理'**
  String get s418;

  /// No description provided for @s419.
  ///
  /// In zh_CN, this message translates to:
  /// **'添加、修改、排序你的守护者（最多 10 位）'**
  String get s419;

  /// No description provided for @s420.
  ///
  /// In zh_CN, this message translates to:
  /// **'查看与编辑你发出的守护卡'**
  String get s420;

  /// No description provided for @s422.
  ///
  /// In zh_CN, this message translates to:
  /// **'平安确认'**
  String get s422;

  /// No description provided for @s423.
  ///
  /// In zh_CN, this message translates to:
  /// **'让守护者知道你一切平安'**
  String get s423;

  /// No description provided for @s424.
  ///
  /// In zh_CN, this message translates to:
  /// **'什么是守护圈'**
  String get s424;

  /// No description provided for @s425.
  ///
  /// In zh_CN, this message translates to:
  /// **'了解守护圈的工作原理'**
  String get s425;

  /// No description provided for @s426.
  ///
  /// In zh_CN, this message translates to:
  /// **'你 今日签到'**
  String get s426;

  /// No description provided for @s427.
  ///
  /// In zh_CN, this message translates to:
  /// **'已经完成今天的报到，一切安好'**
  String get s427;

  /// No description provided for @s429.
  ///
  /// In zh_CN, this message translates to:
  /// **'你的守护者已报平安'**
  String get s429;

  /// No description provided for @s430.
  ///
  /// In zh_CN, this message translates to:
  /// **'刚刚'**
  String get s430;

  /// No description provided for @s432.
  ///
  /// In zh_CN, this message translates to:
  /// **'圈内动态'**
  String get s432;

  /// No description provided for @s433.
  ///
  /// In zh_CN, this message translates to:
  /// **'今天圈内还静悄悄的'**
  String get s433;

  /// No description provided for @s434.
  ///
  /// In zh_CN, this message translates to:
  /// **'签到或报个平安，让守护圈看见你'**
  String get s434;

  /// No description provided for @s435.
  ///
  /// In zh_CN, this message translates to:
  /// **'开启生命体征守护'**
  String get s435;

  /// No description provided for @s436.
  ///
  /// In zh_CN, this message translates to:
  /// **'同步 Apple Watch 心率、血氧与睡眠'**
  String get s436;

  /// No description provided for @s438.
  ///
  /// In zh_CN, this message translates to:
  /// **'守护就绪 · 数据收集中'**
  String get s438;

  /// No description provided for @s439.
  ///
  /// In zh_CN, this message translates to:
  /// **'已开启生命体征守护，正在同步 Apple Watch 数据'**
  String get s439;

  /// No description provided for @s440.
  ///
  /// In zh_CN, this message translates to:
  /// **'心率'**
  String get s440;

  /// No description provided for @s441.
  ///
  /// In zh_CN, this message translates to:
  /// **'血氧'**
  String get s441;

  /// No description provided for @s442.
  ///
  /// In zh_CN, this message translates to:
  /// **'睡眠'**
  String get s442;

  /// No description provided for @s443.
  ///
  /// In zh_CN, this message translates to:
  /// **'点按查看完整体征'**
  String get s443;

  /// No description provided for @s444.
  ///
  /// In zh_CN, this message translates to:
  /// **'自动守护中 · 点按查看完整体征'**
  String get s444;

  /// No description provided for @s445.
  ///
  /// In zh_CN, this message translates to:
  /// **'自动守护已关闭 · 点按查看完整体征'**
  String get s445;

  /// No description provided for @s446.
  ///
  /// In zh_CN, this message translates to:
  /// **'刚刚同步'**
  String get s446;

  /// No description provided for @s449.
  ///
  /// In zh_CN, this message translates to:
  /// **'守护中'**
  String get s449;

  /// No description provided for @s450.
  ///
  /// In zh_CN, this message translates to:
  /// **'我守护的人 · 已建立守护关系'**
  String get s450;

  /// No description provided for @s451.
  ///
  /// In zh_CN, this message translates to:
  /// **'还没有守护的人'**
  String get s451;

  /// No description provided for @s452.
  ///
  /// In zh_CN, this message translates to:
  /// **'告诉对方你的守护码，对方在 App 内录入即可建立守护关系'**
  String get s452;

  /// No description provided for @s454.
  ///
  /// In zh_CN, this message translates to:
  /// **'互为守护'**
  String get s454;

  /// No description provided for @s455.
  ///
  /// In zh_CN, this message translates to:
  /// **'拨打电话'**
  String get s455;

  /// No description provided for @s456.
  ///
  /// In zh_CN, this message translates to:
  /// **'平安'**
  String get s456;

  /// No description provided for @s457.
  ///
  /// In zh_CN, this message translates to:
  /// **'提醒'**
  String get s457;

  /// No description provided for @s458.
  ///
  /// In zh_CN, this message translates to:
  /// **'邀请'**
  String get s458;

  /// No description provided for @s459.
  ///
  /// In zh_CN, this message translates to:
  /// **'请求平安确认'**
  String get s459;

  /// No description provided for @s460.
  ///
  /// In zh_CN, this message translates to:
  /// **'提醒TA下载'**
  String get s460;

  /// No description provided for @s461.
  ///
  /// In zh_CN, this message translates to:
  /// **'邀请注册'**
  String get s461;

  /// No description provided for @s462.
  ///
  /// In zh_CN, this message translates to:
  /// **'该守护者未设置电话号码'**
  String get s462;

  /// No description provided for @s465.
  ///
  /// In zh_CN, this message translates to:
  /// **'拨打'**
  String get s465;

  /// No description provided for @s466.
  ///
  /// In zh_CN, this message translates to:
  /// **'无法打开拨号界面，请手动拨打'**
  String get s466;

  /// No description provided for @s470.
  ///
  /// In zh_CN, this message translates to:
  /// **'发送请求'**
  String get s470;

  /// No description provided for @s471.
  ///
  /// In zh_CN, this message translates to:
  /// **'该守护者未绑定手机号，无法发送平安确认'**
  String get s471;

  /// No description provided for @s473.
  ///
  /// In zh_CN, this message translates to:
  /// **'网络请求失败，请检查网络后重试'**
  String get s473;

  /// No description provided for @s476.
  ///
  /// In zh_CN, this message translates to:
  /// **'解除守护关系'**
  String get s476;

  /// No description provided for @s479.
  ///
  /// In zh_CN, this message translates to:
  /// **'解除守护'**
  String get s479;

  /// No description provided for @s480.
  ///
  /// In zh_CN, this message translates to:
  /// **'找不到该联系人的记录'**
  String get s480;

  /// No description provided for @s482.
  ///
  /// In zh_CN, this message translates to:
  /// **'解除失败'**
  String get s482;

  /// No description provided for @s484.
  ///
  /// In zh_CN, this message translates to:
  /// **'守护圈是你的专属安全网络。'**
  String get s484;

  /// No description provided for @s485.
  ///
  /// In zh_CN, this message translates to:
  /// **'🛡️ 添加信任的家人和朋友作为守护者'**
  String get s485;

  /// No description provided for @s486.
  ///
  /// In zh_CN, this message translates to:
  /// **'🔔 你每天的签到状态守护者可见'**
  String get s486;

  /// No description provided for @s487.
  ///
  /// In zh_CN, this message translates to:
  /// **'🆘 紧急求助触发时守护者会立即收到通知'**
  String get s487;

  /// No description provided for @s488.
  ///
  /// In zh_CN, this message translates to:
  /// **'❤️ 让关心你的人安心'**
  String get s488;

  /// No description provided for @s489.
  ///
  /// In zh_CN, this message translates to:
  /// **'我知道了'**
  String get s489;

  /// No description provided for @s490.
  ///
  /// In zh_CN, this message translates to:
  /// **'向你的守护者发送一条平安消息，让他们知道你一切安好。\n\n\"我很好，不用担心 ❤️\"'**
  String get s490;

  /// No description provided for @s491.
  ///
  /// In zh_CN, this message translates to:
  /// **'发送确认'**
  String get s491;

  /// No description provided for @s492.
  ///
  /// In zh_CN, this message translates to:
  /// **'还没有添加守护者，请先添加紧急联系人'**
  String get s492;

  /// No description provided for @s493.
  ///
  /// In zh_CN, this message translates to:
  /// **'守护者信息异常，请重新添加联系人'**
  String get s493;

  /// No description provided for @s495.
  ///
  /// In zh_CN, this message translates to:
  /// **'你 报平安'**
  String get s495;

  /// No description provided for @s498.
  ///
  /// In zh_CN, this message translates to:
  /// **'无法打开短信界面，请手动发送平安消息'**
  String get s498;

  /// No description provided for @s540.
  ///
  /// In zh_CN, this message translates to:
  /// **'{p1} 位'**
  String s540(Object? p1);

  /// No description provided for @s541.
  ///
  /// In zh_CN, this message translates to:
  /// **'{ph}:签到={ci},头像={av},lastSignin={p1},isActive={p2}; '**
  String s541(Object? ph, Object? ci, Object? av, Object? p1, Object? p2);

  /// No description provided for @s542.
  ///
  /// In zh_CN, this message translates to:
  /// **'batchLookup RAW_RESULTS_KEYS={p1} | 守护者: {sb}'**
  String s542(Object? p1, Object? sb);

  /// No description provided for @s543.
  ///
  /// In zh_CN, this message translates to:
  /// **'dump异常: {e}'**
  String s543(Object? e);

  /// No description provided for @s544.
  ///
  /// In zh_CN, this message translates to:
  /// **'batchLookup 异常(走兜底): {e}'**
  String s544(Object? e);

  /// No description provided for @s545.
  ///
  /// In zh_CN, this message translates to:
  /// **'未连接（点击开启生命体征守护 · {ts}）'**
  String s545(Object? ts);

  /// No description provided for @s546.
  ///
  /// In zh_CN, this message translates to:
  /// **'已连接（心率{hr}/血氧{bo} · {ts}）'**
  String s546(Object? hr, Object? bo, Object? ts);

  /// No description provided for @s547.
  ///
  /// In zh_CN, this message translates to:
  /// **'已连接 · 数据同步中（{ts}）'**
  String s547(Object? ts);

  /// No description provided for @s548.
  ///
  /// In zh_CN, this message translates to:
  /// **'今日已签到{p1}'**
  String s548(Object? p1);

  /// No description provided for @s549.
  ///
  /// In zh_CN, this message translates to:
  /// **'【在呢】{safeName} 邀你一起守护 🛡️ 我在用「在呢」App每天报平安，独处时也安心。\n点链接，注册就能和我互相守护：\n{landingUrl}'**
  String s549(Object? safeName, Object? landingUrl);

  /// No description provided for @s550.
  ///
  /// In zh_CN, this message translates to:
  /// **'已提醒 {name} 下载并签到 ✅'**
  String s550(Object? name);

  /// No description provided for @s551.
  ///
  /// In zh_CN, this message translates to:
  /// **'提醒发送失败: {e}'**
  String s551(Object? e);

  /// No description provided for @s552.
  ///
  /// In zh_CN, this message translates to:
  /// **'{p1} 位守护者'**
  String s552(Object? p1);

  /// No description provided for @s553.
  ///
  /// In zh_CN, this message translates to:
  /// **'已成功守护 {p1} 位朋友'**
  String s553(Object? p1);

  /// No description provided for @s554.
  ///
  /// In zh_CN, this message translates to:
  /// **'与 {p1} 位互为守护'**
  String s554(Object? p1);

  /// No description provided for @s555.
  ///
  /// In zh_CN, this message translates to:
  /// **'{p1} 天'**
  String s555(Object? p1);

  /// No description provided for @s556.
  ///
  /// In zh_CN, this message translates to:
  /// **'{p1} 天'**
  String s556(Object? p1);

  /// No description provided for @s557.
  ///
  /// In zh_CN, this message translates to:
  /// **'管理 {p1} 位你守护的人'**
  String s557(Object? p1);

  /// No description provided for @s558.
  ///
  /// In zh_CN, this message translates to:
  /// **'{name} 今日签到'**
  String s558(Object? name);

  /// No description provided for @s559.
  ///
  /// In zh_CN, this message translates to:
  /// **'{p1}分钟前'**
  String s559(Object? p1);

  /// No description provided for @s560.
  ///
  /// In zh_CN, this message translates to:
  /// **'诊断：{_healthAuthDiag}'**
  String s560(Object? _healthAuthDiag);

  /// No description provided for @s561.
  ///
  /// In zh_CN, this message translates to:
  /// **'同步于 {diffMin} 分钟前'**
  String s561(Object? diffMin);

  /// No description provided for @s562.
  ///
  /// In zh_CN, this message translates to:
  /// **'同步于 {diffH} 小时前'**
  String s562(Object? diffH);

  /// No description provided for @s563.
  ///
  /// In zh_CN, this message translates to:
  /// **'· {boundAt} 绑定'**
  String s563(Object? boundAt);

  /// No description provided for @s564.
  ///
  /// In zh_CN, this message translates to:
  /// **'拨打给 {name}'**
  String s564(Object? name);

  /// No description provided for @s565.
  ///
  /// In zh_CN, this message translates to:
  /// **'即将拨打：{p1}\n\n点击确认后打开拨号界面。'**
  String s565(Object? p1);

  /// No description provided for @s566.
  ///
  /// In zh_CN, this message translates to:
  /// **'拨号失败：{e}'**
  String s566(Object? e);

  /// No description provided for @s567.
  ///
  /// In zh_CN, this message translates to:
  /// **'向 {name} 发平安确认请求'**
  String s567(Object? name);

  /// No description provided for @s568.
  ///
  /// In zh_CN, this message translates to:
  /// **'将向 {name} 发送一条平安确认请求，\n对方打开在呢App后可点击\"平安\"确认。\n\n是否继续？'**
  String s568(Object? name);

  /// No description provided for @s569.
  ///
  /// In zh_CN, this message translates to:
  /// **'{name} 尚未注册「在呢」，无法发送平安确认'**
  String s569(Object? name);

  /// No description provided for @s570.
  ///
  /// In zh_CN, this message translates to:
  /// **'已向 {name} 发送平安确认请求'**
  String s570(Object? name);

  /// No description provided for @s571.
  ///
  /// In zh_CN, this message translates to:
  /// **'发送失败：{p1}'**
  String s571(Object? p1);

  /// No description provided for @s572.
  ///
  /// In zh_CN, this message translates to:
  /// **'确定要解除与 {name} ({phone}) 的守护关系吗？\n\n解除后，对方将不再接收你的求助通知，你也无法再看到对方的签到状态。'**
  String s572(Object? name, Object? phone);

  /// No description provided for @s573.
  ///
  /// In zh_CN, this message translates to:
  /// **'确定要将 {name} ({phone}) 从守护圈移除吗？'**
  String s573(Object? name, Object? phone);

  /// No description provided for @s574.
  ///
  /// In zh_CN, this message translates to:
  /// **'已解除与 {p1} 的守护关系'**
  String s574(Object? p1);

  /// No description provided for @s575.
  ///
  /// In zh_CN, this message translates to:
  /// **'操作失败: {e}'**
  String s575(Object? e);

  /// No description provided for @s576.
  ///
  /// In zh_CN, this message translates to:
  /// **'【在呢】{senderName} 一切平安，请放心 ❤️'**
  String s576(Object? senderName);

  /// No description provided for @s577.
  ///
  /// In zh_CN, this message translates to:
  /// **'已向 {p1} 位守护者发送平安消息'**
  String s577(Object? p1);

  /// No description provided for @s578.
  ///
  /// In zh_CN, this message translates to:
  /// **'已为 {p1} 位守护者准备短信，请在短信App中发送'**
  String s578(Object? p1);

  /// No description provided for @s579.
  ///
  /// In zh_CN, this message translates to:
  /// **'短信功能不可用：{e}'**
  String s579(Object? e);

  /// No description provided for @s580.
  ///
  /// In zh_CN, this message translates to:
  /// **'经期设置'**
  String get s580;

  /// No description provided for @s581.
  ///
  /// In zh_CN, this message translates to:
  /// **'月经周期长度'**
  String get s581;

  /// No description provided for @s582.
  ///
  /// In zh_CN, this message translates to:
  /// **'经期长度'**
  String get s582;

  /// No description provided for @s583.
  ///
  /// In zh_CN, this message translates to:
  /// **'提醒设置'**
  String get s583;

  /// No description provided for @s584.
  ///
  /// In zh_CN, this message translates to:
  /// **'保存设置'**
  String get s584;

  /// No description provided for @s585.
  ///
  /// In zh_CN, this message translates to:
  /// **'{p1} 天'**
  String s585(Object? p1);

  /// No description provided for @s586.
  ///
  /// In zh_CN, this message translates to:
  /// **'平均月经周期长度（从本次经期第一天到下次经期第一天）'**
  String get s586;

  /// No description provided for @s587.
  ///
  /// In zh_CN, this message translates to:
  /// **'{p1} 天'**
  String s587(Object? p1);

  /// No description provided for @s588.
  ///
  /// In zh_CN, this message translates to:
  /// **'平均经期长度'**
  String get s588;

  /// No description provided for @s589.
  ///
  /// In zh_CN, this message translates to:
  /// **'开启经期提醒'**
  String get s589;

  /// No description provided for @s590.
  ///
  /// In zh_CN, this message translates to:
  /// **'在经期来临前提醒你'**
  String get s590;

  /// No description provided for @s591.
  ///
  /// In zh_CN, this message translates to:
  /// **'提前 {p1} 天提醒'**
  String s591(Object? p1);

  /// No description provided for @s592.
  ///
  /// In zh_CN, this message translates to:
  /// **'{p1} 天'**
  String s592(Object? p1);

  /// No description provided for @s593.
  ///
  /// In zh_CN, this message translates to:
  /// **'开启排卵期提醒'**
  String get s593;

  /// No description provided for @s594.
  ///
  /// In zh_CN, this message translates to:
  /// **'在排卵期来临时提醒你'**
  String get s594;

  /// No description provided for @s595.
  ///
  /// In zh_CN, this message translates to:
  /// **'设置已保存'**
  String get s595;

  /// No description provided for @s596.
  ///
  /// In zh_CN, this message translates to:
  /// **'保存失败，请重试'**
  String get s596;

  /// No description provided for @s597.
  ///
  /// In zh_CN, this message translates to:
  /// **'分析失败: {e}'**
  String s597(Object? e);

  /// No description provided for @s598.
  ///
  /// In zh_CN, this message translates to:
  /// **'AI 健康分析'**
  String get s598;

  /// No description provided for @s599.
  ///
  /// In zh_CN, this message translates to:
  /// **'暂无分析数据'**
  String get s599;

  /// No description provided for @s600.
  ///
  /// In zh_CN, this message translates to:
  /// **'开始分析'**
  String get s600;

  /// No description provided for @s601.
  ///
  /// In zh_CN, this message translates to:
  /// **'📝 今日待办'**
  String get s601;

  /// No description provided for @s602.
  ///
  /// In zh_CN, this message translates to:
  /// **'⚠️ 需要关注'**
  String get s602;

  /// No description provided for @s603.
  ///
  /// In zh_CN, this message translates to:
  /// **'💡 健康洞察'**
  String get s603;

  /// No description provided for @s604.
  ///
  /// In zh_CN, this message translates to:
  /// **'🎯 个性化建议'**
  String get s604;

  /// No description provided for @s605.
  ///
  /// In zh_CN, this message translates to:
  /// **'分析时间: {p1}'**
  String s605(Object? p1);

  /// No description provided for @s606.
  ///
  /// In zh_CN, this message translates to:
  /// **'优秀'**
  String get s606;

  /// No description provided for @s607.
  ///
  /// In zh_CN, this message translates to:
  /// **'良好'**
  String get s607;

  /// No description provided for @s608.
  ///
  /// In zh_CN, this message translates to:
  /// **'需改善'**
  String get s608;

  /// No description provided for @s609.
  ///
  /// In zh_CN, this message translates to:
  /// **'健康评分'**
  String get s609;

  /// No description provided for @s610.
  ///
  /// In zh_CN, this message translates to:
  /// **'基于您的健康数据分析'**
  String get s610;

  /// No description provided for @s611.
  ///
  /// In zh_CN, this message translates to:
  /// **'当前: {p1}'**
  String s611(Object? p1);

  /// No description provided for @s612.
  ///
  /// In zh_CN, this message translates to:
  /// **'建议: {p1}'**
  String s612(Object? p1);

  /// No description provided for @s613.
  ///
  /// In zh_CN, this message translates to:
  /// **'紧急'**
  String get s613;

  /// No description provided for @s614.
  ///
  /// In zh_CN, this message translates to:
  /// **'重要'**
  String get s614;

  /// No description provided for @s615.
  ///
  /// In zh_CN, this message translates to:
  /// **'建议'**
  String get s615;

  /// No description provided for @s616.
  ///
  /// In zh_CN, this message translates to:
  /// **'提示'**
  String get s616;

  /// No description provided for @s617.
  ///
  /// In zh_CN, this message translates to:
  /// **'严重'**
  String get s617;

  /// No description provided for @s618.
  ///
  /// In zh_CN, this message translates to:
  /// **'中等'**
  String get s618;

  /// No description provided for @s619.
  ///
  /// In zh_CN, this message translates to:
  /// **'轻微'**
  String get s619;

  /// No description provided for @s620.
  ///
  /// In zh_CN, this message translates to:
  /// **'{p1}分钟前'**
  String s620(Object? p1);

  /// No description provided for @s621.
  ///
  /// In zh_CN, this message translates to:
  /// **'{p1}小时前'**
  String s621(Object? p1);

  /// No description provided for @s622.
  ///
  /// In zh_CN, this message translates to:
  /// **'跌倒事件记录'**
  String get s622;

  /// No description provided for @s623.
  ///
  /// In zh_CN, this message translates to:
  /// **'功能说明'**
  String get s623;

  /// No description provided for @s624.
  ///
  /// In zh_CN, this message translates to:
  /// **'精准检测已启用'**
  String get s624;

  /// No description provided for @s625.
  ///
  /// In zh_CN, this message translates to:
  /// **'已配对 · 后台守护中'**
  String get s625;

  /// No description provided for @s626.
  ///
  /// In zh_CN, this message translates to:
  /// **'未配对'**
  String get s626;

  /// No description provided for @s627.
  ///
  /// In zh_CN, this message translates to:
  /// **'手机端'**
  String get s627;

  /// No description provided for @s628.
  ///
  /// In zh_CN, this message translates to:
  /// **'辅助检测已就绪'**
  String get s628;

  /// No description provided for @s629.
  ///
  /// In zh_CN, this message translates to:
  /// **'{p1} 条记录'**
  String s629(Object? p1);

  /// No description provided for @s630.
  ///
  /// In zh_CN, this message translates to:
  /// **'暂无跌倒事件'**
  String get s630;

  /// No description provided for @s631.
  ///
  /// In zh_CN, this message translates to:
  /// **'系统正在持续监测中。\nApple Watch 提供精准跌倒检测，\n手机端提供辅助加速度检测。'**
  String get s631;

  /// No description provided for @s632.
  ///
  /// In zh_CN, this message translates to:
  /// **'位置'**
  String get s632;

  /// No description provided for @s633.
  ///
  /// In zh_CN, this message translates to:
  /// **'置信度'**
  String get s633;

  /// No description provided for @s634.
  ///
  /// In zh_CN, this message translates to:
  /// **'确认于'**
  String get s634;

  /// No description provided for @s635.
  ///
  /// In zh_CN, this message translates to:
  /// **'确认为误报'**
  String get s635;

  /// No description provided for @s636.
  ///
  /// In zh_CN, this message translates to:
  /// **'已通知守护者'**
  String get s636;

  /// No description provided for @s637.
  ///
  /// In zh_CN, this message translates to:
  /// **'未通知'**
  String get s637;

  /// No description provided for @s638.
  ///
  /// In zh_CN, this message translates to:
  /// **'跌倒检测说明'**
  String get s638;

  /// No description provided for @s639.
  ///
  /// In zh_CN, this message translates to:
  /// **'Apple Watch 精准检测'**
  String get s639;

  /// No description provided for @s640.
  ///
  /// In zh_CN, this message translates to:
  /// **'利用 Watch 高精度加速度传感器，可精准识别跌倒动作。\n需 Apple Watch Series 4 及以上机型。'**
  String get s640;

  /// No description provided for @s641.
  ///
  /// In zh_CN, this message translates to:
  /// **'手机端辅助检测'**
  String get s641;

  /// No description provided for @s642.
  ///
  /// In zh_CN, this message translates to:
  /// **'使用 iPhone 加速度传感器进行简化版跌倒判断。\n精度不如 Watch，但作为备用方案依然可提供基础保护。'**
  String get s642;

  /// No description provided for @s643.
  ///
  /// In zh_CN, this message translates to:
  /// **'通知守护者'**
  String get s643;

  /// No description provided for @s644.
  ///
  /// In zh_CN, this message translates to:
  /// **'当检测到跌倒且您60秒内未响应时，您可确认后通知您设置的守护人。'**
  String get s644;

  /// No description provided for @s645.
  ///
  /// In zh_CN, this message translates to:
  /// **'免责声明'**
  String get s645;

  /// No description provided for @s646.
  ///
  /// In zh_CN, this message translates to:
  /// **'本功能仅作为安全参考辅助工具，不能替代专业的医疗诊断或救助服务。'**
  String get s646;

  /// No description provided for @s647.
  ///
  /// In zh_CN, this message translates to:
  /// **'需要位置权限才能设置围栏'**
  String get s647;

  /// No description provided for @s648.
  ///
  /// In zh_CN, this message translates to:
  /// **'删除围栏'**
  String get s648;

  /// No description provided for @s649.
  ///
  /// In zh_CN, this message translates to:
  /// **'确定要删除「{p1}」这个安全围栏吗？'**
  String s649(Object? p1);

  /// No description provided for @s650.
  ///
  /// In zh_CN, this message translates to:
  /// **'清除所有围栏'**
  String get s650;

  /// No description provided for @s651.
  ///
  /// In zh_CN, this message translates to:
  /// **'确定要删除所有安全围栏吗？此操作不可撤销。'**
  String get s651;

  /// No description provided for @s652.
  ///
  /// In zh_CN, this message translates to:
  /// **'全部清除'**
  String get s652;

  /// No description provided for @s653.
  ///
  /// In zh_CN, this message translates to:
  /// **'安全围栏'**
  String get s653;

  /// No description provided for @s654.
  ///
  /// In zh_CN, this message translates to:
  /// **'清除所有'**
  String get s654;

  /// No description provided for @s655.
  ///
  /// In zh_CN, this message translates to:
  /// **'添加围栏'**
  String get s655;

  /// No description provided for @s656.
  ///
  /// In zh_CN, this message translates to:
  /// **'暂无安全围栏'**
  String get s656;

  /// No description provided for @s657.
  ///
  /// In zh_CN, this message translates to:
  /// **'设置家的位置或常去地点作为安全区域\n离开时你可以选择通知守护者'**
  String get s657;

  /// No description provided for @s658.
  ///
  /// In zh_CN, this message translates to:
  /// **'添加第一个围栏'**
  String get s658;

  /// No description provided for @s659.
  ///
  /// In zh_CN, this message translates to:
  /// **'{p1} · {p2}米范围'**
  String s659(Object? p1, Object? p2);

  /// No description provided for @s660.
  ///
  /// In zh_CN, this message translates to:
  /// **'已启用'**
  String get s660;

  /// No description provided for @s661.
  ///
  /// In zh_CN, this message translates to:
  /// **'已禁用'**
  String get s661;

  /// No description provided for @s662.
  ///
  /// In zh_CN, this message translates to:
  /// **'添加安全围栏'**
  String get s662;

  /// No description provided for @s663.
  ///
  /// In zh_CN, this message translates to:
  /// **'围栏名称'**
  String get s663;

  /// No description provided for @s664.
  ///
  /// In zh_CN, this message translates to:
  /// **'如：家、公司、健身房'**
  String get s664;

  /// No description provided for @s665.
  ///
  /// In zh_CN, this message translates to:
  /// **'类型'**
  String get s665;

  /// No description provided for @s666.
  ///
  /// In zh_CN, this message translates to:
  /// **'家'**
  String get s666;

  /// No description provided for @s667.
  ///
  /// In zh_CN, this message translates to:
  /// **'公司'**
  String get s667;

  /// No description provided for @s668.
  ///
  /// In zh_CN, this message translates to:
  /// **'半径（米）'**
  String get s668;

  /// No description provided for @s669.
  ///
  /// In zh_CN, this message translates to:
  /// **'如：200'**
  String get s669;

  /// No description provided for @s670.
  ///
  /// In zh_CN, this message translates to:
  /// **'米'**
  String get s670;

  /// No description provided for @s671.
  ///
  /// In zh_CN, this message translates to:
  /// **'手动设置坐标（可选）'**
  String get s671;

  /// No description provided for @s672.
  ///
  /// In zh_CN, this message translates to:
  /// **'纬度'**
  String get s672;

  /// No description provided for @s673.
  ///
  /// In zh_CN, this message translates to:
  /// **'经度'**
  String get s673;

  /// No description provided for @s674.
  ///
  /// In zh_CN, this message translates to:
  /// **'留空则使用当前位置'**
  String get s674;

  /// No description provided for @s675.
  ///
  /// In zh_CN, this message translates to:
  /// **'请输入围栏名称'**
  String get s675;

  /// No description provided for @s676.
  ///
  /// In zh_CN, this message translates to:
  /// **'添加'**
  String get s676;

  /// No description provided for @s677.
  ///
  /// In zh_CN, this message translates to:
  /// **'希望你每天都平安快乐 💙'**
  String get s677;

  /// No description provided for @s678.
  ///
  /// In zh_CN, this message translates to:
  /// **'不管多远，我都在乎你 🌟'**
  String get s678;

  /// No description provided for @s679.
  ///
  /// In zh_CN, this message translates to:
  /// **'照顾好自己，有需要随时找我 🤗'**
  String get s679;

  /// No description provided for @s680.
  ///
  /// In zh_CN, this message translates to:
  /// **'你是我最在乎的人 💕'**
  String get s680;

  /// No description provided for @s681.
  ///
  /// In zh_CN, this message translates to:
  /// **'平安是最好的消息，每天报个到吧 🏠'**
  String get s681;

  /// No description provided for @s682.
  ///
  /// In zh_CN, this message translates to:
  /// **'无论何时，你不是一个人 ✨'**
  String get s682;

  /// No description provided for @s683.
  ///
  /// In zh_CN, this message translates to:
  /// **'card/list success=false: {p1}'**
  String s683(Object? p1);

  /// No description provided for @s684.
  ///
  /// In zh_CN, this message translates to:
  /// **'card/list 异常: {e}'**
  String s684(Object? e);

  /// No description provided for @s685.
  ///
  /// In zh_CN, this message translates to:
  /// **'invite/stats success=false: {p1}'**
  String s685(Object? p1);

  /// No description provided for @s686.
  ///
  /// In zh_CN, this message translates to:
  /// **'invite/stats 异常: {e}'**
  String s686(Object? e);

  /// No description provided for @s687.
  ///
  /// In zh_CN, this message translates to:
  /// **'card/list 与 invite/stats 都返回 0'**
  String get s687;

  /// No description provided for @s688.
  ///
  /// In zh_CN, this message translates to:
  /// **'请先登录后再发送守护卡'**
  String get s688;

  /// No description provided for @s689.
  ///
  /// In zh_CN, this message translates to:
  /// **'编辑称呼'**
  String get s689;

  /// No description provided for @s690.
  ///
  /// In zh_CN, this message translates to:
  /// **'对方称呼（必填）'**
  String get s690;

  /// No description provided for @s691.
  ///
  /// In zh_CN, this message translates to:
  /// **'例如：小赵'**
  String get s691;

  /// No description provided for @s692.
  ///
  /// In zh_CN, this message translates to:
  /// **'让对方一眼就知道是你寄出的礼物 💌'**
  String get s692;

  /// No description provided for @s693.
  ///
  /// In zh_CN, this message translates to:
  /// **'请输入对方的称呼'**
  String get s693;

  /// No description provided for @s694.
  ///
  /// In zh_CN, this message translates to:
  /// **'生成守护卡'**
  String get s694;

  /// No description provided for @s695.
  ///
  /// In zh_CN, this message translates to:
  /// **'网络连接失败，已保存到重试队列\n恢复网络后将自动重试'**
  String get s695;

  /// No description provided for @s696.
  ///
  /// In zh_CN, this message translates to:
  /// **'登录已失效，请退出后重新登录'**
  String get s696;

  /// No description provided for @s697.
  ///
  /// In zh_CN, this message translates to:
  /// **'没有可用的守护卡（可能已过期）\n请等待被邀请人注册后可获得新卡片'**
  String get s697;

  /// No description provided for @s698.
  ///
  /// In zh_CN, this message translates to:
  /// **'发卡失败，已保存到重试队列\n点击\"重试\"按钮可重新发送'**
  String get s698;

  /// No description provided for @s699.
  ///
  /// In zh_CN, this message translates to:
  /// **'重试'**
  String get s699;

  /// No description provided for @s700.
  ///
  /// In zh_CN, this message translates to:
  /// **'卡片生成失败，请重试'**
  String get s700;

  /// No description provided for @s701.
  ///
  /// In zh_CN, this message translates to:
  /// **'守护卡 · 在呢'**
  String get s701;

  /// No description provided for @s702.
  ///
  /// In zh_CN, this message translates to:
  /// **'守护卡已生成，但分享失败：{e}'**
  String s702(Object? e);

  /// No description provided for @s703.
  ///
  /// In zh_CN, this message translates to:
  /// **'守护卡已发送 💌'**
  String get s703;

  /// No description provided for @s704.
  ///
  /// In zh_CN, this message translates to:
  /// **'分享失败，请重试'**
  String get s704;

  /// No description provided for @s705.
  ///
  /// In zh_CN, this message translates to:
  /// **'已保存到相册 📷'**
  String get s705;

  /// No description provided for @s706.
  ///
  /// In zh_CN, this message translates to:
  /// **'保存失败'**
  String get s706;

  /// No description provided for @s707.
  ///
  /// In zh_CN, this message translates to:
  /// **'无法同步守护卡额度，请检查网络后重试'**
  String get s707;

  /// No description provided for @s708.
  ///
  /// In zh_CN, this message translates to:
  /// **'诊断：{_syncError}'**
  String s708(Object? _syncError);

  /// No description provided for @s709.
  ///
  /// In zh_CN, this message translates to:
  /// **'card/list 与 invite/stats 都返回 0 或失败'**
  String get s709;

  /// No description provided for @s710.
  ///
  /// In zh_CN, this message translates to:
  /// **'同步成功，剩余 {_availableCards} 张守护卡'**
  String s710(Object? _availableCards);

  /// No description provided for @s711.
  ///
  /// In zh_CN, this message translates to:
  /// **'同步失败，请稍后重试'**
  String get s711;

  /// No description provided for @s712.
  ///
  /// In zh_CN, this message translates to:
  /// **'有守护卡发送失败，可重试'**
  String get s712;

  /// No description provided for @s713.
  ///
  /// In zh_CN, this message translates to:
  /// **'您尚未登录，发送守护卡需要登录账号'**
  String get s713;

  /// No description provided for @s714.
  ///
  /// In zh_CN, this message translates to:
  /// **'去登录'**
  String get s714;

  /// No description provided for @s715.
  ///
  /// In zh_CN, this message translates to:
  /// **'发送守护卡'**
  String get s715;

  /// No description provided for @s716.
  ///
  /// In zh_CN, this message translates to:
  /// **'守护卡即将上线'**
  String get s716;

  /// No description provided for @s717.
  ///
  /// In zh_CN, this message translates to:
  /// **'给在乎的人发一张守护卡\n让他们感受到跨越距离的关心'**
  String get s717;

  /// No description provided for @s718.
  ///
  /// In zh_CN, this message translates to:
  /// **'精美守护卡'**
  String get s718;

  /// No description provided for @s719.
  ///
  /// In zh_CN, this message translates to:
  /// **'多款温暖设计的卡片模板'**
  String get s719;

  /// No description provided for @s720.
  ///
  /// In zh_CN, this message translates to:
  /// **'3D 仪式感'**
  String get s720;

  /// No description provided for @s721.
  ///
  /// In zh_CN, this message translates to:
  /// **'沉浸式信封开封动画体验'**
  String get s721;

  /// No description provided for @s722.
  ///
  /// In zh_CN, this message translates to:
  /// **'情感裂变'**
  String get s722;

  /// No description provided for @s723.
  ///
  /// In zh_CN, this message translates to:
  /// **'通过守护卡建立真实的联系'**
  String get s723;

  /// No description provided for @s724.
  ///
  /// In zh_CN, this message translates to:
  /// **'Android 敬请期待'**
  String get s724;

  /// No description provided for @s725.
  ///
  /// In zh_CN, this message translates to:
  /// **'Android 版本正在全速开发中\n我们希望能为你带来最极致的守护体验'**
  String get s725;

  /// No description provided for @s726.
  ///
  /// In zh_CN, this message translates to:
  /// **'剩余守护卡: {_availableCards} 张'**
  String s726(Object? _availableCards);

  /// No description provided for @s727.
  ///
  /// In zh_CN, this message translates to:
  /// **'等待收卡人注册...'**
  String get s727;

  /// No description provided for @s728.
  ///
  /// In zh_CN, this message translates to:
  /// **'守护卡已过期 — 签到解锁新卡'**
  String get s728;

  /// No description provided for @s729.
  ///
  /// In zh_CN, this message translates to:
  /// **'守护卡已用完 — 邀请好友注册解锁'**
  String get s729;

  /// No description provided for @s730.
  ///
  /// In zh_CN, this message translates to:
  /// **'守护卡已用完'**
  String get s730;

  /// No description provided for @s731.
  ///
  /// In zh_CN, this message translates to:
  /// **'{_availableCards} 张'**
  String s731(Object? _availableCards);

  /// No description provided for @s732.
  ///
  /// In zh_CN, this message translates to:
  /// **'24h内注册'**
  String get s732;

  /// No description provided for @s733.
  ///
  /// In zh_CN, this message translates to:
  /// **'再签{remainingDays}天'**
  String s733(Object? remainingDays);

  /// No description provided for @s734.
  ///
  /// In zh_CN, this message translates to:
  /// **'可解锁'**
  String get s734;

  /// No description provided for @s735.
  ///
  /// In zh_CN, this message translates to:
  /// **'加载中'**
  String get s735;

  /// No description provided for @s736.
  ///
  /// In zh_CN, this message translates to:
  /// **'待解锁'**
  String get s736;

  /// No description provided for @s737.
  ///
  /// In zh_CN, this message translates to:
  /// **'{_availableCards} 张可用'**
  String s737(Object? _availableCards);

  /// No description provided for @s738.
  ///
  /// In zh_CN, this message translates to:
  /// **'初始卡剩余有效期: {_initialRemainingDays} 天'**
  String s738(Object? _initialRemainingDays);

  /// No description provided for @s739.
  ///
  /// In zh_CN, this message translates to:
  /// **'24小时内未注册将自动返回'**
  String get s739;

  /// No description provided for @s740.
  ///
  /// In zh_CN, this message translates to:
  /// **'累计签到 {totalDays} 天 — 签到 {targetDays} 天解锁 1 张守护卡'**
  String s740(Object? totalDays, Object? targetDays);

  /// No description provided for @s741.
  ///
  /// In zh_CN, this message translates to:
  /// **'📖 签到解锁规则'**
  String get s741;

  /// No description provided for @s742.
  ///
  /// In zh_CN, this message translates to:
  /// **'• 累计签到（不是连续！）'**
  String get s742;

  /// No description provided for @s743.
  ///
  /// In zh_CN, this message translates to:
  /// **'• 断签不会清空累计天数'**
  String get s743;

  /// No description provided for @s744.
  ///
  /// In zh_CN, this message translates to:
  /// **'• 解锁档位：3/7/14/30 天'**
  String get s744;

  /// No description provided for @s745.
  ///
  /// In zh_CN, this message translates to:
  /// **'💡 放心签到，断签也不怕！'**
  String get s745;

  /// No description provided for @s746.
  ///
  /// In zh_CN, this message translates to:
  /// **'已守护 {_totalRegistered} 人 — 继续邀请获得更多守护卡'**
  String s746(Object? _totalRegistered);

  /// No description provided for @s747.
  ///
  /// In zh_CN, this message translates to:
  /// **'已发出 {p1} 张卡'**
  String s747(Object? p1);

  /// No description provided for @s748.
  ///
  /// In zh_CN, this message translates to:
  /// **'收起'**
  String get s748;

  /// No description provided for @s749.
  ///
  /// In zh_CN, this message translates to:
  /// **'展开'**
  String get s749;

  /// No description provided for @s750.
  ///
  /// In zh_CN, this message translates to:
  /// **'他们还没来（{p1}）'**
  String s750(Object? p1);

  /// No description provided for @s751.
  ///
  /// In zh_CN, this message translates to:
  /// **'已过期'**
  String get s751;

  /// No description provided for @s752.
  ///
  /// In zh_CN, this message translates to:
  /// **'剩 {h} 小时 {m} 分'**
  String s752(Object? h, Object? m);

  /// No description provided for @s753.
  ///
  /// In zh_CN, this message translates to:
  /// **'剩 {m} 分 {s} 秒'**
  String s753(Object? m, Object? s);

  /// No description provided for @s754.
  ///
  /// In zh_CN, this message translates to:
  /// **'卡片已自动退回'**
  String get s754;

  /// No description provided for @s755.
  ///
  /// In zh_CN, this message translates to:
  /// **'即将过期'**
  String get s755;

  /// No description provided for @s756.
  ///
  /// In zh_CN, this message translates to:
  /// **'守护码已复制'**
  String get s756;

  /// No description provided for @s757.
  ///
  /// In zh_CN, this message translates to:
  /// **'提醒TA'**
  String get s757;

  /// No description provided for @s758.
  ///
  /// In zh_CN, this message translates to:
  /// **'点击「提醒TA」选择一句关心的话，复制后去微信粘贴发送'**
  String get s758;

  /// No description provided for @s759.
  ///
  /// In zh_CN, this message translates to:
  /// **'我发了一张守护卡给你，还没收到吗？\n👇 点击链接接受我的守护\n{shareUrl}'**
  String s759(Object? shareUrl);

  /// No description provided for @s760.
  ///
  /// In zh_CN, this message translates to:
  /// **'给你发的守护卡快过期啦～\n点击链接让我知道你在呢 💛\n{shareUrl}'**
  String s760(Object? shareUrl);

  /// No description provided for @s761.
  ///
  /// In zh_CN, this message translates to:
  /// **'守护卡都要过期了，你人呢？😂\n赶紧点击链接，让我继续守护你！\n{shareUrl}'**
  String s761(Object? shareUrl);

  /// No description provided for @s762.
  ///
  /// In zh_CN, this message translates to:
  /// **'我发了一张守护卡给你 👇\n点击链接领取\n{shareUrl}'**
  String s762(Object? shareUrl);

  /// No description provided for @s763.
  ///
  /// In zh_CN, this message translates to:
  /// **'把关心发给TA'**
  String get s763;

  /// No description provided for @s764.
  ///
  /// In zh_CN, this message translates to:
  /// **'换一句'**
  String get s764;

  /// No description provided for @s765.
  ///
  /// In zh_CN, this message translates to:
  /// **'复制并打开微信'**
  String get s765;

  /// No description provided for @s766.
  ///
  /// In zh_CN, this message translates to:
  /// **'重试完成：成功{succeeded}/{retried} 条{p1}'**
  String s766(Object? succeeded, Object? retried, Object? p1);

  /// No description provided for @s767.
  ///
  /// In zh_CN, this message translates to:
  /// **'重试失败，请稍后重试'**
  String get s767;

  /// No description provided for @s768.
  ///
  /// In zh_CN, this message translates to:
  /// **'重试异常：{e}'**
  String s768(Object? e);

  /// No description provided for @s769.
  ///
  /// In zh_CN, this message translates to:
  /// **'已邀请 {_invitedCount} 人加入'**
  String s769(Object? _invitedCount);

  /// No description provided for @s770.
  ///
  /// In zh_CN, this message translates to:
  /// **'获赠 {_invitedCount} 张'**
  String s770(Object? _invitedCount);

  /// No description provided for @s771.
  ///
  /// In zh_CN, this message translates to:
  /// **'对方的称呼（选填），如\"妈妈\"'**
  String get s771;

  /// No description provided for @s772.
  ///
  /// In zh_CN, this message translates to:
  /// **'选择祝福语'**
  String get s772;

  /// No description provided for @s773.
  ///
  /// In zh_CN, this message translates to:
  /// **'自定义祝福语'**
  String get s773;

  /// No description provided for @s774.
  ///
  /// In zh_CN, this message translates to:
  /// **'写下你想说的话...'**
  String get s774;

  /// No description provided for @s775.
  ///
  /// In zh_CN, this message translates to:
  /// **'保存到相册'**
  String get s775;

  /// No description provided for @s776.
  ///
  /// In zh_CN, this message translates to:
  /// **'生命体征守护'**
  String get s776;

  /// No description provided for @s777.
  ///
  /// In zh_CN, this message translates to:
  /// **'守护指标'**
  String get s777;

  /// No description provided for @s778.
  ///
  /// In zh_CN, this message translates to:
  /// **'记录今日体征，随时可主动分享'**
  String get s778;

  /// No description provided for @s779.
  ///
  /// In zh_CN, this message translates to:
  /// **'异常时会提醒你向守护圈报平安'**
  String get s779;

  /// No description provided for @s780.
  ///
  /// In zh_CN, this message translates to:
  /// **'请前往 iPhone 授权健康数据'**
  String get s780;

  /// No description provided for @s781.
  ///
  /// In zh_CN, this message translates to:
  /// **'iOS「设置 → 健康 → 数据来源与访问权限 → 在呢+ → 全部打开」，授权后本页数据会立即同步。'**
  String get s781;

  /// No description provided for @s782.
  ///
  /// In zh_CN, this message translates to:
  /// **'重新检测'**
  String get s782;

  /// No description provided for @s783.
  ///
  /// In zh_CN, this message translates to:
  /// **'正在读取…'**
  String get s783;

  /// No description provided for @s784.
  ///
  /// In zh_CN, this message translates to:
  /// **'同步中…'**
  String get s784;

  /// No description provided for @s785.
  ///
  /// In zh_CN, this message translates to:
  /// **'同步并向守护圈报平安'**
  String get s785;

  /// No description provided for @s786.
  ///
  /// In zh_CN, this message translates to:
  /// **'数据同步于 {_lastUpdated}'**
  String s786(Object? _lastUpdated);

  /// No description provided for @s787.
  ///
  /// In zh_CN, this message translates to:
  /// **'尚未同步健康数据'**
  String get s787;

  /// No description provided for @s788.
  ///
  /// In zh_CN, this message translates to:
  /// **'同步成功，已向守护圈报平安 ❤️'**
  String get s788;

  /// No description provided for @s789.
  ///
  /// In zh_CN, this message translates to:
  /// **'异常时自动通知守护圈'**
  String get s789;

  /// No description provided for @s790.
  ///
  /// In zh_CN, this message translates to:
  /// **'检测到长时间无活动等异常，会自动替你报信'**
  String get s790;

  /// No description provided for @s791.
  ///
  /// In zh_CN, this message translates to:
  /// **'已关闭，异常只在 App 内提醒你本人'**
  String get s791;

  /// No description provided for @s792.
  ///
  /// In zh_CN, this message translates to:
  /// **'已开启：异常时会自动通知守护圈'**
  String get s792;

  /// No description provided for @s793.
  ///
  /// In zh_CN, this message translates to:
  /// **'已关闭：异常仅在 App 内提醒你'**
  String get s793;

  /// No description provided for @s794.
  ///
  /// In zh_CN, this message translates to:
  /// **'血液含氧量'**
  String get s794;

  /// No description provided for @s795.
  ///
  /// In zh_CN, this message translates to:
  /// **'步行稳定性'**
  String get s795;

  /// No description provided for @s796.
  ///
  /// In zh_CN, this message translates to:
  /// **'血压'**
  String get s796;

  /// No description provided for @s797.
  ///
  /// In zh_CN, this message translates to:
  /// **'单位: mmHg'**
  String get s797;

  /// No description provided for @s798.
  ///
  /// In zh_CN, this message translates to:
  /// **'今日活动'**
  String get s798;

  /// No description provided for @s799.
  ///
  /// In zh_CN, this message translates to:
  /// **'{steps} 步'**
  String s799(Object? steps);

  /// No description provided for @s800.
  ///
  /// In zh_CN, this message translates to:
  /// **'运动 {exercise} 分钟 · 站立 {stand} 小时'**
  String s800(Object? exercise, Object? stand);

  /// No description provided for @s801.
  ///
  /// In zh_CN, this message translates to:
  /// **'需佩戴 Apple Watch'**
  String get s801;

  /// No description provided for @s802.
  ///
  /// In zh_CN, this message translates to:
  /// **'今日 {min}–{max} bpm'**
  String s802(Object? min, Object? max);

  /// No description provided for @s803.
  ///
  /// In zh_CN, this message translates to:
  /// **'过去24小时'**
  String get s803;

  /// No description provided for @s804.
  ///
  /// In zh_CN, this message translates to:
  /// **'跌倒风险评估'**
  String get s804;

  /// No description provided for @s805.
  ///
  /// In zh_CN, this message translates to:
  /// **'稳定 · 跌倒风险低'**
  String get s805;

  /// No description provided for @s806.
  ///
  /// In zh_CN, this message translates to:
  /// **'尚可 · 建议留意'**
  String get s806;

  /// No description provided for @s807.
  ///
  /// In zh_CN, this message translates to:
  /// **'偏低 · 跌倒风险高'**
  String get s807;

  /// No description provided for @s808.
  ///
  /// In zh_CN, this message translates to:
  /// **'数据异常'**
  String get s808;

  /// No description provided for @s809.
  ///
  /// In zh_CN, this message translates to:
  /// **'昨晚睡眠'**
  String get s809;

  /// No description provided for @s810.
  ///
  /// In zh_CN, this message translates to:
  /// **'{hours}小时{minutes}分'**
  String s810(Object? hours, Object? minutes);

  /// No description provided for @s811.
  ///
  /// In zh_CN, this message translates to:
  /// **'暂无数据'**
  String get s811;

  /// No description provided for @s812.
  ///
  /// In zh_CN, this message translates to:
  /// **'深度睡眠'**
  String get s812;

  /// No description provided for @s813.
  ///
  /// In zh_CN, this message translates to:
  /// **'核心睡眠'**
  String get s813;

  /// No description provided for @s814.
  ///
  /// In zh_CN, this message translates to:
  /// **'数据来源：HealthKit（可能包含 iPhone 和 Apple Watch）'**
  String get s814;

  /// No description provided for @s815.
  ///
  /// In zh_CN, this message translates to:
  /// **'经期中'**
  String get s815;

  /// No description provided for @s816.
  ///
  /// In zh_CN, this message translates to:
  /// **'非经期'**
  String get s816;

  /// No description provided for @s817.
  ///
  /// In zh_CN, this message translates to:
  /// **'未开启跟踪'**
  String get s817;

  /// No description provided for @s818.
  ///
  /// In zh_CN, this message translates to:
  /// **'女性经期跟踪'**
  String get s818;

  /// No description provided for @s819.
  ///
  /// In zh_CN, this message translates to:
  /// **'第{cycleDay}天'**
  String s819(Object? cycleDay);

  /// No description provided for @s820.
  ///
  /// In zh_CN, this message translates to:
  /// **'平均周期'**
  String get s820;

  /// No description provided for @s821.
  ///
  /// In zh_CN, this message translates to:
  /// **'{avgCycle}天'**
  String s821(Object? avgCycle);

  /// No description provided for @s822.
  ///
  /// In zh_CN, this message translates to:
  /// **'预测下次'**
  String get s822;

  /// No description provided for @s823.
  ///
  /// In zh_CN, this message translates to:
  /// **'数据不足'**
  String get s823;

  /// No description provided for @s824.
  ///
  /// In zh_CN, this message translates to:
  /// **'可手动记录经期日期，系统将自动计算周期并预测下次经期时间'**
  String get s824;

  /// No description provided for @s825.
  ///
  /// In zh_CN, this message translates to:
  /// **'记录经期'**
  String get s825;

  /// No description provided for @s826.
  ///
  /// In zh_CN, this message translates to:
  /// **'开始记录'**
  String get s826;

  /// No description provided for @s827.
  ///
  /// In zh_CN, this message translates to:
  /// **'明天'**
  String get s827;

  /// No description provided for @s828.
  ///
  /// In zh_CN, this message translates to:
  /// **'{diff}天后'**
  String s828(Object? diff);

  /// No description provided for @s829.
  ///
  /// In zh_CN, this message translates to:
  /// **'更多身体数据'**
  String get s829;

  /// No description provided for @s830.
  ///
  /// In zh_CN, this message translates to:
  /// **'静息心率'**
  String get s830;

  /// No description provided for @s831.
  ///
  /// In zh_CN, this message translates to:
  /// **'心率变异性 HRV'**
  String get s831;

  /// No description provided for @s832.
  ///
  /// In zh_CN, this message translates to:
  /// **'呼吸频率'**
  String get s832;

  /// No description provided for @s833.
  ///
  /// In zh_CN, this message translates to:
  /// **'次/分'**
  String get s833;

  /// No description provided for @s834.
  ///
  /// In zh_CN, this message translates to:
  /// **'手腕温度'**
  String get s834;

  /// No description provided for @s835.
  ///
  /// In zh_CN, this message translates to:
  /// **'需佩戴过夜'**
  String get s835;

  /// No description provided for @s836.
  ///
  /// In zh_CN, this message translates to:
  /// **'行走距离'**
  String get s836;

  /// No description provided for @s837.
  ///
  /// In zh_CN, this message translates to:
  /// **'活跃能量'**
  String get s837;

  /// No description provided for @s838.
  ///
  /// In zh_CN, this message translates to:
  /// **'千卡'**
  String get s838;

  /// No description provided for @s839.
  ///
  /// In zh_CN, this message translates to:
  /// **'心电图 · 听力 · 体能等完整数据'**
  String get s839;

  /// No description provided for @s840.
  ///
  /// In zh_CN, this message translates to:
  /// **'这些数据 Apple 仅在系统「健康」App 中开放'**
  String get s840;

  /// No description provided for @s841.
  ///
  /// In zh_CN, this message translates to:
  /// **'请在 iPhone 上打开系统「健康」App 查看'**
  String get s841;

  /// No description provided for @s842.
  ///
  /// In zh_CN, this message translates to:
  /// **'健康数据由 Apple HealthKit 提供\n仅供参考，不作为医疗诊断依据'**
  String get s842;

  /// No description provided for @s843.
  ///
  /// In zh_CN, this message translates to:
  /// **'✅ 位置权限已开启！'**
  String get s843;

  /// No description provided for @s844.
  ///
  /// In zh_CN, this message translates to:
  /// **'需要位置权限'**
  String get s844;

  /// No description provided for @s845.
  ///
  /// In zh_CN, this message translates to:
  /// **'您之前拒绝了位置权限，请在系统设置中开启。\n\n设置路径：\n隐私 → 定位服务 → 在呢 → \"使用App期间\"'**
  String get s845;

  /// No description provided for @s846.
  ///
  /// In zh_CN, this message translates to:
  /// **'去设置'**
  String get s846;

  /// No description provided for @s847.
  ///
  /// In zh_CN, this message translates to:
  /// **'位置权限未开启。紧急求助需要您的位置才能发送求救信息'**
  String get s847;

  /// No description provided for @s848.
  ///
  /// In zh_CN, this message translates to:
  /// **'位置权限仍未开启，请确保已设置为「使用期间允许」'**
  String get s848;

  /// No description provided for @s849.
  ///
  /// In zh_CN, this message translates to:
  /// **'北纬 {p1}°'**
  String s849(Object? p1);

  /// No description provided for @s850.
  ///
  /// In zh_CN, this message translates to:
  /// **'东经 {p1}°'**
  String s850(Object? p1);

  /// No description provided for @s851.
  ///
  /// In zh_CN, this message translates to:
  /// **'紧急求助'**
  String get s851;

  /// No description provided for @s852.
  ///
  /// In zh_CN, this message translates to:
  /// **'紧急求助页面加载异常'**
  String get s852;

  /// No description provided for @s853.
  ///
  /// In zh_CN, this message translates to:
  /// **'错误信息: {e}'**
  String s853(Object? e);

  /// No description provided for @s854.
  ///
  /// In zh_CN, this message translates to:
  /// **'档案'**
  String get s854;

  /// No description provided for @s855.
  ///
  /// In zh_CN, this message translates to:
  /// **'联系人'**
  String get s855;

  /// No description provided for @s856.
  ///
  /// In zh_CN, this message translates to:
  /// **'定位'**
  String get s856;

  /// No description provided for @s857.
  ///
  /// In zh_CN, this message translates to:
  /// **'📱 设置手机号'**
  String get s857;

  /// No description provided for @s858.
  ///
  /// In zh_CN, this message translates to:
  /// **'设置后，紧急求助短信中将包含您的手机号'**
  String get s858;

  /// No description provided for @s859.
  ///
  /// In zh_CN, this message translates to:
  /// **'手机号'**
  String get s859;

  /// No description provided for @s860.
  ///
  /// In zh_CN, this message translates to:
  /// **'请输入正确的11位手机号'**
  String get s860;

  /// No description provided for @s861.
  ///
  /// In zh_CN, this message translates to:
  /// **'手机号已设置为 {normalizedPhone}'**
  String s861(Object? normalizedPhone);

  /// No description provided for @s862.
  ///
  /// In zh_CN, this message translates to:
  /// **'北纬 '**
  String get s862;

  /// No description provided for @s863.
  ///
  /// In zh_CN, this message translates to:
  /// **'东经 '**
  String get s863;

  /// No description provided for @s864.
  ///
  /// In zh_CN, this message translates to:
  /// **'北纬 {p1}°'**
  String s864(Object? p1);

  /// No description provided for @s865.
  ///
  /// In zh_CN, this message translates to:
  /// **'东经 {p1}°'**
  String s865(Object? p1);

  /// No description provided for @s866.
  ///
  /// In zh_CN, this message translates to:
  /// **'未知地址'**
  String get s866;

  /// No description provided for @s867.
  ///
  /// In zh_CN, this message translates to:
  /// **'【在呢 紧急求助】'**
  String get s867;

  /// No description provided for @s868.
  ///
  /// In zh_CN, this message translates to:
  /// **'求救人：{p1}'**
  String s868(Object? p1);

  /// No description provided for @s869.
  ///
  /// In zh_CN, this message translates to:
  /// **'手机号：{p1}'**
  String s869(Object? p1);

  /// No description provided for @s870.
  ///
  /// In zh_CN, this message translates to:
  /// **'年龄：{p1}'**
  String s870(Object? p1);

  /// No description provided for @s871.
  ///
  /// In zh_CN, this message translates to:
  /// **'血型：{_bloodType}'**
  String s871(Object? _bloodType);

  /// No description provided for @s872.
  ///
  /// In zh_CN, this message translates to:
  /// **'病史：{_disease}'**
  String s872(Object? _disease);

  /// No description provided for @s873.
  ///
  /// In zh_CN, this message translates to:
  /// **'药物：{_medicine}'**
  String s873(Object? _medicine);

  /// No description provided for @s874.
  ///
  /// In zh_CN, this message translates to:
  /// **'过敏：{_allergy}'**
  String s874(Object? _allergy);

  /// No description provided for @s875.
  ///
  /// In zh_CN, this message translates to:
  /// **'备注：{_emergencyNote}'**
  String s875(Object? _emergencyNote);

  /// No description provided for @s876.
  ///
  /// In zh_CN, this message translates to:
  /// **'区'**
  String get s876;

  /// No description provided for @s877.
  ///
  /// In zh_CN, this message translates to:
  /// **'区 '**
  String get s877;

  /// No description provided for @s878.
  ///
  /// In zh_CN, this message translates to:
  /// **'县'**
  String get s878;

  /// No description provided for @s879.
  ///
  /// In zh_CN, this message translates to:
  /// **'县 '**
  String get s879;

  /// No description provided for @s880.
  ///
  /// In zh_CN, this message translates to:
  /// **'市'**
  String get s880;

  /// No description provided for @s881.
  ///
  /// In zh_CN, this message translates to:
  /// **'市 '**
  String get s881;

  /// No description provided for @s882.
  ///
  /// In zh_CN, this message translates to:
  /// **'地址：{addrBroken}'**
  String s882(Object? addrBroken);

  /// No description provided for @s883.
  ///
  /// In zh_CN, this message translates to:
  /// **'🍎 苹果地图导航'**
  String get s883;

  /// No description provided for @s884.
  ///
  /// In zh_CN, this message translates to:
  /// **'📍 Google Maps 导航'**
  String get s884;

  /// No description provided for @s885.
  ///
  /// In zh_CN, this message translates to:
  /// **'⚠️ 位置获取失败，请立即回拨确认位置！'**
  String get s885;

  /// No description provided for @s886.
  ///
  /// In zh_CN, this message translates to:
  /// **'如果方便，请描述您当前的位置（如：XX路口、XX小区、XX商场附近）'**
  String get s886;

  /// No description provided for @s887.
  ///
  /// In zh_CN, this message translates to:
  /// **'请立即联系我或拨打{num}！'**
  String s887(Object num);

  /// No description provided for @s888.
  ///
  /// In zh_CN, this message translates to:
  /// **'在呢 - 独居守护App'**
  String get s888;

  /// No description provided for @s889.
  ///
  /// In zh_CN, this message translates to:
  /// **'你'**
  String get s889;

  /// No description provided for @s890.
  ///
  /// In zh_CN, this message translates to:
  /// **'【在呢·紧急求助】{r}，我是{s}。我可能遇到了危险，已经通过「在呢」把我的实时位置和求助信息发出去了。请你马上点开下面的链接看我的位置，并帮我拨打{num}急救电话！ {shortUrl}'**
  String s890(Object? r, Object? s, Object? shortUrl, Object num);

  /// No description provided for @s891.
  ///
  /// In zh_CN, this message translates to:
  /// **'位置记录'**
  String get s891;

  /// No description provided for @s892.
  ///
  /// In zh_CN, this message translates to:
  /// **'选择日期'**
  String get s892;

  /// No description provided for @s893.
  ///
  /// In zh_CN, this message translates to:
  /// **'yyyy年MM月dd日'**
  String get s893;

  /// No description provided for @s894.
  ///
  /// In zh_CN, this message translates to:
  /// **'切换'**
  String get s894;

  /// No description provided for @s895.
  ///
  /// In zh_CN, this message translates to:
  /// **'暂无位置记录'**
  String get s895;

  /// No description provided for @s896.
  ///
  /// In zh_CN, this message translates to:
  /// **'开启位置追踪后，每5分钟记录一次位置'**
  String get s896;

  /// No description provided for @s897.
  ///
  /// In zh_CN, this message translates to:
  /// **'位置记录 {p1}'**
  String s897(Object? p1);

  /// No description provided for @s898.
  ///
  /// In zh_CN, this message translates to:
  /// **'精度±{p1}m'**
  String s898(Object? p1);

  /// No description provided for @s899.
  ///
  /// In zh_CN, this message translates to:
  /// **'纬度: {p1}'**
  String s899(Object? p1);

  /// No description provided for @s900.
  ///
  /// In zh_CN, this message translates to:
  /// **'经度: {p1}'**
  String s900(Object? p1);

  /// No description provided for @s901.
  ///
  /// In zh_CN, this message translates to:
  /// **'定位精度约 {p1} 米（数值越小越精确）'**
  String s901(Object? p1);

  /// No description provided for @s902.
  ///
  /// In zh_CN, this message translates to:
  /// **'静止'**
  String get s902;

  /// No description provided for @s903.
  ///
  /// In zh_CN, this message translates to:
  /// **'行走'**
  String get s903;

  /// No description provided for @s904.
  ///
  /// In zh_CN, this message translates to:
  /// **'跑步'**
  String get s904;

  /// No description provided for @s905.
  ///
  /// In zh_CN, this message translates to:
  /// **'骑行'**
  String get s905;

  /// No description provided for @s906.
  ///
  /// In zh_CN, this message translates to:
  /// **'驾驶'**
  String get s906;

  /// No description provided for @s907.
  ///
  /// In zh_CN, this message translates to:
  /// **'今日轨迹'**
  String get s907;

  /// No description provided for @s908.
  ///
  /// In zh_CN, this message translates to:
  /// **'轨迹列表'**
  String get s908;

  /// No description provided for @s909.
  ///
  /// In zh_CN, this message translates to:
  /// **'今日暂无轨迹记录'**
  String get s909;

  /// No description provided for @s910.
  ///
  /// In zh_CN, this message translates to:
  /// **'开启位置共享后，这里会显示你的活动地图'**
  String get s910;

  /// No description provided for @s911.
  ///
  /// In zh_CN, this message translates to:
  /// **'今日移动'**
  String get s911;

  /// No description provided for @s912.
  ///
  /// In zh_CN, this message translates to:
  /// **'活动范围'**
  String get s912;

  /// No description provided for @s913.
  ///
  /// In zh_CN, this message translates to:
  /// **'0分'**
  String get s913;

  /// No description provided for @s914.
  ///
  /// In zh_CN, this message translates to:
  /// **'围栏内停留'**
  String get s914;

  /// No description provided for @s915.
  ///
  /// In zh_CN, this message translates to:
  /// **'{h}时{p1}分'**
  String s915(Object? h, Object? p1);

  /// No description provided for @s916.
  ///
  /// In zh_CN, this message translates to:
  /// **'{min}分'**
  String s916(Object? min);

  /// No description provided for @s917.
  ///
  /// In zh_CN, this message translates to:
  /// **'记录已保存'**
  String get s917;

  /// No description provided for @s918.
  ///
  /// In zh_CN, this message translates to:
  /// **'经期记录'**
  String get s918;

  /// No description provided for @s919.
  ///
  /// In zh_CN, this message translates to:
  /// **'开始日期'**
  String get s919;

  /// No description provided for @s920.
  ///
  /// In zh_CN, this message translates to:
  /// **'选择开始日期'**
  String get s920;

  /// No description provided for @s921.
  ///
  /// In zh_CN, this message translates to:
  /// **'结束日期（可选）'**
  String get s921;

  /// No description provided for @s922.
  ///
  /// In zh_CN, this message translates to:
  /// **'选择结束日期'**
  String get s922;

  /// No description provided for @s923.
  ///
  /// In zh_CN, this message translates to:
  /// **'流量级别'**
  String get s923;

  /// No description provided for @s924.
  ///
  /// In zh_CN, this message translates to:
  /// **'症状（可选）'**
  String get s924;

  /// No description provided for @s925.
  ///
  /// In zh_CN, this message translates to:
  /// **'备注（可选）'**
  String get s925;

  /// No description provided for @s926.
  ///
  /// In zh_CN, this message translates to:
  /// **'记录你的感受...'**
  String get s926;

  /// No description provided for @s927.
  ///
  /// In zh_CN, this message translates to:
  /// **'保存记录'**
  String get s927;

  /// No description provided for @s928.
  ///
  /// In zh_CN, this message translates to:
  /// **'开始使用'**
  String get s928;

  /// No description provided for @s929.
  ///
  /// In zh_CN, this message translates to:
  /// **'输入手机号，即刻开启安全守护'**
  String get s929;

  /// No description provided for @s930.
  ///
  /// In zh_CN, this message translates to:
  /// **'手机号登录，即刻开启'**
  String get s930;

  /// No description provided for @s931.
  ///
  /// In zh_CN, this message translates to:
  /// **'请输入手机号'**
  String get s931;

  /// No description provided for @s932.
  ///
  /// In zh_CN, this message translates to:
  /// **'有人给你发守护码了？'**
  String get s932;

  /// No description provided for @s933.
  ///
  /// In zh_CN, this message translates to:
  /// **'输入守护码，一键完成绑定 →'**
  String get s933;

  /// No description provided for @s934.
  ///
  /// In zh_CN, this message translates to:
  /// **'在呢，守护独居的你'**
  String get s934;

  /// No description provided for @s935.
  ///
  /// In zh_CN, this message translates to:
  /// **'输入守护码'**
  String get s935;

  /// No description provided for @s936.
  ///
  /// In zh_CN, this message translates to:
  /// **'守护码由对方提供，输入后即可与对方建立守护关系'**
  String get s936;

  /// No description provided for @s937.
  ///
  /// In zh_CN, this message translates to:
  /// **'例如: TFABT4'**
  String get s937;

  /// No description provided for @s938.
  ///
  /// In zh_CN, this message translates to:
  /// **'请输入守护码'**
  String get s938;

  /// No description provided for @s939.
  ///
  /// In zh_CN, this message translates to:
  /// **'守护码至少4位'**
  String get s939;

  /// No description provided for @s940.
  ///
  /// In zh_CN, this message translates to:
  /// **'无效的守护码'**
  String get s940;

  /// No description provided for @s941.
  ///
  /// In zh_CN, this message translates to:
  /// **'验证失败，请检查网络'**
  String get s941;

  /// No description provided for @s942.
  ///
  /// In zh_CN, this message translates to:
  /// **'✅ 守护码已保存，登录后将自动绑定'**
  String get s942;

  /// No description provided for @s943.
  ///
  /// In zh_CN, this message translates to:
  /// **'确认'**
  String get s943;

  /// No description provided for @s944.
  ///
  /// In zh_CN, this message translates to:
  /// **'Apple 登录失败：{p1}'**
  String s944(Object? p1);

  /// No description provided for @s945.
  ///
  /// In zh_CN, this message translates to:
  /// **'Apple 登录失败：{e}'**
  String s945(Object? e);

  /// No description provided for @s946.
  ///
  /// In zh_CN, this message translates to:
  /// **'独居生活的贴心守护者'**
  String get s946;

  /// No description provided for @s947.
  ///
  /// In zh_CN, this message translates to:
  /// **'每一个独居的夜晚\n你并不孤单'**
  String get s947;

  /// No description provided for @s948.
  ///
  /// In zh_CN, this message translates to:
  /// **'守护你的每个夜晚'**
  String get s948;

  /// No description provided for @s949.
  ///
  /// In zh_CN, this message translates to:
  /// **'需要时主动发出求助'**
  String get s949;

  /// No description provided for @s950.
  ///
  /// In zh_CN, this message translates to:
  /// **'实时定位，守护者即刻响应'**
  String get s950;

  /// No description provided for @s951.
  ///
  /// In zh_CN, this message translates to:
  /// **'让爱你的人不再提心吊胆'**
  String get s951;

  /// No description provided for @s952.
  ///
  /// In zh_CN, this message translates to:
  /// **'在呢 — 让在乎你的人知道你很好'**
  String get s952;

  /// No description provided for @s953.
  ///
  /// In zh_CN, this message translates to:
  /// **'完善你的健康档案'**
  String get s953;

  /// No description provided for @s954.
  ///
  /// In zh_CN, this message translates to:
  /// **'让救援人员在第一时间了解你的情况'**
  String get s954;

  /// No description provided for @s955.
  ///
  /// In zh_CN, this message translates to:
  /// **'关键信息，精准守护'**
  String get s955;

  /// No description provided for @s956.
  ///
  /// In zh_CN, this message translates to:
  /// **'血型 —— 输血时的关键参考'**
  String get s956;

  /// No description provided for @s957.
  ///
  /// In zh_CN, this message translates to:
  /// **'药物过敏 —— 避免二次伤害'**
  String get s957;

  /// No description provided for @s958.
  ///
  /// In zh_CN, this message translates to:
  /// **'病史备注 —— 帮助医生判断'**
  String get s958;

  /// No description provided for @s959.
  ///
  /// In zh_CN, this message translates to:
  /// **'这些信息只在求助触发时发送'**
  String get s959;

  /// No description provided for @s960.
  ///
  /// In zh_CN, this message translates to:
  /// **'添加你的守护者'**
  String get s960;

  /// No description provided for @s961.
  ///
  /// In zh_CN, this message translates to:
  /// **'紧急联系人 = 你的安全网'**
  String get s961;

  /// No description provided for @s962.
  ///
  /// In zh_CN, this message translates to:
  /// **'至少添加1位家人或朋友'**
  String get s962;

  /// No description provided for @s963.
  ///
  /// In zh_CN, this message translates to:
  /// **'求助时按优先顺序通知'**
  String get s963;

  /// No description provided for @s964.
  ///
  /// In zh_CN, this message translates to:
  /// **'快捷发送求救短信+位置'**
  String get s964;

  /// No description provided for @s965.
  ///
  /// In zh_CN, this message translates to:
  /// **'可拖动调整优先级'**
  String get s965;

  /// No description provided for @s966.
  ///
  /// In zh_CN, this message translates to:
  /// **'他们会在你最需要的时候收到消息'**
  String get s966;

  /// No description provided for @s967.
  ///
  /// In zh_CN, this message translates to:
  /// **'开启位置权限'**
  String get s967;

  /// No description provided for @s968.
  ///
  /// In zh_CN, this message translates to:
  /// **'我们承诺：绝不监控你的日常位置'**
  String get s968;

  /// No description provided for @s969.
  ///
  /// In zh_CN, this message translates to:
  /// **'只在求助时获取一次位置'**
  String get s969;

  /// No description provided for @s970.
  ///
  /// In zh_CN, this message translates to:
  /// **'平时不追踪、不监控、不上传'**
  String get s970;

  /// No description provided for @s971.
  ///
  /// In zh_CN, this message translates to:
  /// **'只有你主动触发求助才定位'**
  String get s971;

  /// No description provided for @s972.
  ///
  /// In zh_CN, this message translates to:
  /// **'精确到米级，附带地图链接'**
  String get s972;

  /// No description provided for @s973.
  ///
  /// In zh_CN, this message translates to:
  /// **'你的隐私，我们用生命捍卫'**
  String get s973;

  /// No description provided for @s974.
  ///
  /// In zh_CN, this message translates to:
  /// **'紧急求助短信将包含您的手机号'**
  String get s974;

  /// No description provided for @s975.
  ///
  /// In zh_CN, this message translates to:
  /// **'您的信息仅用于平安守护与亲友互助'**
  String get s975;

  /// No description provided for @s976.
  ///
  /// In zh_CN, this message translates to:
  /// **'未注册手机号将自动创建账号'**
  String get s976;

  /// No description provided for @s977.
  ///
  /// In zh_CN, this message translates to:
  /// **'为了在你触发求助时，守护者能第一时间知道你的准确位置，我们需要获取位置权限。'**
  String get s977;

  /// No description provided for @s978.
  ///
  /// In zh_CN, this message translates to:
  /// **'我们承诺：'**
  String get s978;

  /// No description provided for @s979.
  ///
  /// In zh_CN, this message translates to:
  /// **'• 平时不追踪、不监控、不上传你的位置'**
  String get s979;

  /// No description provided for @s980.
  ///
  /// In zh_CN, this message translates to:
  /// **'• 只有你主动触发求助时才获取一次位置'**
  String get s980;

  /// No description provided for @s981.
  ///
  /// In zh_CN, this message translates to:
  /// **'• 你的隐私，我们用生命捍卫'**
  String get s981;

  /// No description provided for @s982.
  ///
  /// In zh_CN, this message translates to:
  /// **'继续'**
  String get s982;

  /// No description provided for @s983.
  ///
  /// In zh_CN, this message translates to:
  /// **'登录中...'**
  String get s983;

  /// No description provided for @s984.
  ///
  /// In zh_CN, this message translates to:
  /// **'登录 / 注册'**
  String get s984;

  /// No description provided for @s985.
  ///
  /// In zh_CN, this message translates to:
  /// **'请输入有效的手机号码'**
  String get s985;

  /// No description provided for @s986.
  ///
  /// In zh_CN, this message translates to:
  /// **'网络连接超时，请检查网络后重试'**
  String get s986;

  /// No description provided for @s987.
  ///
  /// In zh_CN, this message translates to:
  /// **'网络连接失败，请检查网络后重试'**
  String get s987;

  /// No description provided for @s988.
  ///
  /// In zh_CN, this message translates to:
  /// **'网络请求超时，请检查网络后重试'**
  String get s988;

  /// No description provided for @s989.
  ///
  /// In zh_CN, this message translates to:
  /// **'安全连接失败，请检查网络环境'**
  String get s989;

  /// No description provided for @s990.
  ///
  /// In zh_CN, this message translates to:
  /// **'服务器繁忙'**
  String get s990;

  /// No description provided for @s991.
  ///
  /// In zh_CN, this message translates to:
  /// **'服务器返回空响应'**
  String get s991;

  /// No description provided for @s992.
  ///
  /// In zh_CN, this message translates to:
  /// **'服务器响应异常'**
  String get s992;

  /// No description provided for @s993.
  ///
  /// In zh_CN, this message translates to:
  /// **'服务器响应格式错误'**
  String get s993;

  /// No description provided for @s994.
  ///
  /// In zh_CN, this message translates to:
  /// **'登录失败，请稍后重试'**
  String get s994;

  /// No description provided for @s995.
  ///
  /// In zh_CN, this message translates to:
  /// **'守护邀请'**
  String get s995;

  /// No description provided for @s996.
  ///
  /// In zh_CN, this message translates to:
  /// **'手机号 {inviterPhone} 的用户已将你设为紧急联系人'**
  String s996(Object? inviterPhone);

  /// No description provided for @s997.
  ///
  /// In zh_CN, this message translates to:
  /// **'你是否也希望对方守护你？'**
  String get s997;

  /// No description provided for @s998.
  ///
  /// In zh_CN, this message translates to:
  /// **'互相守护'**
  String get s998;

  /// No description provided for @s999.
  ///
  /// In zh_CN, this message translates to:
  /// **'  你们可以查看彼此的状态，遇到紧急情况互相帮助'**
  String get s999;

  /// No description provided for @s1000.
  ///
  /// In zh_CN, this message translates to:
  /// **'你也可以选择\"不用了\"，仅作为对方的紧急联系人'**
  String get s1000;

  /// No description provided for @s1001.
  ///
  /// In zh_CN, this message translates to:
  /// **'不用了'**
  String get s1001;

  /// No description provided for @s1002.
  ///
  /// In zh_CN, this message translates to:
  /// **'跨越距离的温情传递'**
  String get s1002;

  /// No description provided for @s1003.
  ///
  /// In zh_CN, this message translates to:
  /// **'梅先生'**
  String get s1003;

  /// No description provided for @s1004.
  ///
  /// In zh_CN, this message translates to:
  /// **'见字如面，愿你平安喜乐。'**
  String get s1004;

  /// No description provided for @s1005.
  ///
  /// In zh_CN, this message translates to:
  /// **'亲爱的'**
  String get s1005;

  /// No description provided for @s1006.
  ///
  /// In zh_CN, this message translates to:
  /// **'全天候生命体征守护'**
  String get s1006;

  /// No description provided for @s1007.
  ///
  /// In zh_CN, this message translates to:
  /// **'心率、血压、睡眠，一切尽在掌握'**
  String get s1007;

  /// No description provided for @s1008.
  ///
  /// In zh_CN, this message translates to:
  /// **'你的专属安全网络'**
  String get s1008;

  /// No description provided for @s1009.
  ///
  /// In zh_CN, this message translates to:
  /// **'需要时，一键通知所有守护者'**
  String get s1009;

  /// No description provided for @s1010.
  ///
  /// In zh_CN, this message translates to:
  /// **'请输入守护码'**
  String get s1010;

  /// No description provided for @s1011.
  ///
  /// In zh_CN, this message translates to:
  /// **'兑换失败'**
  String get s1011;

  /// No description provided for @s1012.
  ///
  /// In zh_CN, this message translates to:
  /// **'守护关系已建立'**
  String get s1012;

  /// No description provided for @s1013.
  ///
  /// In zh_CN, this message translates to:
  /// **'你已成为 {senderName} 的守护人\n你们可以互相守护彼此的安全'**
  String s1013(Object? senderName);

  /// No description provided for @s1014.
  ///
  /// In zh_CN, this message translates to:
  /// **'如果收到了对方的守护码，可以在这里直接录入完成绑定'**
  String get s1014;

  /// No description provided for @s1015.
  ///
  /// In zh_CN, this message translates to:
  /// **'守护码'**
  String get s1015;

  /// No description provided for @s1016.
  ///
  /// In zh_CN, this message translates to:
  /// **'例如: ABC123'**
  String get s1016;

  /// No description provided for @s1017.
  ///
  /// In zh_CN, this message translates to:
  /// **'守护码由对方在 App 内出示，请向对方索取'**
  String get s1017;

  /// No description provided for @s1018.
  ///
  /// In zh_CN, this message translates to:
  /// **'确认绑定'**
  String get s1018;

  /// No description provided for @s1019.
  ///
  /// In zh_CN, this message translates to:
  /// **'跌倒未响应，请确认是否通知守护者'**
  String get s1019;

  /// No description provided for @s1020.
  ///
  /// In zh_CN, this message translates to:
  /// **'✅ 平安确认完成！'**
  String get s1020;

  /// No description provided for @s1021.
  ///
  /// In zh_CN, this message translates to:
  /// **'📱 手机端跌倒检测已开启（简化版）'**
  String get s1021;

  /// No description provided for @s1022.
  ///
  /// In zh_CN, this message translates to:
  /// **'📱 手机端跌倒检测已关闭'**
  String get s1022;

  /// No description provided for @s1023.
  ///
  /// In zh_CN, this message translates to:
  /// **'请开启位置权限'**
  String get s1023;

  /// No description provided for @s1024.
  ///
  /// In zh_CN, this message translates to:
  /// **'安全'**
  String get s1024;

  /// No description provided for @s1025.
  ///
  /// In zh_CN, this message translates to:
  /// **'一般'**
  String get s1025;

  /// No description provided for @s1026.
  ///
  /// In zh_CN, this message translates to:
  /// **'需关注'**
  String get s1026;

  /// No description provided for @s1027.
  ///
  /// In zh_CN, this message translates to:
  /// **'安全状态'**
  String get s1027;

  /// No description provided for @s1028.
  ///
  /// In zh_CN, this message translates to:
  /// **'定时确认'**
  String get s1028;

  /// No description provided for @s1029.
  ///
  /// In zh_CN, this message translates to:
  /// **'位置追踪'**
  String get s1029;

  /// No description provided for @s1030.
  ///
  /// In zh_CN, this message translates to:
  /// **'有未确认事件'**
  String get s1030;

  /// No description provided for @s1031.
  ///
  /// In zh_CN, this message translates to:
  /// **'您的安全保护已全面开启，让我们一起守护您的平安。'**
  String get s1031;

  /// No description provided for @s1032.
  ///
  /// In zh_CN, this message translates to:
  /// **'定时确认已开启，建议开启位置追踪获得更全面的保护。'**
  String get s1032;

  /// No description provided for @s1033.
  ///
  /// In zh_CN, this message translates to:
  /// **'建议开启定时确认和位置追踪，构建更完善的保护体系。'**
  String get s1033;

  /// No description provided for @s1034.
  ///
  /// In zh_CN, this message translates to:
  /// **'安全小贴士'**
  String get s1034;

  /// No description provided for @s1035.
  ///
  /// In zh_CN, this message translates to:
  /// **'建议每天至少确认一次平安'**
  String get s1035;

  /// No description provided for @s1036.
  ///
  /// In zh_CN, this message translates to:
  /// **'开启位置追踪可在紧急时快速定位'**
  String get s1036;

  /// No description provided for @s1037.
  ///
  /// In zh_CN, this message translates to:
  /// **'绑定 Apple Watch 可同步健康数据'**
  String get s1037;

  /// No description provided for @s1038.
  ///
  /// In zh_CN, this message translates to:
  /// **'记得定期检查紧急联系人是否正确'**
  String get s1038;

  /// No description provided for @s1039.
  ///
  /// In zh_CN, this message translates to:
  /// **'社交互动'**
  String get s1039;

  /// No description provided for @s1040.
  ///
  /// In zh_CN, this message translates to:
  /// **'妈妈'**
  String get s1040;

  /// No description provided for @s1041.
  ///
  /// In zh_CN, this message translates to:
  /// **'爸爸'**
  String get s1041;

  /// No description provided for @s1042.
  ///
  /// In zh_CN, this message translates to:
  /// **'闺蜜小美'**
  String get s1042;

  /// No description provided for @s1043.
  ///
  /// In zh_CN, this message translates to:
  /// **'暂无消息'**
  String get s1043;

  /// No description provided for @s1044.
  ///
  /// In zh_CN, this message translates to:
  /// **'开始和守护你的人互动吧~'**
  String get s1044;

  /// No description provided for @s1045.
  ///
  /// In zh_CN, this message translates to:
  /// **'发送了一个表情'**
  String get s1045;

  /// No description provided for @s1046.
  ///
  /// In zh_CN, this message translates to:
  /// **'已签到平安'**
  String get s1046;

  /// No description provided for @s1047.
  ///
  /// In zh_CN, this message translates to:
  /// **'发送了紧急求助'**
  String get s1047;

  /// No description provided for @s1048.
  ///
  /// In zh_CN, this message translates to:
  /// **'解锁了新成就'**
  String get s1048;

  /// No description provided for @s1049.
  ///
  /// In zh_CN, this message translates to:
  /// **'还没有收到表情'**
  String get s1049;

  /// No description provided for @s1050.
  ///
  /// In zh_CN, this message translates to:
  /// **'守护你的人会发送表情给你~'**
  String get s1050;

  /// No description provided for @s1051.
  ///
  /// In zh_CN, this message translates to:
  /// **'昨天'**
  String get s1051;

  /// No description provided for @s1052.
  ///
  /// In zh_CN, this message translates to:
  /// **'本周'**
  String get s1052;

  /// No description provided for @s1053.
  ///
  /// In zh_CN, this message translates to:
  /// **'{p1}月{p2}日'**
  String s1053(Object? p1, Object? p2);

  /// No description provided for @s1054.
  ///
  /// In zh_CN, this message translates to:
  /// **'健康'**
  String get s1054;

  /// No description provided for @s1055.
  ///
  /// In zh_CN, this message translates to:
  /// **'签到'**
  String get s1055;

  /// No description provided for @s1056.
  ///
  /// In zh_CN, this message translates to:
  /// **'经期'**
  String get s1056;

  /// No description provided for @s1057.
  ///
  /// In zh_CN, this message translates to:
  /// **'心率趋势'**
  String get s1057;

  /// No description provided for @s1058.
  ///
  /// In zh_CN, this message translates to:
  /// **'血氧趋势'**
  String get s1058;

  /// No description provided for @s1059.
  ///
  /// In zh_CN, this message translates to:
  /// **'睡眠时长'**
  String get s1059;

  /// No description provided for @s1060.
  ///
  /// In zh_CN, this message translates to:
  /// **'分钟'**
  String get s1060;

  /// No description provided for @s1061.
  ///
  /// In zh_CN, this message translates to:
  /// **'智能分析您的健康数据，提供个性化建议'**
  String get s1061;

  /// No description provided for @s1062.
  ///
  /// In zh_CN, this message translates to:
  /// **'设置 → 健康 → 数据来源与访问权限 → 在呢+ → 全部打开'**
  String get s1062;

  /// No description provided for @s1063.
  ///
  /// In zh_CN, this message translates to:
  /// **'请打开 iPhone「设置 → 健康」手动授权'**
  String get s1063;

  /// No description provided for @s1064.
  ///
  /// In zh_CN, this message translates to:
  /// **'订阅产品尚未就绪，请稍后再试'**
  String get s1064;

  /// No description provided for @s1065.
  ///
  /// In zh_CN, this message translates to:
  /// **'⏰ 订阅产品正在准备中\nApple 审核通过后需 2-24 小时生效'**
  String get s1065;

  /// No description provided for @s1066.
  ///
  /// In zh_CN, this message translates to:
  /// **'App Store 购买服务不可用，请稍后再试'**
  String get s1066;

  /// No description provided for @s1067.
  ///
  /// In zh_CN, this message translates to:
  /// **'未找到订阅产品（{productId}），请稍后重试或联系客服'**
  String s1067(Object? productId);

  /// No description provided for @s1068.
  ///
  /// In zh_CN, this message translates to:
  /// **'网络'**
  String get s1068;

  /// No description provided for @s1069.
  ///
  /// In zh_CN, this message translates to:
  /// **'购买失败：网络不稳定，请检查后重试\n（沙盒测试建议关闭 VPN）'**
  String get s1069;

  /// No description provided for @s1070.
  ///
  /// In zh_CN, this message translates to:
  /// **'验证失败，请重启App重试'**
  String get s1070;

  /// No description provided for @s1071.
  ///
  /// In zh_CN, this message translates to:
  /// **'⚠️ 支付验证失败\n请重启App自动重试，或联系客服'**
  String get s1071;

  /// No description provided for @s1072.
  ///
  /// In zh_CN, this message translates to:
  /// **'验证失败：{e}'**
  String s1072(Object? e);

  /// No description provided for @s1073.
  ///
  /// In zh_CN, this message translates to:
  /// **'⚠️ 网络异常，请重启App自动重试'**
  String get s1073;

  /// No description provided for @s1074.
  ///
  /// In zh_CN, this message translates to:
  /// **'购买已取消'**
  String get s1074;

  /// No description provided for @s1075.
  ///
  /// In zh_CN, this message translates to:
  /// **'购买记录已恢复'**
  String get s1075;

  /// No description provided for @s1076.
  ///
  /// In zh_CN, this message translates to:
  /// **'未找到可恢复的购买记录'**
  String get s1076;

  /// No description provided for @s1077.
  ///
  /// In zh_CN, this message translates to:
  /// **'yyyy年M月d日'**
  String get s1077;

  /// No description provided for @s1078.
  ///
  /// In zh_CN, this message translates to:
  /// **'在呢+'**
  String get s1078;

  /// No description provided for @s1079.
  ///
  /// In zh_CN, this message translates to:
  /// **'你的守护圈，已被点亮'**
  String get s1079;

  /// No description provided for @s1080.
  ///
  /// In zh_CN, this message translates to:
  /// **'点亮你的守护圈'**
  String get s1080;

  /// No description provided for @s1081.
  ///
  /// In zh_CN, this message translates to:
  /// **'那些在乎你的人，此刻更安心了'**
  String get s1081;

  /// No description provided for @s1082.
  ///
  /// In zh_CN, this message translates to:
  /// **'让在乎你的人，时刻知道你在'**
  String get s1082;

  /// No description provided for @s1083.
  ///
  /// In zh_CN, this message translates to:
  /// **'守护有效期至 {p1}'**
  String s1083(Object? p1);

  /// No description provided for @s1084.
  ///
  /// In zh_CN, this message translates to:
  /// **'快捷拨打3人'**
  String get s1084;

  /// No description provided for @s1085.
  ///
  /// In zh_CN, this message translates to:
  /// **'快捷短信3人'**
  String get s1085;

  /// No description provided for @s1086.
  ///
  /// In zh_CN, this message translates to:
  /// **'10位守护人'**
  String get s1086;

  /// No description provided for @s1087.
  ///
  /// In zh_CN, this message translates to:
  /// **'一句\"我在呢\"，胜过千言万语'**
  String get s1087;

  /// No description provided for @s1088.
  ///
  /// In zh_CN, this message translates to:
  /// **'紧急时刻，快捷通知3位联系人'**
  String get s1088;

  /// No description provided for @s1089.
  ///
  /// In zh_CN, this message translates to:
  /// **'一键求助，快捷拨打并短信通知前3位联系人，分秒必争'**
  String get s1089;

  /// No description provided for @s1090.
  ///
  /// In zh_CN, this message translates to:
  /// **'最多10位守护人，全家都放心'**
  String get s1090;

  /// No description provided for @s1091.
  ///
  /// In zh_CN, this message translates to:
  /// **'父母、伴侣、挚友……每个重要的人，都不会被遗漏'**
  String get s1091;

  /// No description provided for @s1092.
  ///
  /// In zh_CN, this message translates to:
  /// **'守护卡，把关心传递给更多人'**
  String get s1092;

  /// No description provided for @s1093.
  ///
  /// In zh_CN, this message translates to:
  /// **'初始3张守护卡，邀请亲友加入你的守护圈，让爱流动'**
  String get s1093;

  /// No description provided for @s1094.
  ///
  /// In zh_CN, this message translates to:
  /// **'守护力对比'**
  String get s1094;

  /// No description provided for @s1095.
  ///
  /// In zh_CN, this message translates to:
  /// **'守护能力'**
  String get s1095;

  /// No description provided for @s1096.
  ///
  /// In zh_CN, this message translates to:
  /// **'体验版'**
  String get s1096;

  /// No description provided for @s1097.
  ///
  /// In zh_CN, this message translates to:
  /// **'智能版'**
  String get s1097;

  /// No description provided for @s1098.
  ///
  /// In zh_CN, this message translates to:
  /// **'紧急联系人上限'**
  String get s1098;

  /// No description provided for @s1099.
  ///
  /// In zh_CN, this message translates to:
  /// **'5位'**
  String get s1099;

  /// No description provided for @s1100.
  ///
  /// In zh_CN, this message translates to:
  /// **'10位'**
  String get s1100;

  /// No description provided for @s1101.
  ///
  /// In zh_CN, this message translates to:
  /// **'紧急快捷拨打'**
  String get s1101;

  /// No description provided for @s1102.
  ///
  /// In zh_CN, this message translates to:
  /// **'1位'**
  String get s1102;

  /// No description provided for @s1103.
  ///
  /// In zh_CN, this message translates to:
  /// **'3位'**
  String get s1103;

  /// No description provided for @s1104.
  ///
  /// In zh_CN, this message translates to:
  /// **'紧急快捷短信'**
  String get s1104;

  /// No description provided for @s1105.
  ///
  /// In zh_CN, this message translates to:
  /// **'智能守护'**
  String get s1105;

  /// No description provided for @s1106.
  ///
  /// In zh_CN, this message translates to:
  /// **'一份小小的订阅，一份大大的安心'**
  String get s1106;

  /// No description provided for @s1107.
  ///
  /// In zh_CN, this message translates to:
  /// **'每天仅需 {p1}'**
  String s1107(Object? p1);

  /// No description provided for @s1108.
  ///
  /// In zh_CN, this message translates to:
  /// **'通过 Apple 订阅管理自动续费'**
  String get s1108;

  /// No description provided for @s1109.
  ///
  /// In zh_CN, this message translates to:
  /// **'订阅产品加载中，点击购买将自动刷新'**
  String get s1109;

  /// No description provided for @s1110.
  ///
  /// In zh_CN, this message translates to:
  /// **'⚠ App Store 暂不可用，请稍后再试'**
  String get s1110;

  /// No description provided for @s1111.
  ///
  /// In zh_CN, this message translates to:
  /// **'加载中...'**
  String get s1111;

  /// No description provided for @s1112.
  ///
  /// In zh_CN, this message translates to:
  /// **'/月'**
  String get s1112;

  /// No description provided for @s1113.
  ///
  /// In zh_CN, this message translates to:
  /// **'/年'**
  String get s1113;

  /// No description provided for @s1114.
  ///
  /// In zh_CN, this message translates to:
  /// **'月度'**
  String get s1114;

  /// No description provided for @s1115.
  ///
  /// In zh_CN, this message translates to:
  /// **'年度'**
  String get s1115;

  /// No description provided for @s1116.
  ///
  /// In zh_CN, this message translates to:
  /// **'{p1}/年'**
  String s1116(Object? p1);

  /// No description provided for @s1117.
  ///
  /// In zh_CN, this message translates to:
  /// **'省28%'**
  String get s1117;

  /// No description provided for @s1118.
  ///
  /// In zh_CN, this message translates to:
  /// **'立即开启守护'**
  String get s1118;

  /// No description provided for @s1119.
  ///
  /// In zh_CN, this message translates to:
  /// **'立即开启守护 · 年付更省'**
  String get s1119;

  /// No description provided for @s1120.
  ///
  /// In zh_CN, this message translates to:
  /// **'你的守护已点亮'**
  String get s1120;

  /// No description provided for @s1121.
  ///
  /// In zh_CN, this message translates to:
  /// **'紧急时刻，快捷守护3位联系人'**
  String get s1121;

  /// No description provided for @s1122.
  ///
  /// In zh_CN, this message translates to:
  /// **'一键求助，快捷拨打并短信通知前3位联系人'**
  String get s1122;

  /// No description provided for @s1123.
  ///
  /// In zh_CN, this message translates to:
  /// **'最多10位守护人'**
  String get s1123;

  /// No description provided for @s1124.
  ///
  /// In zh_CN, this message translates to:
  /// **'父母、伴侣、挚友，每个重要的人都不会遗漏'**
  String get s1124;

  /// No description provided for @s1125.
  ///
  /// In zh_CN, this message translates to:
  /// **'守护卡传递关心'**
  String get s1125;

  /// No description provided for @s1126.
  ///
  /// In zh_CN, this message translates to:
  /// **'邀请亲友加入守护圈，让爱流动起来'**
  String get s1126;

  /// No description provided for @s1127.
  ///
  /// In zh_CN, this message translates to:
  /// **'管理守护订阅'**
  String get s1127;

  /// No description provided for @s1128.
  ///
  /// In zh_CN, this message translates to:
  /// **'通过 Apple ID 管理你的守护订阅，可随时调整'**
  String get s1128;

  /// No description provided for @s1129.
  ///
  /// In zh_CN, this message translates to:
  /// **'前往 Apple ID 管理'**
  String get s1129;

  /// No description provided for @s1130.
  ///
  /// In zh_CN, this message translates to:
  /// **'你的信任，我们用心守护'**
  String get s1130;

  /// No description provided for @s1131.
  ///
  /// In zh_CN, this message translates to:
  /// **'Apple 官方支付'**
  String get s1131;

  /// No description provided for @s1132.
  ///
  /// In zh_CN, this message translates to:
  /// **'随时可取消'**
  String get s1132;

  /// No description provided for @s1133.
  ///
  /// In zh_CN, this message translates to:
  /// **'隐私安全'**
  String get s1133;

  /// No description provided for @s1134.
  ///
  /// In zh_CN, this message translates to:
  /// **'恢复购买'**
  String get s1134;

  /// No description provided for @s1135.
  ///
  /// In zh_CN, this message translates to:
  /// **'≈{p1} {p2}/月'**
  String s1135(Object? p1, Object? p2);

  /// No description provided for @s1136.
  ///
  /// In zh_CN, this message translates to:
  /// **'≈\$5.00/月'**
  String get s1136;

  /// No description provided for @s1192.
  ///
  /// In zh_CN, this message translates to:
  /// **'每月自动续费'**
  String get s1192;

  /// No description provided for @s1193.
  ///
  /// In zh_CN, this message translates to:
  /// **'每年自动续费'**
  String get s1193;

  /// No description provided for @s1194.
  ///
  /// In zh_CN, this message translates to:
  /// **'{p1}/月（约合 {p2}/天）'**
  String s1194(Object? p1, Object? p2);

  /// No description provided for @s1195.
  ///
  /// In zh_CN, this message translates to:
  /// **'{p1}/年（约合 {p2}/天）'**
  String s1195(Object? p1, Object? p2);

  /// No description provided for @s1137.
  ///
  /// In zh_CN, this message translates to:
  /// **' · 月度 {p1}'**
  String s1137(Object? p1);

  /// No description provided for @s1138.
  ///
  /// In zh_CN, this message translates to:
  /// **' · 年度 {p1}'**
  String s1138(Object? p1);

  /// No description provided for @s1139.
  ///
  /// In zh_CN, this message translates to:
  /// **'查看隐私政策'**
  String get s1139;

  /// No description provided for @s1140.
  ///
  /// In zh_CN, this message translates to:
  /// **'查看服务条款（用户协议）'**
  String get s1140;

  /// No description provided for @s1141.
  ///
  /// In zh_CN, this message translates to:
  /// **'无法打开页面：{url}'**
  String s1141(Object? url);

  /// No description provided for @s1142.
  ///
  /// In zh_CN, this message translates to:
  /// **'少量'**
  String get s1142;

  /// No description provided for @s1143.
  ///
  /// In zh_CN, this message translates to:
  /// **'偏少'**
  String get s1143;

  /// No description provided for @s1144.
  ///
  /// In zh_CN, this message translates to:
  /// **'正常'**
  String get s1144;

  /// No description provided for @s1145.
  ///
  /// In zh_CN, this message translates to:
  /// **'偏多'**
  String get s1145;

  /// No description provided for @s1146.
  ///
  /// In zh_CN, this message translates to:
  /// **'大量'**
  String get s1146;

  /// No description provided for @s1147.
  ///
  /// In zh_CN, this message translates to:
  /// **'腹痛'**
  String get s1147;

  /// No description provided for @s1148.
  ///
  /// In zh_CN, this message translates to:
  /// **'腰酸'**
  String get s1148;

  /// No description provided for @s1149.
  ///
  /// In zh_CN, this message translates to:
  /// **'头痛'**
  String get s1149;

  /// No description provided for @s1150.
  ///
  /// In zh_CN, this message translates to:
  /// **'乳房胀痛'**
  String get s1150;

  /// No description provided for @s1151.
  ///
  /// In zh_CN, this message translates to:
  /// **'疲劳'**
  String get s1151;

  /// No description provided for @s1152.
  ///
  /// In zh_CN, this message translates to:
  /// **'情绪波动'**
  String get s1152;

  /// No description provided for @s1153.
  ///
  /// In zh_CN, this message translates to:
  /// **'食欲增加'**
  String get s1153;

  /// No description provided for @s1154.
  ///
  /// In zh_CN, this message translates to:
  /// **'失眠'**
  String get s1154;

  /// No description provided for @s1155.
  ///
  /// In zh_CN, this message translates to:
  /// **'痘痘'**
  String get s1155;

  /// No description provided for @s1156.
  ///
  /// In zh_CN, this message translates to:
  /// **'便秘'**
  String get s1156;

  /// No description provided for @s1157.
  ///
  /// In zh_CN, this message translates to:
  /// **'服务器返回空响应 (HTTP {p1})'**
  String s1157(Object? p1);

  /// No description provided for @s1158.
  ///
  /// In zh_CN, this message translates to:
  /// **'服务器繁忙，请稍后重试'**
  String get s1158;

  /// No description provided for @s1159.
  ///
  /// In zh_CN, this message translates to:
  /// **'请求过于频繁，请稍后再试'**
  String get s1159;

  /// No description provided for @s1160.
  ///
  /// In zh_CN, this message translates to:
  /// **'服务器响应异常 (HTTP {p1})'**
  String s1160(Object? p1);

  /// No description provided for @s1161.
  ///
  /// In zh_CN, this message translates to:
  /// **'服务器响应格式错误 (HTTP {p1})'**
  String s1161(Object? p1);

  /// No description provided for @s1162.
  ///
  /// In zh_CN, this message translates to:
  /// **'每日签到提醒'**
  String get s1162;

  /// No description provided for @s1163.
  ///
  /// In zh_CN, this message translates to:
  /// **'提醒您完成每日签到，让守护者知道您平安'**
  String get s1163;

  /// No description provided for @s1164.
  ///
  /// In zh_CN, this message translates to:
  /// **'该签到啦 🏠'**
  String get s1164;

  /// No description provided for @s1165.
  ///
  /// In zh_CN, this message translates to:
  /// **'点击打开「在呢」，完成今日签到，让守护者放心 ❤️'**
  String get s1165;

  /// No description provided for @s1166.
  ///
  /// In zh_CN, this message translates to:
  /// **'当天未签到时的额外提醒'**
  String get s1166;

  /// No description provided for @s1167.
  ///
  /// In zh_CN, this message translates to:
  /// **'别忘了签到哦 💙'**
  String get s1167;

  /// No description provided for @s1168.
  ///
  /// In zh_CN, this message translates to:
  /// **'今天还没签到呢，花3秒报个平安，让守护者放心'**
  String get s1168;

  /// No description provided for @s1169.
  ///
  /// In zh_CN, this message translates to:
  /// **'StoreKit 不可用，请稍后再试'**
  String get s1169;

  /// No description provided for @s1170.
  ///
  /// In zh_CN, this message translates to:
  /// **'购买请求发起失败'**
  String get s1170;

  /// No description provided for @s1171.
  ///
  /// In zh_CN, this message translates to:
  /// **'购买失败：{lastError}'**
  String s1171(Object? lastError);

  /// No description provided for @s1172.
  ///
  /// In zh_CN, this message translates to:
  /// **'网络连接不稳定\n请检查网络后重试\n（沙盒测试环境可能需要关闭 VPN）'**
  String get s1172;

  /// No description provided for @s1173.
  ///
  /// In zh_CN, this message translates to:
  /// **'沙盒服务暂不可用\n请稍后重试或重启 App'**
  String get s1173;

  /// No description provided for @s1174.
  ///
  /// In zh_CN, this message translates to:
  /// **'购买遇到问题 ({p1}...)'**
  String s1174(Object? p1);

  /// No description provided for @s1175.
  ///
  /// In zh_CN, this message translates to:
  /// **'购买异常：{errStr}'**
  String s1175(Object? errStr);

  /// No description provided for @s1176.
  ///
  /// In zh_CN, this message translates to:
  /// **'产品未找到: {productId}'**
  String s1176(Object? productId);

  /// No description provided for @s1177.
  ///
  /// In zh_CN, this message translates to:
  /// **'购买失败'**
  String get s1177;

  /// No description provided for @s1180.
  ///
  /// In zh_CN, this message translates to:
  /// **'朋友发你守护码了？点此绑定'**
  String get s1180;

  /// No description provided for @languageSettings.
  ///
  /// In zh_CN, this message translates to:
  /// **'语言'**
  String get languageSettings;

  /// No description provided for @languageHint.
  ///
  /// In zh_CN, this message translates to:
  /// **'切换应用显示语言'**
  String get languageHint;

  /// No description provided for @langSystem.
  ///
  /// In zh_CN, this message translates to:
  /// **'跟随系统'**
  String get langSystem;

  /// No description provided for @langZhCn.
  ///
  /// In zh_CN, this message translates to:
  /// **'简体中文'**
  String get langZhCn;

  /// No description provided for @langZhTw.
  ///
  /// In zh_CN, this message translates to:
  /// **'繁體中文（台灣）'**
  String get langZhTw;

  /// No description provided for @langZhHk.
  ///
  /// In zh_CN, this message translates to:
  /// **'繁體中文（香港）'**
  String get langZhHk;

  /// No description provided for @langEn.
  ///
  /// In zh_CN, this message translates to:
  /// **'English'**
  String get langEn;

  /// No description provided for @splashSlogan.
  ///
  /// In zh_CN, this message translates to:
  /// **'让在乎你的人，时刻知道你在'**
  String get splashSlogan;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'我有守护码'**
  String get s1181;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'守护码已记录'**
  String get s1182;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'输入对方的守护码'**
  String get s1183;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'先填着，登录成功后自动建立守护关系'**
  String get s1184;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'已确认 {senderName} 的守护码，登录成功后自动建立'**
  String s1185(Object? senderName);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'请输入对方的守护码'**
  String get s1186;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'守护码无效或已失效'**
  String get s1187;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'网络异常，请稍后再试'**
  String get s1188;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'分享给好友'**
  String get s1189;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'我的守护码'**
  String get s1190;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'扫一扫上面的二维码，或在「在呢」中输入守护码\n即可与我建立守护关系'**
  String get s1191;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'{p1} 已离开'**
  String z0607(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'{p1}天前'**
  String z0003(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'{p1}小时前'**
  String z0002(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'{p1}分钟前'**
  String z0001(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'{p1}个围栏 · {p2}在区内'**
  String z0606(Object? p1, Object? p2);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'{p1} ({p2}米)'**
  String z0611(Object? p1, Object? p2);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'{p1} 个位置记录'**
  String z0562(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'{p1}个定位点 · 点击查看详情'**
  String z0579(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'Apple Watch 已配对 · 后台守护中'**
  String get z0595;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'Apple Watch 精准检测中'**
  String get z0594;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'Apple Watch 跌倒检测'**
  String get z0582;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'Apple Watch 跌倒检测（精准版）'**
  String get z0601;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'⚠ 待确认'**
  String get z0599;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'✓ 已确认'**
  String get z0598;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'上午{p1}点'**
  String z0551(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'上午9点'**
  String get z0543;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'上次确认: {p1}'**
  String z0530(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'上次记录'**
  String get z0564;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'下午{p1}点'**
  String z0552(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'下午6点'**
  String get z0544;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'中午12点'**
  String get z0025;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'位置共享'**
  String get z0554;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'使用手机的加速度传感器检测跌倒，精度不如 Apple Watch，但\"有总比没有好\"。适合没有 Apple Watch 的用户。'**
  String get z0603;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'保护您的行踪安全'**
  String get z0555;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'停止追踪'**
  String get z0565;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'关闭手机检测'**
  String get z0592;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'凌晨{p1}点'**
  String z0550(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'凌晨0点'**
  String get z0549;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'守护者可查看你的实时位置 · {p1}'**
  String z0557(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'定时平安确认'**
  String get z0525;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'实时'**
  String get z0573;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'实时追踪中 · ⚡耗电较高'**
  String get z0567;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'已开启'**
  String get z0585;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'已连接 · 精准检测'**
  String get z0583;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'开启'**
  String get z0556;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'开启手机检测'**
  String get z0593;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'开始追踪'**
  String get z0566;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'开始追踪前可选'**
  String get z0561;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'手机端检测中 · 简化版'**
  String get z0596;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'手机端跌倒检测（简化版）'**
  String get z0026;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'手表心跳'**
  String get z0541;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'手表心跳自动确认'**
  String get z0534;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'手表检测到你时确认，安心守护'**
  String get z0529;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'提醒频率'**
  String get z0526;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'早7点'**
  String get z0542;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'时间定时'**
  String get z0024;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'晚10点'**
  String get z0546;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'晚9点'**
  String get z0545;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'晚上{p1}点'**
  String z0553(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'普通'**
  String get z0575;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'普通追踪中 · 推荐模式'**
  String get z0568;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'暂无今日轨迹记录'**
  String get z0563;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'暂无跌倒记录，检测系统正在运行中'**
  String get z0588;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'最近跌倒 ({p1} 条待确认)'**
  String z0586(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'最近跌倒记录'**
  String get z0587;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'未启用'**
  String get z0581;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'未开启'**
  String get z0023;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'未设置安全区域'**
  String get z0605;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'未连接'**
  String get z0584;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'本功能提供两种跌倒检测方式：'**
  String get z0600;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'查看历史'**
  String get z0591;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'查看历史 ({p1})'**
  String z0590(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'查看详情'**
  String get z0022;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'步行稳定性 & 跌倒检测'**
  String get z0580;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'每15分钟'**
  String get z0578;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'每15分钟更新'**
  String get z0572;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'每30秒'**
  String get z0574;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'每30秒更新'**
  String get z0570;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'每5分钟'**
  String get z0576;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'每5分钟更新'**
  String get z0571;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'每周'**
  String get z0539;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'每周提醒 · {p1}'**
  String z0536(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'每天'**
  String get z0538;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'每天提醒 · {p1}'**
  String z0535(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'添加时间'**
  String get z0547;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'省电'**
  String get z0577;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'省电追踪中 · 🔋省电'**
  String get z0569;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'离开安全区'**
  String get z0540;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'离开安全区域时，你可以选择通知守护者'**
  String get z0608;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'离开安全区时自动确认，无需固定时间'**
  String get z0528;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'离开安全区自动确认'**
  String get z0533;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'立即确认平安'**
  String get z0532;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'管理围栏'**
  String get z0610;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'自定义'**
  String get z0015;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'自定义时间 · {p1}'**
  String z0537(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'触发方式'**
  String get z0527;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'设置安全围栏'**
  String get z0609;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'跌倒检测数据仅用于安全参考，不作为医疗诊断依据'**
  String get z0589;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'跌倒检测数据仅用于安全参考，不作为医疗诊断依据。'**
  String get z0604;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'轨迹数据收集中...'**
  String get z0558;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'运行中'**
  String get z0560;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'连续 {p1} 次未确认'**
  String z0531(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'追踪模式'**
  String get z0559;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'选择提醒时间'**
  String get z0548;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'需要 Apple Watch Series 4 及以上机型。利用手表的加速度传感器和陀螺仪精确检测跌倒。检测到跌倒时，你可以在确认后通知你的守护者。'**
  String get z0602;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'需要 Apple Watch 或开启手机端检测'**
  String get z0597;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'{p1} 周{p2} · 已签到'**
  String z0890(Object? p1, Object? p2);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'{p1} 周{p2} · 未签到'**
  String z0891(Object? p1, Object? p2);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'{p1}月'**
  String z0889(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'1年'**
  String get z0886;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'30天'**
  String get z0884;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'7天'**
  String get z0883;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'90天'**
  String get z0885;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'多'**
  String get z0892;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'天'**
  String get z0004;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'当前连续'**
  String get z0896;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'总签到 {p1} 天 · 连续 {p2} 天 · 最长 {p3} 天'**
  String z0888(Object? p1, Object? p2, Object? p3);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'最近 {p1} 天还没有签到记录'**
  String z0893(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'本周签到'**
  String get z0897;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'每天签到，点亮你的安全日历'**
  String get z0894;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'签到热力图'**
  String get z0887;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'签到统计'**
  String get z0895;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'{p1}天'**
  String z0663(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'{p1} 天'**
  String z0654(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'{p1}天'**
  String z0655(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'下次经期'**
  String get z0659;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'周期长度'**
  String get z0662;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'在健康概览页记录经期数据后可查看周期分析'**
  String get z0646;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'安全期'**
  String get z0651;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'平均周期 {p1} 天'**
  String z0648(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'易孕期'**
  String get z0652;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'易孕窗口'**
  String get z0660;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'暂无经期记录'**
  String get z0645;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'第{p1}天'**
  String z0656(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'第{p1}-{p2}天'**
  String z0661(Object? p1, Object? p2);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'经期周期'**
  String get z0647;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'经期第 {p1} 天'**
  String z0649(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'经期预测'**
  String get z0658;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'近期记录'**
  String get z0653;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'预测'**
  String get z0657;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'预计 {p1} 天后'**
  String z0650(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'姓名 · 年龄 · 血型'**
  String get z0666;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'完善健康档案'**
  String get z0029;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'点击下方按钮 → 弹出系统框 → 点「允许」'**
  String get z0668;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'简单 {p1} 步，一次设置永久生效'**
  String z0671(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'至少绑定一位家人或朋友'**
  String get z0667;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'让紧急求助'**
  String get z0669;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'还差最后一步就大功告成！'**
  String get z0672;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'随时可用'**
  String get z0670;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'位置权限已开启，求助时可发送准确位置'**
  String get z0635;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'去发送'**
  String get z0634;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'去开启'**
  String get z0028;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'去添加'**
  String get z0632;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'发送 1 张守护卡'**
  String get z0633;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'填写关键健康信息，关键时刻能帮上忙'**
  String get z0629;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'守护先锋 · 新手任务全部完成'**
  String get z0644;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'已完成'**
  String get z0643;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'已完成！继续打卡解锁更多徽章 🏆'**
  String get z0638;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'已连续签到 {p1} 天，再坚持 {p2} 天 💪'**
  String z0639(Object? p1, Object? p2);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'新手任务全部完成！'**
  String get z0627;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'新手守护任务'**
  String get z0628;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'每天签到，让守护者知道你平安'**
  String get z0640;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'求助时才能发送准确位置给守护者'**
  String get z0636;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'添加 1 位守护者'**
  String get z0630;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'紧急联系人会自动成为你的守护者'**
  String get z0631;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'解锁徽章：守护先锋'**
  String get z0641;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'进行中'**
  String get z0642;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'连续签到 3 天'**
  String get z0637;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'上午好'**
  String get z0772;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'下午好'**
  String get z0774;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'中午好'**
  String get z0773;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'夜深了'**
  String get z0010;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'早上好'**
  String get z0771;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'晚上好'**
  String get z0775;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'{p1}岁'**
  String z0722(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'{p1}, {p2}'**
  String z0732(Object? p1, Object? p2);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'https://maps.apple.com/?daddr={p1},{p2}&q={p3}'**
  String z0734(Object? p1, Object? p2, Object? p3);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'━━━━━━━━ 求助者位置信息 ━━━━━━━━'**
  String get z0727;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'✅ 已发送给全部 {p1} 位守护人'**
  String z0709(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'位置信息'**
  String get z0741;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'升级智能版，解锁全部守护人通知'**
  String get z0712;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'发送短信给 {p1}'**
  String z0713(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'地址'**
  String get z0728;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'坐标：'**
  String get z0733;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'已发送'**
  String get z0030;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'已复制到剪贴板'**
  String get z0719;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'已完成所有联系人的电话拨打'**
  String get z0716;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'已拨打'**
  String get z0737;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'已获取'**
  String get z0742;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'待发送'**
  String get z0740;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'待拨打'**
  String get z0738;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'我没事了'**
  String get z0708;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'更多守护人'**
  String get z0711;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'未设置'**
  String get z0721;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'正在采取以下行动：'**
  String get z0735;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'求救人'**
  String get z0720;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'求救信息预览（点击展开）'**
  String get z0718;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'求救信息（点击收起）'**
  String get z0717;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'病史'**
  String get z0724;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'短信通知'**
  String get z0739;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'紧急求助已触发'**
  String get z0707;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'紧急联系人电话'**
  String get z0736;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'苹果地图'**
  String get z0729;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'药物'**
  String get z0725;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'获取中...'**
  String get z0743;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'血型'**
  String get z0723;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'请立即联系我或拨打{num}！\n在呢 - 独居守护App'**
  String z0731(Object num);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'过敏'**
  String get z0726;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'谷歌地图'**
  String get z0730;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'（坐标未知）'**
  String get z0031;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'（已完成）'**
  String get z0715;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'📞 拨打 {p1} 电话'**
  String z0714(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'📨 发送求救短信给第 {p1}/{p2} 位：{p3}'**
  String z0710(Object? p1, Object? p2, Object? p3);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'🚑 拨打 {num} 急救电话'**
  String z0744(Object num);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'久坐提醒'**
  String get z0675;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'保持手机电量充足，紧急时刻它就是你的生命线'**
  String get z0696;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'保持联络'**
  String get z0687;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'充电备用'**
  String get z0695;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'关注心脏'**
  String get z0679;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'外卖虽方便，但也要记得补充蔬菜和蛋白质'**
  String get z0682;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'好好吃饭'**
  String get z0681;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'如果正在服药，设置闹钟提醒自己，不要漏服'**
  String get z0690;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'室内温度保持在22-26℃，过冷过热都影响身体状态'**
  String get z0700;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'尽量在23:30前入睡，保证7-8小时睡眠'**
  String get z0678;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'开窗通风'**
  String get z0685;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'心情记录'**
  String get z0691;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'急救知识'**
  String get z0697;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'情绪低落时试着写下来，倾诉是治愈的第一步'**
  String get z0692;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'感到心慌胸闷时不要硬撑，及时拨打{num}'**
  String z0680(Object num);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'按时服药'**
  String get z0689;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'数字 detox'**
  String get z0683;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'早晚各通风15分钟，保持室内空气新鲜'**
  String get z0686;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'检查门窗'**
  String get z0693;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'每45分钟起来走动5分钟，保护颈椎和腰椎'**
  String get z0676;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'每周至少和家人或朋友通话1次，别把自己封闭起来'**
  String get z0688;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'温度调节'**
  String get z0699;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'独居容易忘记喝水，建议每小时起身喝一杯温水'**
  String get z0674;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'睡前1小时放下手机，让大脑和眼睛休息一下'**
  String get z0684;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'睡前确认门窗已锁好，安全意识不能松懈'**
  String get z0694;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'花10分钟学习心肺复苏（CPR），关键时刻能派上用场'**
  String get z0698;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'规律作息'**
  String get z0677;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'记得多喝水'**
  String get z0673;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'{p1}{p2} · {p3}岁 · {p4}'**
  String z0875(Object? p1, Object? p2, Object? p3, Object? p4);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'体验演示'**
  String get z0879;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'手机号未设置，点击此处补充 →'**
  String get z0876;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'档案 · 联系人 · 定位 已就绪'**
  String get z0874;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'正在发送求助...'**
  String get z0877;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'求助'**
  String get z0005;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'点击触发紧急求助'**
  String get z0878;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'紧急情况才使用，将联系紧急联系人并发送位置'**
  String get z0873;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'{p1} 秒后自动触发紧急求助'**
  String z0505(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'我没事'**
  String get z0506;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'检测到可能的跌倒'**
  String get z0503;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'系统检测到您可能发生了跌倒。\n如果您没事，请点击\"我没事\"。\n如果需要帮助，请点击\"需要帮助\"。'**
  String get z0504;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'系统检测到您可能发生了跌倒，请确认您的安全状态'**
  String get z0511;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'跌倒检测'**
  String get z0508;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'跌倒检测提醒'**
  String get z0510;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'跌倒检测提醒通知'**
  String get z0509;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'需要帮助'**
  String get z0507;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'GPS 定位中'**
  String get z0470;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'GPS 定位中...'**
  String get z0491;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'✅ {num} 拨号界面已打开'**
  String z0477(Object num);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'✅ 位置已获取'**
  String get z0471;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'✅ 所有联系人已通知'**
  String get z0481;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'✅ 求救短信已发送'**
  String get z0474;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'以上为演示'**
  String get z0500;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'以上为演示，未发送任何真实信息'**
  String get z0484;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'准备开始演示...'**
  String get z0465;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'北京市朝阳区建国路88号SOHO现代城'**
  String get z0466;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'发送求救短信'**
  String get z0492;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'向守护圈发送实时位置'**
  String get z0499;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'向守护圈成员发送实时位置'**
  String get z0480;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'妈妈正在赶来'**
  String get z0482;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'完成'**
  String get z0487;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'已打开拨号界面'**
  String get z0496;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'已通知 3 位联系人'**
  String get z0493;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'已通知：妈妈、爸爸、李医生'**
  String get z0475;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'我已了解，返回求助页面'**
  String get z0502;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'所有成员已收到通知'**
  String get z0498;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'拨打 {num}'**
  String z0495(Object num);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'正在发起求救...'**
  String get z0467;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'正在发送求救短信...'**
  String get z0472;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'正在拨打 {num} 急救电话...'**
  String z0476(Object num);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'正在获取位置信息...'**
  String get z0469;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'正在通知紧急联系人...'**
  String get z0479;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'演示过程中没有发送任何真实短信或拨打电话。\n真实求助将在您确认后联系守护人并获取您的精确位置。'**
  String get z0501;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'用户可手动拨打急救电话'**
  String get z0478;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'用户手动点击求助按钮发起求救'**
  String get z0489;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'用户手动触发求助'**
  String get z0468;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'真实求助将在您确认后联系守护人并发送位置'**
  String get z0485;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'获取位置'**
  String get z0490;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'触发求助'**
  String get z0488;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'跳转到系统拨号界面'**
  String get z0021;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'通知 3 位紧急联系人'**
  String get z0473;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'通知守护圈'**
  String get z0497;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'通知紧急联系人'**
  String get z0494;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'🎉 演示完成'**
  String get z0483;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'🎬 演示模式'**
  String get z0486;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'iOS HealthKit 隐私模型下永远 false，请使用 checkRealAuthStatus()'**
  String get z0303;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'体征异常预警'**
  String get z0014;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'心率过快 ({p1} bpm)'**
  String z0304(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'心率过缓 ({p1} bpm)'**
  String z0305(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'血氧饱和度偏低 ({p1}%)'**
  String z0306(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'检测到血压偏高 ({p1}/{p2} mmHg)'**
  String z0307(Object? p1, Object? p2);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'检测到血压偏低 ({p1} mmHg)'**
  String z0308(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'呼吸频率异常偏快 ({p1} 次/分)'**
  String z0309(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'呼吸频率异常偏慢 ({p1} 次/分)'**
  String z0310(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'检测到体温偏高 ({p1}°C)'**
  String z0311(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'经期体温偏高 ({p1}°C)，注意休息'**
  String z0312(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'经期可能即将到来（周期第{p1}天）'**
  String z0313(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'经期周期偏长（已第{p1}天，平均{p2}天）'**
  String z0314(Object? p1, Object? p2);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'今日已签到，跳过自动签到(仍同步健康数据到手表) fromHeartbeat={p1} hasWatchSignal={p2}'**
  String z0315(Object? p1, Object? p2);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'执行 Watch 心跳自动签到 clientId={p1}'**
  String z0316(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'签到超时(10s) source={p1}'**
  String z0317(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'签到异常 source={p1}: {p2}'**
  String z0318(Object? p1, Object? p2);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'签到成功 source={p1} uid={p2}'**
  String z0319(Object? p1, Object? p2);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'签到未成功(服务端) source={p1}: {p2}'**
  String z0320(Object? p1, Object? p2);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'定时判断已签到: 全局={p1} uid({p2})={p3} today={p4} => true(本地命中)'**
  String z0333(Object? p1, Object? p2, Object? p3, Object? p4);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'定时判断已签到: 本地未命中，用服务端缓存 => {p1} (today={p2})'**
  String z0334(Object? p1, Object? p2);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'定时判断已签到: 本地未命中，查服务端 checked_in_today={p1} (today={p2}) res={p3}'**
  String z0335(Object? p1, Object? p2, Object? p3);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'定时判断已签到: 服务端查询异常({p1})，回退本地=false'**
  String z0336(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'手表检测到你 💓'**
  String get z0337;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'是否已平安？点开 App 即可一键确认'**
  String get z0338;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'已连续 {p1} 次未确认平安'**
  String z0339(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'如需让守护人知道，请打开 App 手动通知守护人'**
  String get z0340;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'{p1} 次'**
  String z0341(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'定时确认提醒'**
  String get z0006;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'提醒您进行平安确认'**
  String get z0007;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'平安确认提醒 💚'**
  String get z0342;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'您今天还没有确认平安，点击这里进行签到'**
  String get z0343;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'已离开{p1}'**
  String z0344(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'手表检测到你'**
  String get z0345;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'你已离开「{p1}」，请打开 App 确认平安'**
  String z0346(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'检测到你的心跳，请打开 App 确认平安'**
  String get z0347;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'已离开安全区，自动确认平安 🛡️'**
  String get z0348;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'离开「{p1}」，已自动为你签到平安'**
  String z0349(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'手表检测到你，自动确认平安 💓'**
  String get z0350;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'检测到你的心跳，已自动为你签到平安'**
  String get z0351;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'{p1}'**
  String z0352(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'今天几乎没有活动记录（{p1} 步）'**
  String z0353(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'今日活动偏少，已静止约 {p1} 小时'**
  String z0354(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'心率 {p1} bpm，超出常规区间'**
  String z0355(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'今日心率波动较大（{p1}–{p2} bpm）'**
  String z0356(Object? p1, Object? p2);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'Apple Watch 近 30 天记录到 {p1} 次心率通知'**
  String z0357(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'血氧 {p1}%，明显偏低'**
  String z0358(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'血氧 {p1}%，略低于常规值'**
  String z0359(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'步行稳定性 {p1}%，跌倒风险偏高'**
  String z0360(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'昨晚仅睡 {p1} 小时'**
  String z0361(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'昨晚睡眠 {p1} 小时，异常偏长'**
  String z0362(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'暂无健康数据'**
  String get z0008;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'佩戴 Apple Watch 并开启健康权限后，这里会显示你的今日状态'**
  String get z0009;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'早上状态不错'**
  String get z0016;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'今天状态平稳'**
  String get z0017;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'今天一切都好'**
  String get z0018;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'有几项值得留意'**
  String get z0019;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'今日状态良好，可主动告知家人'**
  String get z0363;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'建议向守护圈报个平安'**
  String get z0364;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'今日 {p1} 步，各项体征正常，可随时主动告知家人'**
  String z0365(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'各项体征正常，可随时主动告知家人'**
  String get z0366;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'共 {p1} 项提醒，不一定有问题，建议留意一下'**
  String z0367(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'检测到一些值得关注的信号，可主动告知家人，让家人少担心一点'**
  String get z0368;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'今日 {p1} 步，各项体征正常，可以让家人放心'**
  String z0369(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'各项体征正常，可以让家人放心'**
  String get z0370;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'共 {p1} 项提醒，不一定有问题，但建议留意一下'**
  String z0371(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'检测到异常信号，主动报个平安能让家人少担心一点'**
  String get z0372;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'爱心'**
  String get z0373;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'开心'**
  String get z0374;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'花朵'**
  String get z0375;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'阳光'**
  String get z0376;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'月亮'**
  String get z0377;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'幸运草'**
  String get z0378;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'加油'**
  String get z0379;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'祈福'**
  String get z0380;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'庆祝'**
  String get z0381;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'拥抱'**
  String get z0382;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'点赞'**
  String get z0383;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'胜利'**
  String get z0384;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'彩虹'**
  String get z0385;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'蝴蝶'**
  String get z0386;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'音乐'**
  String get z0387;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'咖啡'**
  String get z0388;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'连续7天签到'**
  String get z0389;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'连续签到7天，展现你的坚持'**
  String get z0390;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'连续30天签到'**
  String get z0391;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'连续签到一个月，守护之心不变'**
  String get z0392;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'签到大师'**
  String get z0393;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'累计签到100天，成为守护达人'**
  String get z0394;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'初次关怀'**
  String get z0395;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'第一次向守护对象发送表情'**
  String get z0396;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'温暖传递'**
  String get z0397;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'累计发送10次表情关怀'**
  String get z0398;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'爱心大使'**
  String get z0399;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'累计发送50次表情关怀'**
  String get z0400;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'防患未然'**
  String get z0401;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'设置好紧急联系人信息'**
  String get z0402;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'未雨绸缪'**
  String get z0403;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'测试一次紧急求助功能'**
  String get z0404;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'三人守护'**
  String get z0405;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'拥有3位守护人'**
  String get z0406;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'守护联盟'**
  String get z0407;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'拥有5位守护人'**
  String get z0408;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'守护10人'**
  String get z0409;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'守护10位亲友'**
  String get z0410;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'请改用 refreshAllAchievements，一次性刷新全部 11 个成就'**
  String get z0411;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'心率偏高'**
  String get z0412;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'当前心率 {p1} bpm，高于正常静息心率范围'**
  String z0413(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'放松身心'**
  String get z0414;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'尝试深呼吸或冥想，帮助降低心率'**
  String get z0415;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'开始冥想'**
  String get z0020;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'心率偏低'**
  String get z0416;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'当前心率 {p1} bpm，低于正常范围'**
  String z0417(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'心率正常'**
  String get z0418;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'您的心率 {p1} bpm 处于健康范围内'**
  String z0419(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'心肺功能优秀'**
  String get z0420;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'您的静息心率较低，说明心肺功能良好'**
  String get z0421;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'睡眠不足'**
  String get z0422;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'昨晚睡眠仅 {p1} 小时，建议保证7-9小时睡眠'**
  String z0423(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'{p1} 小时'**
  String z0424(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'7-9 小时'**
  String get z0425;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'改善睡眠'**
  String get z0426;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'尝试提前30分钟上床，建立规律作息'**
  String get z0427;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'设置睡眠提醒'**
  String get z0428;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'睡眠充足'**
  String get z0429;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'昨晚睡眠充足，有助于身体恢复'**
  String get z0430;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'深度睡眠不足'**
  String get z0431;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'深度睡眠仅占 {p1}%，影响恢复质量'**
  String z0432(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'血氧偏低'**
  String get z0433;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'当前血氧 {p1}%，建议关注呼吸健康'**
  String z0434(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'关注呼吸健康'**
  String get z0435;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'血氧过低，建议就医检查'**
  String get z0436;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'血氧正常'**
  String get z0437;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'血氧水平良好，呼吸系统健康'**
  String get z0438;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'压力较大'**
  String get z0439;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'心率变异性较低，提示身体处于高压状态'**
  String get z0440;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'减压放松'**
  String get z0441;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'尝试深呼吸、瑜伽或冥想，帮助缓解压力'**
  String get z0442;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'压力管理良好'**
  String get z0443;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'心率变异性良好，说明压力管理得当'**
  String get z0444;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'经期较长'**
  String get z0445;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'当前经期第 {p1} 天，如持续过长建议咨询医生'**
  String z0446(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'经期护理'**
  String get z0447;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'注意保暖，避免剧烈运动，多喝温水'**
  String get z0448;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'周期不规律'**
  String get z0449;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'当前周期 {p1} 天，不在正常范围（21-35天）'**
  String z0450(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'{p1} 天'**
  String z0451(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'21-35 天'**
  String get z0452;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'今日打卡'**
  String get z0453;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'今天还没有确认平安，点击签到让守护你的人放心'**
  String get z0454;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'立即签到'**
  String get z0455;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'数据不足，需要至少2个周期记录'**
  String get z0456;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'周期数据异常'**
  String get z0457;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'基于 {p1} 个周期预测'**
  String z0458(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'图片生成失败'**
  String get z0027;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'图片解码失败'**
  String get z0612;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'徽章图片已保存到相册'**
  String get z0613;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'保存失败：{p1}'**
  String z0614(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'签到成功 ✓'**
  String get z0615;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'你已连续守护自己 {p1} 天'**
  String z0616(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'敬请'**
  String get z0617;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'期待'**
  String get z0618;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'扫码下载「在呢」'**
  String get z0619;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'独居安全守护 App\n让在乎的人知道你很好'**
  String get z0620;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'Android 版本即将上线\n敬请期待'**
  String get z0621;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'已守护 {p1} 天'**
  String z0622(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'保存徽章'**
  String get z0623;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'{p1}天'**
  String z0624(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'还没有消息'**
  String get z0512;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'发送第一条消息吧~'**
  String get z0513;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'发送消息...'**
  String get z0514;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'{p1} 发送了表情'**
  String z0515(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'成就解锁'**
  String get z0516;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'点击查看详情'**
  String get z0517;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'守护对象已签到'**
  String get z0518;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'恭喜！'**
  String get z0519;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'守护成就'**
  String get z0859;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'全部'**
  String get z0860;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'关怀'**
  String get z0861;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'里程碑'**
  String get z0862;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'已解锁 {p1} / {p2}'**
  String z0863(Object? p1, Object? p2);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'开始你的守护之旅吧！'**
  String get z0864;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'继续加油！'**
  String get z0865;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'表现不错！'**
  String get z0866;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'接近目标了！'**
  String get z0867;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'太棒了！全部解锁！'**
  String get z0868;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'已解锁'**
  String get z0869;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'解锁于 {p1}'**
  String z0870(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'成就解锁！'**
  String get z0871;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'太棒了！'**
  String get z0872;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'终身守护王'**
  String get z0052;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'5年+，守护已成为习惯'**
  String get z0053;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'千四传奇'**
  String get z0054;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'近4年，传奇永不落幕'**
  String get z0055;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'三冠王者'**
  String get z0056;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'3年+，王者风范'**
  String get z0057;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'双冠传奇'**
  String get z0058;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'近3年，传奇继续'**
  String get z0059;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'守护之钻'**
  String get z0060;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'2年+，你是最可靠的守护者'**
  String get z0061;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'双冠王者'**
  String get z0062;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'近2年，荣耀加倍'**
  String get z0063;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'双钻守护'**
  String get z0064;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'近2年，钻石闪耀'**
  String get z0065;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'年度冠军'**
  String get z0066;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'近1.5年，冠军之心'**
  String get z0067;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'年度烈焰'**
  String get z0068;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'1年+，你的坚持令人敬佩'**
  String get z0069;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'三百王者'**
  String get z0070;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'近1年，王者之路'**
  String get z0071;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'黄金守护'**
  String get z0072;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'250天+，黄金品质'**
  String get z0073;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'守护宝石'**
  String get z0074;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'200天+，宝石璀璨'**
  String get z0075;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'白银守护'**
  String get z0076;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'半年+，银光闪闪'**
  String get z0077;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'青铜守护'**
  String get z0078;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'近半年，青铜坚韧'**
  String get z0079;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'铜质奖章'**
  String get z0080;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'140天+，奖章荣耀'**
  String get z0081;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'守护勋章'**
  String get z0082;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'120天+，勋章加身'**
  String get z0083;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'百日守护'**
  String get z0011;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'100天+，习惯已经养成'**
  String get z0084;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'艺术大师'**
  String get z0085;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'95天+，大师风范'**
  String get z0086;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'季度闪耀'**
  String get z0087;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'一个季度，闪耀光芒'**
  String get z0088;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'舞台主角'**
  String get z0089;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'85天+，主角光环'**
  String get z0090;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'马戏明星'**
  String get z0091;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'80天+，明星风采'**
  String get z0092;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'露营达人'**
  String get z0093;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'75天+，达人之路'**
  String get z0094;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'雪山巍峨'**
  String get z0095;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'70天+，巍峨如山'**
  String get z0096;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'火山喷发'**
  String get z0097;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'65天+，热情如火'**
  String get z0098;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'双月烈焰'**
  String get z0099;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'两个月，烈焰燃烧'**
  String get z0100;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'海浪奔腾'**
  String get z0101;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'55天+，奔腾不息'**
  String get z0102;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'五十雷霆'**
  String get z0103;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'50天+，雷霆万钧'**
  String get z0104;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'云端漫步'**
  String get z0105;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'45天+，漫步云端'**
  String get z0106;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'彩虹初现'**
  String get z0107;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'40天+，彩虹绚烂'**
  String get z0108;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'月半守护'**
  String get z0109;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'35天+，月半圆满'**
  String get z0110;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'月度之星'**
  String get z0012;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'一个月，你是真正的守护者'**
  String get z0111;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'果实累累'**
  String get z0112;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'28天+，硕果累累'**
  String get z0113;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'秋叶静美'**
  String get z0114;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'26天+，静美如斯'**
  String get z0115;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'枫叶飘红'**
  String get z0116;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'24天+，枫叶正红'**
  String get z0117;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'绿树成荫'**
  String get z0118;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'22天+，绿树成荫'**
  String get z0119;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'青松挺拔'**
  String get z0120;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'20天+，青松挺拔'**
  String get z0121;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'仙人掌'**
  String get z0122;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'18天+，坚韧不拔'**
  String get z0123;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'棕榈挺立'**
  String get z0124;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'16天+，挺立如松'**
  String get z0125;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'两周绽放'**
  String get z0126;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'两周，绽放光彩'**
  String get z0127;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'玫瑰初绽'**
  String get z0128;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'12天+，玫瑰初绽'**
  String get z0129;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'向阳而生'**
  String get z0130;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'10天+，向阳而生'**
  String get z0131;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'雏菊绽放'**
  String get z0132;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'9天+，雏菊绽放'**
  String get z0133;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'樱花初开'**
  String get z0134;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'8天+，樱花初开'**
  String get z0135;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'闪亮新星'**
  String get z0136;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'一周，好的开始是成功的一半'**
  String get z0137;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'初露锋芒'**
  String get z0138;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'6天+，锋芒初露'**
  String get z0139;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'含苞待放'**
  String get z0140;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'5天+，含苞待放'**
  String get z0141;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'幼苗成长'**
  String get z0142;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'4天+，幼苗成长'**
  String get z0143;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'三叶草'**
  String get z0144;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'3天，幸运三连'**
  String get z0145;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'嫩芽初绽'**
  String get z0146;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'2天，嫩芽初绽'**
  String get z0147;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'守护种子'**
  String get z0148;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'每一个伟大都始于第一步'**
  String get z0013;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'坚持，比完美更重要'**
  String get z0149;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'守护自己，是你给世界最好的礼物'**
  String get z0150;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'今天的你，比昨天更强大'**
  String get z0151;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'独居不独心，有人在默默关注你'**
  String get z0152;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'你比自己想象的更坚强'**
  String get z0153;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'每一天，都是新的开始'**
  String get z0154;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'别怕慢，怕的是停下脚步'**
  String get z0155;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'你值得被好好对待'**
  String get z0156;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'照顾好自己，世界才会更好'**
  String get z0157;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'你的坚持，正在改变一切'**
  String get z0158;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'别小看今天的自己'**
  String get z0159;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'平安，就是最好的消息'**
  String get z0160;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'对自己温柔一点，你也很辛苦'**
  String get z0161;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'签到只是一秒钟，安心却是一整天'**
  String get z0162;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'你的存在本身就很重要'**
  String get z0163;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'先照顾好自己，再照顾世界'**
  String get z0164;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'今天也是被在乎的一天'**
  String get z0165;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'你认真生活的样子，真好看'**
  String get z0166;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'小小的习惯，大大的力量'**
  String get z0167;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'今天，也请为自己骄傲'**
  String get z0168;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'世上最温暖的词，叫「我在」'**
  String get z0169;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'你从来不是一个人'**
  String get z0170;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'每一个今天，都是未来的基石'**
  String get z0171;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'对自己说一句：今天辛苦了'**
  String get z0172;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'把今天过好，就是最好的明天'**
  String get z0173;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'你值得拥有平安和幸福'**
  String get z0174;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'今天也要记得微笑'**
  String get z0175;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'守护自己，就是守护爱着你的人'**
  String get z0176;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'关关难过关关过，你真的很棒'**
  String get z0177;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'昨天偷了个懒？没关系，今天继续就好。'**
  String get z0178;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'几天不见，你还好吗？回来就好，我们继续。'**
  String get z0179;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'一周没见。最近在忙什么？记得有人在等你。'**
  String get z0180;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'快半个月没见了。欢迎回来，这里有人在想你。'**
  String get z0181;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'好久不见。这一个月过得怎么样？不论如何，欢迎回家。'**
  String get z0182;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'你终于回来了！这段时间去了哪里？我们都很想你。'**
  String get z0183;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'好久好久不见。感谢你还记得这里。无论离开多久，家永远为你敞开。'**
  String get z0184;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'一周啦'**
  String get z0185;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'一周啦！新习惯正在养成，你比自己想象的更棒。'**
  String get z0186;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'两位数'**
  String get z0187;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'两位数打卡达成！继续向前。'**
  String get z0188;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'20天'**
  String get z0189;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'20天的坚持，你已经在悄悄变强。'**
  String get z0190;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'🎉 一个月！恭喜你成为「月度之星」，守护已融入日常。'**
  String get z0191;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'一个半月'**
  String get z0192;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'一个半月。你用实际行动证明，坚持并不难。'**
  String get z0193;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'两个月'**
  String get z0194;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'🔥 两个月！你的守护之火正在燃烧。'**
  String get z0195;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'一个季度'**
  String get z0196;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'一个季度。你渡过了春夏秋冬的一个切面，了不起。'**
  String get z0197;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'⭐ 百日守护！你是自己的英雄。今天值得好好庆祝。'**
  String get z0198;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'半年'**
  String get z0199;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'半年了。这180天的坚守，是你给自己最好的礼物。'**
  String get z0200;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'一周年'**
  String get z0201;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'👑 一年！你做到了。守护已经成为你的本能。'**
  String get z0202;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'{p1}天里程碑'**
  String z0203(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'第 {p1} 天！你的每一步坚持都在创造奇迹。'**
  String z0204(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'元旦'**
  String get z0205;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'新年第一天，从这个签到开始。今年，也要好好守护自己。'**
  String get z0206;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'清明'**
  String get z0207;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'慎终追远，珍惜当下。好好活着，就是最好的告慰。'**
  String get z0208;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'劳动节'**
  String get z0209;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'致敬每一个认真生活的你。今天，让自己歇一歇。'**
  String get z0210;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'端午'**
  String get z0211;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'端午安康。系一根彩绳，也系住对自己的那份关心。'**
  String get z0212;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'中秋'**
  String get z0213;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'海上生明月，天涯共此时。你并不孤单。'**
  String get z0214;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'国庆'**
  String get z0215;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'普天同庆，山河远阔。别忘了，对自己好一点。'**
  String get z0216;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'春节'**
  String get z0217;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'新年快乐！无论在哪过年，记得有人一直在牵挂你。'**
  String get z0218;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'除夕'**
  String get z0219;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'岁末的最后一次签到。这一年，你辛苦了。'**
  String get z0220;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'元宵'**
  String get z0221;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'花灯如昼，月圆人圆。愿你每一天都温暖明亮。'**
  String get z0222;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'龙抬头'**
  String get z0223;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'二月二，龙抬头。春天来了，你的好运也开始抬头。'**
  String get z0224;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'七夕'**
  String get z0225;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'今夜星河璀璨。先爱自己，再爱他人。'**
  String get z0226;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'重阳'**
  String get z0227;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'登高望远，天高云淡。人生不怕晚，就怕不上山。'**
  String get z0228;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'小寒'**
  String get z0229;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'天寒地冻，照顾好自己就是最大的温暖。'**
  String get z0230;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'大寒'**
  String get z0231;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'一年中最冷的时刻，也是最靠近春天的时刻。'**
  String get z0232;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'立春'**
  String get z0233;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'春回大地。你心里的种子，要发芽了。'**
  String get z0234;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'雨水'**
  String get z0235;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'好雨知时节。今天记得带伞，也要记得吃饭。'**
  String get z0236;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'惊蛰'**
  String get z0237;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'春雷乍响，万物复苏。你身体里的能量也该醒了。'**
  String get z0238;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'春分'**
  String get z0239;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'昼夜等长，阴阳平衡。今天，和自己和解。'**
  String get z0240;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'清明（节气）'**
  String get z0241;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'春和景明，万物生长。今天适合出去走走。'**
  String get z0242;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'谷雨'**
  String get z0243;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'雨生百谷。播种希望，静待收获。'**
  String get z0244;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'立夏'**
  String get z0245;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'夏天来了，热气腾腾地活着。'**
  String get z0246;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'小满'**
  String get z0247;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'小满胜万全。凡事不必太满，刚刚好就好。'**
  String get z0248;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'芒种'**
  String get z0249;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'芒种忙种。所有付出，终将收获。'**
  String get z0250;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'夏至'**
  String get z0251;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'一年中最长的白昼。今天，要多爱自己一点。'**
  String get z0252;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'小暑'**
  String get z0253;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'暑气渐浓。心静自然凉。'**
  String get z0254;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'大暑'**
  String get z0255;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'炎炎夏日，记得给自己一杯凉白开。'**
  String get z0256;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'立秋'**
  String get z0257;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'一叶知秋。有些事，该放就放。'**
  String get z0258;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'处暑'**
  String get z0259;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'暑气消退，秋意渐浓。一切都在慢慢变好。'**
  String get z0260;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'白露'**
  String get z0261;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'白露为霜。天凉了，记得添衣。'**
  String get z0262;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'秋分'**
  String get z0263;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'平分秋色。生活有一半明媚，一半从容。'**
  String get z0264;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'寒露'**
  String get z0265;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'露水渐寒。再忙，也别忘了签到。'**
  String get z0266;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'霜降'**
  String get z0267;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'霜降人间。秋天最后一个节气，要好好收尾。'**
  String get z0268;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'立冬'**
  String get z0269;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'冬天来了。记得把温暖留一份给自己。'**
  String get z0270;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'小雪'**
  String get z0271;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'小雪飘落。愿你心里有光，不惧严寒。'**
  String get z0272;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'大雪'**
  String get z0273;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'大雪纷飞。在最冷的日子里，做自己的暖阳。'**
  String get z0274;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'冬至'**
  String get z0275;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'冬至大如年。今天记得吃饺子/汤圆，也要记得签到。'**
  String get z0276;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'欢迎回来'**
  String get z0277;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'开发者模式 v2.0'**
  String get z0776;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'3D 宣传录制模式'**
  String get z0777;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'进入电影感动画秀，用于录制宣传视频'**
  String get z0778;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'重置今日签到'**
  String get z0779;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'清除今天的签到记录，可重新签到'**
  String get z0780;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'恢复为初始3张卡状态'**
  String get z0781;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'体验版 ↔ 智能版'**
  String get z0782;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'测试智能版过期后自动降级为体验版'**
  String get z0783;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'逆地理诊断'**
  String get z0032;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'查看本次地址来源（高德/系统）及错误码'**
  String get z0784;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'Apple Watch 测试'**
  String get z0033;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'查看 Watch 信号 & 触发一次静默签到'**
  String get z0785;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'HealthKit 诊断'**
  String get z0034;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'查看授权/错误/最近一次拉取，并可一键触发读取'**
  String get z0786;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'导出工作记忆 / 切换账号'**
  String get z0787;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'导出本机调试数据（不含token）并退出登录'**
  String get z0788;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'来源：{p1}'**
  String z0789(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'时间：{p1}'**
  String z0790(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'地址：{p1}'**
  String z0791(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'高德 info：{p1}'**
  String z0792(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'高德 infocode：{p1}'**
  String z0793(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'诊断信息已复制'**
  String get z0794;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'最后一次 Watch action：{p1}'**
  String z0795(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'最后一次 Watch 时间：{p1}'**
  String z0796(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'提示：健康数据读取不依赖 Watch App，Apple Watch 佩戴数据会自动写入 iPhone 健康。'**
  String get z0797;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'已写入 Watch 签到信号（pending_watch_checkin=true）'**
  String get z0798;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'模拟信号'**
  String get z0799;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'触发静默签到'**
  String get z0800;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'最近授权：{p1}'**
  String z0801(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'授权时间：{p1}'**
  String z0802(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'授权错误：{p1}'**
  String z0803(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'最近拉取条数：{p1}'**
  String z0804(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'拉取时间：{p1}'**
  String z0805(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'拉取错误：{p1}'**
  String z0806(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'按类型条数：{p1}'**
  String z0807(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'按类型错误：{p1}'**
  String z0808(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'重新授权'**
  String get z0809;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'触发读取'**
  String get z0810;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'导出工作记忆'**
  String get z0811;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'已复制工作记忆（不含token）'**
  String get z0812;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'第1天'**
  String get z0813;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'第6天'**
  String get z0814;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'第7天'**
  String get z0815;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'第29天'**
  String get z0816;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'第30天'**
  String get z0817;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'第99天'**
  String get z0818;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'第100天'**
  String get z0819;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'第364天'**
  String get z0820;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'第365天'**
  String get z0821;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'第1825天'**
  String get z0822;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'设置连续签到天数，然后点击\"模拟签到\"。'**
  String get z0823;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'连续签到天数'**
  String get z0824;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'输入 1-1825 之间的天数'**
  String get z0825;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'快捷选择：'**
  String get z0826;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'请输入 1-1825 之间的有效天数'**
  String get z0827;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'模拟签到'**
  String get z0828;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'已模拟连续签到 {p1} 天 ✓'**
  String z0829(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'弹窗显示失败: {p1}'**
  String z0830(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'重置签到'**
  String get z0831;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'这将清除今天的签到记录，你可以重新签到。'**
  String get z0832;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'连续天数不会受影响。'**
  String get z0833;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'今日签到已重置 ✓'**
  String get z0834;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'这将重置守护卡为初始状态：'**
  String get z0835;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'• 后端配额重置为 3 张（30天有效期）'**
  String get z0836;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'• 清除本地所有守护卡缓存数据'**
  String get z0837;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'• 重置首次发卡日期'**
  String get z0838;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'后端已发出的卡片不受影响，仍可被注册'**
  String get z0839;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'守护卡已重置为初始状态 ✓（3张，30天有效）'**
  String get z0840;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'本地守护卡已重置 ✓（后端未登录未重置）'**
  String get z0841;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'请先切换为智能版，再测试过期降级'**
  String get z0842;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'模拟会员过期'**
  String get z0843;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'模拟智能版过期后自动降级为体验版：'**
  String get z0844;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'• 紧急求助快捷拨打上限：3位 → 1位'**
  String get z0845;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'• 联系人上限：10位 → 5位'**
  String get z0846;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'• 超出限制的联系人显示锁定图标'**
  String get z0847;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'• 已添加的联系人数据保留'**
  String get z0848;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'⚠️ 仅开发测试用，不影响后端数据'**
  String get z0035;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'已模拟会员过期降级 → 体验版 ✓'**
  String get z0849;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'模拟过期'**
  String get z0850;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'体验版（免费）'**
  String get z0851;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'智能版（¥9/月）'**
  String get z0852;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'紧急求助快捷拨打 1 位 · 最多 5 位联系人'**
  String get z0853;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'紧急求助快捷拨打 3 位 · 最多 10 位联系人'**
  String get z0854;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'当前：{p1}'**
  String z0855(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'切换为：{p1}'**
  String z0856(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'已切换为 {p1} ✓'**
  String z0857(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'确认切换'**
  String get z0858;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'在安全区'**
  String get z0326;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'已离开'**
  String get z0327;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'未检查'**
  String get z0328;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'安全围栏提醒'**
  String get z0329;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'离开安全区域时提醒'**
  String get z0330;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'已离开{p1}安全区'**
  String z0331(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'你已离开「{p1}」安全区域'**
  String z0332(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'父母深夜等你报平安，爱人担心你独自出行，孩子希望你早点回家。'**
  String get z0279;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'在呢，不只是App，是你和在乎的人之间，一条永远在线的守护线。'**
  String get z0280;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'• 订阅名称：在呢智能版\n'**
  String get z0281;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'• 订阅时长：{p1}\n'**
  String z0282(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'• 订阅价格：{p1}\n'**
  String z0283(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'• 自动续费：当前计费周期结束前24小时自动扣款\n'**
  String get z0284;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'• 取消方式：随时可在 Apple ID 设置中取消，取消后当前周期仍可用'**
  String get z0285;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'暂无{p1}数据'**
  String z0765(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'佩戴 Apple Watch 并开启健康权限后可查看'**
  String get z0766;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'最近{p1}天趋势'**
  String z0767(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'当前'**
  String get z0768;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'平均'**
  String get z0769;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'最高'**
  String get z0770;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'\n      CREATE TABLE checkin_records (\n        id INTEGER PRIMARY KEY AUTOINCREMENT,\n        checkin_date TEXT NOT NULL,      -- 签到日期 (YYYY-MM-DD)\n        checkin_time TEXT NOT NULL,      -- 签到时间 (HH:MM:SS)\n        timestamp INTEGER NOT NULL,       -- Unix 时间戳（毫秒）\n        created_at TEXT DEFAULT CURRENT_TIMESTAMP\n      )\n    '**
  String get z0295;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'\n      CREATE TABLE contacts (\n        id INTEGER PRIMARY KEY AUTOINCREMENT,\n        server_id TEXT,                   -- 服务器返回的 ID（可为空，本地联系人）\n        name TEXT NOT NULL,\n        phone TEXT NOT NULL,\n        relation TEXT,                    -- 关系：家人/朋友/同事等\n        avatar_path TEXT,                 -- 头像本地路径\n        is_local INTEGER DEFAULT 0,       -- 1=本地联系人，0=服务器同步\n        is_emergency INTEGER DEFAULT 0,   -- 1=紧急联系人\n        sort_order INTEGER DEFAULT 0,     -- 排序权重\n        created_at TEXT DEFAULT CURRENT_TIMESTAMP,\n        updated_at TEXT DEFAULT CURRENT_TIMESTAMP\n      )\n    '**
  String get z0296;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'\n      CREATE TABLE health_cache (\n        id INTEGER PRIMARY KEY AUTOINCREMENT,\n        data_type TEXT NOT NULL,          -- 数据类型：steps/heart_rate/distance\n        value REAL NOT NULL,              -- 数值\n        unit TEXT,                        -- 单位\n        date TEXT NOT NULL,               -- 日期 (YYYY-MM-DD)\n        timestamp INTEGER NOT NULL,       -- 记录时间戳\n        source TEXT,                      -- 数据来源：HealthKit/手动\n        UNIQUE(data_type, date) ON CONFLICT REPLACE\n      )\n    '**
  String get z0297;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'\n      CREATE TABLE notification_history (\n        id INTEGER PRIMARY KEY AUTOINCREMENT,\n        type TEXT NOT NULL,               -- 类型：sos/checkin/reminder\n        recipient TEXT,                   -- 接收者\n        content TEXT,                     -- 内容摘要\n        status TEXT,                      -- 状态：sent/failed/pending\n        sent_at TEXT DEFAULT CURRENT_TIMESTAMP\n      )\n    '**
  String get z0298;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'\n      CREATE TABLE location_history (\n        id INTEGER PRIMARY KEY AUTOINCREMENT,\n        latitude REAL NOT NULL,\n        longitude REAL NOT NULL,\n        address TEXT,                     -- 逆地理编码地址\n        accuracy REAL,                    -- 精度（米）\n        trigger_reason TEXT,              -- 触发原因：sos/checkin/manual\n        created_at TEXT DEFAULT CURRENT_TIMESTAMP\n      )\n    '**
  String get z0299;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'首页'**
  String get z0036;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'守护圈'**
  String get z0037;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'我的'**
  String get z0038;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'正在获取位置...'**
  String get z0461;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'当前位置'**
  String get z0462;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'位置获取失败'**
  String get z0463;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'点击刷新重试'**
  String get z0464;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'连续签到'**
  String get z0745;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'{p1} 天'**
  String z0746(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'{p1} 天'**
  String z0747(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'本周进度'**
  String get z0748;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'守护已就绪 · {p1} 天连续守护'**
  String z0898(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'请完善健康档案，开启守护'**
  String get z0899;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **' · {p1} 位守护成员'**
  String z0900(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **' · {p1} 位守护者'**
  String z0901(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'已完成 ✓'**
  String get z0625;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'🔒 请先完成上一步'**
  String get z0626;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'真的待解锁'**
  String get z0286;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'  卡片[{p1}] id={p2} status={p3} (type:{p4}) receiver={p5} code={p6}...'**
  String z0287(
      Object? p1, Object? p2, Object? p3, Object? p4, Object? p5, Object? p6);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'  ⚠️ 发卡后被过滤器丢弃: status={p1} is_free={p2}'**
  String z0288(Object? p1, Object? p2);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'{p1}，我在「在呢」给你发了一张守护卡，还没激活哦~\n\n'**
  String z0289(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'下载 App 登录后，我们就能互相报平安、遇到事情第一时间找到彼此。\n\n'**
  String get z0290;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'点下面链接立即激活守护关系：\n{p1}'**
  String z0291(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'位置权限未开启，请先在求助页面开启位置权限'**
  String get z0300;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'定位服务未开启，请在系统设置中开启'**
  String get z0301;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'位置获取失败，请手动告知位置'**
  String get z0302;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'超时自动确认 — 已通知守护者'**
  String get z0323;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'用户确认为误报'**
  String get z0324;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'用户确认需要帮助 — 已通知守护者'**
  String get z0325;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'守护成功 🎉'**
  String get z0522;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'开启你的守护礼'**
  String get z0523;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'已成为你的守护人'**
  String get z0524;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'{p1}想确认你是否平安'**
  String z0762(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'点击下方按钮让他们安心'**
  String get z0763;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'我平安'**
  String get z0764;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'暂无紧急联系人'**
  String get z0880;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'添加至少一个紧急联系人\n确保求助功能正常触发'**
  String get z0881;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'紧急联系人将在求助时收到您的位置和健康信息\n拖动可调整优先顺序'**
  String get z0882;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'已复制，去微信粘贴发送 💬'**
  String get z0039;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'打开微信'**
  String get z0040;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'（{p1}）'**
  String z0321(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'未记录'**
  String get z0322;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'点击发送紧急求助'**
  String get z0520;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'请先完善健康档案'**
  String get z0521;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'亲友'**
  String get z0664;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'编辑'**
  String get z0665;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'智能版已激活！'**
  String get z0760;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'现在可同时通知3位守护人'**
  String get z0761;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'在呢+'**
  String get z0278;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'旧关系={p1}, 新关系={p2}'**
  String z0292(Object? p1, Object? p2);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'点了没反应'**
  String get z0293;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'{p1} @ {p2}:{p3}'**
  String z0294(Object? p1, Object? p2, Object? p3);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'Apple 登录失败: {p1}'**
  String z0459(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'安全区域'**
  String get z0460;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'· 在呢 · 守护卡 ·'**
  String get z0749;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'致 {p1}'**
  String z0750(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'见信如晤'**
  String get z0751;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'扫一扫，领取守护'**
  String get z0752;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'在呢+ · 收到一份温暖的牵挂'**
  String get z0753;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'扫码失败？在 App 内输入此码绑定'**
  String get z0754;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'已有 {p1} 人加入守护圈'**
  String z0755(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'· 在呢 · 守护已建立 ·'**
  String get z0756;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'{p1} 想守护你'**
  String z0757(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'从今天起，你们将互相收到每日签到提醒'**
  String get z0758;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'让在乎的人知道你很好 💌'**
  String get z0759;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'发送给 {p1}'**
  String z0701(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'情感'**
  String get z0702;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'自然'**
  String get z0703;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'动作'**
  String get z0704;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'社交'**
  String get z0705;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'{p1} 送给你'**
  String z0706(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'春'**
  String get z0041;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'夏'**
  String get z0042;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'秋'**
  String get z0043;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'冬'**
  String get z0044;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'早安'**
  String get z0045;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'午安'**
  String get z0046;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'晚安'**
  String get z0047;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'{p1}，春暖花开'**
  String z0048(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'{p1}，夏日清凉'**
  String z0049(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'{p1}，秋高气爽'**
  String z0050(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'{p1}，冬日温暖'**
  String z0051(Object? p1);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'我没事'**
  String get z0902;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'立即签到'**
  String get z0903;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'需要帮助'**
  String get z0904;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'确认向守护者发送求助通知？他们收到后会尽快联系你。'**
  String get z0905;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'通知守护者'**
  String get z0906;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'已通知守护者'**
  String get z0907;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'平安确认中'**
  String get z0908;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'已报平安'**
  String get z0909;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'已联系'**
  String get z0910;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'暂无可处理的请求'**
  String get z0911;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'已标记为已处理'**
  String get z0912;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'标记失败，请重试'**
  String get z0913;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'回复后对方会立即看到你的状态'**
  String get z0914;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'说点什么…（选填，最多100字）'**
  String get z0915;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'留言仅发送给你的守护者'**
  String get z0916;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'补充一句（10字内）'**
  String get z0925;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'{p1}（{p2}）'**
  String z0926(Object? p1, Object? p2);

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'留言'**
  String get z0917;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'报个平安'**
  String get z0918;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'刚到家'**
  String get z0919;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'刚下班'**
  String get z0920;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'刚吃过饭'**
  String get z0921;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'准备睡了'**
  String get z0922;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'选个状态（选填）'**
  String get z0923;

  /// auto i18n extracted
  ///
  /// In zh_CN, this message translates to:
  /// **'状态'**
  String get z0924;

  /// v1.98.0 home arrival feature
  ///
  /// In zh_CN, this message translates to:
  /// **'到家提醒'**
  String get homeArrivalTitle;

  /// v1.98.0 home arrival feature
  ///
  /// In zh_CN, this message translates to:
  /// **'回家第一时间，让牵挂你的人安心'**
  String get homeArrivalDesc;

  /// v1.98.0 home arrival feature
  ///
  /// In zh_CN, this message translates to:
  /// **'开启到家提醒'**
  String get homeArrivalEnable;

  /// v1.98.1 home arrival permission / copy tweaks
  ///
  /// In zh_CN, this message translates to:
  /// **'同时通知守护人'**
  String get homeArrivalModeBNotify;

  /// v1.98.1 home arrival permission / copy tweaks
  ///
  /// In zh_CN, this message translates to:
  /// **'开启后，你一到家守护人就会收到「已安全到家」通知；关闭则只提醒你自己报平安。'**
  String get homeArrivalModeBDetail;

  /// v1.98.0 home arrival feature
  ///
  /// In zh_CN, this message translates to:
  /// **'设置家的位置'**
  String get homeArrivalSetHome;

  /// v1.98.0 home arrival feature
  ///
  /// In zh_CN, this message translates to:
  /// **'使用当前位置设为家'**
  String get homeArrivalUseCurrent;

  /// v1.98.0 home arrival feature
  ///
  /// In zh_CN, this message translates to:
  /// **'家已设置'**
  String get homeArrivalHomeSet;

  /// v1.98.0 home arrival feature
  ///
  /// In zh_CN, this message translates to:
  /// **'尚未设置家的位置'**
  String get homeArrivalHomeNotSet;

  /// v1.98.0 home arrival feature
  ///
  /// In zh_CN, this message translates to:
  /// **'到家提醒需要「始终允许」定位权限，以便在后台检测你到家'**
  String get homeArrivalNeedLocationPerm;

  /// v1.98.0 home arrival feature
  ///
  /// In zh_CN, this message translates to:
  /// **'记得先设置家的位置（一键用当前位置）'**
  String get homeArrivalSetHomeHint;

  /// v1.98.0 home arrival feature
  ///
  /// In zh_CN, this message translates to:
  /// **'设置家位置失败'**
  String get homeArrivalSetHomeFailed;

  /// v1.98.0 home arrival feature
  ///
  /// In zh_CN, this message translates to:
  /// **'到家啦 🏠'**
  String get homeArrivalLocalTitle;

  /// v1.98.0 home arrival feature
  ///
  /// In zh_CN, this message translates to:
  /// **'记得报个平安，让守护你的人放心。'**
  String get homeArrivalLocalBody;

  /// v1.98.0 home arrival feature
  ///
  /// In zh_CN, this message translates to:
  /// **'开启到家提醒？'**
  String get homeArrivalNewUserTitle;

  /// v1.98.0 home arrival feature
  ///
  /// In zh_CN, this message translates to:
  /// **'回家时自动提醒你报平安，或让守护人知道你已安全到家。'**
  String get homeArrivalNewUserBody;

  /// v1.98.0 home arrival feature
  ///
  /// In zh_CN, this message translates to:
  /// **'开启'**
  String get homeArrivalNewUserEnable;

  /// v1.98.0 home arrival feature
  ///
  /// In zh_CN, this message translates to:
  /// **'稍后'**
  String get homeArrivalNewUserLater;

  /// v1.98.0 home arrival feature
  ///
  /// In zh_CN, this message translates to:
  /// **'获取位置失败，请检查定位权限后重试'**
  String get homeArrivalLocationFailed;

  /// v1.98.0 home arrival pick home on Apple Maps
  ///
  /// In zh_CN, this message translates to:
  /// **'在地图上选家'**
  String get homeArrivalPickOnMap;

  /// v1.98.1 home arrival permission / copy tweaks
  ///
  /// In zh_CN, this message translates to:
  /// **'到家提醒需要「始终允许」定位权限，才能在 App 关闭时触发。请到 iPhone 设置 → 在呢+ → 位置 中选择「始终允许」。'**
  String get homeArrivalNeedAlways;

  /// v1.98.1 home arrival permission / copy tweaks
  ///
  /// In zh_CN, this message translates to:
  /// **'去设置'**
  String get homeArrivalGoSettings;

  /// v1.98.1 home arrival permission / copy tweaks
  ///
  /// In zh_CN, this message translates to:
  /// **'请在弹窗中选择「始终允许」，到家提醒才能在 App 关闭时生效。'**
  String get homeArrivalAlwaysPrompt;

  /// v1.98.1 home arrival permission / copy tweaks
  ///
  /// In zh_CN, this message translates to:
  /// **'已开启始终定位，到家提醒生效 🏠'**
  String get homeArrivalAlwaysGranted;
}

class _SDelegate extends LocalizationsDelegate<S> {
  const _SDelegate();

  @override
  Future<S> load(Locale locale) {
    return SynchronousFuture<S>(lookupS(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_SDelegate old) => false;
}

S lookupS(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.countryCode) {
          case 'CN':
            return SZhCn();
          case 'HK':
            return SZhHk();
          case 'TW':
            return SZhTw();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return SEn();
    case 'zh':
      return SZh();
  }

  throw FlutterError(
      'S.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
