/// 手机号归一化工具（前端）
/// ================================
/// 与后端 `zaine-backend/utils/phone.py` 的 `normalize_phone` **语义 1:1 对齐**。
///
/// 背景（2026-07-12 实测 bug / 2026-10-31 断点#1 增强）：
/// 手动添加紧急联系人时，从通讯录粘贴的手机号常带 +86 / 空格 / 横杠 / 括号，
/// 而注册端 User.phone 存的是纯数字。后端按精确字符串匹配反查
/// （GuardianCard.receiver_phone == User.phone），脏格式永远匹配不上
/// → 免费守护卡无法被认领 / 显示「未注册」。
///
/// 海外用户（美/英/港澳台等）号码格式更杂：
///   +1 415-555-0123 / 001 415 555 0123 / 1 (415) 555-0123 ...
///
/// 归一化规则（与后端完全一致）：
///   1. 去除所有非数字字符
///   2. 剥离国际呼叫前缀「00」（ITU-T 国际直拨前缀，等价于 +），仅当剥离后仍 ≥ 7 位
///   3. 剥离多余的中国大陆「86」前缀（仅当 13 位且以 86 开头）
///   4. 非中国号不擅自增删国家码（业务约定：海外号必须带国家码）
///
/// ⚠️ 约定：存储和查询时都必须调用本函数，海外号一律用
///   「国家码 + 号码」纯数字形式（如 14155550123）。
library;

class PhoneUtil {
  PhoneUtil._();

  static final RegExp _nonDigits = RegExp(r'[^\d]');

  /// 归一化手机号：统一为「国家码 + 号码」纯数字形式。
  ///
  /// 中国大陆示例（行为与旧版完全一致）：
  ///   '13900007777'        -> '13900007777'
  ///   '+8613900007777'     -> '13900007777'
  ///   '139-0000-7777'      -> '13900007777'
  ///   '(86) 139 0000 7777' -> '13900007777'
  ///
  /// 海外示例：
  ///   '+1 415-555-0123'    -> '14155550123'
  ///   '001 44 7911 123456' -> '447911123456'  （剥离 00 国际前缀）
  ///   '+852 9123 4567'     -> '85291234567'
  ///
  /// 空值：null / '' / 'abc' -> ''
  static String normalize(String? phone) {
    if (phone == null || phone.isEmpty) return '';
    var digits = phone.replaceAll(_nonDigits, '');
    if (digits.isEmpty) return '';

    // 1) 剥离国际呼叫前缀「00」——仅在 00 开头且长度足够时，
    //    避免误伤本地号（如意大利以 0 开头的号码）。
    //    剥离后直接返回，防止 13 位结果被误判为「86 前缀」。
    if (digits.startsWith('00') && digits.length >= 9) {
      return digits.substring(2);
    }

    // 2) 剥离多余的中国大陆「86」国际前缀（仅当 13 位且以 86 开头）。
    if (digits.length == 13 && digits.startsWith('86')) {
      digits = digits.substring(2);
    }

    return digits;
  }

  /// 手机号格式校验（与后端 `SmsService._validate_phone` 对齐）：
  /// 归一化后为 7-15 位纯数字即合法（覆盖 ITU-T E.164 国际号码）。
  static bool isValid(String? phone) {
    final cleaned = normalize(phone);
    return cleaned.length >= 7 && cleaned.length <= 15;
  }
}
