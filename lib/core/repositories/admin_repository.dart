import 'package:flutter_disaster_app/admin_APP/services/api_services.dart';

import '../models/citizen.dart';
import '../models/emergency_request.dart';
import '../models/supply.dart';
import '../models/allocation.dart';
import '../models/dispatch.dart';

class AdminRepository {
  /// =========================
  /// Citizen
  /// =========================

  Future<List<Citizen>> getCitizens() async {
    try {
      final data = await ApiServices.post({
        "type": "getAllUsers",
      });

      if (data['success'] == true) {
        return (data['data'] as List)
            .map((e) => Citizen.fromJson(e))
            .toList();
      }

      return [];
    } catch (e) {
      print('GET CITIZENS ERROR: $e');
      return [];
    }
  }

  /// =========================
  /// Emergency
  /// =========================

  Future<List<EmergencyRequest>> getEmergencies() async {
    try {
      final data = await ApiServices.post({
        "type": "getAllReports",
      });

      if (data['success'] == true) {
        return (data['data'] as List)
            .map((e) => EmergencyRequest.fromJson(e))
            .toList();
      }

      return [];
    } catch (e) {
      print('GET EMERGENCIES ERROR: $e');
      return [];
    }
  }

  /// =========================
  /// Inventory
  /// =========================

  Future<List<SupplyItem>> getInventory() async {
    try {
      final data = await ApiServices.post({
        "type": "getInventory",
      });

      if (data['success'] == true) {
        return (data['data'] as List)
            .map((e) => SupplyItem.fromJson(e))
            .toList();
      }

      return [];
    } catch (e) {
      print('GET INVENTORY ERROR: $e');
      return [];
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
      final data = await ApiServices.post({
        "type": "addInventory",
        "name": name,
        "category": category,
        "unit": unit,
        "stockQty": stockQty,
        "neededQty": neededQty,
      });

      return data['success'] == true;
    } catch (e) {
      print('ADD INVENTORY ERROR: $e');
      return false;
    }
  }

  Future<bool> updateStock({
    required int itemId,
    required int qty,
  }) async {
    try {
      final data = await ApiServices.post({
        "type": "updateStock",
        "itemId": itemId,
        "qty": qty,
      });

      return data['success'] == true;
    } catch (e) {
      print('UPDATE STOCK ERROR: $e');
      return false;
    }
  }

  Future<bool> updateNeeded({
    required int itemId,
    required int neededQty,
  }) async {
    try {
      final data = await ApiServices.post({
        "type": "updateNeeded",
        "itemId": itemId,
        "neededQty": neededQty,
      });

      return data['success'] == true;
    } catch (e) {
      print('UPDATE NEEDED ERROR: $e');
      return false;
    }
  }

  /// =========================
  /// Allocation
  /// =========================

  Future<List<AllocationItem>> getAllocations() async {
    try {
      final data = await ApiServices.post({
        "type": "getAllocations",
      });

      if (data['success'] == true) {
        return (data['data'] as List)
            .map((e) => AllocationItem.fromJson(e))
            .toList();
      }

      return [];
    } catch (e) {
      print('GET ALLOCATIONS ERROR: $e');
      return [];
    }
  }

  Future<bool> allocate({
    required int itemId,
    required String zoneId,
    required int qty,
  }) async {
    try {
      final data = await ApiServices.post({
        "type": "allocate",
        "itemId": itemId,
        "zoneId": zoneId,
        "qty": qty,
      });

      return data['success'] == true;
    } catch (e) {
      print('ALLOCATE ERROR: $e');
      return false;
    }
  }

  /// =========================
  /// Dispatch
  /// =========================

  Future<List<DispatchItem>> getDispatches() async {
    try {
      final data = await ApiServices.post({
        "type": "getDispatches",
      });

      if (data['success'] == true) {
        return (data['data'] as List)
            .map((e) => DispatchItem.fromJson(e))
            .toList();
      }

      return [];
    } catch (e) {
      print('GET DISPATCHES ERROR: $e');
      return [];
    }
  }

  Future<bool> dispatch({
    required int allocationId,
  }) async {
    try {
      final data = await ApiServices.post({
        "type": "dispatch",
        "allocationId": allocationId,
      });

      return data['success'] == true;
    } catch (e) {
      print('DISPATCH ERROR: $e');
      return false;
    }
  }
}