import 'package:flutter/material.dart';
import 'package:flutter_disaster_app/core/models/emergency_request.dart';
import 'package:flutter_disaster_app/core/repositories/admin_repository.dart';

class EmergencyViewModel extends ChangeNotifier {
  List<EmergencyRequest> _emergencies = [];
  List<EmergencyRequest> get emergencies => _emergencies;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> loadEmergencies() async {
    _isLoading = true;
    notifyListeners();

    _emergencies = await AdminRepository().getEmergencies();

    _isLoading = false;
    notifyListeners();
  }

  void markHandled(EmergencyRequest emergency) {
    final index = _emergencies.indexWhere((e) => e.id == emergency.id);
    if (index != -1) {
      _emergencies[index].handled = true;
      notifyListeners();
    }
  }
}