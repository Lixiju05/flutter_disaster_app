import 'package:flutter/material.dart';
import 'package:flutter_disaster_app/core/models/supply.dart';
import 'package:flutter_disaster_app/core/repositories/admin_repository.dart';

class AdminSupplyViewModel extends ChangeNotifier {
  final AdminRepository _repo = AdminRepository();

  List<SupplyItem> _supplies = [];
  List<SupplyItem> _allSupplies = [];

  bool _isLoading = false;
  String? _errorMessage;

  List<SupplyItem> get supplies => _supplies;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  AdminSupplyViewModel() {
    loadSupplies();
  }

  Future<void> loadSupplies() async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final data = await _repo.getInventory();
      _allSupplies = data;
      _supplies = data;
    } catch (e) {
      _errorMessage = '物資資料載入失敗：$e';
      _supplies = [];
      _allSupplies = [];
    }

    _setLoading(false);
  }

  Future<bool> addSupply({
    required String name,
    required String category,
    required String unit,
    required int stockQty,
    required int neededQty,
  }) async {
    try {
      final success = await _repo.addInventory(
        name: name,
        category: category,
        unit: unit,
        stockQty: stockQty,
        neededQty: neededQty,
      );

      if (success) {
        await loadSupplies();
      }

      return success;
    } catch (e) {
      _errorMessage = '新增物資失敗：$e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateStock({
    required int itemId,
    required int qty,
  }) async {
    try {
      final success = await _repo.updateStock(
        itemId: itemId,
        qty: qty,
      );

      if (success) {
        await loadSupplies();
      }

      return success;
    } catch (e) {
      _errorMessage = '補貨失敗：$e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateNeeded({
    required int itemId,
    required int neededQty,
  }) async {
    try {
      final success = await _repo.updateNeeded(
        itemId: itemId,
        neededQty: neededQty,
      );

      if (success) {
        await loadSupplies();
      }

      return success;
    } catch (e) {
      _errorMessage = '修改需求量失敗：$e';
      notifyListeners();
      return false;
    }
  }

  void search(String keyword) {
    final text = keyword.trim().toLowerCase();

    if (text.isEmpty) {
      _supplies = _allSupplies;
    } else {
      _supplies = _allSupplies.where((item) {
        return item.name.toLowerCase().contains(text) ||
            item.category.toLowerCase().contains(text);
      }).toList();
    }

    notifyListeners();
  }

  void clearSearch() {
    _supplies = _allSupplies;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}