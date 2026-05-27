import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'dashboard_page.dart'
    show kGreen, kMuted, kBorder, kBlue, kOrange, kTextMain, kTextSub;
import 'area_data.dart';
import 'gov_shelter_service.dart';

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

class ShelterMapDialog extends StatefulWidget {
  final String adminArea;

  const ShelterMapDialog({
    super.key,
    required this.adminArea,
  });

  @override
  State<ShelterMapDialog> createState() => _ShelterMapDialogState();
}

class _ShelterMapDialogState extends State<ShelterMapDialog> {
  int _selectedIndex = 0;
  final MapController _mapController = MapController();

  List<ShelterData> _shelters = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadShelters();
  }

  Future<void> _loadShelters() async {
    try {
      final data = await GovShelterService.fetchShelters(widget.adminArea);

      final shelters = data.map((e) {
        return ShelterData(
          name: e['建築物名稱']?.toString() ??
              e['名稱']?.toString() ??
              e['場所名稱']?.toString() ??
              e['name']?.toString() ??
              '未命名防空避難設施',
          address: e['地址']?.toString() ??
              e['地點']?.toString() ??
              e['address']?.toString() ??
              '地址未提供',
          capacity: int.tryParse(
                e['可容納人數']?.toString().replaceAll(',', '') ??
                    e['容量']?.toString().replaceAll(',', '') ??
                    e['容納人數']?.toString().replaceAll(',', '') ??
                    '0',
              ) ??
              0,
          floors: e['樓層']?.toString() ??
              e['避難樓層']?.toString() ??
              e['地下樓層數']?.toString() ??
              'B1',
          lat: double.tryParse(
                e['緯度']?.toString() ??
                    e['lat']?.toString() ??
                    e['latitude']?.toString() ??
                    '0',
              ) ??
              0,
          lng: double.tryParse(
                e['經度']?.toString() ??
                    e['lng']?.toString() ??
                    e['longitude']?.toString() ??
                    '0',
              ) ??
              0,
        );
      }).where((s) => s.lat != 0 && s.lng != 0).toList();

      if (!mounted) return;
      setState(() {
        _shelters = shelters;
        _loading = false;
        _selectedIndex = 0;
      });
    } catch (e) {
      debugPrint('LOAD GOV SHELTERS ERROR: $e');
      if (!mounted) return;
      setState(() {
        _shelters = [];
        _loading = false;
      });
    }
  }

  int get _totalCapacity {
    return _shelters.fold(0, (sum, s) => sum + s.capacity);
  }

  LatLng get _mapCenter {
    if (_shelters.isNotEmpty) {
      return LatLng(_shelters.first.lat, _shelters.first.lng);
    }
    return const LatLng(23.9609, 120.9683);
  }

  String get _areaShortName {
    final data = AreaDataHelper.findByName(widget.adminArea);
    return data.name;
  }

  String _formatNumber(int value) {
    return value.toString().replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (m) => ',',
        );
  }

  void _selectShelter(int index) {
    setState(() => _selectedIndex = index);
    _mapController.move(
      LatLng(_shelters[index].lat, _shelters[index].lng),
      15.5,
    );
  }

  Future<void> _openNavigation(ShelterData shelter) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=${shelter.lat},${shelter.lng}'
      '&travelmode=driving',
    );

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) debugPrint('無法開啟 Google Maps 導航');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Dialog(
        child: SizedBox(
          width: 320,
          height: 180,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_shelters.isEmpty) {
      return Dialog(
        child: SizedBox(
          width: 420,
          height: 190,
          child: Center(
            child: Text(
              '${widget.adminArea} 目前沒有取得防空避難設施資料',
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ),
      );
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      child: Container(
        width: 1000,
        height: 620,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.6),
              blurRadius: 40,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 360,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      border: Border(right: BorderSide(color: kBorder)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          child: Text(
                            '設施清單（${_shelters.length} 處）',
                            style: const TextStyle(
                              color: kMuted,
                              fontSize: 11,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: _shelters.length,
                            itemBuilder: (_, i) => _buildListItem(i),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: _buildMap()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: kBorder)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: kOrange.withOpacity(.10),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kOrange.withOpacity(.24)),
            ),
            child: const Icon(Icons.apartment, color: kOrange, size: 19),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '防空避難設施地圖',
                style: TextStyle(
                  color: kTextMain,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '$_areaShortName 轄區內共 ${_shelters.length} 處避難設施　總容量 ${_formatNumber(_totalCapacity)} 人',
                style: const TextStyle(color: kMuted, fontSize: 11),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: kTextSub, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildListItem(int index) {
    final s = _shelters[index];
    final selected = _selectedIndex == index;

    return InkWell(
      onTap: () => _selectShelter(index),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: selected ? kOrange.withOpacity(.08) : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: selected ? kOrange : Colors.transparent,
              width: 3,
            ),
            bottom: const BorderSide(color: kBorder),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color:
                    selected ? kOrange.withOpacity(.12) : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.apartment,
                color: selected ? kOrange : kTextSub,
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.name,
                    style: const TextStyle(
                      color: kTextMain,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    s.address,
                    style: const TextStyle(color: kMuted, fontSize: 10),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _tag('可容納 ${s.capacity} 人', kGreen),
                      const SizedBox(width: 6),
                      _tag(s.floors, kBlue),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: selected ? kOrange : kTextSub,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color.withOpacity(.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildMap() {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topRight: Radius.circular(12),
        bottomRight: Radius.circular(12),
      ),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _mapCenter,
              initialZoom: 14.5,
              backgroundColor: const Color(0xFFF8FAFC),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.example.disaster_app',
              ),
              MarkerLayer(
                markers: _shelters.asMap().entries.map((entry) {
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
                          color:
                              selected ? kOrange : kOrange.withOpacity(.82),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(.3),
                            width: selected ? 2.5 : 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: kOrange.withOpacity(
                                selected ? .32 : .20,
                              ),
                              blurRadius: selected ? 16 : 8,
                              spreadRadius: selected ? 3 : 1,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.apartment,
                          color: Colors.white,
                          size: selected ? 26 : 20,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          Positioned(
            bottom: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.94),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: kBorder),
              ),
              child: Row(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: const BoxDecoration(
                      color: kOrange,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 7),
                  const Text(
                    '防空避難設施',
                    style: TextStyle(color: kTextSub, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.94),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: kOrange.withOpacity(.24)),
              ),
              child: Text(
                '總容量：${_formatNumber(_totalCapacity)} 人',
                style: const TextStyle(
                  color: kOrange,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: _selectedInfoCard(),
          ),
        ],
      ),
    );
  }

  Widget _selectedInfoCard() {
    final s = _shelters[_selectedIndex];

    return Container(
      width: 230,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.96),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kOrange.withOpacity(.24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.name,
            style: const TextStyle(
              color: kTextMain,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            s.address,
            style: const TextStyle(color: kMuted, fontSize: 10),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _tag('容 ${s.capacity} 人', kGreen),
              const SizedBox(width: 6),
              _tag(s.floors, kBlue),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 36,
            child: ElevatedButton.icon(
              onPressed: () => _openNavigation(s),
              icon: const Icon(Icons.navigation_rounded, size: 15),
              label: const Text(
                '導航前往',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: kOrange.withOpacity(.10),
                foregroundColor: kOrange,
                elevation: 0,
                side: BorderSide(color: kOrange.withOpacity(.24)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}