import 'package:flutter/material.dart';

/// 跟用戶管理頁一致的姓名頭像：圓形、依序輪流上色，顏色不會因為姓氏撞色而集中
class UserAvatar extends StatelessWidget {
  final String name;
  final int index;
  final double size;

  const UserAvatar({super.key, required this.name, required this.index, this.size = 36});

  static const _colors = [
    Color(0xFFDC2626), Color(0xFFD97706), Color(0xFF16A34A),
    Color(0xFF2563EB), Color(0xFF7C3AED), Color(0xFFDB2777),
  ];

  /// 同一顆索引在別處（例如姓名文字）要用一樣的顏色時呼叫這個
  static Color colorFor(int index) => _colors[index % _colors.length];

  @override
  Widget build(BuildContext context) {
    final color = name.isEmpty ? const Color(0xFF64748B) : colorFor(index);
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(color: color.withValues(alpha: .20), shape: BoxShape.circle),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0] : '?',
          style: TextStyle(color: color, fontSize: size * 0.44, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
