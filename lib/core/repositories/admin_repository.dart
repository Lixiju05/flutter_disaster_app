import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/citizen.dart';
import '../models/emergency_request.dart';
import '../models/supply.dart';
import '../models/supply_request.dart';
import 'package:flutter_disaster_app/core/api_config.dart';

class AdminRepository {
  final String _baseUrl;

  AdminRepository({
    String baseUrl = ApiConfig.baseUrl,
  }) : _baseUrl = baseUrl;

  Future<String> _getAdminId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('adminId') ?? 'admin_ncnu';
  }

  /// 取得庫存列表
  Future<List<SupplyItem>> getAdminSupplies() async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        body: jsonEncode({"type": "getInventory"}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return (data['data'] as List)
              .map((item) => SupplyItem.fromJson(item))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('Fetch supplies error: $e');
      return [];
    }
  }

  /// 取得求救列表
  Future<List<EmergencyRequest>> getEmergencies() async {
    try {
      final adminId = await _getAdminId();
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({
          "type": "getEmergencyRequestsByAdmin",
          "receiverAdminId": adminId,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return (data['data'] as List)
              .map((e) => EmergencyRequest.fromJson(e))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('Fetch emergencies error: $e');
      return [];
    }
  }

  /// 更新 SOS 狀態
  Future<bool> updateEmergencyStatus({
    required String emergencyId,
    required String status,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({
          "type": "updateEmergencyStatus",
          "emergencyId": emergencyId,
          "status": status,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('Update emergency status error: $e');
      return false;
    }
  }

  /// 取得民眾列表
  Future<List<Citizen>> getCitizens() async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        body: jsonEncode({"type": "getAllUsers"}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return (data['data'] as List)
              .map((c) => Citizen.fromJson(c))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('Fetch citizens error: $e');
      return [];
    }
  }

  /// 執行物資分配
  Future<bool> allocate({
    required int itemId,
    required String zoneId,
    required int qty,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        body: jsonEncode({
          "type": "allocate",
          "itemId": itemId,
          "zoneId": zoneId,
          "qty": qty,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('Allocate error: $e');
      return false;
    }
  }

  Future<bool> addInventory({
    required String name,
    required String category,
    required String unit,
    required int stockQty,
    required int neededQty,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        body: jsonEncode({
          "type": "addInventory",
          "name": name,
          "category": category,
          "unit": unit,
          "stockQty": stockQty,
          "neededQty": neededQty,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('Add Inventory API Error: $e');
      return false;
    }
  }

  Future<bool> updateStock({
    required int itemId,
    required int additionalQty,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        body: jsonEncode({
          "type": "updateStock",
          "itemId": itemId,
          "qty": additionalQty,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateNeeded({
    required int itemId,
    required int neededQty,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        body: jsonEncode({
          "type": "updateNeeded",
          "itemId": itemId,
          "neededQty": neededQty,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('Update Needed Qty Error: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getAllocations() async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        body: jsonEncode({"type": "getAllocations"}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
      return [];
    } catch (e) {
      print('Fetch allocations error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getDispatches() async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        body: jsonEncode({"type": "getDispatches"}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
      return [];
    } catch (e) {
      print('Fetch dispatches error: $e');
      return [];
    }
  }

  Future<bool> dispatch({
    required int dispatchId,
    required String status,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          // 後端 dispatch 以 allocationId 出貨（扣庫存）
          "type": "dispatch",
          "allocationId": dispatchId,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('Dispatch action error: $e');
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════
  // 義工認領物資需求
  // ══════════════════════════════════════════════════════════

  /// 取得待認領物資需求（後端需要 stationId，回傳該據點 status = reserved 的需求）
  Future<List<SupplyRequest>> getPendingSupplyRequests({required String stationId}) async {
    final data = await _postJson({
      "type": "getPendingSupplyRequests",
      "stationId": stationId,
    });
    if (data['success'] == true) {
      final list = (data['data'] ?? data['requests'] ?? []) as List;
      return list.map((r) => SupplyRequest.fromJson(r)).toList();
    }

    // 後端還沒有 getPendingSupplyRequests 時（回 Unknown type），
    // 改用已存在的 getSupplyRequestDetails，再自己篩出待認領
    if (data['message'] == 'Unknown type') {
      final all = await getAllSupplyRequests();
      return all.where((r) => r.isPending).toList();
    }

    throw Exception(data['message'] ?? '取得待認領需求失敗');
  }

  /// 取得全部物資需求（含 pending / claimed）
  Future<List<SupplyRequest>> getAllSupplyRequests() async {
    final data = await _postJson({"type": "getSupplyRequestDetails"});
    if (data['success'] != true) {
      throw Exception(data['message'] ?? '取得物資需求失敗');
    }
    return (data['data'] as List)
        .map((r) => SupplyRequest.fromJson(r))
        .toList();
  }

  Future<Map<String, dynamic>> _postJson(Map<String, dynamic> body) async {
    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': 'true',
      },
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 10));
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// 共用：送出義工動作，回傳成功與否 + 後端訊息
  Future<({bool success, String message})> _volunteerAction(Map<String, dynamic> body) async {
    try {
      final data = await _postJson(body);
      final message = (data['message'] ?? '').toString().replaceFirst('Exception: ', '');
      return (success: data['success'] == true, message: message);
    } catch (e) {
      return (success: false, message: '連線失敗，請確認後端是否開啟');
    }
  }

  /// 取得我的配送（V001 在 S001 的任務：claimed / dispatched / completed）
  Future<List<SupplyRequest>> getVolunteerClaims({
    required String volunteerId,
    required String stationId,
  }) async {
    final data = await _postJson({
      "type": "getVolunteerClaims",
      "volunteerId": volunteerId,
      "stationId": stationId,
    });

    // 後端還沒上線 getVolunteerClaims 時（回 Unknown type），
    // 改用已存在的 getSupplyRequestDetails，篩出這位義工的任務
    if (data['message'] == 'Unknown type') {
      final all = await getAllSupplyRequests();
      return all
          .where((r) => r.volunteerId == volunteerId && (r.isClaimed || r.isDelivering || r.isDone))
          .toList();
    }

    if (data['success'] != true) {
      throw Exception(data['message'] ?? '取得我的配送任務失敗');
    }
    final list = (data['data'] ?? data['requests'] ?? []) as List;
    return list.map((r) => SupplyRequest.fromJson(r)).toList();
  }

  /// 義工動作共用欄位：requestId + volunteerId + stationId
  Future<({bool success, String message})> _volunteerStep(
    String type, {
    required String requestId,
    required String volunteerId,
    required String stationId,
  }) =>
      _volunteerAction({
        'type': type,
        'requestId': requestId,
        'volunteerId': volunteerId,
        'stationId': stationId,
      });

  /// 認領任務：reserved → claimed
  Future<({bool success, String message})> claimSupplyRequest({
    required String requestId,
    required String volunteerId,
    required String stationId,
  }) =>
      _volunteerStep('claimSupplyRequest',
          requestId: requestId, volunteerId: volunteerId, stationId: stationId);

  /// 取消認領：claimed → reserved
  Future<({bool success, String message})> cancelSupplyRequestClaim({
    required String requestId,
    required String volunteerId,
    required String stationId,
  }) =>
      _volunteerStep('cancelSupplyRequestClaim',
          requestId: requestId, volunteerId: volunteerId, stationId: stationId);

  /// 確認取貨：claimed → dispatched（此時後端才扣庫存）
  Future<({bool success, String message})> pickupSupplyRequest({
    required String requestId,
    required String volunteerId,
    required String stationId,
  }) =>
      _volunteerStep('dispatchSupplyRequest',
          requestId: requestId, volunteerId: volunteerId, stationId: stationId);

  /// 配送完成：dispatched → completed
  Future<({bool success, String message})> completeSupplyRequest({
    required String requestId,
    required String volunteerId,
    required String stationId,
  }) =>
      _volunteerStep('completeSupplyRequest',
          requestId: requestId, volunteerId: volunteerId, stationId: stationId);
}
