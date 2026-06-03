// lib/widgets/widget_health_tip.dart
// 健康小贴士组件（从 home_page.dart 拆出）

import 'package:flutter/material.dart';
import '../theme/theme_helper.dart';

/// 健康小贴士卡片
/// 每天固定显示一条（基于日期索引），点击可刷新
class HealthTipWidget extends StatelessWidget {
  const HealthTipWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final tips = [
      {'icon': Icons.water_drop, 'color': Colors.blue, 'title': '记得多喝水', 'desc': '独居容易忘记喝水，建议每小时起身喝一杯温水'},
      {'icon': Icons.directions_walk, 'color': Colors.green, 'title': '久坐提醒', 'desc': '每45分钟起来走动5分钟，保护颈椎和腰椎'},
      {'icon': Icons.bedtime, 'color': Colors.indigo, 'title': '规律作息', 'desc': '尽量在23:30前入睡，保证7-8小时睡眠'},
      {'icon': Icons.favorite, 'color': Colors.red, 'title': '关注心脏', 'desc': '感到心慌胸闷时不要硬撑，及时拨打120'},
      {'icon': Icons.restaurant, 'color': Colors.orange, 'title': '好好吃饭', 'desc': '外卖虽方便，但也要记得补充蔬菜和蛋白质'},
      {'icon': Icons.phone_android, 'color': Colors.purple, 'title': '数字 detox', 'desc': '睡前1小时放下手机，让大脑和眼睛休息一下'},
      {'icon': Icons.window, 'color': Colors.teal, 'title': '开窗通风', 'desc': '早晚各通风15分钟，保持室内空气新鲜'},
      {'icon': Icons.people, 'color': Colors.deepOrange, 'title': '保持联络', 'desc': '每周至少和家人或朋友通话1次，别把自己封闭起来'},
      {'icon': Icons.medication, 'color': Colors.amber, 'title': '按时服药', 'desc': '如果正在服药，设置闹钟提醒自己，不要漏服'},
      {'icon': Icons.emoji_emotions, 'color': Colors.pink, 'title': '心情记录', 'desc': '情绪低落时试着写下来，倾诉是治愈的第一步'},
      {'icon': Icons.safety_check, 'color': Colors.cyan, 'title': '检查门窗', 'desc': '睡前确认门窗已锁好，安全意识不能松懈'},
      {'icon': Icons.flash_on, 'color': Colors.amber.shade700, 'title': '充电备用', 'desc': '保持手机电量充足，紧急时刻它就是你的生命线'},
      {'icon': Icons.local_hospital, 'color': Colors.redAccent, 'title': '急救知识', 'desc': '花10分钟学习心肺复苏（CPR），关键时刻能救命'},
      {'icon': Icons.thermostat, 'color': Colors.lightBlue, 'title': '温度调节', 'desc': '室内温度保持在22-26℃，过冷过热都影响身体状态'},
    ];

    final now = DateTime.now();
    final dayIndex = now.difference(DateTime(2026, 1, 1)).inDays % tips.length;
    final tip = tips[dayIndex];

    return GestureDetector(
      onTap: () {}, // 点击反馈由父组件处理
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              (tip['color'] as Color).withOpacity(0.08),
              (tip['color'] as Color).withOpacity(0.04),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: (tip['color'] as Color).withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: (tip['color'] as Color).withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(tip['icon'] as IconData,
                  size: 20, color: tip['color'] as Color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tip['title'] as String,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: ZaiNeColors.textPrimary(),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    tip['desc'] as String,
                    style: TextStyle(fontSize: 12, color: ZaiNeColors.textSecondary()),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.refresh, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}
