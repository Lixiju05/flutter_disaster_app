import 'package:flutter/material.dart';
import 'package:flutter_disaster_app/core/models/allocation.dart';
import 'package:flutter_disaster_app/core/models/dispatch.dart';
import 'package:flutter_disaster_app/core/models/supply.dart';
import 'package:flutter_disaster_app/core/repositories/admin_repository.dart';

class AllocationViewModel extends ChangeNotifier {
  final AdminRepository _repo = AdminRepository();

  // --- Inventory（給分配時選物資用）---
  List<SupplyItem> _supplies = [];
  List<SupplyItem> get supplies => _supplies;

  // --- Allocations ---
  List<AllocationItem> _allocations = [];
  List<AllocationItem> get allocations => _allocations;

  // --- Dispatches ---
  List<DispatchItem> _dispatches = [];
  List<DispatchItem> get dispatches => _dispatches;

  bool _isLoading = false;
  String? _errorMessage;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  AllocationViewModel() {
    loadAll();
  }

  Future<void> loadAll() async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final results = await Future.wait([
        _repo.getAdminSupplies(),
        _repo.getAllocations(),
        _repo.getDispatches(),
      ]);
      _supplies    = results[0] as List<SupplyItem>;
      _allocations = results[1] as List<AllocationItem>;
      _dispatches  = results[2] as List<DispatchItem>;
    } catch (e) {
      _errorMessage = '資料載入失敗：$e';
    }
    _setLoading(false);
  }

  Future<bool> allocate({
    required int itemId,
    required String zoneId,
    required int qty,
  }) async {
    try {
      final success = await _repo.allocate(
        itemId: itemId,
        zoneId: zoneId,
        qty: qty,
      );
      if (success) await loadAll();
      return success;
    } catch (e) {
      _errorMessage = '分配失敗：$e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> dispatch(int allocationId) async {
  try {
    // 1️⃣ 修正：使用傳入的參數 allocationId，而不是未定義的 allocation.id
    final success = await _repo.dispatch(
      dispatchId: allocationId, 
      status: 'shipped',
    );

    if (success) {
      await loadDispatches(); // 成功後刷新清單
      return true; // ✅ 補上回傳值，解決 body_might_complete_normally
    }
    
    return false; // ✅ 執行失敗也要回傳 false
  } catch (e) {
    _errorMessage = '出貨失敗：$e';
    notifyListeners();
    return false;
  }
}

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }
}
