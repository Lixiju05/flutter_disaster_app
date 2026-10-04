import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// ══════════════════════════════════════════════════════════
// DATA MODELS
// ══════════════════════════════════════════════════════════

enum DisasterType {
  earthquake,
  typhoon,
  rain,
  flood,
  wind,
  wave,
  other,
}

class DisasterAlert {
  final String id;
  final DisasterType type;
  final String title;
  final String description;
  final String location;
  final DateTime time;
  final String severity;
  final Map<String, dynamic> raw;

  const DisasterAlert({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.location,
    required this.time,
    required this.severity,
    required this.raw,
  });
}

// ══════════════════════════════════════════════════════════
// WEATHER SERVICE
// ══════════════════════════════════════════════════════════

class WeatherService {
  static const String _cwaBase =
      'https://opendata.cwa.gov.tw/api/v1/rest/datastore';

  static String _auth(String apiKey) {
    return apiKey.isNotEmpty ? '&Authorization=$apiKey' : '';
  }

  static Future<List<DisasterAlert>> fetchAllAlerts({
    String apiKey = '',
  }) async {
    try {
      final results = await Future.wait([
        fetchEarthquakes(apiKey: apiKey),
        fetchHeavyRain(apiKey: apiKey),
        fetchTyphoons(apiKey: apiKey),
      ]);

      final all = results.expand((e) => e).toList();
      all.sort((a, b) => b.time.compareTo(a.time));

      return all;
    } catch (e) {
      debugPrint('[WeatherService] fetchAllAlerts error: $e');
      return [];
    }
  }

  static Future<List<DisasterAlert>> fetchEarthquakes({
    String apiKey = '',
  }) async {
    try {
      final url = '$_cwaBase/E-A0015-001?format=JSON&limit=5${_auth(apiKey)}';

      final res = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 12));

      if (res.statusCode != 200) return [];

      final data = jsonDecode(res.body);
      final records = data['records']?['Earthquake'] as List<dynamic>? ?? [];

      return records.map<DisasterAlert>((e) {
        final info = e['EarthquakeInfo'] ?? {};
        final epicenter = info['Epicenter'] ?? {};
        final mag = info['EarthquakeMagnitude']?['MagnitudeValue'];
        final depth = info['FocalDepth'];
        final loc = epicenter['Location']?.toString() ?? '未知地點';

        DateTime time;
        try {
          time = DateTime.parse(info['OriginTime']?.toString() ?? '');
        } catch (_) {
          time = DateTime.now();
        }

        final magVal = _toDouble(mag);

        String severity = '輕度';
        if (magVal >= 6.0) {
          severity = '重度';
        } else if (magVal >= 5.0) {
          severity = '中度';
        }

        return DisasterAlert(
          id: e['EarthquakeNo']?.toString() ??
              'EQ_${time.millisecondsSinceEpoch}',
          type: DisasterType.earthquake,
          title: '地震速報 M${magVal.toStringAsFixed(1)}',
          description: '震源深度 ${depth ?? '--'} km，$loc',
          location: loc,
          time: time,
          severity: severity,
          raw: Map<String, dynamic>.from(e),
        );
      }).toList();
    } catch (e) {
      debugPrint('[WeatherService] 地震 error: $e');
      return [];
    }
  }

  static Future<List<DisasterAlert>> fetchHeavyRain({
    String apiKey = '',
  }) async {
    try {
      final url = '$_cwaBase/W-C0033-001?format=JSON${_auth(apiKey)}';

      final res = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 12));

      if (res.statusCode != 200) return [];

      final data = jsonDecode(res.body);
      final records = data['records'];

      final List<dynamic> locations =
          records?['location'] ??
          records?['Location'] ??
          [];

      final List<DisasterAlert> alerts = [];

      for (final loc in locations) {
        final locationName =
            loc['locationName']?.toString() ??
            loc['LocationName']?.toString() ??
            '未知地區';

        final hazardsRaw =
            loc['hazardConditions']?['hazards'] ??
            loc['hazardConditions']?['hazard'] ??
            loc['HazardConditions']?['Hazards'];

        final List<dynamic> hazards = [];

        if (hazardsRaw is List) {
          hazards.addAll(hazardsRaw);
        } else if (hazardsRaw is Map) {
          final h = hazardsRaw['hazard'];
          if (h is List) {
            hazards.addAll(h);
          } else if (h != null) {
            hazards.add(h);
          }
        }

        for (final h in hazards) {
          final info = h['info'] ?? h['hazard']?['info'] ?? {};
          final phenomena = info['phenomena']?.toString() ?? '';
          final significance = info['significance']?.toString() ?? '';

          if (phenomena.isEmpty && significance.isEmpty) continue;

          DateTime time;
          try {
            time = DateTime.parse(
              h['validTime']?['startTime']?.toString() ??
                  h['validTime']?['startCondition']?['startTime']?.toString() ??
                  '',
            );
          } catch (_) {
            time = DateTime.now();
          }

          final title = '$phenomena $significance'.trim();

          alerts.add(
            DisasterAlert(
              id: 'RAIN_${locationName}_${title}_${time.millisecondsSinceEpoch}',
              type: DisasterType.rain,
              title: title.isEmpty ? '豪大雨特報' : title,
              description: '$locationName 發布豪大雨相關特報',
              location: locationName,
              time: time,
              severity: _rainSeverity(title),
              raw: h is Map ? Map<String, dynamic>.from(h) : {},
            ),
          );
        }
      }

      return alerts;
    } catch (e) {
      debugPrint('[WeatherService] 豪雨 error: $e');
      return [];
    }
  }

  static Future<List<DisasterAlert>> fetchTyphoons({
    String apiKey = '',
  }) async {
    try {
      final url = '$_cwaBase/W-C0034-005?format=JSON${_auth(apiKey)}';

      final res = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 12));

      if (res.statusCode != 200) return [];

      final data = jsonDecode(res.body);

      final records =
          data['records']?['tropicalCyclones']?['tropicalCyclone']
              as List<dynamic>? ??
              [];

      return records.map<DisasterAlert>((t) {
        final name =
            t['cwaTyphoonName']?.toString() ??
            t['typhoonName']?.toString() ??
            '颱風';

        final fixes = t['fix'] as List<dynamic>? ?? [];
        final latest = fixes.isNotEmpty ? fixes.last : {};

        DateTime time;
        try {
          time = DateTime.parse(latest['fixTime']?.toString() ?? '');
        } catch (_) {
          time = DateTime.now();
        }

        return DisasterAlert(
          id: t['typhoonNo']?.toString() ?? 'TY_${time.millisecondsSinceEpoch}',
          type: DisasterType.typhoon,
          title: '$name 颱風警報',
          description: '颱風資料更新，請注意風雨與海面狀況。',
          location: '台灣附近海域',
          time: time,
          severity: '重度',
          raw: Map<String, dynamic>.from(t),
        );
      }).toList();
    } catch (e) {
      debugPrint('[WeatherService] 颱風 error: $e');
      return [];
    }
  }

  static String _rainSeverity(String text) {
    if (text.contains('超大豪雨') ||
        text.contains('大豪雨') ||
        text.contains('豪雨')) {
      return '重度';
    }

    if (text.contains('大雨') || text.contains('強風')) {
      return '中度';
    }

    return '輕度';
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }
}

