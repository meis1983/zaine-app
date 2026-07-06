import 'package:flutter/material.dart';
import '../models/menstrual_record.dart';
import '../services/menstrual_service.dart';
import '../theme/theme_helper.dart';

/// 经期设置页面
class MenstrualSettingsPage extends StatefulWidget {
  const MenstrualSettingsPage({super.key});

  @override
  State<MenstrualSettingsPage> createState() => _MenstrualSettingsPageState();
}

class _MenstrualSettingsPageState extends State<MenstrualSettingsPage> {
  MenstrualSettings _settings = MenstrualSettings();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  /// 加载设置
  Future<void> _loadSettings() async {
    final settings = await MenstrualService.getSettings();
    setState(() {
      _settings = settings;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('经期设置'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ZaiNeSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 月经周期长度
            _buildSectionTitle('月经周期长度'),
            const SizedBox(height: ZaiNeSpacing.sm),
            _buildCycleLengthSelector(),
            const SizedBox(height: ZaiNeSpacing.lg),

            // 经期长度
            _buildSectionTitle('经期长度'),
            const SizedBox(height: ZaiNeSpacing.sm),
            _buildPeriodLengthSelector(),
            const SizedBox(height: ZaiNeSpacing.lg),

            // 提醒设置
            _buildSectionTitle('提醒设置'),
            const SizedBox(height: ZaiNeSpacing.sm),
            _buildReminderSettings(),
            const SizedBox(height: ZaiNeSpacing.xl),

            // 保存按钮
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pink,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ZaiNeRadius.small),
                  ),
                ),
                child: const Text('保存设置'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// section 标题
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  /// 月经周期长度选择器
  Widget _buildCycleLengthSelector() {
    return Container(
      padding: const EdgeInsets.all(ZaiNeSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: ZaiNeColors.borderColor()),
        borderRadius: BorderRadius.circular(ZaiNeRadius.small),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_settings.cycleLength} 天',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: ZaiNeSpacing.sm),
          Slider(
            value: _settings.cycleLength.toDouble(),
            min: 21,
            max: 35,
            divisions: 14,
            label: '${_settings.cycleLength} 天',
            activeColor: Colors.pink,
            onChanged: (value) {
              setState(() {
                _settings.cycleLength = value.toInt();
              });
            },
          ),
          const Text(
            '平均月经周期长度（从本次经期第一天到下次经期第一天）',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  /// 经期长度选择器
  Widget _buildPeriodLengthSelector() {
    return Container(
      padding: const EdgeInsets.all(ZaiNeSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: ZaiNeColors.borderColor()),
        borderRadius: BorderRadius.circular(ZaiNeRadius.small),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_settings.periodLength} 天',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: ZaiNeSpacing.sm),
          Slider(
            value: _settings.periodLength.toDouble(),
            min: 3,
            max: 7,
            divisions: 4,
            label: '${_settings.periodLength} 天',
            activeColor: Colors.pink,
            onChanged: (value) {
              setState(() {
                _settings.periodLength = value.toInt();
              });
            },
          ),
          const Text(
            '平均经期长度',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  /// 提醒设置
  Widget _buildReminderSettings() {
    return Column(
      children: [
        // 开启提醒
        SwitchListTile(
          title: const Text('开启经期提醒'),
          subtitle: const Text('在经期来临前提醒你'),
          value: _settings.enableReminder,
          activeThumbColor: Colors.pink,
          onChanged: (value) {
            setState(() {
              _settings.enableReminder = value;
            });
          },
        ),

        if (_settings.enableReminder) ...[
          const SizedBox(height: ZaiNeSpacing.sm),
          Container(
            padding: const EdgeInsets.all(ZaiNeSpacing.md),
            decoration: BoxDecoration(
              border: Border.all(color: ZaiNeColors.borderColor()),
              borderRadius: BorderRadius.circular(ZaiNeRadius.small),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '提前 ${_settings.reminderDaysBefore} 天提醒',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: ZaiNeSpacing.sm),
                Slider(
                  value: _settings.reminderDaysBefore.toDouble(),
                  min: 1,
                  max: 7,
                  divisions: 6,
                  label: '${_settings.reminderDaysBefore} 天',
                  activeColor: Colors.pink,
                  onChanged: (value) {
                    setState(() {
                      _settings.reminderDaysBefore = value.toInt();
                    });
                  },
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: ZaiNeSpacing.sm),

        // 排卵期提醒
        SwitchListTile(
          title: const Text('开启排卵期提醒'),
          subtitle: const Text('在排卵期来临时提醒你'),
          value: _settings.enableOvulationReminder,
          activeThumbColor: Colors.pink,
          onChanged: (value) {
            setState(() {
              _settings.enableOvulationReminder = value;
            });
          },
        ),
      ],
    );
  }

  /// 保存设置
  Future<void> _saveSettings() async {
    final success = await MenstrualService.saveSettings(_settings);

    if (success) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('设置已保存')),
      );
      Navigator.pop(context);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存失败，请重试')),
      );
    }
  }
}
