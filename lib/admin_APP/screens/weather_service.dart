import 'dart:convert';
import 'package:http/http.dart' as http;

// ══════════════════════════════════════════════════════════
//  DATA MODELS
// ══════════════════════════════════════════════════════════

enum DisasterType { earthquake, typhoon, rain, flood, landslide, other }

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

class RainfallStation {
  final String stationId;
  final String stationName;
  final double rainfall10Min;
  final double rainfallHour;
  final double rainfall24Hr;
  final double waterLevel;
  final DateTime observeTime;

  const RainfallStation({
    required this.stationId,
    required this.stationName,
    required this.rainfall10Min,
    required this.rainfallHour,
    required this.rainfall24Hr,
    required this.waterLevel,
    required this.observeTime,
  });
}

class AqiStation {
  final String siteName;
  final String county;
  final int aqi;
  final String status;
  final double pm25;
  final double pm10;
  final DateTime publishTime;

  const AqiStation({
    required this.siteName,
    required this.county,
    required this.aqi,
    required this.status,
    required this.pm25,
    required this.pm10,
    required this.publishTime,
  });
}

// ══════════════════════════════════════════════════════════
//  WEATHER SERVICE
// ══════════════════════════════════════════════════════════

class WeatherService {
  static const String _cwaBase =
      'https://opendata.cwa.gov.tw/api/v1/rest/datastore';

  static String _auth(String apiKey) =>
      apiKey.isNotEmpty ? '&Authorization=$apiKey' : '';

  // ── 地震速報 ──
  static Future<List<DisasterAlert>> fetchEarthquakes({
    String apiKey = '',
  }) async {
    try {
      final url =
          '$_cwaBase/E-A0015-001?format=JSON&limit=5${_auth(apiKey)}';
      final res = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body);
      final records =
          data['records']?['Earthquake'] as List<dynamic>? ?? [];
      return records.map((e) {
        final info = e['EarthquakeInfo'] ?? {};
        final epicenter = info['Epicenter'] ?? {};
        final mag =
            info['EarthquakeMagnitude']?['MagnitudeValue'] ?? 0.0;
        final depth = info['FocalDepth'] ?? 0;
        final loc = epicenter['Location'] ?? '未知地點';
        final timeStr = info['OriginTime'] ?? '';
        DateTime time;
        try {
          time = DateTime.parse(timeStr);
        } catch (_) {
          time = DateTime.now();
        }
        final magVal = (mag is num) ? mag.toDouble() : 0.0;
        String severity = '輕度';
        if (magVal >= 6.0) severity = '重度';
        else if (magVal >= 5.0) severity = '中度';
        return DisasterAlert(
          id: e['EarthquakeNo']?.toString() ?? DateTime.now().toString(),
          type: DisasterType.earthquake,
          title: '地震速報 M${magVal.toStringAsFixed(1)}',
          description: '震源深度 ${depth}km，$loc',
          location: loc,
          time: time,
          severity: severity,
          raw: Map<String, dynamic>.from(e),
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // ── 颱風資訊 ──
  static Future<List<DisasterAlert>> fetchTyphoons({
    String apiKey = '',
  }) async {
    try {
      final url =
          '$_cwaBase/W-C0034-005?format=JSON${_auth(apiKey)}';
      final res = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body);
      final records =
          data['records']?['tropicalCyclones']?['tropicalCyclone']
              as List<dynamic>? ?? [];
      return records.map((t) {
        final name =
            t['cwaTyphoonName'] ?? t['typhoonName'] ?? '颱風';
        final fixes = t['fix'] as List<dynamic>? ?? [];
        final latest = fixes.isNotEmpty ? fixes.last : {};
        final intensity = latest['intensity'] ?? '';
        DateTime time;
        try {
          time = DateTime.parse(latest['fixTime'] ?? '');
        } catch (_) {
          time = DateTime.now();
        }
        return DisasterAlert(
          id: t['typhoonNo']?.toString() ?? name,
          type: DisasterType.typhoon,
          title: '$name 颱風',
          description: intensity.toString().isNotEmpty
              ? '強度：$intensity'
              : '颱風警報生效中',
          location: '台灣附近海域',
          time: time,
          severity: '重度',
          raw: Map<String, dynamic>.from(t),
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // ── 豪大雨特報 ──
  static Future<List<DisasterAlert>> fetchHeavyRain({
    String apiKey = '',
  }) async {
    try {
      final url =
          '$_cwaBase/W-C0033-001?format=JSON${_auth(apiKey)}';
      final res = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body);
      final records =
          data['records']?['location'] as List<dynamic>? ?? [];
      final List<DisasterAlert> alerts = [];
      for (final loc in records) {
        final hazards =
            loc['hazardConditions']?['hazards']?['hazard']
                as List<dynamic>? ?? [];
        for (final h in hazards) {
          final info = h['info'] ?? {};
          final phenomena = info['phenomena'] ?? '';
          final significance = info['significance'] ?? '';
          if (phenomena.toString().isEmpty) continue;
          final startStr =
              h['validTime']?['startCondition']?['startTime'] ?? '';
          DateTime time;
          try {
            time = DateTime.parse(startStr);
          } catch (_) {
            time = DateTime.now();
          }
          alerts.add(DisasterAlert(
            id: '${loc['locationName']}_${phenomena}_${time.millisecondsSinceEpoch}',
            type: DisasterType.rain,
            title: '$phenomena$significance',
            description: '${loc['locationName']} 豪大雨特報',
            location: loc['locationName'] ?? '未知',
            time: time,
            severity: phenomena.contains('大豪雨') ? '重度' : '中度',
            raw: {},
          ));
        }
      }
      return alerts;
    } catch (e) {
      return [];
    }
  }

  // ── 整合所有災害通報 ──
  static Future<List<DisasterAlert>> fetchAllAlerts({
    String apiKey = '',
  }) async {
    final results = await Future.wait([
      fetchEarthquakes(apiKey: apiKey),
      fetchTyphoons(apiKey: apiKey),
      fetchHeavyRain(apiKey: apiKey),
    ]);
    final all = results.expand((e) => e).toList();
    all.sort((a, b) => b.time.compareTo(a.time));
    return all;
  }
}

// ══════════════════════════════════════════════════════════
//  RAINFALL SERVICE（氣象署雨量測站）
// ══════════════════════════════════════════════════════════

class RainfallService {
  static const String _cwaBase =
      'https://opendata.cwa.gov.tw/api/v1/rest/datastore';

  // 南投縣埔里鎮附近測站
  static const String _stationIds = 'C0I310,C0I280,C0I260';

  static Future<List<RainfallStation>> fetchRainfall({
    String apiKey = '',
  }) async {
    try {
      final auth =
          apiKey.isNotEmpty ? '&Authorization=$apiKey' : '';
      final url =
          '$_cwaBase/O-A0002-001?format=JSON&StationId=$_stationIds$auth';
      final res = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return _mockRainfall();
      final data = jsonDecode(res.body);
      final stations =
          data['records']?['Station'] as List<dynamic>? ?? [];
      if (stations.isEmpty) return _mockRainfall();
      return stations.map((s) {
        final obs = s['RainfallElement'] ?? {};
        DateTime time;
        try {
          time =
              DateTime.parse(s['ObsTime']?['DateTime'] ?? '');
        } catch (_) {
          time = DateTime.now();
        }
        return RainfallStation(
          stationId: s['StationId'] ?? '',
          stationName: s['StationName'] ?? '',
          rainfall10Min:
              _toDouble(obs['Now']?['Precipitation']),
          rainfallHour:
              _toDouble(obs['Past1hr']?['Precipitation']),
          rainfall24Hr:
              _toDouble(obs['Past24hr']?['Precipitation']),
          waterLevel: 0.0,
          observeTime: time,
        );
      }).toList();
    } catch (e) {
      return _mockRainfall();
    }
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  static List<RainfallStation> _mockRainfall() => [
        RainfallStation(
          stationId: 'MOCK',
          stationName: '眉溪監測站（離線）',
          rainfall10Min: 0,
          rainfallHour: 0,
          rainfall24Hr: 0,
          waterLevel: 0,
          observeTime: DateTime.now(),
        ),
      ];
}

// ══════════════════════════════════════════════════════════
//  AQI SERVICE（環境部）
// ══════════════════════════════════════════════════════════

class AqiService {
  static Future<AqiStation?> fetchNantouAqi() async {
    try {
      const url =
          'https://data.moenv.gov.tw/api/v2/aqx_p_432'
          '?api_key=e8dd42e6-9b8b-43f8-991e-b3dee723a52d'
          '&limit=1000&format=JSON';
      final res = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body);
      final records = data['records'] as List<dynamic>? ?? [];
      final nantou = records.firstWhere(
        (r) => r['county'] == '南投縣',
        orElse: () => null,
      );
      if (nantou == null) return null;
      DateTime time;
      try {
        time = DateTime.parse(nantou['publishtime'] ?? '');
      } catch (_) {
        time = DateTime.now();
      }
      return AqiStation(
        siteName: nantou['sitename'] ?? '南投',
        county: nantou['county'] ?? '南投縣',
        aqi: int.tryParse(nantou['aqi']?.toString() ?? '0') ?? 0,
        status: nantou['status'] ?? '良好',
        pm25:
            double.tryParse(nantou['pm2.5']?.toString() ?? '0') ?? 0,
        pm10:
            double.tryParse(nantou['pm10']?.toString() ?? '0') ?? 0,
        publishTime: time,
      );
    } catch (e) {
      return null;
    }
  }
}