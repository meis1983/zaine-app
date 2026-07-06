import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import '../theme/theme_helper.dart';
import '../utils/contact_parser.dart';
import '../services/membership_service.dart';
import '../services/api/contact_service.dart';
import '../services/api/card_service.dart';
import '../services/api_service.dart';
import '../pages/subscription_page.dart';
import '../data/app_constants.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/contact_card_widget.dart';

/// 预设关系选项
/// 【v1.93.2 修复】增加"自定义..."选项，允许用户自由输入任意关系
/// 【v1.93.5 修复】增加"守护人"，兼容通过守护卡绑定的联系人默认关系
const List<String> kRelationOptions = [
  '家人',
  '朋友',
  '同事',
  '父母',
  '配偶',
  '子女',
  '守护人',
  '其他',
  '自定义...',
];

class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key});

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  List<Map<String, dynamic>> _contacts = [];
  bool _isLoading = true;
  String _userName = ''; // 加载状态标记

  
  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 每次进入页面都重新加载（处理从 guardian_page 返回的场景）
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    // 先标记为加载中
    if (mounted) {
      setState(() => _isLoading = true);
    }

    final prefs = await SharedPreferences.getInstance();

    // 【修复 v1.9.8】使用用户隔离key，防止跨账号泄露
    final userId = prefs.getString('user_id');
    final contactsKey = (userId != null && userId.isNotEmpty)
        ? 'emergency_contacts_$userId'
        : 'emergency_contacts';

    // 加载用户信息（用于短信昵称）— 同样使用用户隔离key
    final profileKey = (userId != null && userId.isNotEmpty)
        ? 'user_profile_$userId'
        : 'user_profile';
    final profileJson = prefs.getString(profileKey);

    if (profileJson != null) {
      try {
        final profile = jsonDecode(profileJson) as Map<String, dynamic>;
        _userName = profile['name']?.toString() ?? '';
      } catch (_) {}
    }

    // 数据迁移：如果新key不存在但旧全局key存在，则迁移数据
    if (userId != null && userId.isNotEmpty) {
      final oldData = prefs.getString('emergency_contacts');
      final newData = prefs.getString(contactsKey);
      if (oldData != null && newData == null) {
        // 迁移旧数据到新key
        await prefs.setString(contactsKey, oldData);
        if (kDebugMode) debugPrint('[ContactsPage] 数据迁移: 从全局key迁移到 $contactsKey');
      }
    }

    // ====== Step 1: 先读本地缓存（即时展示） ======
    final contactsJson = prefs.getString(contactsKey);

    if (kDebugMode) debugPrint('[ContactsPage] _loadContacts() 被调用');
    if (kDebugMode) debugPrint('[ContactsPage] raw emergency_contacts = ${contactsJson ?? "NULL!! 确实不存在"}');

    if (contactsJson != null && contactsJson.isNotEmpty) {
      List<Map<String, dynamic>> contacts = [];
      bool hasMigration = false; // 【v1.93.1】在循环内直接标记是否需要迁移
      try {
        final decoded = jsonDecode(contactsJson);
        if (kDebugMode) debugPrint('[ContactsPage] jsonDecode 类型: ${decoded.runtimeType}, 内容: $decoded');

        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              // 【v1.93.1 修复】迁移旧关系"兄弟姐妹" → "家人"
              if (item['relation'] == '兄弟姐妹') {
                item['relation'] = '家人';
                hasMigration = true;
              }
              contacts.add(item);
            } else if (item is Map) {
              final mutable = Map<String, dynamic>.from(item);
              if (mutable['relation'] == '兄弟姐妹') {
                mutable['relation'] = '家人';
                hasMigration = true;
              }
              contacts.add(mutable);
            }
          }
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[ContactsPage] jsonDecode 失败: $e, 尝试兼容模式');
        contacts = ContactParser.parse(contactsJson);
      }

      if (kDebugMode) debugPrint('[ContactsPage] 本地缓存: ${contacts.length} 个联系人');

      // 【v1.93.1 修复】如果发生了关系迁移，立即持久化到本地
      if (hasMigration) {
        try {
          final userId = prefs.getString('user_id');
          final saveKey = (userId != null && userId.isNotEmpty)
              ? 'emergency_contacts_$userId'
              : 'emergency_contacts';
          await prefs.setString(saveKey, jsonEncode(contacts));
          if (kDebugMode) debugPrint('[ContactsPage] ✅ 已迁移"兄弟姐妹"→"家人"并持久化保存');
        } catch (e) {
          if (kDebugMode) debugPrint('[ContactsPage] ⚠️ 迁移后保存失败: $e');
        }
      }

      // 即时展示本地数据
      if (mounted) {
        setState(() {
          _contacts = contacts;
          _isLoading = false;
        });
      }
    } else {
      if (kDebugMode) debugPrint('[ContactsPage] emergency_contacts 为空或不存在 → 显示空状态');
      if (mounted) {
        setState(() {
          _contacts = [];
          _isLoading = false;
        });
      }
    }

    // ====== Step 2: 异步从后端拉取并合并（非阻塞） ======
    _syncFromServer();
  }

  /// 从后端拉取联系人列表，合并到本地
  /// 策略：后端有数据 → 覆盖本地；后端为空 + 本地有数据 → 自动迁移
  Future<void> _syncFromServer() async {
    try {
      final res = await ContactService.getContacts();

      if (res['success'] != true) {
        if (kDebugMode) debugPrint('[ContactsPage] 后端拉取失败: ${res['error'] ?? res}');
        return;
      }

      final serverContacts = res['contacts'] as List<dynamic>? ?? [];
      final List<Map<String, dynamic>> parsed = [];
      bool hasMigration = false;

      for (final item in serverContacts) {
        if (item is Map<String, dynamic>) {
          // 【v1.93.2 修复】迁移旧关系"兄弟姐妹" → "家人"
          if (item['relation'] == '兄弟姐妹') {
            item['relation'] = '家人';
            hasMigration = true;
          }
          parsed.add(item);
        } else if (item is Map) {
          final mutable = Map<String, dynamic>.from(item);
          if (mutable['relation'] == '兄弟姐妹') {
            mutable['relation'] = '家人';
            hasMigration = true;
          }
          parsed.add(mutable);
        }
      }

      // 【v1.93.2 修复】如果发生了关系迁移，立即回写服务端防止下次同步覆盖
      if (hasMigration) {
        _syncMigrationToServer(parsed);
      }

      if (kDebugMode) debugPrint('[ContactsPage] 后端返回 ${parsed.length} 个联系人，本地 ${_contacts.length} 个');

      if (parsed.isEmpty && _contacts.isNotEmpty) {
        // 场景：老用户首次 —— 本地有数据但后端为空，自动迁移
        if (kDebugMode) debugPrint('[ContactsPage] 检测到老用户数据，开始自动迁移到后端...');
        await _migrateLocalToServer();
        return;
      }

      if (parsed.isNotEmpty) {
        // 场景：正常使用 —— 后端数据覆盖本地（保证一致性）
        await _mergeFromServer(parsed);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[ContactsPage] _syncFromServer 异常: $e');
    }
  }

  /// 【v1.93.2 修复】迁移关系后立即回写服务端，防止下次同步又覆盖回来
  /// 异步执行，不阻塞 UI
  void _syncMigrationToServer(List<Map<String, dynamic>> migratedContacts) {
    Future.microtask(() async {
      try {
        for (final contact in migratedContacts) {
          final id = contact['id'];
          if (id != null) {
            await ContactService.updateContact(id.toString(), {
              'relation': contact['relation'],
            });
          }
        }
        if (kDebugMode) debugPrint('[ContactsPage] ✅ 已回写服务端：${migratedContacts.length} 个联系人的关系已迁移');
      } catch (e) {
        if (kDebugMode) debugPrint('[ContactsPage] ⚠️ 回写服务端迁移失败（下次刷新重试）: $e');
      }
    });
  }

  /// 用后端数据覆盖本地缓存
  Future<void> _mergeFromServer(List<Map<String, dynamic>> serverContacts) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    final contactsKey = (userId != null && userId.isNotEmpty)
        ? 'emergency_contacts_$userId'
        : 'emergency_contacts';

    if (mounted) {
      setState(() {
        _contacts = serverContacts;
      });
    }

    // 同步写到本地缓存
    await prefs.setString(contactsKey, jsonEncode(serverContacts));
    if (kDebugMode) debugPrint('[ContactsPage] 已用后端数据覆盖本地缓存 (${serverContacts.length} 条)');
  }

  /// 老用户首次迁移：把本地联系人批量上传到后端
  Future<void> _migrateLocalToServer() async {
    try {
      // 上传本地数据（去掉旧格式的多余字段，只保留后端需要的）
      final cleanContacts = _contacts.map((c) => <String, dynamic>{
        'name': (c['name'] ?? '').toString(),
        'phone': (c['phone'] ?? '').toString(),
        'relation': (c['relation'] ?? '').toString(),
      }).where((c) => c['name']!.isNotEmpty && c['phone']!.isNotEmpty).toList();

      if (cleanContacts.isEmpty) return;

      final res = await ContactService.saveContacts(cleanContacts);

      if (res['success'] == true) {
        final serverContacts = res['contacts'] as List<dynamic>? ?? [];
        final List<Map<String, dynamic>> parsed = [];
        for (final item in serverContacts) {
          if (item is Map<String, dynamic>) {
            parsed.add(item);
          } else if (item is Map) {
            parsed.add(Map<String, dynamic>.from(item));
          }
        }

        if (parsed.isNotEmpty) {
          await _mergeFromServer(parsed);
          if (kDebugMode) debugPrint('[ContactsPage] ✅ 老用户数据迁移完成：${parsed.length} 条联系人已同步到后端');
        }
      } else {
        if (kDebugMode) debugPrint('[ContactsPage] 老用户迁移上传失败: ${res['error'] ?? res}');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[ContactsPage] _migrateLocalToServer 异常: $e');
    }
  }

  Future<void> _saveContacts() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 【修复 v1.9.8】使用用户隔离key，防止跨账号泄露
    final userId = prefs.getString('user_id');
    final contactsKey = (userId != null && userId.isNotEmpty) 
        ? 'emergency_contacts_$userId' 
        : 'emergency_contacts';
    
    final jsonStr = jsonEncode(_contacts);
    if (kDebugMode) debugPrint('[ContactsPage] _saveContacts() 保存数据: $jsonStr');
    await prefs.setString(contactsKey, jsonStr);

    // 立即回读验证
    final verify = prefs.getString(contactsKey);
    if (kDebugMode) debugPrint('[ContactsPage] 回读验证: ${verify ?? "NULL!! 保存失败!"}');
  }

  Future<void> _addContact() async {
    // 【v1.17.3】添加前校验数量上限，超限弹出明确的升级引导对话框
    final maxContacts = MembershipService.getMaxContacts();
    if (_contacts.length >= maxContacts) {
      if (mounted) {
        final isSmart = MembershipService.isSmartMember();
        if (isSmart) {
          // 智能版已达上限，简单提示
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('智能版最多添加 $maxContacts 位联系人'),
              backgroundColor: Colors.amber.shade50,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          // 体验版已达上限，弹出明确的升级引导对话框
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZaiNeRadius.card)),
              title: Row(
                children: [
                  Icon(Icons.workspace_premium_rounded, color: Colors.amber.shade700, size: 28),
                  const SizedBox(width: ZaiNeSpacing.md),
                  const Expanded(
                    child: Text('联系人已达上限', style: TextStyle(fontSize: ZaiNeFontSize.title, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '体验版最多可添加 $maxContacts 位紧急联系人。',
                    style: TextStyle(fontSize: ZaiNeFontSize.body, color: ZaiNeColors.textPrimary()),
                  ),
                  const SizedBox(height: ZaiNeSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(ZaiNeSpacing.md),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8F0),
                      borderRadius: BorderRadius.circular(ZaiNeRadius.small),
                      border: Border.all(color: const Color(0xFFFFE0B2)),
                    
                      boxShadow: ZaiNeShadows.card,),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '升级到智能版，你将获得：',
                          style: TextStyle(fontSize: ZaiNeFontSize.bodySm, fontWeight: FontWeight.w600, color: Color(0xFFE65100)),
                        ),
                        const SizedBox(height: ZaiNeSpacing.sm),
                        _buildUpgradeBenefit(Icons.people_alt_outlined, '紧急联系人 5位 → ${MembershipService.smartMaxContacts}位'),
                        _buildUpgradeBenefit(Icons.call_outlined, '紧急快捷拨打 1位 → ${MembershipService.smartAutoCallLimit}位'),
                        _buildUpgradeBenefit(Icons.sms_outlined, '紧急快捷短信 1位 → ${MembershipService.smartAutoCallLimit}位'),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('稍后再说', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _goToSubscription();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B35),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.xl, vertical: ZaiNeSpacing.md),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZaiNeRadius.small)),
                  ),
                  child: const Text('立即升级', style: TextStyle(fontSize: ZaiNeFontSize.body, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          );
        }
      }
      return;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const AddContactDialog(),
    );

    if (result != null) {
      if (kDebugMode) debugPrint('[ContactsPage] 收到添加联系人结果: $result');

      final contactName = (result['name'] ?? '').toString();
      final contactPhone = (result['phone'] ?? '').toString();

      // 乐观更新：先写本地
      setState(() {
        _contacts.add(result);
      });
      await _saveContacts();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: ZaiNeSpacing.md),
                Text('$contactName 已添加为守护者'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
          ),
        );
      }

      // 【v1.86.0】升级提示改为更简洁的方式（不弹横幅，避免干扰）
      // 原逻辑：添加第2位联系人后弹 _showUpgradeHint() 横幅
      // 改为：静默记录，在用户点击"发送邀请"时再提示（如果超出免费额度）

      // 添加成功后，询问是否发送短信邀请（仅新添加时，非编辑时）
      if (contactPhone.isNotEmpty && mounted) {
        await Future.delayed(const Duration(milliseconds: 600));
        if (!mounted) return;
        _showInviteDialog(contactName, contactPhone);
      }

      // 异步同步到后端（非阻塞）
      _syncAddToBackend(result);

      // 【修复 v1.84.0】同步完成后立即刷新列表（防止需要手动返回再进入）
      // 延迟1秒等待后端写入，然后刷新
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          if (kDebugMode) debugPrint('[ContactsPage] 添加联系人后自动刷新列表');
          _loadContacts();
        }
      });
    }
  }

  /// 跳转订阅页面（抽取为独立方法，避免 SnackBarAction 编译错误）
  void _goToSubscription() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const SubscriptionPage()),
    );
  }

  /// 【v1.17.3】升级引导对话框中的权益条目
  Widget _buildUpgradeBenefit(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFFFF6B35)),
          const SizedBox(width: ZaiNeSpacing.sm),
          Text(text, style: TextStyle(fontSize: ZaiNeFontSize.caption, color: ZaiNeColors.textPrimary())),
        ],
      ),
    );
  }

  /// 异步添加联系人到后端（非阻塞，失败不影响本地）
  Future<void> _syncAddToBackend(Map<String, dynamic> contact) async {
    try {
      final res = await ContactService.addContact({
        'name': (contact['name'] ?? '').toString(),
        'phone': (contact['phone'] ?? '').toString(),
        'relation': (contact['relation'] ?? '').toString(),
      });

      if (res['success'] == true) {
        // 用后端返回的数据（含真实 id）替换本地临时记录
        final serverContacts = res['contacts'] as List<dynamic>? ?? [];
        if (serverContacts.isNotEmpty) {
          final serverContact = serverContacts.first;
          final Map<String, dynamic> parsed;
          if (serverContact is Map<String, dynamic>) {
            parsed = serverContact;
          } else if (serverContact is Map) {
            parsed = Map<String, dynamic>.from(serverContact);
          } else {
            return;
          }

          // 找到本地对应的联系人（匹配 name+phone）并替换为后端版本
          if (mounted) {
            setState(() {
              for (int i = 0; i < _contacts.length; i++) {
                if (_contacts[i]['name'] == parsed['name'] &&
                    _contacts[i]['phone'] == parsed['phone'] &&
                    _contacts[i]['id'] == null) {
                  _contacts[i] = parsed;
                  if (kDebugMode) debugPrint('[ContactsPage] 已用后端数据替换本地临时记录 (id=${parsed['id']})');
                  break;
                }
              }
            });
            await _saveContacts();
          }
        }
      } else {
        if (kDebugMode) debugPrint('[ContactsPage] 后端添加失败: ${res['error'] ?? res}');
        // 【修复 v1.17.3-Bug1】后端拒绝时弹提示（如超限）
        final errorCode = res['error']?.toString() ?? '';
        final errorDetail = res['detail'];
        final bool isLimitExceeded = errorCode.contains('contact_limit_exceeded') ||
            (errorDetail is Map && (errorDetail['error']?.toString().contains('contact_limit_exceeded') ?? false));
        if (isLimitExceeded && mounted) {
          final upgradeHint = errorDetail is Map
              ? (errorDetail['upgrade_hint']?.toString() ?? '升级智能版可添加更多联系人')
              : '升级智能版可添加更多联系人';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.workspace_premium_rounded, color: Colors.amber.shade700, size: 20),
                  const SizedBox(width: ZaiNeSpacing.md),
                  Expanded(child: Text(upgradeHint, style: const TextStyle(fontSize: ZaiNeFontSize.caption))),
                ],
              ),
              backgroundColor: Colors.amber.shade50,
              behavior: SnackBarBehavior.floating,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
              duration: const Duration(seconds: 5),
              showCloseIcon: true,
              closeIconColor: Colors.grey,
              action: SnackBarAction(
                label: '去升级',
                textColor: Colors.orange.shade800,
                onPressed: _goToSubscription,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[ContactsPage] _syncAddToBackend 异常: $e');
    }
  }

  /// 添加联系人后弹出邀请短信确认（带昵称编辑）
  void _showInviteDialog(String name, String phone) {
    // 使用 TextEditingController 管理输入状态，避免 setState 时重建导致删除异常
    final senderController = TextEditingController(text: _userName.isNotEmpty ? _userName : '我');
    final recipientController = TextEditingController(text: name);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            // 读取当前输入值
            final senderName = senderController.text.trim();
            final recipientName = recipientController.text.trim();

            // 【修复 v1.16.0】使用 landing 页链接，不再使用 App Store 直链
            final smsBody = '【在呢】嗨 ${recipientName.isNotEmpty ? recipientName : name}！我是$senderName，刚把你设为我的紧急联系人 🛡️\n\n我在用「在呢」App 守护自己的安全——每天签到报平安，遇到紧急情况一键求助 会自动通知你我的实时位置。\n\n如果你也下载「在呢」，我们可以互相守护，让彼此都更安心。❤️\n\n点击链接接受邀请：${AppConstants.contactsInviteUrl(phone)}';

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZaiNeRadius.card)),
              title: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(ZaiNeRadius.input),
                    
                      boxShadow: ZaiNeShadows.card,),
                    child: Icon(Icons.sms_rounded, color: Colors.green.shade600, size: 20),
                  ),
                  const SizedBox(width: ZaiNeSpacing.md),
                  const Text('发送邀请短信', style: TextStyle(fontSize: ZaiNeFontSize.subtitle)),
                ],
              ),
              // 【修复 v1.9.6】键盘弹出时允许滚动，避免溢出警告
              content: SingleChildScrollView(
                child: SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('已为 $name 设置为紧急联系人。', style: TextStyle(fontSize: ZaiNeFontSize.bodySm, color: ZaiNeColors.textPrimary())),
                      const SizedBox(height: ZaiNeSpacing.sm),
                      Text('编辑短信内容（双方昵称可选）', style: TextStyle(fontSize: ZaiNeFontSize.micro, color: ZaiNeColors.textSecondary())),
                      const SizedBox(height: ZaiNeSpacing.md),

                      // 发送者昵称（使用 controller 避免重建丢失状态）
                      TextField(
                        controller: senderController,
                        onChanged: (_) => setDlgState(() {}),  // 只触发预览刷新，不重建 controller
                        decoration: InputDecoration(
                          labelText: '你的昵称',
                          hintText: '发短信时显示你是谁',
                          prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF4CAF50)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(ZaiNeRadius.small)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.md, vertical: ZaiNeSpacing.md),
                        ),
                        style: const TextStyle(fontSize: ZaiNeFontSize.bodySm),
                      ),
                      const SizedBox(height: ZaiNeSpacing.md),

                      // 接收者称呼
                      TextField(
                        controller: recipientController,
                        onChanged: (_) => setDlgState(() {}),  // 只触发预览刷新，不重建 controller
                        decoration: InputDecoration(
                          labelText: '对方称呼',
                          hintText: '你想怎么称呼对方',
                          prefixIcon: const Icon(Icons.favorite_outline, color: ZaiNeColors.brandOrange),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(ZaiNeRadius.small)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.md, vertical: ZaiNeSpacing.md),
                        ),
                        style: const TextStyle(fontSize: ZaiNeFontSize.bodySm),
                      ),
                      const SizedBox(height: ZaiNeSpacing.md),

                      // 短信预览
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(ZaiNeSpacing.md),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(ZaiNeRadius.small),
                          border: Border.all(color: ZaiNeColors.borderColor()),
                        
                          boxShadow: ZaiNeShadows.card,),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('短信预览：', style: TextStyle(fontSize: ZaiNeFontSize.micro, color: ZaiNeColors.textSecondary(), fontWeight: FontWeight.w500)),
                            const SizedBox(height: ZaiNeSpacing.sm),
                            Text(
                              smsBody,
                              style: TextStyle(fontSize: ZaiNeFontSize.micro, color: ZaiNeColors.textSecondary(), height: 1.4),
                              maxLines: 8,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    senderController.dispose();
                    recipientController.dispose();
                    Navigator.pop(ctx);
                  },
                  child: const Text('取消'),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    // 发送时取最终值
                    final finalSender = senderController.text.trim();
                    final finalRecipient = recipientController.text.trim();
                    final recipientDisplayName = finalRecipient.isNotEmpty ? finalRecipient : name;

                    // 【修复 v1.9.77】先创建免费守护卡，让对方注册后能互为守护人
                    try {
                      await CardService.createFreeCard(
                        receiverPhone: phone,
                        receiverName: recipientDisplayName,
                      );
                    } catch (e) {
                      if (kDebugMode) debugPrint('[ContactsPage] 创建免费守护卡失败: $e');
                    }

                    // 【修复 v1.17.3-Bug4】生成通用短链替代长链接
                    String inviteShortUrl;
                    try {
                      final targetUrl = AppConstants.contactsInviteUrl(phone);
                      final linkRes = await ApiService.createShortLink(
                        targetUrl: targetUrl,
                        linkType: 'invite',
                        meta: '{"sender":"$finalSender","recipient":"$recipientDisplayName"}',
                      );
                      if (linkRes['success'] == true) {
                        inviteShortUrl = linkRes['short_url']?.toString() ?? targetUrl;
                        if (kDebugMode) debugPrint('[ContactsPage] 邀请短链生成成功: $inviteShortUrl');
                      } else {
                        inviteShortUrl = targetUrl;
                        if (kDebugMode) debugPrint('[ContactsPage] 邀请短链生成失败，降级使用长链接');
                      }
                    } catch (e) {
                      inviteShortUrl = AppConstants.contactsInviteUrl(phone);
                      if (kDebugMode) debugPrint('[ContactsPage] 邀请短链异常，降级使用长链接: $e');
                    }

                    // 【修复 v1.75.0】链接单独一行，避免 iOS 短信换行导致 URL 不可点击
                    // 根因：URL 跨行后 iOS Data Detector 无法识别为可点击链接
                    final finalBody = '【在呢】嗨 $recipientDisplayName！我是$finalSender，刚把你设为我的紧急联系人 🛡️\n\n我在用「在呢」App 守护自己的安全——每天签到报平安，遇到紧急情况一键求助 会自动通知你我的实时位置。\n\n如果你也下载「在呢」，我们可以互相守护，让彼此都更安心。❤️\n\n点击链接接受邀请：\n$inviteShortUrl';
                    _sendInviteSms(phone, recipientDisplayName, finalBody);
                    senderController.dispose();
                    recipientController.dispose();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZaiNeRadius.small)),
                  ),
                  icon: const Icon(Icons.send, size: 16),
                  label: const Text('发送短信'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 通过系统短信界面发送邀请（v1.16.0 修复）
  /// 【重要】使用 Uri 构造器 + queryParameters 自动标准编码
  /// 旧方案 Uri.parse + encodeComponent 对 ? 等字符编码后，iOS Data Detector 可能无法识别 URL
  Future<void> _sendInviteSms(String phone, String recipientName, String smsBody) async {
    // 【v1.16.0】使用 Uri 构造器替代手动拼接
    final uri = Uri(
      scheme: 'sms',
      path: phone,
      queryParameters: {'body': smsBody},
    );

    if (kDebugMode) debugPrint('[ContactsPage] 短信 URI: $uri');

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        if (mounted) {
          HapticFeedback.lightImpact();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('已在短信App中准备好给 ${recipientName.isNotEmpty ? recipientName : '对方'} 的邀请'),
            backgroundColor: Colors.teal,
            behavior: SnackBarBehavior.floating,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
          ));
        }
      } else {
        // canLaunchUrl 返回 false，尝试直接 launch（兼容部分机型）
        if (kDebugMode) debugPrint('[ContactsPage] canLaunchUrl 返回 false，尝试直接 launch');
        final altUri = Uri(
          scheme: 'sms',
          path: phone,
          queryParameters: {'body': smsBody},
        );
        if (await canLaunchUrl(altUri)) {
          await launchUrl(altUri);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('无法打开短信应用，请检查系统设置'),
                backgroundColor: Colors.orange,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[ContactsPage] 短信发送失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('短信发送失败: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _editContact(int index) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AddContactDialog(existingContact: _contacts[index]),
    );

    if (result != null) {
      final contactId = _contacts[index]['id'];
      final oldRelation = _contacts[index]['relation'];
      final newRelation = result['relation'];

      if (kDebugMode) {
        debugPrint('[ContactsPage] 编辑联系人 index=$index, id=$contactId, '
            '旧关系=$oldRelation, 新关系=$newRelation');
      }

      // 乐观更新：先写本地
      setState(() {
        // 保留后端 id，更新其他字段
        result['id'] = contactId;
        _contacts[index] = result;
      });
      await _saveContacts();

      // 异步同步到后端
      // 【修复 v1.93.9】增强临时 ID 检测逻辑
      final isTempId = contactId == null || 
          (contactId is String && (contactId.contains('临时') || contactId.contains('temp')));
      
      if (!isTempId) {
        // 有有效的后端 ID，直接编辑
        if (kDebugMode) debugPrint('[ContactsPage] 联系人有明确 id=$contactId，调用编辑 API');
        _syncEditToBackend(contactId, result);
      } else {
        // 【修复 v1.93.9】临时 ID 或 null → 先同步到后端获取真实 ID，再编辑
        if (kDebugMode) {
          debugPrint('[ContactsPage] ⚠️ 联系人 id=$contactId 是临时 ID，改为调用新增 API');
          debugPrint('[ContactsPage] 临时 ID 详情: contactId=$contactId, isTempId=$isTempId');
        }
        _syncAddToBackend(result).then((_) {
          // 新增成功后，后端会返回真实 ID，下次编辑就能正常工作了
          if (kDebugMode) debugPrint('[ContactsPage] ✅ 临时联系人已同步到后端，下次编辑将使用真实 ID');
        });
      }
    }
  }

  /// 异步编辑联系人到后端
  Future<void> _syncEditToBackend(dynamic contactId, Map<String, dynamic> contact) async {
    try {
      final relation = (contact['relation'] ?? '').toString();
      
      // 【调试 v1.93.9】增强日志 - 打印所有关键信息
      if (kDebugMode) {
        debugPrint('=' * 60);
        debugPrint('[ContactsPage] 🔧 开始编辑联系人');
        debugPrint('  [联系人 ID] $contactId (类型: ${contactId.runtimeType})');
        debugPrint('  [请求参数]');
        debugPrint('    - name: ${contact['name']}');
        debugPrint('    - phone: ${contact['phone']}');
        debugPrint('    - relation: $relation');
        debugPrint('  [完整 contact 数据] $contact');
        debugPrint('=' * 60);
      }

      // 【调试】检查 contactId 是否有效
      if (contactId == null || contactId.toString().isEmpty || contactId == 'null') {
        if (kDebugMode) debugPrint('[ContactsPage] ⚠️ 警告: contactId 无效！这可能是守护卡联系人未同步到后端');
        // 对于未同步的联系人，只更新本地，不同步到后端
        if (mounted) {
          setState(() {
            for (int i = 0; i < _contacts.length; i++) {
              if (_contacts[i]['id'] == contactId || _contacts[i] == contact) {
                _contacts[i]['relation'] = relation;
                break;
              }
            }
          });
          await _saveContacts();
          if (kDebugMode) debugPrint('[ContactsPage] ✅ 已更新本地联系人关系（未同步到后端）');
        }
        return;
      }

      if (kDebugMode) debugPrint('[ContactsPage] 📡 发送请求到后端...');

      // 【调试 v1.93.10】打印完整的请求体
      final requestBody = {
        'name': (contact['name'] ?? '').toString(),
        'phone': (contact['phone'] ?? '').toString(),
        'relation': relation,
      };
      if (kDebugMode) {
        debugPrint('[ContactsPage] 📡 发送 PUT /api/contacts/$contactId');
        debugPrint('  [请求体] $requestBody');
      }

      final res = await ContactService.updateContact(
        contactId.toString(),
        requestBody,
      );

      // 【调试】打印完整响应
      if (kDebugMode) {
        debugPrint('=' * 60);
        debugPrint('[ContactsPage] 📥 后端编辑响应:');
        debugPrint('  [完整响应] $res');
        if (res != null && res is Map) {
          debugPrint('  [success] ${res['success']}');
          debugPrint('  [error] ${res['error']}');
          debugPrint('  [contacts] ${res['contacts']}');
        }
        debugPrint('=' * 60);
      }

      if (res['success'] == true) {
        if (kDebugMode) debugPrint('[ContactsPage] ✅ 后端编辑成功 id=$contactId, relation=$relation');
        // 【修复 v1.93.10】不再强制刷新列表，避免后端未保存 relation 时被覆盖
        // 乐观更新已经生效，后端成功只做日志确认
        if (kDebugMode) debugPrint('[ContactsPage] ℹ️ 跳过 _loadContacts()，保留本地乐观更新');
      } else {
        if (kDebugMode) debugPrint('[ContactsPage] ❌ 后端编辑失败: ${res['error'] ?? res}');
        // 【修复 v1.17.3-Bug2】编辑失败时提示用户
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('保存失败: ${res['error'] ?? '请检查网络后重试'}'),
              backgroundColor: Colors.orange.shade700,
              behavior: SnackBarBehavior.floating,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
              action: SnackBarAction(
                label: '查看日志',
                onPressed: () {
                  if (kDebugMode) debugPrint('[ContactsPage] 查看 Xcode 控制台获取详细错误信息');
                },
              ),
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('[ContactsPage] ❌ _syncEditToBackend 异常: $e');
        debugPrint('[ContactsPage] 堆栈跟踪: $stackTrace');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存异常: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
          ),
        );
      }
    }
  }

  Future<void> _deleteContact(int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZaiNeRadius.card)),
        title: const Text('删除联系人'),
        content: Text('确定要删除 ${_contacts[index]['name']} 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final contactId = _contacts[index]['id'];

      // 乐观更新：先从本地删除
      setState(() {
        _contacts.removeAt(index);
      });
      await _saveContacts();

      // 异步同步到后端
      if (contactId != null) {
        _syncDeleteToBackend(contactId);
      } else {
        if (kDebugMode) debugPrint('[ContactsPage] 删除的联系人无后端 id，仅本地删除');
      }
    }
  }

  /// 异步删除后端联系人
  Future<void> _syncDeleteToBackend(dynamic contactId) async {
    try {
      final res = await ContactService.deleteContact(contactId.toString());

      if (res['success'] == true) {
        if (kDebugMode) debugPrint('[ContactsPage] 后端删除成功 id=$contactId');

        // 用后端返回的剩余列表更新本地（处理 sort_order 重排）
        final serverContacts = res['contacts'] as List<dynamic>? ?? [];
        if (serverContacts.isNotEmpty) {
          final List<Map<String, dynamic>> parsed = [];
          for (final item in serverContacts) {
            if (item is Map<String, dynamic>) {
              parsed.add(item);
            } else if (item is Map) {
              parsed.add(Map<String, dynamic>.from(item));
            }
          }
          if (mounted) {
            setState(() => _contacts = parsed);
          }
          await _saveContacts();
        }
      } else {
        if (kDebugMode) debugPrint('[ContactsPage] 后端删除失败: ${res['error'] ?? res}');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[ContactsPage] _syncDeleteToBackend 异常: $e');
    }
  }

  /// 异步同步排序到后端
  Future<void> _syncReorderToBackend() async {
    try {
      // 收集所有有后端 id 的联系人 id（按当前排序）
      final contactIds = <int>[];
      for (final contact in _contacts) {
        final id = contact['id'];
        if (id != null) {
          contactIds.add(id as int);
        }
      }

      if (contactIds.isEmpty) {
        if (kDebugMode) debugPrint('[ContactsPage] 所有联系人都无后端 id，跳过排序同步');
        return;
      }

      final res = await ContactService.reorderContacts(contactIds);

      if (res['success'] == true) {
        if (kDebugMode) debugPrint('[ContactsPage] 后端排序同步成功');
      } else {
        if (kDebugMode) debugPrint('[ContactsPage] 后端排序同步失败: ${res['error'] ?? res}');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[ContactsPage] _syncReorderToBackend 异常: $e');
    }
  }

  /// 获取优先级标签完整文字（带图标）
  String _priorityLabelWithIcon(int index) {
    switch (index) {
      case 0: return '👑 优先';
      case 1: return '二';
      case 2: return '三';
      case 3: return '四';
      case 4: return '五';
      case 5: return '六';
      case 6: return '七';
      case 7: return '八';
      case 8: return '九';
      case 9: return '十';
      default: return '${index + 1}';
    }
  }

  Color _priorityColor(int index) {
    switch (index) {
      case 0: return Colors.red;
      case 1: return Colors.orange;
      case 2: return Colors.amber.shade700;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZaiNeColors.scaffoldBg(),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: ZaiNeColors.textPrimary()),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '紧急联系人',
          style: TextStyle(color: ZaiNeColors.textPrimary()),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: ZaiNeColors.brandOrange),
            onPressed: _addContact,
          ),
        ],
      ),
      // 【修复 v1.9.8】用 SafeArea 包裹 body，防止底部溢出（开发者模式黄黑条）
      body: SafeArea(
        top: false,  // AppBar 已处理顶部安全区
        bottom: true,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: ZaiNeColors.brandOrange))
          : _contacts.isEmpty
              ? const EmptyStateWidget()
              : _buildContactsList(),
      ),
      floatingActionButton: _contacts.isEmpty && !_isLoading
          ? FloatingActionButton.extended(
              onPressed: _addContact,
              backgroundColor: ZaiNeColors.brandOrange,
              icon: const Icon(Icons.person_add),
              label: const Text('添加联系人'),
            )
          : null,
    );
  }

  Widget _buildContactsList() {
    // 使用 ReorderableListView 支持拖拽排序
    return ReorderableListView(
      padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.lg, vertical: ZaiNeSpacing.sm),
      onReorder: _handleReorder,
      buildDefaultDragHandles: false, // 使用自定义拖拽手柄
      children: [
        // 第一个位置放说明框（不可拖拽）
        Container(
          key: const ValueKey('info_header'),
          padding: const EdgeInsets.all(ZaiNeSpacing.md),
          margin: const EdgeInsets.only(bottom: ZaiNeSpacing.md),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(ZaiNeRadius.small),
          
            boxShadow: ZaiNeShadows.card,),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
              const SizedBox(width: ZaiNeSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '求助时将按优先顺序拨打，拖动左侧☰调整排序',
                      style: TextStyle(fontSize: ZaiNeFontSize.caption, color: Colors.blue.shade700),
                    ),
                    Text(
                      '第一位联系人 = 第一紧急联系人（最优先）',
                      style: TextStyle(fontSize: ZaiNeFontSize.micro, color: Colors.blue.shade500),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // 联系人列表
        for (int i = 0; i < _contacts.length; i++)
          ContactCardWidget(
            key: ValueKey('contact_${_contacts[i]['id'] ?? _contacts[i]['phone']}_$i'),
            itemIndex: i + 1, // +1 因为header在index 0
            contactIndex: i,
            contact: _contacts[i],
            priorityColor: _priorityColor(i),
            priorityLabel: _priorityLabelWithIcon(i),
            isPremium: i < MembershipService.getAutoCallLimit(),
            onEdit: () => _editContact(i),
            onDelete: () => _deleteContact(i),
            dragHandle: ReorderableDragStartListener(
              index: i + 1, // +1 因为header在index 0
              child: Container(
                padding: const EdgeInsets.all(ZaiNeSpacing.sm),
                child: Icon(
                  Icons.drag_handle,
                  color: ZaiNeColors.textSecondary(),
                  size: 20,
                ),
              ),
            ),
          ),
      ],
    );
  }
  
  /// 处理拖拽排序（ReorderableListView.onReorder 回调）
  void _handleReorder(int oldIndex, int newIndex) {
    // 调整 newIndex（Flutter 的 ReorderableListView 规则）
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    
    // 不允许拖拽header（index 0）
    if (oldIndex == 0 || newIndex == 0) return;
    
    // 调整为 _contacts 数组的索引（去掉header）
    final adjustedOldIndex = oldIndex - 1;
    final adjustedNewIndex = newIndex - 1;
    
    setState(() {
      final contact = _contacts.removeAt(adjustedOldIndex);
      _contacts.insert(adjustedNewIndex, contact);
    });
    
    // 保存并同步到后端
    _saveContacts();
    _syncReorderToBackend();
  }

  /// 单个联系人卡片（支持拖动手柄）
}

/// 添加联系人对话框 — 精美设计版 v2
class AddContactDialog extends StatefulWidget {
  final Map<String, dynamic>? existingContact;

  const AddContactDialog({super.key, this.existingContact});

  @override
  State<AddContactDialog> createState() => _AddContactDialogState();
}

class _AddContactDialogState extends State<AddContactDialog> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _customRelationController;
  String _selectedRelation = '家人';
  bool _isCustomRelation = false;
  final _formKey = GlobalKey<FormState>();
  bool _obscurePhone = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existingContact?['name'] ?? '');
    _phoneController = TextEditingController(text: widget.existingContact?['phone'] ?? '');
    _customRelationController = TextEditingController();

    String savedRelation = widget.existingContact?['relation'] ?? '';
    // 【v1.93.1 修复】归一化旧关系"兄弟姐妹" → "家人"，防止老数据在 UI 中显示
    if (savedRelation == '兄弟姐妹') {
      savedRelation = '家人';
    }

    // 检查保存的关系是否为自定义关系（不在预设列表中，且不是'自定义...'）
    final isCustom = savedRelation.isNotEmpty &&
        savedRelation != '自定义...' &&
        !kRelationOptions.take(kRelationOptions.length - 1).contains(savedRelation);
    // kRelationOptions 最后一个元素是 '自定义...'，不计入预设

    if (isCustom) {
      // 自定义关系：激活自定义输入模式
      _isCustomRelation = true;
      _customRelationController.text = savedRelation;
      _selectedRelation = '自定义...';
    } else if (savedRelation.isNotEmpty) {
      _selectedRelation = savedRelation;
    } else {
      _selectedRelation = '家人';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _customRelationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingContact != null;
    // 计算安全高度：确保键盘弹出时不会溢出
    final screenHeight = MediaQuery.of(context).size.height;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    // 最大可用高度 = 屏幕高度 - 键盘高度 - 安全区域上下边距
    final maxContentHeight = screenHeight - keyboardHeight - 80;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZaiNeRadius.card)),
      insetPadding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.xl),
      child: Container(
        constraints: BoxConstraints(maxHeight: maxContentHeight),
        decoration: BoxDecoration(
          color: ZaiNeColors.cardBg(),
          borderRadius: BorderRadius.circular(ZaiNeRadius.lg),
        
          boxShadow: ZaiNeShadows.card,),
        child: SingleChildScrollView(
          // 确保内容可滚动，防止键盘弹出时溢出
          physics: const ClampingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ====== 头部区域（渐变背景） ======
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [ZaiNeColors.brandOrange, Color(0xFFFFB347)],
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: ZaiNeColors.brandOrange.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // 图标 — 更精致的设计
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.5),
                      ),
                      child: Icon(
                        isEdit ? Icons.edit_note : Icons.person_add_alt_1_rounded,
                        size: 30,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: ZaiNeSpacing.lg),
                    Text(
                      isEdit ? '编辑紧急联系人' : '添加紧急联系人',
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: ZaiNeSpacing.sm),
                    Text(
                      isEdit ? '修改后将自动保存优先顺序' : '求助时将按优先顺序拨打',
                      style: TextStyle(fontSize: ZaiNeFontSize.caption, color: Colors.white.withValues(alpha: 0.85)),
                    ),
                  ],
                ),
              ),

              // ====== 表单区域 ======
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 12),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 姓名 — 精美输入框
                      _buildPremiumField(
                        controller: _nameController,
                        label: '姓名',
                        hint: '请输入联系人姓名',
                        prefixIcon: Icons.person_rounded,
                        validator: (v) => (v == null || v.isEmpty) ? '请输入姓名' : null,
                      ),

                      const SizedBox(height: ZaiNeSpacing.lg),

                      // 手机号 — 带显示/隐藏切换（眼睛图标垂直居中）
                      _buildPremiumField(
                        controller: _phoneController,
                        label: '手机号码',
                        hint: '请输入11位手机号',
                        prefixIcon: Icons.phone_android_rounded,
                        keyboardType: TextInputType.phone,
                        obscureText: !_obscurePhone,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePhone ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            size: 19,
                            color: Colors.grey[400],
                          ),
                          onPressed: () => setState(() => _obscurePhone = !_obscurePhone),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          visualDensity: VisualDensity.compact,
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return '请输入手机号码';
                          // 【v1.93.5 修复】放宽手机号验证：清洗后验证，兼容国际号和前缀
                          final cleaned = v.trim().replaceAll(RegExp(r'^(\+86|86|\s|-|\(|\))'), '');
                          if (cleaned.isEmpty) return '请输入手机号码';
                          // 中国手机号严格验证
                          if (RegExp(r'^1[3-9]\d{9}$').hasMatch(cleaned)) return null;
                          // 编辑模式：手机号未修改时，允许非标准格式（如国际号）
                          if (widget.existingContact != null && v == widget.existingContact!['phone']) return null;
                          // 新增模式：允许6-15位数字（国际号兼容）
                          if (RegExp(r'^\d{6,15}$').hasMatch(cleaned)) return null;
                          return '请输入正确的手机号';
                        },
                      ),

                      const SizedBox(height: ZaiNeSpacing.lg),

                      // 关系选择 — 精美芯片式下拉
                      // 【修复 v1.91.0】动态构建下拉选项，包含自定义关系（兼容老数据）
                      Builder(builder: (context) {
                        // 如果当前选择的关系不在预设列表中，临时加入
                        final List<String> effectiveOptions = List.from(kRelationOptions);
                        if (!effectiveOptions.contains(_selectedRelation)) {
                          effectiveOptions.add(_selectedRelation);
                        }
                        return DropdownButtonFormField<String>(
                          initialValue: _selectedRelation,
                          decoration: InputDecoration(
                            labelText: '与您的关系',
                            labelStyle: TextStyle(color: Colors.grey[600], fontSize: ZaiNeFontSize.caption),
                            prefixIcon: Icon(Icons.favorite_border_rounded, color: Colors.orange.shade400, size: 20),
                            filled: true,
                            fillColor: Colors.orange.shade50.withValues(alpha: 0.4),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(ZaiNeRadius.cardSm),
                              borderSide: BorderSide(color: Colors.orange.shade200),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(ZaiNeRadius.cardSm),
                              borderSide: BorderSide(color: Colors.orange.shade200),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(ZaiNeRadius.cardSm),
                              borderSide: const BorderSide(color: ZaiNeColors.brandOrange, width: 1.5),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(ZaiNeRadius.cardSm),
                              borderSide: BorderSide(color: Colors.red.shade300),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.lg, vertical: ZaiNeSpacing.lg),
                          ),
                          icon: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey[600]),
                          style: TextStyle(fontSize: ZaiNeFontSize.bodySm, color: Colors.grey[800]),
                          items: effectiveOptions.map((relation) {
                            return DropdownMenuItem(value: relation, child: Text(relation));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              if (val == '自定义...') {
                                setState(() {
                                  _isCustomRelation = true;
                                  _selectedRelation = '自定义...';
                                });
                              } else {
                                setState(() {
                                  _isCustomRelation = false;
                                  _selectedRelation = val;
                                });
                              }
                            }
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) return '请选择关系';
                            return null;
                          },
                        );
                      }),

                      const SizedBox(height: ZaiNeSpacing.sm),

                      // 【v1.93.2】自定义关系输入框
                      if (_isCustomRelation)
                        Container(
                          margin: const EdgeInsets.only(top: ZaiNeSpacing.sm),
                          padding: const EdgeInsets.all(ZaiNeSpacing.md),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(ZaiNeRadius.cardSm),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('请输入自定义关系', style: TextStyle(fontSize: ZaiNeFontSize.caption, color: Colors.grey[600])),
                              const SizedBox(height: ZaiNeSpacing.sm),
                              TextFormField(
                                controller: _customRelationController,
                                decoration: InputDecoration(
                                  hintText: '例如：师兄、邻居、室友',
                                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: ZaiNeFontSize.bodySm),
                                  prefixIcon: Icon(Icons.edit_note_rounded, color: Colors.orange.shade400, size: 20),
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(ZaiNeRadius.input),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.md, vertical: ZaiNeSpacing.sm),
                                ),
                                style: TextStyle(fontSize: ZaiNeFontSize.body, color: Colors.grey[800]),
                                validator: (value) {
                                  if (_isCustomRelation && (value == null || value.trim().isEmpty)) {
                                    return '请输入自定义关系';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: ZaiNeSpacing.sm),
                    ],
                  ),
                ),
              ),

              // ====== 底部按钮区 ======
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 22),
                child: Row(
                  children: [
                    // 取消按钮
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: ZaiNeSpacing.lg),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZaiNeRadius.card)),
                          side: BorderSide(color: ZaiNeColors.borderColor()),
                        ),
                        child: Text('取消', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500)),
                      ),
                    ),
                    const SizedBox(width: ZaiNeSpacing.md),

                    // 保存按钮
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            final relation = _isCustomRelation
                                ? _customRelationController.text.trim()
                                : _selectedRelation;
                            Navigator.of(context).pop(<String, dynamic>{
                              'name': _nameController.text.trim(),
                              'phone': _phoneController.text.trim(),
                              'relation': relation,
                            });
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ZaiNeColors.brandOrange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: ZaiNeSpacing.lg),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZaiNeRadius.card)),
                          elevation: 0,
                          shadowColor: ZaiNeColors.brandOrange.withValues(alpha: 0.3),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(isEdit ? Icons.check_rounded : Icons.person_add_rounded, size: 18),
                            const SizedBox(width: ZaiNeSpacing.sm),
                            Text(isEdit ? '保存修改' : '添加联系人', style: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.3)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 大厂级精致输入框组件 v2
  Widget _buildPremiumField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData prefixIcon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: ZaiNeFontSize.body, letterSpacing: 0.3),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: Colors.grey[600], fontSize: ZaiNeFontSize.caption),
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: ZaiNeFontSize.bodySm),
        prefixIcon: Icon(prefixIcon, color: ZaiNeColors.brandOrange, size: 21),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: ZaiNeColors.scaffoldBg() == const Color(0xFF121212)
            ? const Color(0xFF1E1E1E)
            : Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ZaiNeRadius.cardSm),
          borderSide: BorderSide(color: ZaiNeColors.borderColor()),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ZaiNeRadius.cardSm),
          borderSide: BorderSide(color: ZaiNeColors.borderColor()),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ZaiNeRadius.cardSm),
          borderSide: const BorderSide(color: ZaiNeColors.brandOrange, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ZaiNeRadius.cardSm),
          borderSide: BorderSide(color: Colors.red.shade300),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.lg, vertical: ZaiNeSpacing.lg),
      ),
      validator: validator,
    );
  }
}
