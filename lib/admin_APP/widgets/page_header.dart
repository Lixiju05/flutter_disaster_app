import 'package:flutter/material.dart';

/// 管理端各頁共用的頁首：固定高度、白底、底線，標題字級一致
class PageHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  /// 標題右側的小標籤（例如「待處理 3 件」）
  final List<Widget> badges;

  /// 最右側的按鈕（例如重新整理）
  final List<Widget> actions;

  const PageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.badges = const [],
    this.actions = const [],
  });

  static const double height = 76;

  static const Color _textMain = Color(0xFF0F172A);
  static const Color _textSub  = Color(0xFF475569);
  static const Color _border   = Color(0xFFE5E7EB);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(children: [
        Flexible(
          flex: 0,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: _textMain, fontSize: 24, fontWeight: FontWeight.w800, height: 1.2)),
              const SizedBox(height: 2),
              Text(subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _textSub, fontSize: 12, letterSpacing: 1.3)),
            ],
          ),
        ),
        for (final b in badges) ...[const SizedBox(width: 12), b],
        // 剩下的空間全部放在中間，按鈕固定靠右
        const Spacer(),
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          actions[i],
        ],
      ]),
    );
  }
}

/// 頁首右側的方形圖示按鈕（各頁一致 36×36）
class PageHeaderButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  const PageHeaderButton({super.key, required this.icon, this.onPressed, this.tooltip});

  @override
  Widget build(BuildContext context) {
    final btn = InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onPressed,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Icon(icon, color: const Color(0xFF2563EB), size: 18),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}
