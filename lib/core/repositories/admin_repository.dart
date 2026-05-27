import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/citizen.dart';
import '../models/emergency_request.dart';
import '../models/supply.dart';

class AdminRepository {
  final String _baseUrl =
      'https://delphine-eisteddfodic-afflictively.ngrok-free.dev';

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
          "type": "allocateSupply",
          "itemId": itemId,
          "zoneId": zoneId,
          "quantity": qty,
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
          "type": "addItem",
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
          "type": "addStock",
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
        body: jsonEncode({"type": "getAllAllocations"}),
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
        body: jsonEncode({"type": "getAllDispatches"}),
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
          "type": "updateDispatchStatus",
          "dispatchId": dispatchId,
          "status": status,
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
}