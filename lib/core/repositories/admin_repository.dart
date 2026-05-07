import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/citizen.dart';
import '../models/emergency_request.dart';
import '../models/supply.dart'; // 確保這裡面的類別叫 SupplyItem

class AdminRepository {
 
  final String _baseUrl = 'https://delphine-eisteddfodic-afflictively.ngrok-free.dev';

  /// 取得庫存列表 (從後端資料庫)
  Future<List<SupplyItem>> getAdminSupplies() async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        body: jsonEncode({"type": "getAllInventory"}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (data['success'] == true) {
          final List list = data['data'];
          return list.map((item) => SupplyItem.fromJson(item)).toList();
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
      final response = await http.post(
        Uri.parse(_baseUrl),
        body: jsonEncode({"type": "getAllReports"}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (data['success'] == true) {
          final List list = data['data'];
          return list.map((e) => EmergencyRequest.fromJson(e)).toList();
        }
      }
      return [];
    } catch (e) {
      print('Fetch emergencies error: $e');
      return [];
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
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (data['success'] == true) {
          final List list = data['data'];
          return list.map((c) => Citizen.fromJson(c)).toList();
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
/// 更新物資庫存 (補貨) - 修改後
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
      // ... 其餘邏輯不變 ...
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
  /// 更新物資需求量 (Needed Qty)
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
  /// 取得所有已分配/已出貨紀錄
  Future<List<Map<String, dynamic>>> getAllocations() async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        body: jsonEncode({"type": "getAllAllocations"}), // 確保後端 switch 有處理這個
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (data['success'] == true) {
          // 因為分配紀錄通常包含多個 Table 的 Join (物資名、區域等)
          // 這裡直接回傳原始 List<Map> 供 UI 使用，或是你可以建立一個 AllocationModel
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
      return [];
    } catch (e) {
      print('Fetch allocations error: $e');
      return [];
    }
  }
  /// 取得所有出貨紀錄 (已離開倉庫)
  Future<List<Map<String, dynamic>>> getDispatches() async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        body: jsonEncode({"type": "getAllDispatches"}), // 對應後端 type
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
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
  /// 執行出貨動作
  /// 將特定分配紀錄的狀態改為「已出貨」
  Future<bool> dispatch({
    required int dispatchId,
    required String status, // 例如 'shipped' 或 'completed'
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "type": "updateDispatchStatus", // 確保後端 switch 處理這個 type
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