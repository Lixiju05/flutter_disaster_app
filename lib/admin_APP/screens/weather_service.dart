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
  landslide,
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

class RainfallStation {
  final String stationId;
  final String stationName;
  final double rainfall10Min;
  final double rainfallHour;
  final double rainfall24Hr;
  final double waterLevel;
  final DateTime observeTime;
  final bool isMock;

  const RainfallStation({
    required this.stationId,
    required this.stationName,
    required this.rainfall10Min,
    required this.rainfallHour,
    required this.rainfall24Hr,
    required this.waterLevel,
    required this.observeTime,
    this.isMock = false,
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
  final bool isMock;

  const AqiStation({
    required this.siteName,
    required this.county,
    required this.aqi,
    required this.status,
    required this.pm25,
    required this.pm10,
    required this.publishTime,
    this.isMock = false,
  });
}

// ══════════════════════════════════════════════════════════
// SIMULATION DATA
// ══════════════════════════════════════════════════════════

class SimulationData {
  static List<DisasterAlert> getSimulatedAlerts() {
    final now = DateTime.now();

    return [
      DisasterAlert(
        id: 'SIM_TY_001',
        type: DisasterType.typhoon,
        title: '颱風警報',
        description: '強烈颱風接近台灣，山區及沿海地區需嚴防強風豪雨。',
        location: '台灣全島',
        time: now.subtract(const Duration(hours: 2)),
        severity: '重度',
        raw: {},
      ),
      DisasterAlert(
        id: 'SIM_LS_001',
        type: DisasterType.landslide,
        title: '土石流紅色警戒',
        description: '南投縣埔里鎮中山路北段、愛蘭橋附近發布土石流紅色警戒。',
        location: '南投縣埔里鎮',
        time: now.subtract(const Duration(hours: 1)),
        severity: '重度',
        raw: {},
      ),
      DisasterAlert(
        id: 'SIM_RN_001',
        type: DisasterType.rain,
        title: '超大豪雨特報',
        description: '南投山區 24 小時累積雨量超過 600 毫米，請注意坍方與落石。',
        location: '南投縣',
        time: now.subtract(const Duration(minutes: 50)),
        severity: '重度',
        raw: {},
      ),
      DisasterAlert(
        id: 'SIM_FL_001',
        type: DisasterType.flood,
        title: '淹水警戒一級',
        description: '眉溪水位持續上升，埔里低窪地區需注意淹水。',
        location: '南投縣埔里鎮',
        time: now.subtract(const Duration(minutes: 30)),
        severity: '重度',
        raw: {},
      ),
      DisasterAlert(
        id: 'SIM_EQ_001',
        type: DisasterType.earthquake,
        title: '地震速報 M5.8',
        description: '震源深度 12 公里，南投縣魚池鄉附近發生有感地震。',
        location: '南投縣魚池鄉',
        time: now.subtract(const Duration(hours: 4)),
        severity: '中度',
        raw: {},
      ),
    ];
  }

  static List<RainfallStation> getSimulatedRainfall() {
    return [
      RainfallStation(
        stationId: 'SIM_C0I310',
        stationName: '埔里測站（模擬）',
        rainfall10Min: 18.5,
        rainfallHour: 112.0,
        rainfall24Hr: 487.3,
        waterLevel: 3.82,
        observeTime: DateTime.now(),
        isMock: true,
      ),
      RainfallStation(
        stationId: 'SIM_C0I280',
        stationName: '眉溪測站（模擬）',
        rainfall10Min: 22.1,
        rainfallHour: 98.5,
        rainfall24Hr: 412.8,
        waterLevel: 4.15,
        observeTime: DateTime.now(),
        isMock: true,
      ),
    ];
  }

  static AqiStation getSimulatedAqi() {
    return AqiStation(
      siteName: '南投（模擬）',
      county: '南投縣',
      aqi: 142,
      status: '對敏感族群不健康',
      pm25: 55.3,
      pm10: 88.7,
      publishTime: DateTime.now(),
      isMock: true,
    );
  }
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
        fetchLandslide(),
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

  static Future<List<DisasterAlert>> fetchLandslide() async {
    try {
      const url = 'https://246.swcb.gov.tw/api/Debris/GetDebrisFlowWarning';

      final res = await http
          .get(
            Uri.parse(url),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) return [];

      final data = jsonDecode(res.body);
      final List<dynamic> items =
          data is List ? data : (data['data'] ?? data['Data'] ?? []);

      final List<DisasterAlert> alerts = [];

      for (final item in items) {
        if (item is! Map) continue;

        final county =
            item['county'] ??
            item['County'] ??
            item['countyName'] ??
            '';

        final town =
            item['town'] ??
            item['Town'] ??
            item['townName'] ??
            '';

        final level =
            item['warningLevel'] ??
            item['WarningLevel'] ??
            item['level'] ??
            '';

        final streamName =
            item['streamName'] ??
            item['StreamName'] ??
            item['name'] ??
            '';

        if (level.toString().isEmpty) continue;

        final levelStr = level.toString();

        final severity =
            levelStr.contains('紅') || levelStr == '1'
                ? '重度'
                : levelStr.contains('黃') || levelStr == '2'
                    ? '中度'
                    : '輕度';

        alerts.add(
          DisasterAlert(
            id: 'LS_${county}_${town}_${streamName}_${DateTime.now().millisecondsSinceEpoch}',
            type: DisasterType.landslide,
            title: '土石流${levelStr.contains('紅') ? '紅色' : levelStr.contains('黃') ? '黃色' : ''}警戒',
            description: '$county$town $streamName 土石流危險溪流警戒',
            location: '$county$town',
            time: DateTime.now(),
            severity: severity,
            raw: Map<String, dynamic>.from(item),
          ),
        );
      }

      return alerts.take(10).toList();
    } catch (e) {
      debugPrint('[WeatherService] 土石流 error: $e');
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

// ══════════════════════════════════════════════════════════
// RAINFALL SERVICE
// ══════════════════════════════════════════════════════════

class RainfallService {
  static const String _cwaBase =
      'https://opendata.cwa.gov.tw/api/v1/rest/datastore';

  static const String _stationIds = 'C0I310,C0I280,C0I260';

  static Future<List<RainfallStation>> fetchRainfall({
    String apiKey = '',
  }) async {
    try {
      final auth = apiKey.isNotEmpty ? '&Authorization=$apiKey' : '';

      final url =
          '$_cwaBase/O-A0002-001?format=JSON&StationId=$_stationIds$auth';

      debugPrint('[RainfallService] URL: $url');

      final res = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 12));

      if (res.statusCode != 200) {
        debugPrint('[RainfallService] HTTP ${res.statusCode}');
        return [];
      }

      final data = jsonDecode(res.body);
      final records = data['records'];

      final stations =
          records?['Station'] ??
          records?['station'] ??
          [];

      if (stations is! List || stations.isEmpty) {
        debugPrint('[RainfallService] 無測站資料');
        return [];
      }

      final result = stations.map<RainfallStation>((s) {
        final obs =
            s['RainfallElement'] ??
            s['rainfallElement'] ??
            {};

        DateTime time;

        try {
          time = DateTime.parse(
            s['ObsTime']?['DateTime'] ??
                s['obsTime']?['dateTime'] ??
                '',
          );
        } catch (_) {
          time = DateTime.now();
        }

        return RainfallStation(
          stationId: s['StationId'] ?? s['stationId'] ?? '',
          stationName: s['StationName'] ?? s['stationName'] ?? '未知測站',
          rainfall10Min: _toDouble(
            obs['Now']?['Precipitation'] ??
                obs['now']?['precipitation'],
          ),
          rainfallHour: _toDouble(
            obs['Past1hr']?['Precipitation'] ??
                obs['Past1Hr']?['Precipitation'] ??
                obs['past1hr']?['precipitation'],
          ),
          rainfall24Hr: _toDouble(
            obs['Past24hr']?['Precipitation'] ??
                obs['Past24Hr']?['Precipitation'] ??
                obs['past24hr']?['precipitation'],
          ),
          waterLevel: 0.0,
          observeTime: time,
          isMock: false,
        );
      }).toList();

      debugPrint('[RainfallService] 成功取得 ${result.length} 筆測站資料');

      return result;
    } catch (e) {
      debugPrint('[RainfallService] error: $e');
      return [];
    }
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();

    final text = v.toString();

    if (text == '-99' || text == '-999' || text == 'T' || text == 'X') {
      return 0.0;
    }

    return double.tryParse(text) ?? 0.0;
  }
}

// ══════════════════════════════════════════════════════════
// AQI SERVICE
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
          .timeout(const Duration(seconds: 12));

      if (res.statusCode != 200) {
        debugPrint('[AqiService] HTTP ${res.statusCode}');
        return null;
      }

      final data = jsonDecode(res.body);
      final records = data['records'] as List<dynamic>? ?? [];

      dynamic found;

      for (final r in records) {
        final siteName = r['sitename']?.toString() ?? '';
        final county = r['county']?.toString() ?? '';

        if (siteName.contains('南投') ||
            siteName.contains('埔里') ||
            county == '南投縣') {
          found = r;
          break;
        }
      }

      if (found == null) return null;

      DateTime time;
      try {
        time = DateTime.parse(found['publishtime']?.toString() ?? '');
      } catch (_) {
        time = DateTime.now();
      }

      final aqiVal = int.tryParse(found['aqi']?.toString() ?? '0') ?? 0;

      return AqiStation(
        siteName: found['sitename']?.toString() ?? '南投',
        county: found['county']?.toString() ?? '南投縣',
        aqi: aqiVal,
        status: found['status']?.toString() ?? _aqiToStatus(aqiVal),
        pm25: double.tryParse(found['pm2.5']?.toString() ?? '0') ?? 0,
        pm10: double.tryParse(found['pm10']?.toString() ?? '0') ?? 0,
        publishTime: time,
        isMock: false,
      );
    } catch (e) {
      debugPrint('[AqiService] error: $e');
      return null;
    }
  }

  static String _aqiToStatus(int aqi) {
    if (aqi <= 50) return '良好';
    if (aqi <= 100) return '普通';
    if (aqi <= 150) return '對敏感族群不健康';
    if (aqi <= 200) return '對所有族群不健康';
    if (aqi <= 300) return '非常不健康';
    return '危害';
  }
}