import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_disaster_app/core/models/supply_request.dart';
import 'package:flutter_disaster_app/core/repositories/admin_repository.dart';

/// 義工流程（依後端說明）：
/// reserved（待認領）─認領→ claimed（已認領）─確認取貨→ dispatched（配送中）─配送完成→ completed
///                    ←取消認領─
///
/// 頁面只有兩區：
///  ① 待認領任務：getPendingSupplyRequests（S001 的 reserved）
///  ② 我的配送：getVolunteerClaims（V001 在 S001 的任務）
class VolunteerViewModel extends ChangeNotifier {
  final AdminRepository _repo = AdminRepository();

  /// Demo 固定資料，正式版改成登入 / 掃 QR Code 取得
  final String volunteerId;
  final String stationId;
  final String stationName;

  Timer? _timer;

  VolunteerViewModel({
    this.volunteerId = 'V001',
    this.stationId = 'S001',
    this.stationName = 'A收容中心',
  }) {
    loadAll();
    // 每 15 秒自動更新，新任務會自動出現
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => loadAll(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  List<SupplyRequest> _pending = [];
  List<SupplyRequest> _myTasks = [];
  bool _isLoading = false;
  String? _errorMessage;
  DateTime? _lastUpdated;

  /// 正在處理動作的 requestId（按鈕顯示 loading 用）
  String? _busyId;

  /// ① 待認領任務
  List<SupplyRequest> get pending => _pending;

  /// ② 我的配送（已認領 → 配送中 → 已完成）
  List<SupplyRequest> get myTasks => _myTasks;
  int get activeCount => _myTasks.where((r) => r.isClaimed || r.isDelivering).length;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  DateTime? get lastUpdated => _lastUpdated;
  String? get busyId => _busyId;

  /// silent = 背景自動更新，不顯示轉圈圈
  Future<void> loadAll({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final results = await Future.wait([
        _repo.getPendingSupplyRequests(stationId: stationId),
        _repo.getVolunteerClaims(volunteerId: volunteerId, stationId: stationId),
      ]);

      _pending = results[0];

      const order = {'claimed': 0, 'dispatched': 1, 'completed': 2};
      _myTasks = results[1]
        ..sort((a, b) {
          final byStatus = (order[a.status] ?? 3).compareTo(order[b.status] ?? 3);
          if (byStatus != 0) return byStatus;
          return (b.claimedAt ?? DateTime(0)).compareTo(a.claimedAt ?? DateTime(0));
        });

      _errorMessage = null;
      _lastUpdated = DateTime.now();
    } catch (e) {
      _errorMessage = '載入失敗，請確認後端是否開啟';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// 執行動作後一律重新讀取，以後端結果為準
  Future<({bool success, String message})> _run(
    SupplyRequest r,
    Future<({bool success, String message})> Function({
      required String requestId,
      required String volunteerId,
      required String stationId,
    }) action,
  ) async {
    _busyId = r.requestId;
    notifyListeners();
    final result = await action(
        requestId: r.requestId, volunteerId: volunteerId, stationId: stationId);
    _busyId = null;
    await loadAll();
    return result;
  }

  /// 認領任務：reserved → claimed
  Future<({bool success, String message})> claim(SupplyRequest r) =>
      _run(r, _repo.claimSupplyRequest);

  /// 取消認領：claimed → reserved
  Future<({bool success, String message})> cancelClaim(SupplyRequest r) =>
      _run(r, _repo.cancelSupplyRequestClaim);

  /// 確認取貨：claimed → dispatched（後端此時扣庫存）
  Future<({bool success, String message})> pickup(SupplyRequest r) =>
      _run(r, _repo.pickupSupplyRequest);

  /// 配送完成：dispatched → completed
  Future<({bool success, String message})> complete(SupplyRequest r) =>
      _run(r, _repo.completeSupplyRequest);
}
