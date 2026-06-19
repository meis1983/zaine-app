import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../main.dart';
import '../theme/theme_helper.dart';
import '../data/app_constants.dart';
import '../widgets/developer_mode.dart';
import '../utils/avatar_helper.dart';
import '../services/api_service.dart';
import 'redeem_card_page.dart';
import 'settings_page.dart';
import 'safety_settings_page.dart';

class ProfilePage extends StatefulWidget {
  /// 是否为 push 模式（需要返回按钮）
  /// true = 从首页等页面 Navigator.push 进来，需要返回
  /// false = 作为 MainNavigation 的 tab 页面，无返回按钮
  final bool isPushed;

  const ProfilePage({super.key, this.isPushed = false});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with DeveloperMode<ProfilePage> {
  bool _isLoggedIn = false;
  bool _isLoading = true;
  String? _avatarPath;

  // 健康档案 - 必填
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  String _gender = '男';
  String _bloodType = '未知';
  final _allergyController = TextEditingController();

  // 健康档案 - 选填
  final _diseaseController = TextEditingController();
  final _medicineController = TextEditingController();
  final _emergencyNoteController = TextEditingController();

  // 实时定位（仅用于求助页面，档案页不再显示）

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  /// 【修复 v1.9.5】页面重新可见时刷新登录状态
  /// 根因：从引导页登录后 pushReplacement 到 MainNavigation，ProfilePage 作为 tab 页面
  /// 在某些情况下状态未同步，导致仍显示"当前未登录"
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _allergyController.dispose();
    _diseaseController.dispose();
    _medicineController.dispose();
    _emergencyNoteController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();

    // 【修复 v1.9.x】按用户隔离读取健康档案，防止跨账号泄露
    final userId = prefs.getString('user_id');
    final phone = prefs.getString('user_phone');

    String? profileJson;
    String? profileKey;

    // 优先使用 user_id 作为隔离标识
    if (userId != null && userId.isNotEmpty) {
      profileKey = 'user_profile_$userId';
      profileJson = prefs.getString(profileKey);

      // 兼容旧数据：如果用户特定的键不存在，尝试全局键
      if (profileJson == null) {
        profileJson = prefs.getString('user_profile');
        // 如果找到了旧数据，迁移到用户特定的键
        if (profileJson != null) {
          await prefs.setString(profileKey, profileJson);
          debugPrint('[ProfilePage] ✅ 健康档案已从全局键迁移到用户特定键: $profileKey');
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
      // 未登录状态，读取全局键（兼容性）
      profileKey = 'user_profile';
      profileJson = prefs.getString(profileKey);
    }

    if (profileJson != null) {
      final profile = jsonDecode(profileJson);
      _nameController.text = profile['name'] ?? '';
      _ageController.text = profile['age']?.toString() ?? '';
      _gender = profile['gender'] ?? '男';
      
      // 【修复 v2.0】校验血型初始值，防止 DropdownButton 断言红屏
      final savedBloodType = profile['bloodType'] ?? '未知';
      const allowedBloodTypes = ['未知', 'A型', 'B型', 'O型', 'AB型', '其他'];
      _bloodType = allowedBloodTypes.contains(savedBloodType) ? savedBloodType : '未知';
      
      _allergyController.text = profile['allergy'] ?? '';
      _diseaseController.text = profile['disease'] ?? '';
      _medicineController.text = profile['medicine'] ?? '';
      _emergencyNoteController.text = profile['emergencyNote'] ?? '';
    }

    // 【修复 v1.9.5】不再依赖可能不同步的 is_logged_in bool，直接检查 auth_token
    final token = prefs.getString('auth_token');
    final isReallyLoggedIn = token != null && token.isNotEmpty;
    debugPrint('[ProfilePage] _loadProfile: auth_token=${token != null ? '有(${token.substring(0, token.length > 8 ? 8 : token.length)}...)' : '无'}, is_logged_in=${prefs.getBool('is_logged_in')}, 实际登录态=$isReallyLoggedIn, profileKey=$profileKey');

    if (!mounted) return;

    // 检查头像文件是否存在，不存在则从 base64 恢复
    String? avatarPath = await AvatarHelper.getPath(prefs);
    if (avatarPath != null && avatarPath.isNotEmpty && !await File(avatarPath).exists()) {
      avatarPath = await _restoreAvatarFromBase64();
    }

    setState(() {
      _isLoggedIn = isReallyLoggedIn;
      _avatarPath = avatarPath;
      _isLoading = false;
    });
  }

  /// 选择头像
  /// 【修复 v1.9.78】使用 image 包强制压缩为 JPEG，确保 imageQuality 生效
  /// 根因：image_picker 的 imageQuality 只对 JPEG 有效，PNG 格式会被忽略
  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 256,
      maxHeight: 256,
      imageQuality: 60,
    );
    if (picked == null) return;

    try {
      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final savedPath = '${dir.path}/avatar_$timestamp.jpg';

      // 使用 image 包强制压缩为 JPEG（无论原图格式）
      final sourceBytes = await File(picked.path).readAsBytes();
      debugPrint('[Profile] 原图大小: ${sourceBytes.length} bytes');

      final original = img.decodeImage(sourceBytes);
      if (original == null) {
        debugPrint('[Profile] ⚠️ 图片解码失败');
        return;
      }

      // 等比例缩放至 256x256 以内
      final resized = img.copyResize(original, width: 256, height: 256);
      // 编码为 JPEG，质量 60
      final jpegBytes = img.encodeJpg(resized, quality: 60);
      debugPrint('[Profile] 压缩后大小: ${jpegBytes.length} bytes');

      // 保存压缩后的 JPEG
      final file = File(savedPath);
      await file.writeAsBytes(jpegBytes);

      // 验证文件
      if (!await file.exists()) {
        debugPrint('[Profile] ⚠️ 头像文件保存失败！路径: $savedPath');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('头像保存失败，请重试'), backgroundColor: Colors.red),
          );
        }
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      await AvatarHelper.setPath(prefs, savedPath);

      // 【调试】同时存 base64 到 SharedPreferences（小体积 JPEG 应该没问题）
      try {
        final base64Str = base64Encode(jpegBytes);
        debugPrint('[Profile] base64 长度: ${base64Str.length}');
        await AvatarHelper.setBase64(prefs, base64Str);
      } catch (e) {
        debugPrint('[Profile] ⚠️ base64 头像备份失败: $e');
      }

      debugPrint('[Profile] ✅ 头像已保存: $savedPath, size=${jpegBytes.length} bytes');

      if (!mounted) return;
      setState(() => _avatarPath = savedPath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('头像更新成功 ✓'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // 【修复 v1.9.78】选择头像后自动同步到后端
      // 根因：之前只保存本地，没有发到后端，导致重装/换设备后头像丢失
      await _syncAvatarToBackend(prefs, savedPath);
    } catch (e) {
      debugPrint('[Profile] 头像保存异常: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('头像保存失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// 从 SharedPreferences 的 base64 备份恢复头像文件
  /// 覆盖安装时文件被清空但 SharedPreferences 保留，此方法可恢复头像
  Future<String?> _restoreAvatarFromBase64() async {
    final prefs = await SharedPreferences.getInstance();
    final base64Str = await AvatarHelper.getBase64(prefs);
    if (base64Str == null || base64Str.isEmpty) {
      debugPrint('[Profile] ⚠️ 无 base64 头像备份，无法恢复');
      return null;
    }
    try {
      final bytes = base64Decode(base64Str);
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/avatar.png';
      await File(path).writeAsBytes(bytes);
      await AvatarHelper.setPath(prefs, path);
      debugPrint('[Profile] ✅ 头像已从 base64 备份恢复: $path');
      return path;
    } catch (e) {
      debugPrint('[Profile] ⚠️ base64 头像恢复失败: $e');
      return null;
    }
  }

  /// 调试信息行
  Widget _buildDebugRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade500),
          const SizedBox(width: 6),
          SizedBox(
            width: 110,
            child: Text('$label:', style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value, style: TextStyle(fontSize: 11, color: Colors.grey.shade700), maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  /// 同步头像到后端（被 _pickAvatar 和 _saveProfile 共用）
  Future<void> _syncAvatarToBackend(SharedPreferences prefs, String avatarPath) async {
    try {
      final file = File(avatarPath);
      if (!await file.exists()) {
        debugPrint('[Profile] ⚠️ 头像文件不存在，无法同步: $avatarPath');
        return;
      }
      final bytes = await file.readAsBytes();
      final avatarBase64 = base64Encode(bytes);
      debugPrint('[Profile] 同步头像 base64 长度: ${avatarBase64.length}');
      final res = await ApiService.put('/api/user/profile', body: {'avatar': avatarBase64});
      debugPrint('[Profile] 头像同步响应: $res');
      if (res['success'] == true) {
        debugPrint('[Profile] ✅ 头像已同步到后端');
      } else {
        debugPrint('[Profile] ⚠️ 头像同步失败: ${res['error']}');
      }
    } catch (e) {
      debugPrint('[Profile] ⚠️ 头像同步异常: $e');
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final prefs = await SharedPreferences.getInstance();
    final profile = {
      'name': _nameController.text.trim(),
      'age': int.tryParse(_ageController.text) ?? 0,
      'gender': _gender,
      'bloodType': _bloodType,
      'allergy': _allergyController.text.trim(),
      'disease': _diseaseController.text.trim(),
      'medicine': _medicineController.text.trim(),
      'emergencyNote': _emergencyNoteController.text.trim(),
      'updatedAt': DateTime.now().toIso8601String(),
    };

    // 【修复 v1.9.x】按用户隔离存储健康档案，防止跨账号泄露
    final userId = prefs.getString('user_id');
    final phone = prefs.getString('user_phone');
    String profileKey;
    if (userId != null && userId.isNotEmpty) {
      profileKey = 'user_profile_$userId';
    } else if (phone != null && phone.isNotEmpty) {
      profileKey = 'user_profile_$phone';
    } else {
      profileKey = 'user_profile'; // 全局键（兼容旧数据或未登录状态）
    }

    // 【修复 v1.9.78】本地保存的 profile 不含头像 base64，避免 SharedPreferences 截断大 JSON
    // 头像通过单独请求同步到后端
    await prefs.setString(profileKey, jsonEncode(profile));
    await prefs.setBool('is_logged_in', true);
    // 同时保存头像路径和用户名，供首页读取
    if (_avatarPath != null) {
      await AvatarHelper.setPath(prefs, _avatarPath!);
    }
    if (_nameController.text.trim().isNotEmpty) {
      await prefs.setString('user_name', _nameController.text.trim());
    }

    // 【修复 v1.9.78】同步到后端：profile（不含头像）+ 头像单独同步
    // 根因：头像 base64 太大，混入 profile JSON 会导致请求体过大，后面的 disease/medicine/emergencyNote 字段被截断丢失
    bool syncOk = true;
    try {
      // 1. 同步档案（不含头像，小体积 JSON）
      await ApiService.put('/api/user/profile', body: profile);
      // 2. 单独同步头像
      final avatarPath = await AvatarHelper.getPath(prefs);
      if (avatarPath != null && avatarPath.isNotEmpty) {
        await _syncAvatarToBackend(prefs, avatarPath);
      }
    } catch (e) {
      syncOk = false;
      debugPrint('[Profile] ⚠️ 同步到后端失败: $e');
    }

    if (!mounted) return;
    setState(() => _isLoggedIn = true);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(syncOk ? Icons.check_circle : Icons.cloud_off,
                  color: Colors.white),
              const SizedBox(width: 12),
              Text(syncOk
                  ? '健康档案保存成功！'
                  : '本地保存成功，云端同步失败，请检查网络'),
            ],
          ),
          backgroundColor: syncOk ? Colors.green : Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      // push 模式下保存成功后自动返回（求助三道门/首页等场景）
      // tab 模式下不 pop，用户通过底部导航栏切换
      if (widget.isPushed) {
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) Navigator.of(context).pop();
      }
    }
  }

  /// 主题选择
  void _showThemeSelector() {
    final themes = [
      {'name': '浅色', 'mode': ZaiNeThemeMode.light, 'icon': Icons.light_mode, 'color': Colors.orange},
      {'name': '深色', 'mode': ZaiNeThemeMode.dark, 'icon': Icons.dark_mode, 'color': Colors.indigo},
      {'name': '柔光', 'mode': ZaiNeThemeMode.soft, 'icon': Icons.auto_awesome, 'color': Colors.pink},
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.palette, color: Color(0xFFFF7F50)),
            SizedBox(width: 8),
            Text('主题设置'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: themes.map((t) {
            final isSelected = themeNotifier.mode == t['mode'];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                leading: Icon(t['icon'] as IconData, color: t['color'] as Color),
                title: Text(t['name'] as String),
                trailing: isSelected
                    ? const Icon(Icons.check_circle, color: Color(0xFFFF7F50))
                    : null,
                tileColor: isSelected ? const Color(0xFFFF7F50).withValues(alpha: 20) : null,
                onTap: () {
                  themeNotifier.setMode(t['mode'] as ZaiNeThemeMode);
                  Navigator.pop(context);
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  /// 问题反馈（带本地保存 + 查看入口）
  void _showFeedback() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.feedback, color: Color(0xFFFF7F50)),
            SizedBox(width: 8),
            Text('问题反馈'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '您的反馈对我们非常重要，我们会尽快处理。',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: '请描述您遇到的问题或建议...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              final feedbackText = controller.text.trim();
              if (feedbackText.isEmpty) {
                Navigator.pop(context);
                return;
              }
              // 保存到 SharedPreferences
              final prefs = await SharedPreferences.getInstance();
              final existingList = prefs.getStringList('feedback_list') ?? [];
              final entry = jsonEncode({
                'content': feedbackText,
                'time': DateTime.now().toIso8601String(),
                'version': AppConstants.version,
              });
              existingList.insert(0, entry); // 最新的在前面
              await prefs.setStringList('feedback_list', existingList);
              if (!context.mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('感谢您的反馈，我们会尽快处理！✓'),
                  backgroundColor: Color(0xFFFF7F50),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF7F50),
            ),
            child: const Text('提交反馈'),
          ),
        ],
      ),
    );
  }

  /// 查看已提交的反馈列表（开发者/调试用）
  void _viewFeedbackList() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList('feedback_list') ?? [];
    if (rawList.isEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('暂无反馈记录'),
        backgroundColor: Colors.grey,
      ));
      return;
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.feedback_outlined, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Text('用户反馈 (${rawList.length}条)',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  // 一键清空按钮
                  TextButton.icon(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: const Text('确认清空'),
                          content: const Text('确定要删除所有反馈记录吗？此操作不可恢复。'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(c, true),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                              child: const Text('确认删除', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        final p = await SharedPreferences.getInstance();
                        await p.remove('feedback_list');
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('反馈记录已清空'),
                            backgroundColor: Colors.red,
                          ));
                        }
                      }
                    },
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('清空', style: TextStyle(color: Colors.red, fontSize: 12)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: rawList.length,
                itemBuilder: (context, index) {
                  final item = jsonDecode(rawList[index]);
                  final timeStr = DateTime.tryParse(item['time'] ?? '')?.toString().substring(0, 19) ?? '未知时间';
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('#${index + 1}',
                                  style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.bold)),
                              Text(timeStr, style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(item['content'] ?? '',
                              style: const TextStyle(fontSize: 14, height: 1.4)),
                          const SizedBox(height: 6),
                          Text('v${item['version'] ?? '?'}',
                              style: TextStyle(fontSize: 10, color: Colors.orange.shade400)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void showDeveloperMenu() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final bottomSafe = MediaQuery.of(ctx).padding.bottom;
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (_, controller) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: ListView(
              controller: controller,
              padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottomSafe),
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                const Row(children: [
                  const Icon(Icons.shield, color: const Color(0xFFFF7F50)),
                  const SizedBox(width: 8),
                  const Text('守护关系', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 20),

                // 输入守护码
                ListTile(
                  leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: const Color(0xFFFFF5F0), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.vpn_key, color: Color(0xFFFF7F50), size: 20)),
                  title: const Text('输入守护码', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('手动输入安全码，接受他人的守护卡'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const RedeemCardPage()),
                    );
                  },
                ),

                const SizedBox(height: 24),
                Row(children: [
                  Icon(Icons.code_rounded, color: Colors.purple.shade700), const SizedBox(width: 8),
                  const Text('开发者模式', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: Colors.purple.shade100, borderRadius: BorderRadius.circular(10)), child: const Text('DEV', style: TextStyle(fontSize: 10, color: Colors.purple, fontWeight: FontWeight.bold))),
                ]),
                const SizedBox(height: 20),

            // 【调试信息】显示USER-ID和头像详情
            FutureBuilder<SharedPreferences>(
              future: SharedPreferences.getInstance(),
              builder: (ctx, snap) {
                if (!snap.hasData) return const SizedBox.shrink();
                final prefs = snap.data!;
                final uid = prefs.getString('user_id') ?? '未登录';
                final uidShort = uid.length > 12 ? '${uid.substring(0, 6)}...${uid.substring(uid.length - 6)}' : uid;

                // 1. profile JSON里的avatar字段（后端返回的是"avatar"）
                final profileJson = prefs.getString('user_profile_${uid.isNotEmpty ? uid : ''}') ?? prefs.getString('user_profile');
                String? profileAvatar;
                if (profileJson != null) {
                  try {
                    final p = jsonDecode(profileJson);
                    profileAvatar = p['avatar']?.toString();
                  } catch (_) {}
                }

                // 2. 独立的base64 key
                final base64Key = uid.isNotEmpty ? 'avatar_base64_$uid' : 'avatar_base64';
                final base64Val = prefs.getString(base64Key);
                final base64Len = base64Val?.length ?? 0;

                // 3. 独立的path key
                final pathKey = uid.isNotEmpty ? 'avatar_path_$uid' : 'avatar_path';
                final pathVal = prefs.getString(pathKey);

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.perm_identity, size: 16, color: Colors.purple.shade400),
                          const SizedBox(width: 6),
                          Text('USER-ID: $uidShort', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.purple.shade700)),
                          const Spacer(),
                          if (uid != '未登录')
                            GestureDetector(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: uid));
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                  content: Text('USER-ID 已复制到剪贴板'),
                                  backgroundColor: Colors.purple,
                                  behavior: SnackBarBehavior.floating,
                                  duration: Duration(seconds: 2),
                                ));
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(8)),
                                child: Text('复制', style: TextStyle(fontSize: 11, color: Colors.purple.shade600, fontWeight: FontWeight.w500)),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildDebugRow(Icons.image, 'profile.avatar', profileAvatar != null && profileAvatar.isNotEmpty ? '${profileAvatar.substring(0, profileAvatar.length > 40 ? 40 : profileAvatar.length)}...' : '无'),
                      _buildDebugRow(Icons.data_array, 'avatar_base64', base64Len > 0 ? '$base64Len chars' : '无'),
                      _buildDebugRow(Icons.folder, 'avatar_path', pathVal ?? '无'),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // 签到模拟器
            ListTile(
              leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(10)), child: Icon(Icons.science_rounded, color: Colors.amber.shade700, size: 20)),
              title: const Text('签到模拟器', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('设置连续签到天数，测试徽章和里程碑弹窗'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () { Navigator.pop(context); showCheckInSimulator(); },
            ),

            // 重置守护卡（完整链路测试）
            ListTile(
              leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.pink.shade50, borderRadius: BorderRadius.circular(10)), child: Icon(Icons.card_giftcard, color: Colors.pink.shade700, size: 20)),
              title: const Text('重置守护卡', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('恢复为初始3张卡状态，方便测试发卡全链路'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async { Navigator.pop(context); await resetGuardianCard(); },
            ),

            // 清除引导标记
            ListTile(
              leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)), child: Icon(Icons.replay_rounded, color: Colors.blue.shade700, size: 20)),
              title: const Text('重新显示引导页', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('下次启动App时再次显示开机引导'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('onboarding_completed', false);
                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已设置，下次启动将显示引导页 ✓'), backgroundColor: Colors.purple, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10)))));
              },
            ),

            // 【新增 v1.9.5】重置新手任务
            ListTile(
              leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.pink.shade50, borderRadius: BorderRadius.circular(10)), child: Icon(Icons.task_alt, color: Colors.pink.shade700, size: 20)),
              title: const Text('重置新手任务', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('清除新手任务完成状态，重新体验5步引导'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('newbie_tasks_collapsed');
                await prefs.remove('newbie_tasks_all_done_shown');
                await prefs.remove('newbie_card_sent');
                await prefs.remove('newbie_task_location');
                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('新手任务已重置，返回首页即可重新体验 ✓'), backgroundColor: Colors.purple, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10)))));
              },
            ),

            // 切换会员等级（测试用）
            ListTile(
              leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.workspace_premium_rounded, color: Colors.orange, size: 20)),
              title: const Text('切换会员等级', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('体验版 ↔ 智能版，测试会员权益差异'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                showMembershipSwitchDialog();
              },
            ),

            // 模拟会员过期降级（测试用）
            ListTile(
              leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)), child: Icon(Icons.timer_off_rounded, color: Colors.red.shade400, size: 20)),
              title: const Text('模拟会员过期降级', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('智能版 → 体验版，联系人保留但锁定'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                showMembershipExpiryDialog();
              },
            ),

            // 查看用户反馈（profile 独有）
            ListTile(
                leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(10)), child: Icon(Icons.feedback_outlined, color: Colors.orange.shade700, size: 20)),
                title: const Text('查看用户反馈', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('查看所有已提交的反馈内容'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () { Navigator.pop(context); _viewFeedbackList(); },
              ),

          ],
        ),
      ),
    );
      },
    );
  }

  @override
  Future<void> resetTodayCheckIn() async {
    await super.resetTodayCheckIn();
    if (mounted) _loadProfile(); // 重置后刷新档案
  }

  
  @override
  Widget build(BuildContext context) {
    final isDark = ZaiNeColors.scaffoldBg() == const Color(0xFF121212);

    return Scaffold(
      backgroundColor: ZaiNeColors.scaffoldBg(),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: widget.isPushed
            ? IconButton(
                icon: Icon(Icons.arrow_back_ios, color: ZaiNeColors.textPrimary()),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: Text(
          '健康档案',
          style: TextStyle(color: ZaiNeColors.textPrimary(), fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          // 设置入口（v1.9.78 新增）
          IconButton(
            icon: Icon(Icons.settings_outlined, color: ZaiNeColors.textPrimary(), size: 22),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        bottom: true,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  padding: EdgeInsets.zero,
                children: [
                  // ====== 1. 渐变头部 — 头像 + 档案状态 ======
                  _buildProfileHeader(isDark),

                  const SizedBox(height: 8),

                  // ====== 2. 快捷功能卡片 ======
                  _buildQuickActions(isDark),

                  const SizedBox(height: 8),

                  // ====== 2.5 安全中心入口（从底部Tab降级） ======
                  _buildSafetyCenterEntry(isDark),

                  const SizedBox(height: 8),

                  // ====== 3. 基本信息表单 ======
                  _buildFormSection(isDark),

                  const SizedBox(height: 16),

                  // ====== 4. 保存按钮 ======
                  _buildSaveButton(),

                  const SizedBox(height: 16),

                  // ====== 5. 其他 ======
                  _buildOtherSection(isDark),

                  // 底部安全间距
                  const SizedBox(height: 60),
                ],
              ),
            ),
            ),
    );
  }

  // ==================== 渐变头部 ====================
  Widget _buildProfileHeader(bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1E1E2E), const Color(0xFF2A2A3E)]
              : [const Color(0xFFFF7F50).withValues(alpha: 20), const Color(0xFFFFB347).withValues(alpha: 15)],
          stops: const [0.0, 1.0],
        ),
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),

          // 头像
          GestureDetector(
            onTap: _pickAvatar,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF7F50).withValues(alpha: 64),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Container(
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: _avatarPath == null
                          ? LinearGradient(colors: [
                              const Color(0xFFFF7F50).withValues(alpha: 64),
                              const Color(0xFFFFB347).withValues(alpha: 64),
                            ])
                          : null,
                      image: _avatarPath != null
                          ? DecorationImage(image: FileImage(File(_avatarPath!)), fit: BoxFit.cover)
                          : null,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: _avatarPath == null
                        ? const Icon(Icons.person, size: 38, color: Color(0xFFFF7F50))
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFFF7F50), Color(0xFFFF6B35)]),
                        shape: BoxShape.circle,
                        border: Border.all(color: isDark ? const Color(0xFF1E1E2E) : Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _nameController.text.isNotEmpty ? _nameController.text : '点击头像设置',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: ZaiNeColors.textPrimary(),
            ),
          ),
          if (_avatarPath != null)
            Text('点击头像更换照片', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),

          const SizedBox(height: 16),

          // 档案状态卡片
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _isLoggedIn
                    ? [Colors.green.shade400, Colors.teal.shade400]
                    : [Colors.orange.shade300, const Color(0xFFFF7F50)],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: (_isLoggedIn ? Colors.green : Colors.orange).withValues(alpha: 38),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 51),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _isLoggedIn ? Icons.verified_user : Icons.edit_note_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isLoggedIn ? '档案已完善' : '请完善健康档案',
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _isLoggedIn ? '求助功能已解锁，保护自己从现在开始' : '紧急求助需要您的健康信息',
                        style: TextStyle(color: Colors.white.withValues(alpha: 217), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 153)),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ==================== 快捷功能 ====================
  /// 安全中心入口卡片（从底部Tab降级至此）
  Widget _buildSafetyCenterEntry(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: ZaiNeColors.cardBg(),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(((isDark ? 0.12 : 0.04) * 255).round()),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SafetySettingsPage()),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              // 左侧图标
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade400, Colors.blue.shade600],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.security_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              // 中间文字
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('安全中心', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: ZaiNeColors.textPrimary())),
                    const SizedBox(height: 3),
                    Text(
                      '定时平安确认 · 位置共享 · 跌倒检测',
                      style: TextStyle(fontSize: 12, color: ZaiNeColors.textSecondary()),
                    ),
                  ],
                ),
              ),
              // 右侧箭头
              Icon(Icons.chevron_right_rounded, color: ZaiNeColors.textSecondary(), size: 22),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: ZaiNeColors.cardBg(),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(((isDark ? 0.15 : 0.04) * 255).round()),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildQuickActionItem(
            icon: Icons.palette_rounded,
            label: '主题颜色',
            value: _getThemeName(),
            iconBgColor: Colors.purple.shade100,
            iconColor: Colors.purple.shade600,
            onTap: _showThemeSelector,
          ),
          Container(width: 1, height: 36, color: isDark ? Colors.white.withValues(alpha: 20) : Colors.grey.shade200),
          _buildQuickActionItem(
            icon: Icons.key_rounded,
            label: '安全码',
            value: '绑定守护卡',
            iconBgColor: Colors.teal.shade100,
            iconColor: Colors.teal.shade600,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RedeemCardPage()),
              );
            },
          ),
          Container(width: 1, height: 36, color: isDark ? Colors.white.withValues(alpha: 20) : Colors.grey.shade200),
          _buildQuickActionItem(
            icon: Icons.feedback_rounded,
            label: '问题反馈',
            value: '告诉我们',
            iconBgColor: Colors.orange.shade100,
            iconColor: Colors.orange.shade600,
            onTap: _showFeedback,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionItem({
    required IconData icon,
    required String label,
    required String value,
    required Color iconBgColor,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(height: 6),
              Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ZaiNeColors.textPrimary())),
              const SizedBox(height: 2),
              Text(value, style: TextStyle(fontSize: 11, color: ZaiNeColors.textSecondary())),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== 表单区域 ====================
  Widget _buildFormSection(bool isDark) {
    final cardBg = ZaiNeColors.cardBg();
    final borderColor = isDark ? Colors.white.withValues(alpha: 20) : Colors.grey.shade100;
    final labelColor = ZaiNeColors.textSecondary();
    final fieldBg = isDark ? const Color(0xFF1A1A2A) : const Color(0xFFFAFAFA);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(((isDark ? 0.15 : 0.04) * 255).round()),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 分组标题
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 16,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF7F50),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text('基本信息', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ZaiNeColors.textPrimary())),
                const SizedBox(width: 6),
                Text('必填', style: TextStyle(fontSize: 11, color: Colors.red.shade400, fontWeight: FontWeight.w500)),
              ],
            ),
          ),

          Divider(height: 1, color: borderColor, indent: 18, endIndent: 18),

          // 表单字段
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              children: [
                _buildModernField(
                  controller: _nameController,
                  label: '姓名',
                  hint: '请输入您的姓名',
                  icon: Icons.badge_outlined,
                  iconColor: const Color(0xFFFF7F50),
                  fieldBg: fieldBg,
                  validator: (v) => (v == null || v.isEmpty) ? '请输入姓名' : null,
                ),
                const SizedBox(height: 12),
                _buildModernField(
                  controller: _ageController,
                  label: '年龄',
                  hint: '请输入年龄',
                  icon: Icons.cake_outlined,
                  iconColor: Colors.blue.shade500,
                  fieldBg: fieldBg,
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.isEmpty) return '请输入年龄';
                    final age = int.tryParse(v);
                    if (age == null || age < 1 || age > 120) return '请输入有效年龄';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // 性别 + 血型 横排（紧凑型）
                Row(
                  children: [
                    // 性别选择器
                    Expanded(
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: fieldBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor, width: 1),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.wc_outlined, size: 16, color: Colors.pink.shade400),
                            const SizedBox(width: 8),
                            Text('性别', style: TextStyle(fontSize: 13, color: labelColor)),
                            const Spacer(),
                            _buildGenderChip('男'),
                            const SizedBox(width: 4),
                            _buildGenderChip('女'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // 血型选择器
                    Expanded(
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: fieldBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor, width: 1),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _bloodType,
                            isExpanded: true,
                            icon: Icon(Icons.arrow_drop_down, size: 18, color: labelColor),
                            items: ['未知', 'A型', 'B型', 'O型', 'AB型', '其他']
                                .map((t) => DropdownMenuItem(value: t, child: Text(t, style: TextStyle(fontSize: 13, color: ZaiNeColors.textPrimary()))))
                                .toList(),
                            onChanged: (v) => setState(() => _bloodType = v!),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildModernField(
                  controller: _allergyController,
                  label: '过敏史',
                  hint: '如：青霉素、芒果、海鲜（无则填"无"）',
                  icon: Icons.warning_amber_outlined,
                  iconColor: Colors.amber.shade600,
                  fieldBg: fieldBg,
                  maxLines: 2,
                  validator: (v) => (v == null || v.isEmpty) ? '请填写过敏史' : null,
                ),

                // --- 选填区域 ---
                const SizedBox(height: 20),
                Divider(height: 1, color: borderColor, indent: 0, endIndent: 0),
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 12, 0, 8),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.teal.shade400,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('健康信息', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: ZaiNeColors.textPrimary())),
                      const SizedBox(width: 6),
                      Text('选填', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                    ],
                  ),
                ),

                _buildModernField(
                  controller: _diseaseController,
                  label: '既往病史',
                  hint: '如：高血压、糖尿病等',
                  icon: Icons.history_outlined,
                  iconColor: Colors.red.shade400,
                  fieldBg: fieldBg,
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                _buildModernField(
                  controller: _medicineController,
                  label: '常用药物',
                  hint: '如：降压药、胰岛素等',
                  icon: Icons.medication_outlined,
                  iconColor: Colors.green.shade500,
                  fieldBg: fieldBg,
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                _buildModernField(
                  controller: _emergencyNoteController,
                  label: '紧急备注',
                  hint: '救援人员需要知道的信息',
                  icon: Icons.note_alt_outlined,
                  iconColor: Colors.indigo.shade400,
                  fieldBg: fieldBg,
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderChip(String gender) {
    final isSelected = _gender == gender;
    return GestureDetector(
      onTap: () => setState(() => _gender = gender),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF7F50).withValues(alpha: 31) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF7F50) : (ZaiNeColors.scaffoldBg() == const Color(0xFF121212) ? Colors.white.withValues(alpha: 31) : Colors.grey.shade300),
          ),
        ),
        child: Text(
          gender,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? const Color(0xFFFF7F50) : ZaiNeColors.textSecondary(),
          ),
        ),
      ),
    );
  }

  Widget _buildModernField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required Color iconColor,
    required Color fieldBg,
    TextInputType? keyboardType,
    int? maxLines,
    String? Function(String?)? validator,
  }) {
    final borderColor = ZaiNeColors.scaffoldBg() == const Color(0xFF121212) ? Colors.white.withValues(alpha: 20) : Colors.grey.shade200;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: ZaiNeColors.textSecondary())),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines ?? 1,
          validator: validator,
          style: TextStyle(fontSize: 15, color: ZaiNeColors.textPrimary()),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
            filled: true,
            fillColor: fieldBg,
            prefixIcon: Container(
              margin: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: iconColor.withValues(alpha: 26), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFFF7F50), width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 1),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            isDense: true,
          ),
        ),
      ],
    );
  }

  // ==================== 保存按钮 ====================
  Widget _buildSaveButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF7F50).withValues(alpha: 76),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: SizedBox(
          height: 54,
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saveProfile,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF7F50),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_isLoggedIn ? Icons.check_rounded : Icons.shield_rounded, size: 20),
                const SizedBox(width: 8),
                Text(
                  _isLoggedIn ? '更新档案' : '保存并启用求助',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== 隐私说明 ====================
  Widget _buildOtherSection(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ZaiNeColors.cardBg(),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(((isDark ? 0.12 : 0.04) * 255).round()),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? Colors.blue.shade900.withValues(alpha: 38) : Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.shield_outlined, color: Colors.blue.shade600, size: 18),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                '您的健康档案和紧急联系人信息已加密同步到云端，换设备登录后数据不会丢失。我们严格保护您的隐私安全。',
                style: TextStyle(fontSize: 12, color: Color(0xFF666666), height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getThemeName() {
    switch (themeNotifier.mode) {
      case ZaiNeThemeMode.dark: return '深色';
      case ZaiNeThemeMode.soft: return '柔光';
      default: return '浅色';
    }
  }
}
