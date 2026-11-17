import 'package:flutter/material.dart';

/// 地圖放大／縮小切換鈕：同一顆按鈕依狀態切換圖示，仿 YouTube 全螢幕按鈕的用法
class MapToggleButton extends StatelessWidget {
  final bool fullscreen;
  final VoidCallback onTap;
  const MapToggleButton({super.key, required this.fullscreen, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: fullscreen ? '縮小畫面' : '放大檢視',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .94),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Icon(
            fullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
            size: 19, color: const Color(0xFF0F172A),
          ),
        ),
      ),
    );
  }
}
