import 'package:flutter/material.dart';
import 'package:flutter_disaster_app/core/models/supply.dart';
import 'package:flutter_disaster_app/core/repositories/admin_repository.dart';

class AdminSupplyViewModel extends ChangeNotifier {
  // 假資料列表
  List<AdminSupply> _supplies = [
    AdminSupply(itemName: '水', totalQuantity: 100),
    AdminSupply(itemName: '口罩', totalQuantity: 500),
    AdminSupply(itemName: '醫療包', totalQuantity: 50),
  ];

  List<AdminSupply> get supplies => _supplies;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  AdminSupplyViewModel() {
    loadSupplies();
  }

  // 模擬載入資料
  Future<void> loadSupplies() async {
    _isLoading = true;
    notifyListeners();

    await Future.delayed(Duration(milliseconds: 300)); // 模擬等待時間

    _isLoading = false;
    notifyListeners();
  }

  // 分配物資
  void allocateSupply(AdminSupply supply, int quantity) {
    final index = _supplies.indexWhere((s) => s.itemName == supply.itemName);
    if (index != -1) {
      try {
        _supplies[index].allocate(quantity);
        notifyListeners();
      } catch (e) {
        print('分配失敗: ${e.toString()}');
      }
    }
  }

  // 搜尋物資
  void search(String keyword) {
    _supplies = _supplies
        .where((s) => s.itemName.toLowerCase().contains(keyword.toLowerCase()))
        .toList();
    notifyListeners();
  }
}