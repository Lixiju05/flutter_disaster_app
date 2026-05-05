import 'package:flutter/material.dart';
import 'package:flutter_disaster_app/core/models/supply.dart';
import 'package:flutter_disaster_app/core/repositories/admin_repository.dart';

class AdminSupplyViewModel extends ChangeNotifier {
<<<<<<< HEAD
  final AdminRepository _repo = AdminRepository();

  List<SupplyItem> _supplies = [];
  List<SupplyItem> _allSupplies = [];
=======
  final AdminRepository _repository = AdminRepository();

  List<SupplyItem> _supplies = [];
  List<SupplyItem> get supplies => _supplies;
>>>>>>> f69460cd2207e884a63750829a091e7e38ece7cf

  bool _isLoading = false;
  String? _errorMessage;

  List<SupplyItem> get supplies => _supplies;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  AdminSupplyViewModel() {
    fetchSupplies();
  }

<<<<<<< HEAD
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
      if (success) await loadSupplies();
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
      final success = await _repo.updateStock(itemId: itemId, qty: qty);
      if (success) await loadSupplies();
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
          itemId: itemId, neededQty: neededQty);
      if (success) await loadSupplies();
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
=======
  /// 從後端獲取真實庫存資料
  Future<void> fetchSupplies() async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      // 呼叫 Repository 取得資料庫中的 inventory
      _supplies = await _repository.getAdminSupplies(); 
    } catch (e) {
      _errorMessage = '載入失敗: ${e.toString()}';
      print(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 執行物資分配 (呼叫後端 API)
  Future<bool> allocateSupply(int itemId, String zoneId, int quantity) async {
    _isLoading = true;
    notifyListeners();

    try {
      // 呼叫後端邏輯 (對應你之前的 AllocationService)
      final success = await _repository.allocate(
        itemId: itemId,
        zoneId: zoneId,
        qty: quantity,
      );

      if (success) {
        await fetchSupplies(); // 分配成功後，重新整理庫存列表
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = '分配失敗: ${e.toString()}';
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 搜尋物資 (建議改為本地篩選，或是呼叫後端搜尋)
  void filterSupplies(String keyword) {
    if (keyword.isEmpty) {
      fetchSupplies(); // 若清空則重新抓取全部
      return;
    }
    _supplies = _supplies
        .where((s) => s.name.toLowerCase().contains(keyword.toLowerCase()))
        .toList();
>>>>>>> f69460cd2207e884a63750829a091e7e38ece7cf
    notifyListeners();
  }
}