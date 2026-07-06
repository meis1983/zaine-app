import 'package:flutter/material.dart';
import '../theme/theme_helper.dart';

/// 实时定位卡片 Widget
/// 
/// 从 HelpPage 的 _buildLocationCard() 方法提取
/// 显示当前位置信息（地址 + 坐标）或加载状态
class LocationCardWidget extends StatelessWidget {
  final bool isLoading;
  final String? coordLat;
  final String? coordLng;
  final String? address;
  final VoidCallback onRefresh;

  const LocationCardWidget({
    super.key,
    required this.isLoading,
    this.coordLat,
    this.coordLng,
    this.address,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZaiNeSpacing.cardSm),
      decoration: BoxDecoration(
        color: ZaiNeColors.cardBg(),
        borderRadius: BorderRadius.circular(ZaiNeRadius.cardSm),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: ZaiNeColors.scaffoldBg() == const Color(0xFF121212) ? 0.15 : 0.06,
            ),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Colors.green.shade200.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: isLoading
          ? _buildLoadingState()
          : (coordLat != null && coordLng != null)
              ? _buildLocationContent(context)
              : _buildErrorState(),
    );
  }

  /// 加载状态
  Widget _buildLoadingState() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.green.shade600,
          ),
        ),
        const SizedBox(width: ZaiNeSpacing.md),
        Text(
          '正在获取位置...',
          style: TextStyle(fontSize: 13, color: Colors.grey[500]),
        ),
      ],
    );
  }

  /// 位置信息内容
  Widget _buildLocationContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题行
        Row(
          children: [
            Icon(Icons.gps_fixed, color: Colors.green.shade600, size: 18),
            const SizedBox(width: ZaiNeSpacing.sm),
            const Text(
              '当前位置',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: onRefresh,
              child: Icon(Icons.refresh, size: 16, color: Colors.grey[400]),
            ),
          ],
        ),
        const SizedBox(height: ZaiNeSpacing.md),

        // 详细地址（核心显示，大字突出）
        if (address != null && address!.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(ZaiNeSpacing.md),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(10),
            
              boxShadow: ZaiNeShadows.card,),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on, color: Colors.red.shade500, size: 20),
                const SizedBox(width: ZaiNeSpacing.sm),
                Expanded(
                  child: Text(
                    address!,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: ZaiNeColors.textPrimary(),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // 坐标信息
        const SizedBox(height: ZaiNeSpacing.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.md, vertical: ZaiNeSpacing.md),
          decoration: BoxDecoration(
            color: Colors.teal.shade50,
            borderRadius: BorderRadius.circular(10),
          
            boxShadow: ZaiNeShadows.card,),
          child: Row(
            children: [
              Icon(Icons.my_location, size: 16, color: Colors.teal.shade700),
              const SizedBox(width: ZaiNeSpacing.sm),
              if (coordLat != null)
                Text(
                  coordLat!,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.teal[800],
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (coordLat != null && coordLng != null)
                const Text('  ', style: TextStyle(fontFamily: 'monospace')),
              if (coordLng != null)
                Text(
                  coordLng!,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.teal[800],
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// 错误状态（位置获取失败）
  Widget _buildErrorState() {
    return Row(
      children: [
        Icon(Icons.location_off, color: Colors.grey[400], size: 20),
        const SizedBox(width: ZaiNeSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '位置获取失败',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              const SizedBox(height: ZaiNeSpacing.xs),
              Text(
                '点击刷新重试',
                style: TextStyle(fontSize: 11, color: Colors.grey[400]),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.refresh, size: 18),
          onPressed: onRefresh,
          tooltip: '重试',
        ),
      ],
    );
  }
}
