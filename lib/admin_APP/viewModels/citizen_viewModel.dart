import 'package:flutter/material.dart';
import 'package:flutter_disaster_app/core/models/citizen.dart';
import 'package:flutter_disaster_app/core/repositories/admin_repository.dart';

class CitizenViewmodel extends ChangeNotifier {
  final AdminRepository _repository = AdminRepository();

  List<Citizen> _citizens = [];
  List<Citizen> _allCitizens = [];

  bool _isLoading = false;
  String? _errorMessage;

  List<Citizen> get citizens => _citizens;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

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
    } catch (e) {
      _errorMessage = '民眾資料載入失敗：$e';
      _allCitizens = [];
      _citizens = [];
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