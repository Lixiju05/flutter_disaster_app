import 'package:flutter/material.dart';
import 'package:flutter_disaster_app/core/models/supply.dart';
import 'package:flutter_disaster_app/core/repositories/admin_repository.dart';

class AdminSupplyViewModel extends ChangeNotifier {
  final AdminRepository _repository = AdminRepository();

  List<SupplyItem> _supplies = [];
  List<SupplyItem> get supplies => _supplies;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  AdminSupplyViewModel() {
    fetchSupplies();
  }

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
    notifyListeners();
  }
}