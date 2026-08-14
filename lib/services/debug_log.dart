// 双通道调试日志（v1.97.3+190 引入）
//
// 背景：此前在真机诊断「签到入口是否触发」时，依赖 macOS Console.app 的
// 进程过滤 / NSPredicate 语法，极易因「进程名不匹配 / 未点开始流式传输」
// 等原因看到 0 条日志，误导排查方向。
//
// 本工具提供两条不依赖 Console 的兜底通道：
//  ① developer.log（仍走 os_log，可选）
//  ② 追加写入 <应用文档目录>/zaine_debug.log
//     —— 事后从 Xcode → Window → Devices and Simulators → 选中设备 →
//        齿轮菜单 → Download Container → 解压 .xcappdata →
//        AppData/Documents/zaine_debug.log 取回，绝不会丢。
//
// 指定 [prefix]（如 '190 SIGN' / '190 TAP' / '190 CATCH'），日志自动带前缀，
// 便于在文件中 grep。文件通道失败绝不影响业务。

import 'dart:developer' as developer;
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class DebugLog {
  static File? _file;
  static bool _ready = false;

  static Future<void> _init() async {
    if (_ready) return;
    _ready = true;
    try {
      final dir = await getApplicationDocumentsDirectory();
      _file = File('${dir.path}/zaine_debug.log');
    } catch (_) {
      // 文档目录取不到时不阻塞业务
      _file = null;
    }
  }

  /// 写一条带 ISO 时间戳 + 前缀的日志到双通道。
  /// [prefix] 形如 '190 SIGN' / '190 TAP' / '190 CATCH'。
  static Future<void> write(String prefix, String msg) async {
    final ts = DateTime.now().toIso8601String();
    final line = '[$ts] [$prefix] $msg\n';
    // 通道 1：os_log（可选，Console 仍可见）
    developer.log('[$prefix] $msg', name: 'zaine.debug');
    // 通道 2：文件（兜底，事后可下载）
    try {
      await _init();
      await _file?.writeAsString(line, mode: FileMode.append, flush: true);
    } catch (_) {
      // 忽略文件写入错误，不影响业务
    }
  }
}
