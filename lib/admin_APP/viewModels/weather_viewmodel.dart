import 'package:flutter/material.dart';
import 'package:flutter_disaster_app/admin_APP/screens/weather_service.dart'; // 修正路径

class WeatherViewModel extends ChangeNotifier {
  // ── 狀態 ──
  bool _isLoading = false;
  String? _errorMessage;
  bool _isOffline = false;

  // ── 資料 ──
  List<RainfallStation> _rainfallStations = [];
  AqiStation? _aqiStation;
  List<DisasterAlert> _alerts = [];

  // ── Getters ──
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isOffline => _isOffline;
  List<RainfallStation> get rainfallStations => _rainfallStations;
  AqiStation? get aqiStation => _aqiStation;
  List<DisasterAlert> get alerts => _alerts;

  double get rainfall24Hr =>
      _rainfallStations.isNotEmpty ? _rainfallStations.first.rainfall24Hr : 0.0;

  int get aqi => _aqiStation?.aqi ?? 0;
  String get aqiStatus => _aqiStation?.status ?? '載入中';

  WeatherViewModel() {
    loadAll();
  }

  Future<void> loadAll() async {
    _isLoading = true;
    _errorMessage = null;
    _isOffline = false;
    notifyListeners();

    try {
      await Future.wait([
        _loadRainfall(),
        _loadAqi(),
        _loadAlerts(),
      ]);

      _isOffline = _rainfallStations.isEmpty &&
          _aqiStation == null &&
          _alerts.isEmpty;
    } catch (e) {
      _errorMessage = '資料載入失敗：$e';
      _isOffline = true;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadRainfall() async {
    const apiKey = 'CWA-AFE44442-4E97-4836-A31F-0D743B56732B';
    final stations = await RainfallService.fetchRainfall(apiKey: apiKey);
    _rainfallStations = stations;
  }

  Future<void> _loadAqi() async {
    final aqi = await AqiService.fetchNantouAqi();
    _aqiStation = aqi;
  }

  Future<void> _loadAlerts() async {
    const apiKey = 'CWA-AFE44442-4E97-4836-A31F-0D743B56732B';
    final alerts = await WeatherService.fetchAllAlerts(apiKey: apiKey);
    _alerts = alerts;
  }

  Future<void> refresh() async {
    await loadAll();
  }
}