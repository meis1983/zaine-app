// safety_settings_navigator_stub.dart
// CN 合规版（165 起）：编译期选入此 stub。
//
// 关键约束：
// 1. **绝不能 import 'safety_settings_page.dart'**——一旦 import，Dart AOT 会把
//    `SafetySettingsPage` 类符号拉进编译单元 → 二进制残留 → 苹果类级判定扫到。
// 2. **绝不引用 SafetySettingsPage / MaterialPageRoute(builder: ... SafetySettingsPage)**
//    任何标识符——同上。
// 3. 函数体保持空 / 返 SizedBox.shrink——CN UI 既不渲染入口也不响应点击。

import 'package:flutter/material.dart';

/// CN 合规版：安全中心入口完全不渲染。
Widget buildSafetyCenterEntry(bool isDark) => const SizedBox.shrink();

/// CN 合规版：用户点击"安全中心"无响应（入口已隐藏，理论上不会触发；此处为空）。
void openSafetySettings(BuildContext context) {
  // CN 合规版保留空函数签名即可，无需任何跳转/弹窗/外发。
}
