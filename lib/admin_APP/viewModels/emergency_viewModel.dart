import 'package:flutter/material.dart';
import 'package:flutter_disaster_app/core/models/emergency_request.dart';
import 'package:flutter_disaster_app/core/repositories/admin_repository.dart';

class EmergencyViewModel extends ChangeNotifier {
  final AdminRepository _repository = AdminRepository();

  List<EmergencyRequest> _emergencies = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<EmergencyRequest> get emergencies => _emergencies;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  EmergencyViewModel() {
    loadEmergencies();
  }

  Future<void> loadEmergencies() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _emergencies = await _repository.getEmergencies();
    } catch (e) {
      _errorMessage = '緊急事件資料載入失敗：$e';
      _emergencies = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  void markHandled(EmergencyRequest emergency) {
    final index = _emergencies.indexWhere((e) => e.id == emergency.id);
    if (index != -1) {
      _emergencies[index].handled = true; // 現在可以直接賦值了
      notifyListeners();
    }
  }
}