import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

class FullMapPage extends StatelessWidget {
  final double lat;
  final double lng;
  final String title;
  final String subtitle;

  const FullMapPage({
    super.key,
    required this.lat,
    required this.lng,
    this.title = '地圖位置',
    this.subtitle = '目標位置',
  });

  Future<void> _openGoogleNavigation() async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
    );

    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final point = LatLng(lat, lng);

    return Scaffold(
      backgroundColor: const Color(0xFF020C18),
      appBar: AppBar(
        backgroundColor: const Color(0xFF071828),
        foregroundColor: Colors.white,
        title: Text(title),
        actions: [
          TextButton.icon(
            onPressed: _openGoogleNavigation,
            icon: const Icon(Icons.navigation, color: Color(0xFF00C8FF)),
            label: const Text(
              '開始導航',
              style: TextStyle(color: Color(0xFF00C8FF)),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: point,
              initialZoom: 16,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.flutter_disaster_app',
              ),
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: point,
                    radius: 300,
                    useRadiusInMeter: true,
                    color: Colors.red.withOpacity(.15),
                    borderColor: Colors.redAccent,
                    borderStrokeWidth: 2,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: point,
                    width: 70,
                    height: 70,
                    child: const Icon(
                      Icons.location_on,
                      size: 56,
                      color: Colors.redAccent,
                    ),
                  ),
                ],
              ),
            ],
          ),

          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF071828).withOpacity(.95),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF00C8FF).withOpacity(.35)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.redAccent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '$subtitle｜${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
                          style: const TextStyle(
                            color: Color(0xFF7E91A6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _openGoogleNavigation,
                    icon: const Icon(Icons.navigation),
                    label: const Text('導航'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00C8FF),
                      foregroundColor: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}