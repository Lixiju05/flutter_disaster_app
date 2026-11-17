import 'package:flutter/material.dart';
import 'package:flutter_disaster_app/core/models/citizen.dart';
import 'package:flutter_disaster_app/core/repositories/admin_repository.dart';
import 'package:flutter_disaster_app/core/offline_demo_data.dart';

class CitizenViewmodel extends ChangeNotifier {
  final AdminRepository _repository = AdminRepository();

  List<Citizen> _citizens = [];
  List<Citizen> _allCitizens = [];

  bool _isLoading = false;
  String? _errorMessage;
  bool _isOfflineDemo = false;

  List<Citizen> get citizens => _citizens;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isOfflineDemo => _isOfflineDemo;

  CitizenViewmodel() {
    loadCitizens();
  }

  Future<void> loadCitizens() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final List<Citizen> data = await _repository.getCitizens();

      _allCitizens = List.from(data);
      _citizens = List.from(data);
      _isOfflineDemo = false;
    } catch (e) {
      // 連不上後端時，先用示範資料讓畫面可以照常顯示、方便改 UI
      _allCitizens = demoCitizens();
      _citizens = List.from(_allCitizens);
      _isOfflineDemo = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void search(String keyword) {
    final text = keyword.trim().toLowerCase();

    if (text.isEmpty) {
      _citizens = List.from(_allCitizens);
    } else {
      _citizens = _allCitizens.where((c) {
        final name = c.name.toLowerCase();
        final id = c.id.toString().toLowerCase();

        return name.contains(text) || id.contains(text);
      }).toList();
    }

    notifyListeners();
  }

  void updateNeedsRescue(Citizen citizen, bool needsRescue) {
    for (final c in _allCitizens) {
      if (c.id == citizen.id) {
        c.needsRescue = needsRescue;
        break;
      }
    }

    for (final c in _citizens) {
      if (c.id == citizen.id) {
        c.needsRescue = needsRescue;
        break;
      }
    }

    notifyListeners();
  }

  Future<void> refresh() async {
    await loadCitizens();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}