import 'package:flutter/material.dart';
import 'package:flutter_disaster_app/admin_APP/screens/weather_service.dart'; // 修正路徑

// ══════════════════════════════════════════════════════════
//  WEATHER VIEW MODEL
// ══════════════════════════════════════════════════════════

class WeatherViewModel extends ChangeNotifier {
  static const String _apiKey = 'CWA-AFE44442-4E97-4836-A31F-0D743B56732B';

  // ── 狀態 ──
  bool _isLoading = false;
  bool _isOffline = false; // 真正的離線（API 完全失敗）
  bool _hasRealData = false; // 是否有取得任何真實資料
  String? _errorMessage;

  // ── 真實資料 ──
  List<DisasterAlert> _realAlerts = [];

  // ── Getters（根據模式回傳對應資料）──

  bool get isLoading => _isLoading;
  bool get isOffline => _isOffline;
  bool get hasRealData => _hasRealData;
  String? get errorMessage => _errorMessage;

  List<DisasterAlert> get alerts => _realAlerts;

  // ── 最後更新時間 ──
  DateTime? _lastUpdated;
  DateTime? get lastUpdated => _lastUpdated;

  // ══════════════════════════════════════════════════════════
  WeatherViewModel() {
    loadAll();
  }

  // ── 載入所有資料 ──
  Future<void> loadAll() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _loadAlerts();

      // 真正的離線 = 警報來源完全沒資料
      _isOffline = _realAlerts.isEmpty;
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