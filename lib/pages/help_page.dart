import 'package:flutter/material.dart';
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
import '../widgets/help_demo_mode.dart';
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
  bool _smsSent = false;
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
            debugPrint('[Help] ✅ 健康档案已从全局键迁移到用户特定键: $profileKey');
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
          debugPrint('[Help] hasPermission 超时(5s)，默认 false');
          return false;
        });
      } catch (e) {
        debugPrint('[Help] hasPermission 异常: $e');
        _hasLocationReady = false;
      }

      if (!mounted) return;
      setState(() => _prerequisitesChecked = true);

      if (_hasProfileReady && _hasContactsReady && _hasLocationReady) {
        _loadLocation();
      }
    } catch (e) {
      debugPrint('[Help] _checkPrerequisites 异常: $e');
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
    debugPrint('[Help] _requestLocationPermission 开始, 当前 _hasLocationReady=$_hasLocationReady');
    
    // ★ 修复：跳过 hasPermission 缓存检查，直接请求（Geolocator.requestPermission 会返回最新的 iOS 实际状态）
    debugPrint('[Help] ===== 开始请求位置权限（用户主动点击）=====');
    final status = await LocationService.requestPermission();
    debugPrint('[Help] 权限请求结果: $status, isGranted=${status.isGranted}, isLimited=${status.isLimited}');

    if ((status.isGranted || status.isLimited) && mounted) {
      // ✅ 成功 → 绿色提示
      debugPrint('[Help] 权限授权成功！setState _hasLocationReady=true');
      setState(() => _hasLocationReady = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('✅ 位置权限已开启！'),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
    } else if (status.isPermanentlyDenied && mounted) {
      // ★ 永久拒绝 → 弹对话框引导去系统设置
      debugPrint('[Help] 权限被永久拒绝，弹出引导对话框');
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
      debugPrint('[Help] 权限请求失败: $status');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.location_off, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Expanded(child: Text('位置权限未开启。紧急求助需要您的位置才能发送求救信息')),
            ],
          ),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
      debugPrint('[Help] 调用 openAppSettings()...');
      // 使用 permission_handler 的 openAppSettings，它会在用户返回后 resolve
      final opened = await openAppSettings();
      debugPrint('[Help] 用户已从设置返回，opened=$opened');
    } catch (e) {
      debugPrint('[Help] openAppSettings 失败: $e');
    }

    // ⭐ 关键：用户从设置返回后，立刻重新检查权限
    if (!mounted) return;
    debugPrint('[Help] 重新检查位置权限...');
    final hasPerm = await LocationService.hasPermission();
    debugPrint('[Help] 重新检查结果: hasPerm=$hasPerm');

    if (hasPerm && mounted) {
      debugPrint('[Help] 设置返回后权限已开启！setState _hasLocationReady=true');
      setState(() => _hasLocationReady = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 18),
              SizedBox(width: 8),
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
          duration: Duration(seconds: 3),
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
            debugPrint('[Help] ⚠️ build 异常: $e\n$st');
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
                      const SizedBox(height: 16),
                      const Text('紧急求助页面加载异常', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('错误信息: $e', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                      const SizedBox(height: 20),
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
          ? _buildLightweightGuide(missingItems)
          : _buildFullHelpPage();
    }
    return child;
  }

  // ==================== 轻量引导页（核心改造） ====================
  /// 设计原则：
  /// - 不严肃、不吓人 —— 温和的提示语 + 品牌橙色
  /// - 三步清单式，做完一项打 ✓ 自动进下一项
  /// - 位置授权点一下就好

  Widget _buildLightweightGuide(List<String> missingItems) {
    return Scaffold(
      backgroundColor: ZaiNeColors.scaffoldBg(),
      body: SafeArea(
        child: Column(
          children: [
            // 顶部品牌区（无返回按钮，tab 页面）
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  const SizedBox(width: 48), // 左侧占位平衡（替代返回按钮）
                  const Spacer(),
                  Text('求助设置', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: ZaiNeColors.textPrimary())),
                  const Spacer(),
                  const SizedBox(width: 48), // 平衡
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),

                    // 温和标题
                    Center(
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(fontSize: 22, height: 1.4),
                          children: [
                            const TextSpan(text: '让紧急求助 ', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                            TextSpan(text: '随时可用', style: TextStyle(color: Colors.orange.shade600, fontWeight: FontWeight.bold)),
                            const TextSpan(text: ' ✨', style: TextStyle(fontSize: 20)),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // 副标题
                    Center(
                      child: Text(
                        '简单 ${missingItems.length} 步，一次设置永久生效',
                        style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ====== 三步卡片列表 ======
                    _buildStepItem(
                      stepNum: 1,
                      icon: Icons.person_outline,
                      iconBgColor: Colors.blue,
                      label: '完善健康档案',
                      desc: '姓名 · 年龄 · 血型',
                      isDone: _hasProfileReady,
                      onTap: !_hasProfileReady ? () => _goToPage(const ProfilePage(isPushed: true)) : null,
                    ),

                    const SizedBox(height: 14),

                    // 连接线
                    _buildConnector(isActive: _hasProfileReady),

                    _buildStepItem(
                      stepNum: 2,
                      icon: Icons.contact_phone_outlined,
                      iconBgColor: Colors.orange,
                      label: '添加紧急联系人',
                      desc: '至少绑定一位家人或朋友',
                      isDone: _hasContactsReady,
                      onTap: (_hasProfileReady && !_hasContactsReady)
                          ? () => _goToPage(const ContactsPage())
                          : null,
                      locked: !_hasProfileReady, // 上一步没完成则锁定
                    ),

                    const SizedBox(height: 14),

                    _buildConnector(isActive: _hasContactsReady),

                    _buildStepItem(
                      stepNum: 3,
                      icon: Icons.location_on_outlined,
                      iconBgColor: Colors.green,
                      label: '开启位置权限',
                      desc: '点击下方按钮 → 弹出系统框 → 点「允许」',
                      isDone: _hasLocationReady,
                      onTap: (_hasContactsReady && !_hasLocationReady)
                          ? _requestLocationPermission
                          : null,
                      locked: !_hasContactsReady, // 上一步没完成则锁定
                      isActionButton: true, // 标记为需要特殊样式的按钮
                    ),

                    const SizedBox(height: 32),

                    // 底部提示
                    if (missingItems.length == 1)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star, size: 16, color: Colors.orange.shade700),
                              const SizedBox(width: 6),
                              Text(
                                '还差最后一步就大功告成！',
                                style: TextStyle(fontSize: 13, color: Colors.orange.shade800, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // 【修复 v1.9.9】底部留白使用 viewPadding 替代固定值，
                    // 防止在小屏设备或键盘弹出时产生 BOTTOM OVERFLOWED
                    SizedBox(height: MediaQuery.of(context).viewPadding.bottom + 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 单个步骤条目
  Widget _buildStepItem({
    required int stepNum,
    required IconData icon,
    required Color iconBgColor,
    required String label,
    required String desc,
    required bool isDone,
    required VoidCallback? onTap,
    bool locked = false,
    bool isActionButton = false, // 是否为需要用户主动点击的操作按钮
  }) {
    final isActive = !isDone && !locked;
    final bool isLocationAction = !isDone && !locked && isActionButton;

    return Opacity(
      opacity: locked ? 0.5 : 1.0,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDone
                ? Colors.green.shade50                    // ✅ 已完成：浅绿底
                : (isLocationAction
                    ? Colors.green.shade50               // ⚡ 待操作（位置权限）：浅绿底 + 脉冲吸引注意
                    : (isActive ? ZaiNeColors.cardBg() : Colors.grey.shade100)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDone
                  ? Colors.green.shade300                // ✅ 已完成：绿色边框
                  : (isLocationAction
                      ? Colors.green                     // ⚡ 待操作：深绿实心边框（与已完成区分！）
                      : (isActive ? iconBgColor.withValues(alpha: 0.25) : Colors.grey.shade300)),
              width: isDone ? 1.5 : (isLocationAction ? 2.0 : 1),   // 待操作边框更粗
            ),
            boxShadow: isLocationAction
                ? [BoxShadow(color: Colors.green.withValues(alpha: 0.15), blurRadius: 16, offset: const Offset(0, 4))]
                : (isDone
                    ? null                              // ✅ 已完成不需要阴影
                    : (isActive
                        ? [BoxShadow(color: iconBgColor.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4))]
                        : null)),
          ),
          child: Row(
            children: [
              // 左侧：序号 / 图标 / 完成勾 / 动画按钮
              if (isLocationAction)
                // 位置权限特殊样式：脉冲动效按钮
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.green, Color(0xFF38EF7D)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.green.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 3)),
                    ],
                  ),
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) => Transform.scale(
                      scale: 1.0 + (_pulseController.value * 0.08),
                      child: child,
                    ),
                    child: const Icon(Icons.location_searching, color: Colors.white, size: 24),
                  ),
                )
              else if (isDone)
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 24),
                )
              else
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconBgColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconBgColor, size: 22),
                ),

              const SizedBox(width: 14),

              // 中间：文字
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDone ? Colors.green.shade700 : (isLocationAction ? Colors.green.shade700 : Colors.black87),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isDone ? '已完成 ✓' : (locked ? '🔒 请先完成上一步' : desc),
                      style: TextStyle(fontSize: 12, color: isDone ? Colors.green.shade600 : (isLocationAction ? Colors.green.shade600 : Colors.grey[500])),
                    ),
                  ],
                ),
              ),

              // 右侧：箭头 或 锁定图标 或 "去开启"按钮 或 完成对勾
              if (isDone)
                Icon(Icons.check_circle, color: Colors.green.shade400, size: 22)
              else if (locked)
                Icon(Icons.lock_outline, color: Colors.grey[400], size: 20)
              else if (isLocationAction)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.green.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 2))],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('去开启', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                      SizedBox(width: 2),
                      Icon(Icons.arrow_forward_ios, size: 11, color: Colors.white),
                    ],
                  ),
                )
              else
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: iconBgColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.chevron_right, color: iconBgColor, size: 18),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 步骤之间的连接线
  Widget _buildConnector({required bool isActive}) {
    return Padding(
      padding: const EdgeInsets.only(left: 21),
      child: Container(
        width: 2,
        height: 18,
        color: isActive ? Colors.green.shade400 : Colors.grey.shade300,
      ),
    );
  }

  // ==================== 完整求助主界面 ====================

  Widget _buildFullHelpPage() {
    return Scaffold(
      backgroundColor: ZaiNeColors.scaffoldBg(),
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: null, // tab 页面无返回按钮
        title: Text('紧急求助', style: TextStyle(color: ZaiNeColors.textPrimary())),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            children: [
              // 温和警告提示
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text('紧急情况才使用，将联系紧急联系人并发送位置', style: TextStyle(fontSize: 13, color: Colors.orange.shade800))),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // 就绪指示器
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade600, size: 16),
                    const SizedBox(width: 6),
                    Text('档案 · 联系人 · 定位 已就绪', style: TextStyle(fontSize: 12, color: Colors.green.shade700, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),

              // 档案预览
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ZaiNeColors.cardBg(),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Row(
                  children: [
                    Icon(Icons.medical_information, color: Colors.blue.shade600, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text('${(_myPhone != null && _myPhone!.isNotEmpty) ? "$_myPhone · " : ""}$_userName · $_userAge岁 · $_bloodType', style: TextStyle(color: Colors.blue.shade800, fontSize: 13, fontWeight: FontWeight.w600))),
                    Icon(Icons.check_circle, color: Colors.green, size: 16),
                  ],
                ),
              ),

              // 手机号设置提示（未设置时显示，点击可补填）
              if (_myPhone == null || _myPhone!.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: GestureDetector(
                    onTap: _showPhoneInputDialog,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade300),
                      ),
                      child: Row(children: [
                        Icon(Icons.phone_android, color: Colors.orange.shade700, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text('手机号未设置，点击此处补充 →', style: TextStyle(fontSize: 12, color: Colors.orange.shade800, fontWeight: FontWeight.w500))),
                      ]),
                    ),
                  ),
                ),

              const SizedBox(height: 40),

              // 紧急求助按钮
              if (_isTriggering) ...[
                Container(
                  width: 160, height: 160,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.red.shade100, border: Border.all(color: Colors.red, width: 4)),
                  child: Center(child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 1.2, end: 1.0),
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    builder: (context, scale, child) => Transform.scale(
                      scale: scale,
                      child: Text(
                        '$_countdown',
                        key: ValueKey(_countdown),
                        style: TextStyle(
                          fontSize: 70,
                          fontWeight: FontWeight.bold,
                          color: _countdown <= 2 ? Colors.red.shade900 : Colors.red.shade700,
                        ),
                      ),
                    ),
                  )),
                ),
                const SizedBox(height: 14),
                Text('正在发送求助...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red.shade700)),
                const SizedBox(height: 12),
                TextButton(onPressed: _cancelHelp, child: Text('取消', style: TextStyle(fontSize: 15, color: Colors.grey.shade600))),
              ] else ...[
                GestureDetector(
                  onTap: _triggerHelp,
                  // 【P1修复 v1.9.83】移除 onLongPress，避免误触触发紧急求助
                  onTapDown: (_) => HapticFeedback.mediumImpact(),
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) => Transform.scale(scale: 1.0 + (_pulseController.value * 0.08), child: child),
                    child: Container(
                      width: 180, height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.red.shade400, Colors.red.shade600]),
                        boxShadow: [BoxShadow(color: Colors.red.withValues(alpha: 0.4), blurRadius: 30, offset: const Offset(0, 15))],
                      ),
                      child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.emergency, size: 56, color: Colors.white),
                        SizedBox(height: 10),
                        Text('求助', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white)),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text('点击触发紧急求助', style: TextStyle(fontSize: 14, color: ZaiNeColors.textSecondary())),
              ],

              const SizedBox(height: 16),

              // 体验演示按钮
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const HelpDemoMode()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_circle_outline, color: Colors.orange.shade700, size: 18),
                      const SizedBox(width: 6),
                      Text('体验演示', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.orange.shade700)),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right, color: Colors.orange.shade400, size: 16),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 实时定位
              _buildLocationCard(),

              const SizedBox(height: 24),

              // 【修复 v1.9.9】底部留白使用 viewPadding 替代固定值
              SizedBox(height: MediaQuery.of(context).viewPadding.bottom + 16),
            ],
          ),
        ),
      ),
    );
  }

  /// 实时定位卡片（增强版 - 详细信息）
  Widget _buildLocationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ZaiNeColors.cardBg(),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: ZaiNeColors.scaffoldBg() == const Color(0xFF121212) ? 0.15 : 0.06), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: Colors.green.shade200.withValues(alpha: 0.4), width: 1),
      ),
      child: _locationLoading
          ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.green.shade600)),
              const SizedBox(width: 10),
              Text('正在获取位置...', style: TextStyle(fontSize: 13, color: Colors.grey[500])),
            ])
          : (_coordLat != null && _coordLng != null)
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // 标题行
                  Row(children: [
                    Icon(Icons.gps_fixed, color: Colors.green.shade600, size: 18),
                    const SizedBox(width: 6),
                    const Text('当前位置', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
                    const Spacer(),
                    GestureDetector(onTap: _loadLocation, child: Icon(Icons.refresh, size: 16, color: Colors.grey[400])),
                  ]),
                  const SizedBox(height: 10),

                  // 详细地址（核心显示，大字突出）
                  if (_address != null && _address!.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Icon(Icons.location_on, color: Colors.red.shade500, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_address!,
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: ZaiNeColors.textPrimary(), height: 1.4),
                          ),
                        ),
                      ]),
                    ),

                  // 坐标信息（始终显示，无边框避免横杠问题）
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(children: [
                      Icon(Icons.my_location, size: 16, color: Colors.teal.shade700),
                      const SizedBox(width: 8),
                      if (_coordLat != null) Text(_coordLat!, style: TextStyle(fontSize: 13, color: Colors.teal[800], fontFamily: 'monospace', fontWeight: FontWeight.w600)),
                      if (_coordLat != null && _coordLng != null) Text('  ', style: TextStyle(fontFamily: 'monospace')),
                      if (_coordLng != null) Text(_coordLng!, style: TextStyle(fontSize: 13, color: Colors.teal[800], fontFamily: 'monospace', fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ])
              : Row(children: [
                  Icon(Icons.location_off, color: Colors.grey[400], size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('位置获取失败', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                    const SizedBox(height: 2),
                    Text('点击刷新重试', style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                  ])),
                  IconButton(icon: const Icon(Icons.refresh, size: 18), onPressed: _loadLocation, tooltip: '重试'),
                ]),
    );
  }

  // ==================== 求助核心方法 ====================

  /// 弹出手机号设置对话框（用户补填）
  void _showPhoneInputDialog() {
    final controller = TextEditingController(text: _myPhone ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('📱 设置手机号', style: TextStyle(fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('设置后，紧急求助短信中将包含您的手机号', style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 12),
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

    // 【修复 v1.17.3-Bug3】生成 SOS 短链，替代长地图链接
    String? sosShortUrl;
    if (latVal != null && lngVal != null) {
      try {
        final linkRes = await ApiService.createSosLink(
          lat: latVal,
          lng: lngVal,
          address: _address ?? '',
          userName: _userName,
          userPhone: _myPhone ?? '',
        );
        if (linkRes['success'] == true) {
          sosShortUrl = linkRes['short_url']?.toString();
          debugPrint('[Help] SOS 短链生成成功: $sosShortUrl');
        }
      } catch (e) {
        debugPrint('[Help] SOS 短链生成失败，降级使用长链接: $e');
      }
    }

    // 生成完整短信内容（用于预览）
    final helpMessage = _generateHelpMessage(_myPhone ?? '', latStr, lngStr, sosShortUrl);
    debugPrint('[Help] 短信模板:\n$helpMessage');

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

  String _generateHelpMessage(String myPhone, [String? latStr, String? lngStr, String? shortUrl]) {
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
    // 在地址中插入零宽空格，防止 iOS 短信自动识别为可点击地址
    final addrObfuscated = addrPart.split('').join('\u200B');
    sb.writeln('地址：$addrObfuscated');
    if (coordPart.isNotEmpty) {
      sb.writeln('');
      if (shortUrl != null && shortUrl.isNotEmpty) {
        // 【修复 v1.17.3-Bug3】使用短链替代长地图链接
        sb.writeln('🍎 点击跳转苹果地图导航');
        sb.writeln('');
        sb.writeln(shortUrl);
      } else {
        // 降级：使用完整长链接（短链生成失败时的兜底）
        sb.writeln('🍎 点击跳转苹果地图导航');
        sb.writeln('');
        sb.writeln('https://maps.apple.com/?q=$coordPart');
        sb.writeln('');
        sb.writeln('📍 点击跳转高德地图导航');
        sb.writeln('');
        sb.writeln('https://uri.amap.com/marker?position=$lngStr,$latStr');
      }
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
          debugPrint('[HelpPage] Status changed: $status');
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
      ),
    );
  }
}
