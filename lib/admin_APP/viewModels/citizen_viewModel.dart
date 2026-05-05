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

<<<<<<< HEAD
    try {
      final data = await _repository.getCitizens();

      _allCitizens = data;
      _citizens = data;
    } catch (e) {
      _errorMessage = '民眾資料載入失敗：$e';
      _citizens = [];
      _allCitizens = [];
=======
    _citizens=await _repository.getCitizens();

    _isLoading=false;
    notifyListeners();
  }
  //搜尋民眾
  void search(String keyword) async {
    // 如果你要重新從伺服器搜尋，要加上 await
    // 如果只是在本地篩選，請確保 _citizens 已經被 await 過了
    if (keyword.isEmpty) {
      await loadCitizens();
      return;
    }
    _citizens = _citizens
        .where((c) => c.name.toLowerCase().contains(keyword.toLowerCase()))
        .toList();
    notifyListeners();
  }
  //更新民眾是否需要救援
  void updateNeedsRescue(Citizen citizen, bool needsRescue){
    final index= _citizens.indexWhere((c) => c.id == citizen.id);
    if (index != -1){
      _citizens[index].needsRescue=needsRescue;
      notifyListeners();
>>>>>>> f69460cd2207e884a63750829a091e7e38ece7cf
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