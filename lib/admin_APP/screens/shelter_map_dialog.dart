import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'dashboard_page.dart' show kBg, kCardBg, kCyan, kGreen, kMuted, kBorder;

// ══════════════════════════════════════════════════════════
//  SHELTER DATA MODEL
// ══════════════════════════════════════════════════════════

class ShelterData {
  final String name;
  final String address;
  final int capacity;
  final String floors;
  final double lat;
  final double lng;

  const ShelterData({
    required this.name,
    required this.address,
    required this.capacity,
    required this.floors,
    required this.lat,
    required this.lng,
  });
}

const List<ShelterData> kShelters = [
  ShelterData(
    name: '埔里鎮公所地下停車場',
    address: '南投縣埔里鎮中山路一段1號',
    capacity: 500,
    floors: 'B1-B2',
    lat: 23.9609,
    lng: 120.9683,
  ),
  ShelterData(
    name: '埔里國中防空避難室',
    address: '南投縣埔里鎮西安路一段156號',
    capacity: 300,
    floors: 'B1',
    lat: 23.9648,
    lng: 120.9721,
  ),
  ShelterData(
    name: '宏仁國中地下避難所',
    address: '南投縣埔里鎮中山路四段1號',
    capacity: 250,
    floors: 'B1',
    lat: 23.9572,
    lng: 120.9654,
  ),
  ShelterData(
    name: '埔里基督教醫院地下室',
    address: '南投縣埔里鎮鎮山路1號',
    capacity: 400,
    floors: 'B1-B2',
    lat: 23.9631,
    lng: 120.9598,
  ),
  ShelterData(
    name: '愛蘭國小禮堂地下層',
    address: '南投縣埔里鎮愛蘭里',
    capacity: 350,
    floors: 'B1',
    lat: 23.9558,
    lng: 120.9741,
  ),
];

// ══════════════════════════════════════════════════════════
//  SHELTER MAP DIALOG
// ══════════════════════════════════════════════════════════

class ShelterMapDialog extends StatefulWidget {
  const ShelterMapDialog({super.key});

  @override
  State<ShelterMapDialog> createState() => _ShelterMapDialogState();
}

class _ShelterMapDialogState extends State<ShelterMapDialog> {
  int _selectedIndex = 0;
  final MapController _mapController = MapController();

  int get _totalCapacity =>
      kShelters.fold(0, (sum, s) => sum + s.capacity);

  void _selectShelter(int index) {
    setState(() => _selectedIndex = index);
    _mapController.move(
      LatLng(kShelters[index].lat, kShelters[index].lng),
      15.5,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      child: Container(
        width: 1000,
        height: 620,
        decoration: BoxDecoration(
          color: const Color(0xFF060E18),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF112233)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.6),
              blurRadius: 40,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(children: [
          _buildHeader(),
          Expanded(
            child: Row(children: [
              // ── 左側清單 ──
              Container(
                width: 360,
                decoration: const BoxDecoration(
                  border: Border(
                    right: BorderSide(color: Color(0xFF112233)),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Text('設施清單',
                          style: TextStyle(
                              color: kMuted, fontSize: 11, letterSpacing: 1.2)),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: kShelters.length,
                        itemBuilder: (_, i) => _buildListItem(i),
                      ),
                    ),
                  ],
                ),
              ),
              // ── 右側地圖 ──
              Expanded(child: _buildMap()),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF112233))),
      ),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber.withOpacity(.3)),
          ),
          child:
              const Icon(Icons.apartment, color: Colors.amber, size: 19),
        ),
        const SizedBox(width: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('防空避難設施地圖',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          Text('埔里鎮轄區內共 ${kShelters.length} 處避難設施',
              style: TextStyle(color: kMuted, fontSize: 11)),
        ]),
        const Spacer(),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close, color: Colors.white54, size: 20),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ]),
    );
  }

  Widget _buildListItem(int index) {
    final s = kShelters[index];
    final selected = _selectedIndex == index;
    return InkWell(
      onTap: () => _selectShelter(index),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: selected
              ? Colors.amber.withOpacity(.07)
              : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: selected ? Colors.amber : Colors.transparent,
              width: 3,
            ),
            bottom: const BorderSide(color: Color(0xFF0A1A28)),
          ),
        ),
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: selected
                  ? Colors.amber.withOpacity(.18)
                  : const Color(0xFF0A1824),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(Icons.apartment,
                color: selected ? Colors.amber : kMuted, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.name,
                    style: TextStyle(
                        color: selected ? Colors.white : const Color(0xFFB0C8DC),
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
                const SizedBox(height: 3),
                Text(s.address,
                    style: const TextStyle(color: kMuted, fontSize: 10)),
                const SizedBox(height: 6),
                Row(children: [
                  _tag('可容納 ${s.capacity} 人', kGreen),
                  const SizedBox(width: 6),
                  _tag(s.floors, kCyan),
                ]),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: kMuted, size: 16),
        ]),
      ),
    );
  }

  Widget _tag(String text, Color color) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(.12),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: color.withOpacity(.3)),
        ),
        child: Text(text,
            style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.bold)),
      );

  Widget _buildMap() {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topRight: Radius.circular(12),
        bottomRight: Radius.circular(12),
      ),
      child: Stack(children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: LatLng(23.9609, 120.9683),
            initialZoom: 14.5,
            backgroundColor: const Color(0xFF060E18),
          ),
          children: [
            // OpenStreetMap dark tile (CartoDB Dark Matter)
            TileLayer(
              urlTemplate:
                  'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
              subdomains: const ['a', 'b', 'c', 'd'],
              userAgentPackageName: 'com.example.disaster_app',
            ),
            // Shelter markers
            MarkerLayer(
              markers: kShelters.asMap().entries.map((entry) {
                final i = entry.key;
                final s = entry.value;
                final selected = _selectedIndex == i;
                return Marker(
                  point: LatLng(s.lat, s.lng),
                  width: selected ? 52 : 44,
                  height: selected ? 52 : 44,
                  child: GestureDetector(
                    onTap: () => _selectShelter(i),
                    child: Container(
                      decoration: BoxDecoration(
                        color: selected
                            ? Colors.amber
                            : Colors.amber.withOpacity(.75),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(.3),
                          width: selected ? 2.5 : 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.amber.withOpacity(
                                selected ? .6 : .3),
                            blurRadius: selected ? 16 : 8,
                            spreadRadius: selected ? 3 : 1,
                          ),
                        ],
                      ),
                      child: Icon(Icons.apartment,
                          color: Colors.white,
                          size: selected ? 26 : 20),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        // 圖例
        Positioned(
          bottom: 12,
          left: 12,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xCC060E18),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF112233)),
            ),
            child: Row(children: [
              Container(
                width: 14,
                height: 14,
                decoration: const BoxDecoration(
                  color: Colors.amber,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
              const Text('防空避難設施',
                  style: TextStyle(color: Colors.white70, fontSize: 11)),
            ]),
          ),
        ),
        // 總容量
        Positioned(
          bottom: 12,
          right: 12,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xCC060E18),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.amber.withOpacity(.3)),
            ),
            child: Text('總容量：${_totalCapacity.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',')} 人',
                style: const TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
          ),
        ),
        // 選中設施資訊卡
        if (_selectedIndex >= 0)
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              width: 200,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xEE060E18),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withOpacity(.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(kShelters[_selectedIndex].name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(kShelters[_selectedIndex].address,
                      style: const TextStyle(
                          color: kMuted, fontSize: 10)),
                  const SizedBox(height: 8),
                  Row(children: [
                    _tag('容 ${kShelters[_selectedIndex].capacity} 人',
                        kGreen),
                    const SizedBox(width: 6),
                    _tag(kShelters[_selectedIndex].floors, kCyan),
                  ]),
                ],
              ),
            ),
          ),
      ]),
    );
  }
}