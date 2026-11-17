import 'package:flutter/foundation.dart';
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
      _errorMessage = '緊急事件資料載入失敗';
      debugPrint('Load emergencies error: $e');
      _emergencies = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> markHandled(EmergencyRequest emergency) {
    return _setStatus(emergency, 'resolved');
  }

  Future<bool> markProcessing(EmergencyRequest emergency) {
    return _setStatus(emergency, 'processing');
  }

  Future<bool> _setStatus(
    EmergencyRequest emergency,
    String status,
  ) async {
    try {
      final success = await _repository.updateEmergencyStatus(
        emergencyId: emergency.emergencyId,
        status: status,
      );

      if (success) {
        final index = _emergencies.indexWhere(
          (e) => e.emergencyId == emergency.emergencyId,
        );

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
