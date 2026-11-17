import 'package:flutter/material.dart';
import 'package:flutter_disaster_app/core/models/emergency_request.dart';
import 'package:flutter_disaster_app/core/repositories/admin_repository.dart';
import 'package:flutter_disaster_app/core/offline_demo_data.dart';

class EmergencyViewModel extends ChangeNotifier {
  final AdminRepository _repository = AdminRepository();

  List<EmergencyRequest> _emergencies = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _isOfflineDemo = false;

  List<EmergencyRequest> get emergencies => _emergencies;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isOfflineDemo => _isOfflineDemo;

  EmergencyViewModel() {
    loadEmergencies();
  }

  Future<void> loadEmergencies() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _emergencies = await _repository.getEmergencies();
      _isOfflineDemo = false;
    } catch (e) {
      // 連不上後端時，先用示範資料讓畫面可以照常顯示、方便改 UI
      _emergencies = demoEmergencies();
      _isOfflineDemo = true;
    }

    _isLoading = false;
    notifyListeners();
  }

  /// 標記完成：→ resolved。回傳是否成功，畫面用來顯示提示
  Future<bool> markHandled(EmergencyRequest emergency) =>
      _setStatus(emergency, 'resolved');

  /// 開始處理：待處理 → processing
  Future<bool> markProcessing(EmergencyRequest emergency) =>
      _setStatus(emergency, 'processing');

  Future<bool> _setStatus(EmergencyRequest emergency, String status) async {
    try {
      final success = await _repository.updateEmergencyStatus(
        emergencyId: emergency.emergencyId,
        status: status,
      );
      if (success) {
        final index = _emergencies.indexWhere((e) => e.emergencyId == emergency.emergencyId);
        if (index != -1) {
          _emergencies[index] = _emergencies[index].copyWith(status: status);
          notifyListeners();
        }
      }
      return success;
    } catch (e) {
      debugPrint('Update emergency status error: $e');
      return false;
    }
  }
}