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
      final data = await _repository.getCitizens();

      _allCitizens = data;
      _citizens = data;
    } catch (e) {
      _errorMessage = '民眾資料載入失敗：$e';
      _citizens = [];
      _allCitizens = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  void search(String keyword) {
    final text = keyword.trim().toLowerCase();

    if (text.isEmpty) {
      _citizens = _allCitizens;
    } else {
      _citizens = _allCitizens.where((c) {
        return c.name.toLowerCase().contains(text) ||
            c.id.toLowerCase().contains(text);
      }).toList();
    }

    notifyListeners();
  }

  void updateNeedsRescue(Citizen citizen, bool needsRescue) {
    final index = _citizens.indexWhere((c) => c.id == citizen.id);

    if (index != -1) {
      _citizens[index].needsRescue = needsRescue;
    }

    final allIndex = _allCitizens.indexWhere((c) => c.id == citizen.id);

    if (allIndex != -1) {
      _allCitizens[allIndex].needsRescue = needsRescue;
    }

    notifyListeners();
  }
}