/// 联系人 JSON 解析工具
/// 兼容旧格式: {name:"xx",phone:"yy",relation:"zz"},{...}
/// 统一 guardian_page 和 contacts_page 的重复解析逻辑
class ContactParser {
  /// 解析可能为非标准 JSON 格式的联系人字符串
  /// 旧格式: {name:"xx",phone:"yy",relation:"zz"},{...}
  /// 标准格式会由 jsonDecode 直接处理
  static List<Map<String, dynamic>> parse(String raw) {
    final result = <Map<String, dynamic>>[];
    try {
      final cleaned = raw.replaceAll('[', '').replaceAll(']', '');
      final items = cleaned.split('},{');
      for (int i = 0; i < items.length; i++) {
        var item = items[i].replaceAll('{', '').replaceAll('}', '');
        final map = <String, dynamic>{};
        for (final part in item.split(',')) {
          final kv = part.split(':');
          if (kv.length == 2) {
            map[kv[0].trim().replaceAll('"', '')] =
                kv[1].trim().replaceAll('"', '');
          }
        }
        if (map.isNotEmpty && (map['name'] ?? '').toString().isNotEmpty) {
          result.add(map);
        }
      }
    } catch (_) {}
    return result;
  }
}
