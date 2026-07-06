import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/menstrual_record.dart';
import '../services/menstrual_service.dart';
import '../theme/theme_helper.dart';

/// 经期记录页面
class MenstrualPage extends StatefulWidget {
  const MenstrualPage({super.key});

  @override
  State<MenstrualPage> createState() => _MenstrualPageState();
}

class _MenstrualPageState extends State<MenstrualPage> {
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  int _flowLevel = 3;
  final List<String> _selectedSymptoms = [];
  final TextEditingController _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  /// 选择开始日期
  Future<void> _selectStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (date != null) {
      setState(() {
        _startDate = date;
        // 如果结束日期早于开始日期，清空结束日期
        if (_endDate != null && _endDate!.isBefore(_startDate)) {
          _endDate = null;
        }
      });
    }
  }

  /// 选择结束日期
  Future<void> _selectEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate.add(const Duration(days: 5)),
      firstDate: _startDate,
      lastDate: DateTime.now(),
    );

    if (date != null) {
      setState(() {
        _endDate = date;
      });
    }
  }

  /// 切换症状选择
  void _toggleSymptom(String symptom) {
    setState(() {
      if (_selectedSymptoms.contains(symptom)) {
        _selectedSymptoms.remove(symptom);
      } else {
        _selectedSymptoms.add(symptom);
      }
    });
  }

  /// 保存记录
  Future<void> _saveRecord() async {
    final record = MenstrualRecord(
      startDate: _startDate,
      endDate: _endDate,
      flowLevel: _flowLevel,
      symptoms: _selectedSymptoms,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
    );

    final success = await MenstrualService.saveRecord(record);

    if (success) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('记录已保存')),
      );
      Navigator.pop(context);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存失败，请重试')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('经期记录'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ZaiNeSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 开始日期
            _buildSectionTitle('开始日期'),
            const SizedBox(height: ZaiNeSpacing.sm),
            _buildDateSelector(
              date: _startDate,
              onTap: _selectStartDate,
              label: '选择开始日期',
            ),
            const SizedBox(height: ZaiNeSpacing.lg),

            // 结束日期
            _buildSectionTitle('结束日期（可选）'),
            const SizedBox(height: ZaiNeSpacing.sm),
            _buildDateSelector(
              date: _endDate,
              onTap: _selectEndDate,
              label: '选择结束日期',
              isOptional: true,
            ),
            const SizedBox(height: ZaiNeSpacing.lg),

            // 流量级别
            _buildSectionTitle('流量级别'),
            const SizedBox(height: ZaiNeSpacing.sm),
            _buildFlowLevelSelector(),
            const SizedBox(height: ZaiNeSpacing.lg),

            // 症状
            _buildSectionTitle('症状（可选）'),
            const SizedBox(height: ZaiNeSpacing.sm),
            _buildSymptomsSelector(),
            const SizedBox(height: ZaiNeSpacing.lg),

            // 备注
            _buildSectionTitle('备注（可选）'),
            const SizedBox(height: ZaiNeSpacing.sm),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: '记录你的感受...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(ZaiNeRadius.small),
                ),
              ),
            ),
            const SizedBox(height: ZaiNeSpacing.xl),

            // 保存按钮
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveRecord,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pink,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ZaiNeRadius.small),
                  ),
                ),
                child: const Text('保存记录'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  ///  section 标题
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  /// 日期选择器
  Widget _buildDateSelector({
    required DateTime? date,
    required VoidCallback onTap,
    required String label,
    bool isOptional = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(ZaiNeSpacing.md),
        decoration: BoxDecoration(
          border: Border.all(color: ZaiNeColors.borderColor()),
          borderRadius: BorderRadius.circular(ZaiNeRadius.small),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today,
              size: 20,
              color: Colors.pink.shade400,
            ),
            const SizedBox(width: ZaiNeSpacing.md),
            Text(
              date != null
                  ? DateFormat('yyyy年MM月dd日').format(date)
                  : label,
              style: TextStyle(
                fontSize: 16,
                color: date != null
                    ? ZaiNeColors.textPrimary()
                    : ZaiNeColors.textSecondary(),
              ),
            ),
            const Spacer(),
            if (isOptional && date != null)
              IconButton(
                onPressed: () {
                  setState(() {
                    _endDate = null;
                  });
                },
                icon: const Icon(Icons.clear),
                iconSize: 20,
              ),
          ],
        ),
      ),
    );
  }

  /// 流量级别选择器
  Widget _buildFlowLevelSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: List.generate(5, (index) {
        final level = index + 1;
        final isSelected = level == _flowLevel;

        return GestureDetector(
          onTap: () {
            setState(() {
              _flowLevel = level;
            });
          },
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: isSelected ? Colors.pink.shade100 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(ZaiNeRadius.small),
              border: isSelected
                  ? Border.all(color: Colors.pink.shade400, width: 2)
                  : null,
            ),
            child: Center(
              child: Text(
                MenstrualService.getFlowLevelText(level),
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected ? Colors.pink.shade700 : Colors.grey.shade600,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      }),
    );
  }

  /// 症状选择器
  Widget _buildSymptomsSelector() {
    final symptoms = MenstrualService.commonSymptoms;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: symptoms.map((symptom) {
        final isSelected = _selectedSymptoms.contains(symptom);

        return FilterChip(
          label: Text(symptom),
          selected: isSelected,
          onSelected: (_) => _toggleSymptom(symptom),
          selectedColor: Colors.pink.shade100,
          checkmarkColor: Colors.pink.shade700,
        );
      }).toList(),
    );
  }
}
