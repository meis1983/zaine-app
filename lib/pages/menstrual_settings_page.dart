import 'package:flutter/material.dart';
import '../models/menstrual_record.dart';
import '../services/menstrual_service.dart';
import '../theme/theme_helper.dart';
import '../l10n/i18n.dart';

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
        title:  Text(tr.s580),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ZaiNeSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 月经周期长度
            _buildSectionTitle(tr.s581),
            const SizedBox(height: ZaiNeSpacing.sm),
            _buildCycleLengthSelector(),
            const SizedBox(height: ZaiNeSpacing.lg),

            // 经期长度
            _buildSectionTitle(tr.s582),
            const SizedBox(height: ZaiNeSpacing.sm),
            _buildPeriodLengthSelector(),
            const SizedBox(height: ZaiNeSpacing.lg),

            // 提醒设置
            _buildSectionTitle(tr.s583),
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
                child:  Text(tr.s584),
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
            tr.s585(_settings.cycleLength),
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
            label: tr.s585(_settings.cycleLength),
            activeColor: Colors.pink,
            onChanged: (value) {
              setState(() {
                _settings.cycleLength = value.toInt();
              });
            },
          ),
           Text(
            tr.s586,
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
            tr.s587(_settings.periodLength),
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
            label: tr.s587(_settings.periodLength),
            activeColor: Colors.pink,
            onChanged: (value) {
              setState(() {
                _settings.periodLength = value.toInt();
              });
            },
          ),
           Text(
            tr.s588,
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
          title:  Text(tr.s589),
          subtitle:  Text(tr.s590),
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
                  tr.s591(_settings.reminderDaysBefore),
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
                  label: tr.s592(_settings.reminderDaysBefore),
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
          title:  Text(tr.s593),
          subtitle:  Text(tr.s594),
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
         SnackBar(content: Text(tr.s595)),
      );
      Navigator.pop(context);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text(tr.s596)),
      );
    }
  }
}
