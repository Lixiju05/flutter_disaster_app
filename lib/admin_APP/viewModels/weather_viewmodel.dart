import 'package:flutter/material.dart';
import 'package:flutter_disaster_app/admin_APP/screens/weather_service.dart'; // 修正路徑

// ══════════════════════════════════════════════════════════
//  APP MODE（正常模式 / 警戒模擬模式）
// ══════════════════════════════════════════════════════════

enum AppMode {
  normal,     // 即時真實資料
  simulation, // 警戒模擬展示模式
}

// ══════════════════════════════════════════════════════════
//  WEATHER VIEW MODEL
// ══════════════════════════════════════════════════════════

class WeatherViewModel extends ChangeNotifier {
  static const String _apiKey = 'CWA-AFE44442-4E97-4836-A31F-0D743B56732B';

  // ── 模式 ──
  AppMode _mode = AppMode.normal;
  AppMode get mode => _mode;
  bool get isSimulation => _mode == AppMode.simulation;

  // ── 狀態 ──
  bool _isLoading = false;
  bool _isOffline = false; // 真正的離線（API 完全失敗）
  bool _hasRealData = false; // 是否有取得任何真實資料
  String? _errorMessage;

  // ── 真實資料 ──
  List<RainfallStation> _realRainfall = [];
  AqiStation? _realAqi;
  List<DisasterAlert> _realAlerts = [];

  // ── 模擬資料 ──
  final List<RainfallStation> _simRainfall = SimulationData.getSimulatedRainfall();
  final AqiStation _simAqi = SimulationData.getSimulatedAqi();
  final List<DisasterAlert> _simAlerts = SimulationData.getSimulatedAlerts();

  // ── Getters（根據模式回傳對應資料）──

  bool get isLoading => _isLoading;
  bool get isOffline => _mode == AppMode.normal ? _isOffline : false;
  bool get hasRealData => _hasRealData;
  String? get errorMessage => _errorMessage;

  List<RainfallStation> get rainfallStations =>
      _mode == AppMode.simulation ? _simRainfall : _realRainfall;

  AqiStation? get aqiStation =>
      _mode == AppMode.simulation ? _simAqi : _realAqi;

  List<DisasterAlert> get alerts =>
      _mode == AppMode.simulation ? _simAlerts : _realAlerts;

  double get rainfall24Hr {
    final stations = rainfallStations;
    if (stations.isEmpty) return 0.0;
    return stations.first.rainfall24Hr;
  }

  int get aqi => aqiStation?.aqi ?? 0;

  String get aqiStatus => aqiStation?.status ?? (_isOffline ? '無法取得' : '載入中');

  /// 目前顯示的資料是否為模擬 / mock
  bool get isDataMock =>
      _mode == AppMode.simulation ||
      (rainfallStations.isNotEmpty && rainfallStations.first.isMock == true);

  // ── 最後更新時間 ──
  DateTime? _lastUpdated;
  DateTime? get lastUpdated => _lastUpdated;

  // ══════════════════════════════════════════════════════════
  WeatherViewModel() {
    loadAll();
  }

  // ── 切換模式 ──
  void toggleMode() {
    _mode = _mode == AppMode.normal ? AppMode.simulation : AppMode.normal;
    debugPrint('[WeatherViewModel] 切換模式 → ${_mode.name}');
    notifyListeners();
  }

  void setMode(AppMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
  }

  // ── 載入所有資料 ──
  Future<void> loadAll() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await Future.wait([
        _loadRainfall(),
        _loadAqi(),
        _loadAlerts(),
      ]);

      // 真正的離線 = 三個來源都沒資料
      _isOffline = _realRainfall.isEmpty && _realAqi == null && _realAlerts.isEmpty;
      _hasRealData = !_isOffline;

      if (_isOffline) {
        debugPrint('[WeatherViewModel] 全部 API 失敗，系統離線');
        _errorMessage = '無法連線至氣象資料伺服器';
      } else {
        _errorMessage = null;
      }
    } catch (e) {
      _errorMessage = '資料載入失敗：$e';
      _isOffline = true;
      _hasRealData = false;
      debugPrint('[WeatherViewModel] 載入錯誤: $e');
    }

    _isLoading = false;
    _lastUpdated = DateTime.now();
    notifyListeners();
  }

  Future<void> refresh() async {
    await loadAll();
  }

  // ── 私有載入方法 ──

  Future<void> _loadRainfall() async {
    try {
      final stations = await RainfallService.fetchRainfall(apiKey: _apiKey);
      // 只要不是空陣列就採用（API 成功但無資料也是正常情況）
      _realRainfall = stations;
      debugPrint('[WeatherViewModel] 雨量：${stations.length} 筆');
    } catch (e) {
      debugPrint('[WeatherViewModel] 雨量載入失敗: $e');
      _realRainfall = [];
    }
  }

  Future<void> _loadAqi() async {
    try {
      final aqi = await AqiService.fetchNantouAqi();
      _realAqi = aqi;
      debugPrint('[WeatherViewModel] AQI：${aqi?.aqi ?? '無資料'}');
    } catch (e) {
      debugPrint('[WeatherViewModel] AQI 載入失敗: $e');
      _realAqi = null;
    }
  }

  Future<void> _loadAlerts() async {
    try {
      final alerts = await WeatherService.fetchAllAlerts(apiKey: _apiKey);
      _realAlerts = alerts;
      debugPrint('[WeatherViewModel] 警報：${alerts.length} 筆');
    } catch (e) {
      debugPrint('[WeatherViewModel] 警報載入失敗: $e');
      _realAlerts = [];
    }
  }
}