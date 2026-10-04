import 'package:flutter/material.dart';
import 'package:flutter_disaster_app/core/models/supply_request.dart';
import 'package:flutter_disaster_app/core/repositories/admin_repository.dart';

class VolunteerViewModel extends ChangeNotifier {
  final AdminRepository _repo = AdminRepository();

  /// Demo 先固定，正式版改成掃 QR Code 取得 stationId
  final String volunteerId;
  final String stationName;

  VolunteerViewModel({
    this.volunteerId = 'V001',
    this.stationName = 'A收容中心',
  }) {
    loadPendingRequests();
  }

  List<SupplyRequest> _requests = [];
  bool _isLoading = false;
  String? _errorMessage;

  /// 這次 session 中自己認領成功的需求（後端不會再回傳，所以前端留著顯示「已認領／待配送」）
  final List<SupplyRequest> _myClaimed = [];

  /// 正在送出認領的 requestId（按鈕顯示 loading 用）
  String? _claimingId;

  List<SupplyRequest> get requests => _requests;
  List<SupplyRequest> get myClaimed => _myClaimed;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get claimingId => _claimingId;

  Future<void> loadPendingRequests() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _requests = await _repo.getPendingSupplyRequests();
    } catch (e) {
      _errorMessage = '載入失敗，請確認後端是否開啟';
      _requests = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  /// 認領：不管成功失敗都重新抓 pending 列表，以後端結果為準
  Future<({bool success, String message})> claim(SupplyRequest request) async {
    _claimingId = request.requestId;
    notifyListeners();

    final result = await _repo.claimSupplyRequest(
      requestId: request.requestId,
      volunteerId: volunteerId,
    );

    if (result.success) {
      _myClaimed.insert(
        0,
        request.copyWith(
          status: 'claimed',
          volunteerId: volunteerId,
          claimedAt: DateTime.now(),
        ),
      );
    }

    _claimingId = null;
    await loadPendingRequests();

    return result;
  }
}
