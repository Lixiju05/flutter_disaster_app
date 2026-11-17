import 'package:flutter/material.dart';

/// 連不上後端時顯示的小標籤，提示目前畫面是離線示範資料
class OfflineDemoBadge extends StatelessWidget {
  const OfflineDemoBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off_rounded, size: 13, color: Color(0xFFB45309)),
          SizedBox(width: 5),
          Text('離線示範資料',
              style: TextStyle(color: Color(0xFFB45309), fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
