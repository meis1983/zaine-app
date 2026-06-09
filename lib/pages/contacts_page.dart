import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import '../theme/theme_helper.dart';
import '../utils/contact_parser.dart';
import '../services/membership_service.dart';
import '../services/api/contact_service.dart';
import '../services/api/card_service.dart';

/// 预设关系选项
const List<String> kRelationOptions = [
  '家人',
  '朋友',
  '同事',
  '父母',
  '配偶',
  '兄弟姐妹',
  '子女',
  '其他',
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
        debugPrint('[ContactsPage] 数据迁移: 从全局key迁移到 $contactsKey');
      }
    }

    // ====== Step 1: 先读本地缓存（即时展示） ======
    final contactsJson = prefs.getString(contactsKey);

    debugPrint('[ContactsPage] _loadContacts() 被调用');
    debugPrint('[ContactsPage] raw emergency_contacts = ${contactsJson ?? "NULL!! 确实不存在"}');

    if (contactsJson != null && contactsJson.isNotEmpty) {
      List<Map<String, dynamic>> contacts = [];
      try {
        final decoded = jsonDecode(contactsJson);
        debugPrint('[ContactsPage] jsonDecode 类型: ${decoded.runtimeType}, 内容: $decoded');

        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              contacts.add(item);
            } else if (item is Map) {
              contacts.add(Map<String, dynamic>.from(item));
            }
          }
        }
      } catch (e) {
        debugPrint('[ContactsPage] jsonDecode 失败: $e, 尝试兼容模式');
        contacts = ContactParser.parse(contactsJson);
      }

      debugPrint('[ContactsPage] 本地缓存: ${contacts.length} 个联系人');

      // 即时展示本地数据
      if (mounted) {
        setState(() {
          _contacts = contacts;
          _isLoading = false;
        });
      }
    } else {
      debugPrint('[ContactsPage] emergency_contacts 为空或不存在 → 显示空状态');
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
        debugPrint('[ContactsPage] 后端拉取失败: ${res['error'] ?? res}');
        return;
      }

      final serverContacts = res['contacts'] as List<dynamic>? ?? [];
      final List<Map<String, dynamic>> parsed = [];

      for (final item in serverContacts) {
        if (item is Map<String, dynamic>) {
          parsed.add(item);
        } else if (item is Map) {
          parsed.add(Map<String, dynamic>.from(item));
        }
      }

      debugPrint('[ContactsPage] 后端返回 ${parsed.length} 个联系人，本地 ${_contacts.length} 个');

      if (parsed.isEmpty && _contacts.isNotEmpty) {
        // 场景：老用户首次 —— 本地有数据但后端为空，自动迁移
        debugPrint('[ContactsPage] 检测到老用户数据，开始自动迁移到后端...');
        await _migrateLocalToServer();
        return;
      }

      if (parsed.isNotEmpty) {
        // 场景：正常使用 —— 后端数据覆盖本地（保证一致性）
        await _mergeFromServer(parsed);
      }
    } catch (e) {
      debugPrint('[ContactsPage] _syncFromServer 异常: $e');
    }
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
    debugPrint('[ContactsPage] 已用后端数据覆盖本地缓存 (${serverContacts.length} 条)');
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
          debugPrint('[ContactsPage] ✅ 老用户数据迁移完成：${parsed.length} 条联系人已同步到后端');
        }
      } else {
        debugPrint('[ContactsPage] 老用户迁移上传失败: ${res['error'] ?? res}');
      }
    } catch (e) {
      debugPrint('[ContactsPage] _migrateLocalToServer 异常: $e');
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
    debugPrint('[ContactsPage] _saveContacts() 保存数据: $jsonStr');
    await prefs.setString(contactsKey, jsonStr);

    // 立即回读验证
    final verify = prefs.getString(contactsKey);
    debugPrint('[ContactsPage] 回读验证: ${verify ?? "NULL!! 保存失败!"}');
  }

  Future<void> _addContact() async {
    // 【修复 v1.17.3-Bug1】添加前校验数量上限，超限直接提示升级
    final maxContacts = MembershipService.getMaxContacts();
    if (_contacts.length >= maxContacts) {
      if (mounted) {
        final isSmart = MembershipService.isSmartMember();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.workspace_premium_rounded, color: Colors.amber.shade700, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isSmart
                        ? '智能版最多添加 $maxContacts 位联系人'
                        : '体验版最多添加 $maxContacts 位联系人，升级智能版可添加 ${MembershipService.smartMaxContacts} 位',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.amber.shade50,
            behavior: SnackBarBehavior.floating,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
            duration: const Duration(seconds: 4),
            showCloseIcon: true,
            closeIconColor: Colors.grey,
            action: isSmart
                ? null
                : SnackBarAction(
                    label: '去升级',
                    textColor: Colors.orange.shade800,
                    onPressed: () => Navigator.pushNamed(context, '/subscription'),
                  ),
          ),
        );
      }
      return;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const AddContactDialog(),
    );

    if (result != null) {
      debugPrint('[ContactsPage] 收到添加联系人结果: $result');

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
                const SizedBox(width: 12),
                Text('$contactName 已添加为守护者'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
          ),
        );
      }

      // 会员温柔提示：添加第2位起提醒升级智能版
      if (_contacts.length >= 2 && !MembershipService.isSmartMember() && mounted) {
        await Future.delayed(const Duration(milliseconds: 800));
        if (!mounted) return;
        _showUpgradeHint();
      }

      // 添加成功后，询问是否发送短信邀请（仅新添加时，非编辑时）
      if (contactPhone.isNotEmpty && mounted) {
        await Future.delayed(const Duration(milliseconds: 600));
        if (!mounted) return;
        _showInviteDialog(contactName, contactPhone);
      }

      // 异步同步到后端（非阻塞）
      _syncAddToBackend(result);
    }
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
                  debugPrint('[ContactsPage] 已用后端数据替换本地临时记录 (id=${parsed['id']})');
                  break;
                }
              }
            });
            await _saveContacts();
          }
        }
      } else {
        debugPrint('[ContactsPage] 后端添加失败: ${res['error'] ?? res}');
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
                  const SizedBox(width: 10),
                  Expanded(child: Text(upgradeHint, style: const TextStyle(fontSize: 13))),
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
                onPressed: () => Navigator.pushNamed(context, '/subscription'),
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[ContactsPage] _syncAddToBackend 异常: $e');
    }
  }

  /// 温柔提示升级智能版（非弹窗，用底部提示条）
  void _showUpgradeHint() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.workspace_premium_rounded, color: Colors.amber.shade700, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '升级智能版后，前${MembershipService.smartAutoCallLimit}位联系人将自动接收紧急通知 ❤️',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.amber.shade50,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
        duration: const Duration(seconds: 4),
        showCloseIcon: true,
        closeIconColor: Colors.grey,
      ),
    );
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
            final smsBody = '【在呢】嗨 ${recipientName.isNotEmpty ? recipientName : name}！我是$senderName，刚把你设为我的紧急联系人 🛡️\n\n我在用「在呢」App 守护自己的安全——每天签到报平安，遇到紧急情况一键求助 会自动通知你我的实时位置。\n\n如果你也下载「在呢」，我们可以互相守护，让彼此都更安心。❤️\n\n点击链接接受邀请：https://zaine.love/landing/contacts_${phone.replaceAll(RegExp(r'[^0-9]'), '')}';

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.sms_rounded, color: Colors.green.shade600, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text('发送邀请短信', style: TextStyle(fontSize: 17)),
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
                      Text('已为 $name 设置为紧急联系人。', style: TextStyle(fontSize: 14, color: ZaiNeColors.textPrimary())),
                      const SizedBox(height: 8),
                      Text('编辑短信内容（双方昵称可选）', style: TextStyle(fontSize: 12, color: ZaiNeColors.textSecondary())),
                      const SizedBox(height: 12),

                      // 发送者昵称（使用 controller 避免重建丢失状态）
                      TextField(
                        controller: senderController,
                        onChanged: (_) => setDlgState(() {}),  // 只触发预览刷新，不重建 controller
                        decoration: InputDecoration(
                          labelText: '你的昵称',
                          hintText: '发短信时显示你是谁',
                          prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF4CAF50)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 10),

                      // 接收者称呼
                      TextField(
                        controller: recipientController,
                        onChanged: (_) => setDlgState(() {}),  // 只触发预览刷新，不重建 controller
                        decoration: InputDecoration(
                          labelText: '对方称呼',
                          hintText: '你想怎么称呼对方',
                          prefixIcon: const Icon(Icons.favorite_outline, color: Color(0xFFFF7F50)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 12),

                      // 短信预览
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('短信预览：', style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 6),
                            Text(
                              smsBody,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.4),
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
                      debugPrint('[ContactsPage] 创建免费守护卡失败: $e');
                    }

                    // 【修复 v1.17.3-Bug4】生成通用短链替代长链接
                    String inviteShortUrl;
                    try {
                      final targetUrl = 'https://zaine.love/landing/contacts_${phone.replaceAll(RegExp(r'[^0-9]'), '')}';
                      final linkRes = await ApiService.createShortLink(
                        targetUrl: targetUrl,
                        linkType: 'invite',
                        meta: '{"sender":"$finalSender","recipient":"$recipientDisplayName"}',
                      );
                      if (linkRes['success'] == true) {
                        inviteShortUrl = linkRes['short_url']?.toString() ?? targetUrl;
                        debugPrint('[ContactsPage] 邀请短链生成成功: $inviteShortUrl');
                      } else {
                        inviteShortUrl = targetUrl;
                        debugPrint('[ContactsPage] 邀请短链生成失败，降级使用长链接');
                      }
                    } catch (e) {
                      inviteShortUrl = 'https://zaine.love/landing/contacts_${phone.replaceAll(RegExp(r'[^0-9]'), '')}';
                      debugPrint('[ContactsPage] 邀请短链异常，降级使用长链接: $e');
                    }

                    final finalBody = '【在呢】嗨 $recipientDisplayName！我是$finalSender，刚把你设为我的紧急联系人 🛡️\n\n我在用「在呢」App 守护自己的安全——每天签到报平安，遇到紧急情况一键求助 会自动通知你我的实时位置。\n\n如果你也下载「在呢」，我们可以互相守护，让彼此都更安心。❤️\n\n点击链接接受邀请：$inviteShortUrl';
                    _sendInviteSms(phone, recipientDisplayName, finalBody);
                    senderController.dispose();
                    recipientController.dispose();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

    debugPrint('[ContactsPage] 短信 URI: $uri');

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
        debugPrint('[ContactsPage] canLaunchUrl 返回 false，尝试直接 launch');
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
      debugPrint('[ContactsPage] 短信发送失败: $e');
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

      // 乐观更新：先写本地
      setState(() {
        // 保留后端 id，更新其他字段
        result['id'] = contactId;
        _contacts[index] = result;
      });
      await _saveContacts();

      // 异步同步到后端
      if (contactId != null) {
        _syncEditToBackend(contactId, result);
      } else {
        // 【修复 v1.17.3-Bug2】本地有但后端无 id → 改为新增而非跳过
        debugPrint('[ContactsPage] 编辑的联系人无后端 id，改为调用新增 API');
        _syncAddToBackend(result);
      }
    }
  }

  /// 异步编辑联系人到后端
  Future<void> _syncEditToBackend(dynamic contactId, Map<String, dynamic> contact) async {
    try {
      final res = await ContactService.updateContact(
        contactId.toString(),
        {
          'name': (contact['name'] ?? '').toString(),
          'phone': (contact['phone'] ?? '').toString(),
          'relation': (contact['relation'] ?? '').toString(),
        },
      );

      if (res['success'] == true) {
        debugPrint('[ContactsPage] 后端编辑成功 id=$contactId');
      } else {
        debugPrint('[ContactsPage] 后端编辑失败: ${res['error'] ?? res}');
        // 【修复 v1.17.3-Bug2】编辑失败时提示用户
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('保存失败: ${res['error'] ?? '请检查网络后重试'}'),
              backgroundColor: Colors.orange.shade700,
              behavior: SnackBarBehavior.floating,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[ContactsPage] _syncEditToBackend 异常: $e');
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
        debugPrint('[ContactsPage] 删除的联系人无后端 id，仅本地删除');
      }
    }
  }

  /// 异步删除后端联系人
  Future<void> _syncDeleteToBackend(dynamic contactId) async {
    try {
      final res = await ContactService.deleteContact(contactId.toString());

      if (res['success'] == true) {
        debugPrint('[ContactsPage] 后端删除成功 id=$contactId');

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
        debugPrint('[ContactsPage] 后端删除失败: ${res['error'] ?? res}');
      }
    } catch (e) {
      debugPrint('[ContactsPage] _syncDeleteToBackend 异常: $e');
    }
  }

  /// 拖动排序回调
  /// oldIndex/newIndex = ReorderableListView 的实际 item 索引（>=1）
  void _onReorder(int oldIndex, int newIndex) {
    debugPrint('[ContactsPage] _onReorder raw: oldIndex=$oldIndex, newIndex=$newIndex');

    // index 0 是 info header，不应该参与重排（已被 onReorder 拦截）
    // 实际联系人索引 = item 索引 - 1（跳过 header）
    int contactOld = oldIndex - 1;

    // Flutter ReorderableListView 的 newIndex 规则：
    // 如果向下移动（newIndex > oldIndex），newIndex 已经包含了"被拖元素被移走后前面元素前移"的效果
    // 所以实际目标位置需要再减1
    // 如果向上移动（newIndex < oldIndex），newIndex 就是插入位置
    int contactNew;
    if (newIndex > oldIndex) {
      contactNew = newIndex - 2; // 向下拖：减去header(1) + 被移走元素自身(1)
    } else {
      contactNew = newIndex - 1; // 向上拖：只减去header(1)
    }

    debugPrint('[ContactsPage] contact索引: 移动[$contactOld] → 插入[$contactNew], 总数=${_contacts.length}');

    if (contactOld >= 0 && contactOld < _contacts.length &&
        contactNew >= 0 && contactNew <= _contacts.length) {
      setState(() {
        final item = _contacts.removeAt(contactOld);
        _contacts.insert(contactNew, item);
      });
      _saveContacts();

      // 异步同步排序到后端
      _syncReorderToBackend();
    } else {
      debugPrint('[ContactsPage] ⚠️ 索引越界！忽略本次操作');
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
        debugPrint('[ContactsPage] 所有联系人都无后端 id，跳过排序同步');
        return;
      }

      final res = await ContactService.reorderContacts(contactIds);

      if (res['success'] == true) {
        debugPrint('[ContactsPage] 后端排序同步成功');
      } else {
        debugPrint('[ContactsPage] 后端排序同步失败: ${res['error'] ?? res}');
      }
    } catch (e) {
      debugPrint('[ContactsPage] _syncReorderToBackend 异常: $e');
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
            icon: const Icon(Icons.add_circle_outline, color: Color(0xFFFF7F50)),
            onPressed: _addContact,
          ),
        ],
      ),
      // 【修复 v1.9.8】用 SafeArea 包裹 body，防止底部溢出（开发者模式黄黑条）
      body: SafeArea(
        top: false,  // AppBar 已处理顶部安全区
        bottom: true,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF7F50)))
            : _contacts.isEmpty
                ? _buildEmptyState()
                : _buildContactsList(),
      ),
      floatingActionButton: _contacts.isEmpty && !_isLoading
          ? FloatingActionButton.extended(
              onPressed: _addContact,
              backgroundColor: const Color(0xFFFF7F50),
              icon: const Icon(Icons.person_add),
              label: const Text('添加联系人'),
            )
          : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFF7F50).withOpacity(0.1),
              ),
              child: Icon(
                Icons.people_outline,
                size: 50,
                color: Colors.grey.shade300,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '暂无紧急联系人',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: ZaiNeColors.textSecondary(),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '添加至少一个紧急联系人\n确保求助功能正常触发',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: ZaiNeColors.textSecondary().withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      '紧急联系人将在求助时收到您的位置和健康信息\n拖动可调整优先顺序',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactsList() {
    // 使用 ReorderableListView 直接作为主体，不用 Column+Expanded 嵌套
    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _contacts.length + 1, // +1 for the header info box
      onReorder: (oldIndex, newIndex) {
        // index 0 是说明框，不参与重排
        if (oldIndex == 0 || newIndex == 0) return;
        // 直接传递实际列表索引给 _onReorder
        _onReorder(oldIndex, newIndex);
      },
      buildDefaultDragHandles: false,
      itemBuilder: (context, index) {
        // 第一个位置放说明框
        if (index == 0) {
          return Container(
            key: const ValueKey('info_header'),
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '求助时将按优先顺序拨打，拖动左侧☰调整排序',
                        style: TextStyle(fontSize: 13, color:Colors.blue.shade700),
                      ),
                      Text(
                        '第一位联系人 = 第一紧急联系人（最优先）',
                        style: TextStyle(fontSize: 11, color: Colors.blue.shade500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
        
        final contactIndex = index - 1;
        final contact = _contacts[contactIndex];
        // ⚠️ 关键：传入实际的 item 索引(index)，不是 contactIndex！
        // ReorderableDragStartListener 需要的是 ReorderableListView 的 item 索引
        return _buildContactCard(itemIndex: index, contactIndex: contactIndex, contact: contact);
      },
    );
  }

  /// 单个联系人卡片（支持拖动手柄）
  Widget _buildContactCard({
    required int itemIndex,     // ReorderableListView 实际 item 索引（>=1，因为0是header）
    required int contactIndex,  // 联系人在 _contacts 数组中的索引（0-based）
    required Map<String, dynamic> contact,
  }) {
    final priorityColor = _priorityColor(contactIndex);
    final name = (contact['name'] ?? '').toString();
    final phone = (contact['phone'] ?? '').toString();
    final relation = (contact['relation'] ?? '亲友').toString();

    return Container(
      key: ValueKey('contact_${name}_$itemIndex'),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: ZaiNeColors.cardBg(),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // 拖动手柄
            // ⚠️ 必须传 itemIndex（ReorderableListView 实际索引 1,2,3...）
            // onReorder 回调收到的 oldIndex/newIndex 就是这个值
            ReorderableDragStartListener(
              index: itemIndex,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.drag_handle, color: Colors.grey[400], size: 24),
              ),
            ),

            const SizedBox(width: 8),

            // 头像
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFF7F50).withOpacity(0.1),
              ),
              child: Center(
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF7F50),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // 信息区
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      // 会员限制锁定图标（超出自动通知上限的联系人）
                      if (contactIndex >= MembershipService.getAutoCallLimit()) ...[
                        Icon(Icons.lock_outline, size: 13, color: Colors.grey.shade400),
                        const SizedBox(width: 4),
                      ],
                      // 优先级标签
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: priorityColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: priorityColor.withOpacity(0.3), width: 0.5),
                        ),
                        child: Text(
                          _priorityLabelWithIcon(contactIndex),
                          style: TextStyle(
                            fontSize: 9.5,
                            color: priorityColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    phone,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  // 关系标签
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      relation,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 操作按钮（竖排编辑/删除）
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.edit, color: Colors.grey[500], size: 18),
                  onPressed: () => _editContact(contactIndex),
                  visualDensity: VisualDensity.compact,
                  tooltip: '编辑',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                  onPressed: () => _deleteContact(contactIndex),
                  visualDensity: VisualDensity.compact,
                  tooltip: '删除',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
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
  String _selectedRelation = '家人';
  final _formKey = GlobalKey<FormState>();
  bool _obscurePhone = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existingContact?['name'] ?? '');
    _phoneController = TextEditingController(text: widget.existingContact?['phone'] ?? '');

    String savedRelation = widget.existingContact?['relation'] ?? '';
    if (savedRelation.isNotEmpty && kRelationOptions.contains(savedRelation)) {
      _selectedRelation = savedRelation;
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        constraints: BoxConstraints(maxHeight: maxContentHeight),
        decoration: BoxDecoration(
          color: ZaiNeColors.cardBg(),
          borderRadius: BorderRadius.circular(24),
        ),
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
                    colors: [Color(0xFFFF7F50), Color(0xFFFFB347)],
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF7F50).withOpacity(0.25),
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
                        color: Colors.white.withOpacity(0.22),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.35), width: 1.5),
                      ),
                      child: Icon(
                        isEdit ? Icons.edit_note : Icons.person_add_alt_1_rounded,
                        size: 30,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      isEdit ? '编辑紧急联系人' : '添加紧急联系人',
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isEdit ? '修改后将自动保存优先顺序' : '求助时将按优先顺序拨打',
                      style: TextStyle(fontSize: 12.5, color: Colors.white.withOpacity(0.85)),
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

                      const SizedBox(height: 18),

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
                          if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(v)) return '请输入正确的手机号';
                          return null;
                        },
                      ),

                      const SizedBox(height: 18),

                      // 关系选择 — 精美芯片式下拉
                      DropdownButtonFormField<String>(
                        value: kRelationOptions.contains(_selectedRelation)
                            ? _selectedRelation : '其他',
                        decoration: InputDecoration(
                          labelText: '与您的关系',
                          labelStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
                          prefixIcon: Icon(Icons.favorite_border_rounded, color: Colors.orange.shade400, size: 20),
                          filled: true,
                          fillColor: Colors.orange.shade50.withOpacity(0.4),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: Colors.orange.shade200),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: Colors.orange.shade200),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: const Color(0xFFFF7F50), width: 1.5),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: Colors.red.shade300),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                        ),
                        icon: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey[600]),
                        style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                        items: kRelationOptions.map((relation) {
                          return DropdownMenuItem(value: relation, child: Text(relation));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedRelation = val);
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) return '请选择关系';
                          return null;
                        },
                      ),

                      const SizedBox(height: 8),
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
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        child: Text('取消', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500)),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // 保存按钮
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            Navigator.of(context).pop({
                              'name': _nameController.text.trim(),
                              'phone': _phoneController.text.trim(),
                              'relation': _selectedRelation,
                            });
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF7F50),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                          shadowColor: const Color(0xFFFF7F50).withOpacity(0.3),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(isEdit ? Icons.check_rounded : Icons.person_add_rounded, size: 18),
                            const SizedBox(width: 6),
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
      style: const TextStyle(fontSize: 15.5, letterSpacing: 0.3),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
        prefixIcon: Icon(prefixIcon, color: const Color(0xFFFF7F50), size: 21),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: ZaiNeColors.scaffoldBg() == const Color(0xFF121212)
            ? const Color(0xFF1E1E1E)
            : Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: const Color(0xFFFF7F50), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.red.shade300),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      ),
      validator: validator,
    );
  }
}
