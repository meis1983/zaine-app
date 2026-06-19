import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import '../services/platform/location_service.dart';
import '../services/membership_service.dart';
import '../services/api_service.dart';
import '../theme/theme_helper.dart';
import '../widgets/help_result_dialog.dart';
import '../widgets/full_help_page_widget.dart';
import '../widgets/lightweight_guide_widget.dart';
import 'profile_page.dart';
import 'contacts_page.dart';

class HelpPage extends StatefulWidget {
  const HelpPage({super.key});

  @override
  State<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends State<HelpPage> with TickerProviderStateMixin {

  // ========== 三道门前置状态 ==========
  bool _prerequisitesChecked = false;
  bool _hasProfileReady = false;
  bool _hasContactsReady = false;
  bool _hasLocationReady = false;

  // ========== 防止 iOS 手势返回误 pop ==========
  /// 当有子页面被 push 到栈上时设为 true，
  /// 阻止 iOS 手势返回直接把求助页面弹走（导致黑屏）
  bool _isChildPageOpen = false;

  // ========== 定位相关 ==========
  String? _address;
  String? _coordLat;
  String? _coordLng;
  bool _locationLoading = true;

  // ========== 健康档案数据 ==========
  String _userName = '';
  int _userAge = 0;
  String _bloodType = '未知';
  String _allergy = '';
  String _disease = '';
  String _medicine = '';
  String _emergencyNote = '';
  String? _myPhone; // 用户自己的手机号（用于短信模板和UI预览）

  // ========== 求助触发状态 ==========
  bool _isTriggering = false;
  int _countdown = 5;  // 改为 5 秒倒计时（用户可取消）

  // ========== 求助已触发后的行动状态 ==========
  final bool _smsSent = false;
  bool _calledContact = false;
  bool _locationObtained = false;

  // ========== 动画控制器 ==========
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _checkPrerequisites();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // ==================== 三道门前置检查 ====================

  Future<void> _checkPrerequisites() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 条件0：提前读取用户手机号（确保短信模板可用）
      _myPhone = prefs.getString('user_phone') ?? '';

      // 条件1：个人档案【修复 v1.9.x】按用户隔离读取，防止跨账号串数据
      final userId = prefs.getString('user_id');
      final phone = prefs.getString('user_phone');
      String? profileKey;
      String? profileJson;
      
      // 优先使用 user_id 作为隔离标识
      if (userId != null && userId.isNotEmpty) {
        profileKey = 'user_profile_$userId';
        profileJson = prefs.getString(profileKey);
        // 兼容旧数据：如果用户特定的键不存在，尝试全局键并迁移
        if (profileJson == null) {
          profileJson = prefs.getString('user_profile');
          if (profileJson != null) {
            await prefs.setString(profileKey, profileJson);
            if (kDebugMode) debugPrint('[Help] ✅ 健康档案已从全局键迁移到用户特定键: $profileKey');
          }
        }
      } else if (phone != null && phone.isNotEmpty) {
        profileKey = 'user_profile_$phone';
        profileJson = prefs.getString(profileKey);
        if (profileJson == null) {
          profileJson = prefs.getString('user_profile');
          if (profileJson != null) {
            await prefs.setString(profileKey, profileJson);
          }
        }
      } else {
        profileJson = prefs.getString('user_profile');
      }
      
      bool profileOk = false;
      if (profileJson != null) {
        try {
          final profile = jsonDecode(profileJson);
          _userName = profile['name'] ?? '';
          _userAge = profile['age'] ?? 0;
          _bloodType = profile['bloodType'] ?? '未知';
          _allergy = profile['allergy'] ?? '';
          _disease = profile['disease'] ?? '';
          _medicine = profile['medicine'] ?? '';
          _emergencyNote = profile['emergencyNote'] ?? '';
          profileOk = _userName.isNotEmpty && _userAge > 0 && _bloodType != '未知' && _bloodType.isNotEmpty;
        } catch (_) {}
      }
      _hasProfileReady = profileOk;

      // 条件2：紧急联系人（与 contacts_page.dart 保持一致的 key 规则）
      // userId 已在上方 line 92 声明，此处直接复用
      final contactsKey = (userId != null && userId.isNotEmpty)
          ? 'emergency_contacts_$userId'
          : 'emergency_contacts';
      final contactsJson = prefs.getString(contactsKey) ?? '[]';
      List<dynamic> contacts = [];
      try { contacts = jsonDecode(contactsJson); } catch (_) {}
      _hasContactsReady = contacts.isNotEmpty;

      // 条件3：位置权限（加超时保护，防止原生桥调用卡住导致白屏）
      try {
        _hasLocationReady = await LocationService.hasPermission()
            .timeout(const Duration(seconds: 5), onTimeout: () {
          if (kDebugMode) debugPrint('[Help] hasPermission 超时(5s)，默认 false');
          return false;
        });
      } catch (e) {
        if (kDebugMode) debugPrint('[Help] hasPermission 异常: $e');
        _hasLocationReady = false;
      }

      if (!mounted) return;
      setState(() => _prerequisitesChecked = true);

      if (_hasProfileReady && _hasContactsReady && _hasLocationReady) {
        _loadLocation();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Help] _checkPrerequisites 异常: $e');
      // 即使出错也要让页面渲染出来，不能白屏
      if (mounted) {
        setState(() => _prerequisitesChecked = true);
      }
    }
  }

  /// 跳转到目标页面（用 push，不用 replacement，保证返回不黑屏）
  Future<void> _goToPage(Widget page) async {
    setState(() => _isChildPageOpen = true);
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => page),
    );
    // 用户返回后清除标记并重新检查状态
    if (mounted) {
      setState(() => _isChildPageOpen = false);
      _recheck();
    }
  }

  /// 请求位置权限（极简版 —— 用户点一下就搞定）
  ///
  /// 设计原则：
  /// - 不搞复杂引导、不搞多步说明
  /// - 用户点「去开启」→ request() → 弹系统框 → 点允许 → 完成
  /// - 如果系统不弹框（永久拒绝态）→ 一句话 + 一个按钮跳设置
  Future<void> _requestLocationPermission() async {
    if (kDebugMode) debugPrint('[Help] _requestLocationPermission 开始, 当前 _hasLocationReady=$_hasLocationReady');
    
    // ★ 修复：跳过 hasPermission 缓存检查，直接请求（Geolocator.requestPermission 会返回最新的 iOS 实际状态）
    if (kDebugMode) debugPrint('[Help] ===== 开始请求位置权限（用户主动点击）=====');
    final status = await LocationService.requestPermission();
    if (kDebugMode) debugPrint('[Help] 权限请求结果: $status, isGranted=${status.isGranted}, isLimited=${status.isLimited}');

    if ((status.isGranted || status.isLimited) && mounted) {
      // ✅ 成功 → 绿色提示
      if (kDebugMode) debugPrint('[Help] 权限授权成功！setState _hasLocationReady=true');
      setState(() => _hasLocationReady = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 18),
              SizedBox(width: ZaiNeSpacing.sm),
              Text('✅ 位置权限已开启！'),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZaiNeRadius.small)),
          duration: const Duration(seconds: 2),
        ),
      );
    } else if (status.isPermanentlyDenied && mounted) {
      // ★ 永久拒绝 → 弹对话框引导去系统设置
      if (kDebugMode) debugPrint('[Help] 权限被永久拒绝，弹出引导对话框');
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('需要位置权限'),
          content: const Text('您之前拒绝了位置权限，请在系统设置中开启。\n\n设置路径：\n隐私 → 定位服务 → 在呢 → "使用App期间"'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _openLocationSettings();
              },
              child: const Text('去设置'),
            ),
          ],
        ),
      );
    } else if (mounted) {
      // ❌ 失败 → SnackBar提示
      if (kDebugMode) debugPrint('[Help] 权限请求失败: $status');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.location_off, color: Colors.white, size: 18),
              SizedBox(width: ZaiNeSpacing.sm),
              Expanded(child: Text('位置权限未开启。紧急求助需要您的位置才能发送求救信息')),
            ],
          ),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZaiNeRadius.small)),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: '去设置',
            textColor: Colors.white,
            onPressed: () => _openLocationSettings(),
          ),
        ),
      );
    }
  }

  /// 打开系统设置页面（位置服务或 App 设置）
  /// ⚠️ 重要：使用 Navigator.push + EventChannel 监听 App 从后台恢复，
  ///       这样当用户在设置中开启权限并返回时，能自动刷新权限状态。
  Future<void> _openLocationSettings() async {
    try {
      if (kDebugMode) debugPrint('[Help] 调用 openAppSettings()...');
      // 使用 permission_handler 的 openAppSettings，它会在用户返回后 resolve
      final opened = await openAppSettings();
      if (kDebugMode) debugPrint('[Help] 用户已从设置返回，opened=$opened');
    } catch (e) {
      if (kDebugMode) debugPrint('[Help] openAppSettings 失败: $e');
    }

    // ⭐ 关键：用户从设置返回后，立刻重新检查权限
    if (!mounted) return;
    if (kDebugMode) debugPrint('[Help] 重新检查位置权限...');
    final hasPerm = await LocationService.hasPermission();
    if (kDebugMode) debugPrint('[Help] 重新检查结果: hasPerm=$hasPerm');

    if (hasPerm && mounted) {
      if (kDebugMode) debugPrint('[Help] 设置返回后权限已开启！setState _hasLocationReady=true');
      setState(() => _hasLocationReady = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 18),
              SizedBox(width: ZaiNeSpacing.sm),
              Text('✅ 位置权限已开启！'),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
          duration: const Duration(seconds: 2),
        ),
      );
    } else if (mounted) {
      // 还是没有权限——可能用户没改，给个轻提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('位置权限仍未开启，请确保已设置为「使用期间允许」'),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// 重新检查三道门（静默检查，不切回 loading，防止白屏）
  void _recheck() {
    // 不再把 _prerequisitesChecked 设为 false！
    // 直接在后台静默重新检查，完成后 setState 更新各状态即可
    _checkPrerequisites();
  }

  // ==================== 实时定位 ====================

  Future<void> _loadLocation() async {
    if (mounted) setState(() => _locationLoading = true);
    final result = await LocationService.getCurrentLocation();
    if (!mounted) return;
    setState(() {
      _locationLoading = false;
      if (result.isSuccess && result.latitude != null) {
        _address = result.address;
        _coordLat = '北纬 ${result.latitude!.toStringAsFixed(6)}°';
        _coordLng = '东经 ${result.longitude!.toStringAsFixed(6)}°';
      } else {
        _address = null;
        _coordLat = null;
        _coordLng = null;
      }
    });
  }

  // ==================== 构建 UI ====================

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isChildPageOpen,
      child: Builder(
        builder: (context) {
          try {
            return _buildActualPage(context);
          } catch (e, st) {
            if (kDebugMode) debugPrint('[Help] ⚠️ build 异常: $e\n$st');
            // 防止白屏：渲染一个错误提示页面，至少让用户能看到信息
            return Scaffold(
              backgroundColor: ZaiNeColors.scaffoldBg(),
              appBar: AppBar(
                backgroundColor: Colors.transparent, elevation: 0,
                leading: null,
                title: Text('紧急求助', style: TextStyle(color: ZaiNeColors.textPrimary())),
                centerTitle: true,
              ),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 48),
                      const SizedBox(height: ZaiNeSpacing.lg),
                      const Text('紧急求助页面加载异常', style: TextStyle(fontSize: ZaiNeFontSize.title, fontWeight: FontWeight.bold)),
                      const SizedBox(height: ZaiNeSpacing.sm),
                      Text('错误信息: $e', style: const TextStyle(fontSize: ZaiNeFontSize.caption, color: Colors.grey)),
                      const SizedBox(height: ZaiNeSpacing.xl),
                      ElevatedButton(
                        onPressed: () => setState(() {}),
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
        },
      ),
    );
  }

  /// 实际的页面构建逻辑
  Widget _buildActualPage(BuildContext context) {
    Widget child;
    if (!_prerequisitesChecked) {
      child = Scaffold(
        backgroundColor: ZaiNeColors.scaffoldBg(),
        appBar: AppBar(
          backgroundColor: Colors.transparent, elevation: 0,
          leading: null,
          title: Text('紧急求助', style: TextStyle(color: ZaiNeColors.textPrimary())),
          centerTitle: true,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    } else {
      final missingItems = <String>[];
      if (!_hasProfileReady) missingItems.add('档案');
      if (!_hasContactsReady) missingItems.add('联系人');
      if (!_hasLocationReady) missingItems.add('定位');

      child = missingItems.isNotEmpty
          ? LightweightGuideWidget(
              hasProfileReady: _hasProfileReady,
              hasContactsReady: _hasContactsReady,
              hasLocationReady: _hasLocationReady,
              pulseController: _pulseController,
              onGoToProfile: () => _goToPage(const ProfilePage(isPushed: true)),
              onGoToContacts: () => _goToPage(const ContactsPage()),
              onRequestLocationPermission: _requestLocationPermission,
            )
          : _buildFullHelpPageWidget();
    }
    return child;
  }

  /// 构建完整求助页面 Widget（包装 FullHelpPageWidget）
  Widget _buildFullHelpPageWidget() {
    return FullHelpPageWidget(
      isTriggering: _isTriggering,
      countdown: _countdown,
      myPhone: _myPhone,
      userName: _userName,
      userAge: _userAge,
      bloodType: _bloodType,
      pulseController: _pulseController,
      onTriggerHelp: _triggerHelp,
      onCancelHelp: _cancelHelp,
      onShowPhoneInput: _showPhoneInputDialog,
      locationLoading: _locationLoading,
      locationLat: _coordLat,
      locationLng: _coordLng,
      locationAddress: _address,
      onLocationRefresh: _loadLocation,
    );
  }

  // ==================== 完整求助主界面 ====================


  /// 实时定位卡片（增强版 - 详细信息）

  // ==================== 求助核心方法 ====================

  /// 弹出手机号设置对话框（用户补填）
  void _showPhoneInputDialog() {
    final controller = TextEditingController(text: _myPhone ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZaiNeRadius.card)),
        title: const Text('📱 设置手机号', style: TextStyle(fontSize: ZaiNeFontSize.title)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('设置后，紧急求助短信中将包含您的手机号', style: TextStyle(fontSize: ZaiNeFontSize.caption, color: Colors.grey)),
            const SizedBox(height: ZaiNeSpacing.md),
            TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              maxLength: 11,
              autofocus: true,
              decoration: InputDecoration(
                labelText: '手机号',
                hintText: '请输入11位手机号',
                prefixIcon: const Icon(Icons.phone),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              final phone = controller.text.trim();
              if (phone.length < 11) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请输入正确的11位手机号'), backgroundColor: Colors.orange),
                );
                return;
              }
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('user_phone', phone);
              setState(() => _myPhone = phone);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('手机号已设置为 $phone'), backgroundColor: Colors.green),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF7F50)),
            child: const Text('保存', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _triggerHelp() {
    HapticFeedback.heavyImpact();
    setState(() => _isTriggering = true);
    _countdown = 5;  // 改为5秒倒计时
    _startCountdown();
  }

  void _startCountdown() async {
    for (int i = 5; i > 0; i--) {  // 从5倒数到1
      if (!mounted || !_isTriggering) return;
      setState(() => _countdown = i);
      // 逐步加强震动反馈：5→轻，4→中，3→重，2→极重，1→警告
      if (i <= 2) {
        HapticFeedback.heavyImpact();
      } else if (i <= 4) {
        HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.lightImpact();
      }
      await Future.delayed(const Duration(seconds: 1));
    }
    if (!mounted || !_isTriggering) return;
    await _executeHelp();
  }

  Future<void> _executeHelp() async {
    HapticFeedback.heavyImpact();
    final prefs = await SharedPreferences.getInstance();
    // 与 contacts_page.dart 保持一致的 key 规则
    final userId = prefs.getString('user_id');
    final contactsKey = (userId != null && userId.isNotEmpty)
        ? 'emergency_contacts_$userId'
        : 'emergency_contacts';
    String contactsJson = prefs.getString(contactsKey) ?? '[]';
    List<Map<String, dynamic>> contacts = [];
    if (contactsJson.isNotEmpty) { try { contacts = List<Map<String, dynamic>>.from(jsonDecode(contactsJson)); } catch (_) {} }
    
    // 先获取最新位置
    await _loadLocation();

    // 获取用户自己的手机号
    _myPhone = prefs.getString('user_phone') ?? '';

    // 解析坐标（用于短信模板中的导航链接）
    String? latStr, lngStr;
    double? latVal, lngVal;
    if (_coordLat != null && _coordLng != null) {
      latStr = _coordLat!.replaceAll('北纬 ', '').replaceAll('°', '').replaceAll(' ', '');
      lngStr = _coordLng!.replaceAll('东经 ', '').replaceAll('°', '').replaceAll(' ', '');
      latVal = double.tryParse(latStr);
      lngVal = double.tryParse(lngStr);
    }

    // 【修复 v1.17.4-Bug4+5】生成两个 SOS 短链（苹果地图 + 高德地图）
    String? appleMapShortUrl;
    String? amapShortUrl;
    if (latVal != null && lngVal != null) {
      // 1. 生成苹果地图短链（使用现有 SOS 专用接口）
      try {
        final linkRes = await ApiService.createSosLink(
          lat: latVal,
          lng: lngVal,
          address: _address ?? '',
          userName: _userName,
          userPhone: _myPhone ?? '',
        );
        if (linkRes['success'] == true) {
          appleMapShortUrl = linkRes['short_url']?.toString();
          if (kDebugMode) debugPrint('[Help] 苹果地图短链生成成功: $appleMapShortUrl');
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[Help] 苹果地图短链生成失败: $e');
      }

      // 2. 生成高德地图短链（使用通用短链接口）
      try {
        final amapUrl = 'https://uri.amap.com/marker?position=$lngVal,$latVal&name=${Uri.encodeComponent(_address ?? '求助位置')}';
        final linkRes = await ApiService.createShortLink(
          targetUrl: amapUrl,
          linkType: 'amap_sos',
          meta: '${_userName.isNotEmpty ? _userName : "未知"}的紧急位置',
        );
        if (linkRes['success'] == true) {
          amapShortUrl = linkRes['short_url']?.toString();
          if (kDebugMode) debugPrint('[Help] 高德地图短链生成成功: $amapShortUrl');
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[Help] 高德地图短链生成失败: $e');
      }
    }

    // 生成完整短信内容（用于预览）
    final helpMessage = _generateHelpMessage(_myPhone ?? '', latStr, lngStr, appleMapShortUrl, amapShortUrl);
    if (kDebugMode) debugPrint('[Help] 短信模板:\n$helpMessage');

    // 标记位置已获取
    _locationObtained = true;

    // ⭐ 弹出求助已触发结果对话框
    if (mounted) _showHelpResultDialog(contacts, helpMessage);
  }

  void _cancelHelp() {
    HapticFeedback.lightImpact();
    setState(() => _isTriggering = false);
  }

  Future<void> _call120Directly() async {
    final uri = Uri(scheme: 'tel', path: '120');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  String _generateHelpMessage(String myPhone, [String? latStr, String? lngStr, String? appleMapShortUrl, String? amapShortUrl]) {
    final now = DateTime.now();
    final timeStr = '${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')} ${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}';
    final addrPart = (_address != null && _address!.isNotEmpty) ? _address! : '未知地址';
    // 坐标格式：无空格，确保 iOS SMS 能正确识别为 URL
    final coordPart = (latStr != null && lngStr != null)
        ? '$latStr,$lngStr'
        : '';

    final sb = StringBuffer();
    sb.writeln('【在呢 紧急求助】');
    sb.writeln(timeStr);
    sb.writeln('');
    sb.writeln('求救人：${_userName.isNotEmpty ? _userName : "未知"}');
    // 求救者手机号——始终显示（紧急场景不能缺此信息），未设置时提示
    sb.writeln('手机号：${myPhone.isNotEmpty ? myPhone : "未设置"}');
    sb.writeln('年龄：${_userAge > 0 ? "$_userAge岁" : "未知"}');
    sb.writeln('血型：$_bloodType');
    if (_disease.isNotEmpty) sb.writeln('病史：$_disease');
    if (_medicine.isNotEmpty) sb.writeln('药物：$_medicine');
    if (_allergy.isNotEmpty) sb.writeln('过敏：$_allergy');
    if (_emergencyNote.isNotEmpty) sb.writeln('备注：$_emergencyNote');
    sb.writeln('');
    sb.writeln('─── 求助者位置信息 ───');
    // 【修复 v1.76.0】删除零宽空格 \u200B（它会污染 iOS Data Detector，导致后续链接无法识别）
    // 改用普通空格破坏地址连续性，防止 iOS 短信将地址识别为可点击链接
    final addrBroken = addrPart.contains('区')
        ? addrPart.replaceFirst('区', '区 ')
        : addrPart.contains('县')
            ? addrPart.replaceFirst('县', '县 ')
            : addrPart.contains('市')
                ? addrPart.replaceFirst('市', '市 ')
                : addrPart;
    sb.writeln('地址：$addrBroken');
    
    // 【修复 v1.77.0】位置信息降级处理：优先显示地图链接，失败则显示文本坐标
    if (coordPart.isNotEmpty) {
      sb.writeln('');
      // 【修复 v1.17.4-Bug4+5】始终同时显示苹果地图和高德地图（优先使用短链，降级使用长链接）
      if (appleMapShortUrl != null && appleMapShortUrl.isNotEmpty) {
        // 苹果地图短链
        sb.writeln('🍎 点击跳转苹果地图导航');
        sb.writeln('');
        sb.writeln(appleMapShortUrl);
      } else {
        // 【修复 v1.76.0】苹果地图链接使用 ll= 参数传坐标（q= 传坐标会解析异常）
        // ll=lat,lng 指定地图中心坐标，q=%1 防止 Apple Maps 搜索空关键词
        sb.writeln('🍎 点击跳转苹果地图导航');
        sb.writeln('');
        final appleMapUrl = 'https://maps.apple.com/?ll=$coordPart&q=%1';
        sb.writeln(appleMapUrl);
      }
      sb.writeln('');
      if (amapShortUrl != null && amapShortUrl.isNotEmpty) {
        // 高德地图短链
        sb.writeln('📍 点击跳转高德地图导航');
        sb.writeln('');
        sb.writeln(amapShortUrl);
      } else {
        // 降级：高德地图长链接
        sb.writeln('📍 点击跳转高德地图导航');
        sb.writeln('');
        sb.writeln('https://uri.amap.com/marker?position=$lngStr,$latStr');
      }
      // 【修复 v1.77.0】同时显示文本坐标（防止链接失效时仍能获取位置）
      sb.writeln('');
      sb.writeln('坐标（$coordPart）');
    } else {
      // 【修复 v1.77.0】位置获取失败时的降级处理
      sb.writeln('');
      sb.writeln('⚠️ 位置获取失败，请立即回拨确认位置！');
      sb.writeln('如果方便，请描述您当前的位置（如：XX路口、XX小区、XX商场附近）');
    }
    
    sb.writeln('');
    sb.writeln('请立即联系我或拨打120！');
    sb.writeln('在呢 - 独居守护App');
    return sb.toString().trim();
  }

  /// 求助已触发结果弹窗
  /// 布局结构（从上到下）：
  /// 1. ⚠️ 标题栏：紧急求助已触发
  /// 2. 📨 发送求救短信模块（橙色醒目按钮）
  /// 3. 📋 求救信息预览（ExpansionTile 可展开/收起）
  /// 4. 📊 正在采取以下行动（状态追踪）
  /// 5. 🚑 拨打120急救大按钮
  /// 6. 底部「我没事了」取消
  void _showHelpResultDialog(List<Map<String, dynamic>> contacts, String smsContent) {
    // 取第一位联系人的信息用于"拨打联系人电话"
    final firstContact = contacts.isNotEmpty ? contacts.first : null;
    final firstContactName = firstContact?['name']?.toString() ?? '紧急联系人';
    final firstContactPhone = firstContact?['phone']?.toString() ?? '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => HelpResultDialog(
        contacts: contacts,
        contactCount: contacts.length,
        firstContactName: firstContactName,
        firstContactPhone: firstContactPhone,
        smsContent: smsContent,
        autoCallLimit: MembershipService.getAutoCallLimit(),
        onSendSMS: () async { /* 已迁移到 HelpResultDialog 内部处理 */ },
        onCallContact: () async {
          if (firstContactPhone.isNotEmpty) {
            final uri = Uri(scheme: 'tel', path: firstContactPhone);
            if (await canLaunchUrl(uri)) { await launchUrl(uri); }
            setState(() => _calledContact = true);
          }
        },
        onCall120: () async {
          await _call120Directly();
        },
        onCancel: () {
          Navigator.pop(ctx);
          setState(() => _isTriggering = false);
        },
        onStatusChanged: (String status) {
          if (kDebugMode) debugPrint('[HelpPage] Status changed: $status');
        },
        data: HelpDataSnapshot(
          userName: _userName,
          myPhone: _myPhone,
          userAge: _userAge,
          bloodType: _bloodType,
          disease: _disease,
          medicine: _medicine,
          allergy: _allergy,
          address: _address,
          coordLat: _coordLat,
          coordLng: _coordLng,
          calledContact: _calledContact,
          smsSent: _smsSent,
          locationObtained: _locationObtained,
        ),
        isPremium: MembershipService.isSmartMember(),
      ),
    );
  }
}
