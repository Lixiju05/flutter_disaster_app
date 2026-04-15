import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class FullMapPage extends StatelessWidget {
  final double lat;
  final double lng;

  const FullMapPage({
    super.key,
    required this.lat,
    required this.lng,
  });

  @override
  Widget build(BuildContext context) {
    final point = LatLng(lat, lng);

    return Scaffold(
      appBar: AppBar(
        title: const Text('地圖位置'),
        backgroundColor: const Color(0xFF1E3A5F),
      ),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: point,
          initialZoom: 16,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.flutter_disaster_app',
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: point,
                width: 60,
                height: 60,
                child: const Icon(
                  Icons.location_on,
                  size: 50,
                  color: Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}