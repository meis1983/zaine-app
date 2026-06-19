// lib/widgets/connector_widget.dart
// 步骤之间的连接线组件（从 help_page.dart 提取）
// v1.17.4 P3-2 代码复杂度优化

import 'package:flutter/material.dart';

/// 步骤之间的连接线
class ConnectorWidget extends StatelessWidget {
  final bool isActive;

  const ConnectorWidget({
    super.key,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 21),
      child: Container(
        width: 2,
        height: 18,
        color: isActive ? Colors.green.shade400 : Colors.grey.shade300,
      ),
    );
  }
}
