import 'dart:convert';
import 'package:admin_server/database/database_service.dart';
import 'package:sqlite3/sqlite3.dart';

class SupplyReviewRequired extends InventoryException {
  final List<Map<String, Object?>> reasons;
  SupplyReviewRequired(this.reasons)
      : super('需求須人工審核：${reasons.map((r) => r['message']).join('；')}', 409);
}

class SupplyRequestService {
  static const communityStationId = 'OFFICE001';
  final DatabaseService db;
  final int maxRequestQty;
  SupplyRequestService(this.db, {
    this.maxRequestQty = const int.fromEnvironment('MAX_SUPPLY_REQUEST_QTY', defaultValue: 100),
  }) {
    if (maxRequestQty <= 0) throw ArgumentError('MAX_SUPPLY_REQUEST_QTY 必須大於 0');
  }

  List<Map<String, Object?>> _anomalies(Database sql, Map<String, Object?> r) {
    final reasons = <Map<String, Object?>>[];
    void add(String code, String message) => reasons.add({'code': code, 'message': message});
    final user = r['userId'];
    final item = r['itemId'];
    final qty = r['qty'];
    final validUser = user is String && user.trim().isNotEmpty;
    final validItem = item is int && sql.select('SELECT id FROM inventory WHERE id=?', [item]).isNotEmpty;
    final validQty = qty is int && qty > 0;
    if (!validUser || !validItem || !validQty ||
        r['requestId'] is! String || (r['requestId'] as String).trim().isEmpty) {
      add('INCOMPLETE_DATA', '必填資料不完整或無效：requestId、userId、itemId、正整數 qty');
    }
    if (validUser && validItem) {
      final duplicates = sql.select('''
        SELECT requestId FROM supply_requests
        WHERE userId=? AND itemId=? AND requestId<>?
          AND status IN ('pending','reserved','claimed','dispatched')
        ORDER BY requestId
      ''', [user, item, r['requestId']]);
      if (duplicates.isNotEmpty) {
        reasons.add({
          'code': 'DUPLICATE_OPEN_REQUEST', 'message': '同一使用者對同一物資有其他未結案需求',
          'relatedRequestIds': duplicates.map((d) => d['requestId']).toList(),
        });
      }
    }
    if (validQty && qty > maxRequestQty) {
      reasons.add({'code': 'QTY_LIMIT_EXCEEDED', 'message': '需求數量超過單筆上限', 'limit': maxRequestQty});
    }
    if (validItem && validQty) {
      final rows = sql.select('SELECT stockQty,reservedQty FROM station_inventory WHERE stationId=? AND itemId=?', [communityStationId, item]);
      final stock = rows.isEmpty ? null : rows.first['stockQty'];
      final reserved = rows.isEmpty ? null : rows.first['reservedQty'];
      if (stock is! int || reserved is! int || reserved < 0 || stock < reserved) {
        add('INVENTORY_INVALID', 'OFFICE001 庫存紀錄不存在或資料異常');
      } else if (stock - reserved < qty) {
        reasons.add({'code': 'INSUFFICIENT_STOCK', 'message': 'OFFICE001 可用庫存不足', 'availableQty': stock - reserved, 'requestedQty': qty});
      }
    }
    return reasons;
  }

  List<Map<String, Object?>> _storedReasons(Map<String, Object?> r) {
    final value = r['reviewReasons'];
    if (value is! String || value.isEmpty) return [];
    return (jsonDecode(value) as List).map((v) => Map<String, Object?>.from(v as Map)).toList();
  }

  Map<String, Object?> _flagReview(Database sql, Map<String, Object?> r, List<Map<String, Object?>> reasons) {
    final saved = reasons.isEmpty ? _storedReasons(r) : reasons;
    sql.execute("UPDATE supply_requests SET reviewStatus='needs_review',reviewReasons=? WHERE requestId=? AND status='pending'", [jsonEncode(saved), r['requestId']]);
    return {'blockedByReview': true, 'requestId': r['requestId'], 'reasons': saved};
  }

  Map<String, dynamic> _reservationResult(Map<String, dynamic> result) {
    if (result['blockedByReview'] == true) {
      throw SupplyReviewRequired(List<Map<String, Object?>>.from(result['reasons'] as List));
    }
    return result;
  }

  Map<String, Object?> _request(Database sql, String requestId) {
    if (requestId.trim().isEmpty) {
      throw Exception('requestId 不可為空');
    }
    final rows = sql.select(
      'SELECT * FROM supply_requests WHERE requestId = ?',
      [requestId],
    );
    if (rows.isEmpty) {
      throw Exception('找不到這筆物資需求');
    }
    return Map<String, Object?>.from(rows.first);
  }

  int _quantity(Object? value) {
    if (value is! int || value <= 0) {
      throw Exception('需求數量必須是正整數');
    }
    return value;
  }

  Map<String, dynamic> _officeStock(Database sql, int itemId, int qty) {
    _quantity(qty);
    final rows = sql.select(
      '''
      SELECT si.stockQty, si.reservedQty, st.name AS stationName
      FROM station_inventory si
      JOIN stations st ON st.stationId = si.stationId
      JOIN inventory i ON i.id = si.itemId
      WHERE si.stationId = ? AND si.itemId = ?
    ''',
      [communityStationId, itemId],
    );
    if (rows.isEmpty) {
      throw Exception('OFFICE001 沒有這項物資的庫存資料');
    }
    final stock = rows.first['stockQty'];
    final reserved = rows.first['reservedQty'];
    if (stock is! int || reserved is! int || reserved < 0 || stock < reserved) {
      throw Exception('OFFICE001 庫存資料異常');
    }
    final available = stock - reserved;
    if (available < qty) {
      throw Exception('OFFICE001 可用庫存不足，目前可用：$available，需要：$qty');
    }
    return {
      'stationId': communityStationId,
      'stationName': rows.first['stationName'],
      'stockQty': stock,
      'reservedQty': reserved,
      'availableQty': available,
      'distanceKm': null,
    };
  }

  // Retain the callable method and result keys; location no longer selects a station.
  Future<Map<String, dynamic>> findBestStation({
    required int itemId,
    required int qty,
    double? userLat,
    double? userLng,
  }) async =>
      db.stationTransferTransaction((sql) => _officeStock(sql, itemId, qty));

  Map<String, dynamic> _reserve(Database sql, String requestId, {bool manuallyApproved = false}) {
    final request = _request(sql, requestId);
    if (request['status'] != 'pending') {
      throw Exception('只有 pending 的需求可以預留，不能重複預留');
    }
    final priorStation = request['stationId']?.toString();
    if (priorStation != null &&
        priorStation.isNotEmpty &&
        priorStation != communityStationId) {
      throw Exception('舊據點需求不可直接轉移預留，請先人工核對');
    }
    final reasons = _anomalies(sql, request);
    if (!manuallyApproved && (reasons.isNotEmpty || request['reviewStatus'] == 'needs_review')) {
      return Map<String, dynamic>.from(_flagReview(sql, request, reasons));
    }
    final qty = _quantity(request['qty']);
    final itemId = request['itemId'] as int;
    final office = _officeStock(sql, itemId, qty);
    sql.execute(
      '''
      UPDATE station_inventory SET reservedQty = reservedQty + ?, updatedAt = ?
      WHERE stationId = ? AND itemId = ? AND reservedQty >= 0
        AND stockQty - reservedQty >= ?
    ''',
      [
        qty,
        DateTime.now().toUtc().toIso8601String(),
        communityStationId,
        itemId,
        qty,
      ],
    );
    if (sql.updatedRows != 1) {
      throw Exception('OFFICE001 可用庫存不足，無法預留');
    }
    sql.execute(
      '''
      UPDATE supply_requests SET stationId = ?, status = 'reserved', reservedAt = ?
      WHERE requestId = ? AND status = 'pending'
    ''',
      [communityStationId, DateTime.now().toUtc().toIso8601String(), requestId],
    );
    if (sql.updatedRows != 1) {
      throw Exception('需求狀態已變更，未執行預留');
    }
    return {
      'requestId': requestId,
      'stationId': communityStationId,
      'stationName': office['stationName'],
      'distanceKm': null,
      'availableQtyBeforeReserve': office['availableQty'],
      'status': 'reserved',
    };
  }

  Future<Map<String, dynamic>> autoAssignSupplyRequest({
    required String requestId,
  }) async => _reservationResult(db.stationTransferTransaction((sql) => _reserve(sql, requestId)));

  Future<void> reserveSupplyRequest({required String requestId}) async {
    await autoAssignSupplyRequest(requestId: requestId);
  }

  void _requireAdmin(Database sql, int adminId) {
    if (sql.select('SELECT id FROM admins WHERE id=?', [adminId]).isEmpty) {
      throw InventoryException('管理員帳號已不存在', 403);
    }
  }

  Future<List<Map<String, Object?>>> getSupplyRequestReviews({
    required int adminId, String? requestId,
  }) async => db.stationTransferTransaction((sql) {
    _requireAdmin(sql, adminId);
    final rows = sql.select('''
      SELECT * FROM supply_requests WHERE status='pending' AND stationId=?
      ${requestId == null ? '' : 'AND requestId=?'} ORDER BY createdAt,requestId
    ''', [communityStationId, ?requestId]);
    return rows.map((row) {
      final r = Map<String, Object?>.from(row);
      final reasons = _anomalies(sql, r);
      final required = reasons.isNotEmpty || r['reviewStatus'] == 'needs_review';
      if (required) _flagReview(sql, r, reasons);
      return <String, Object?>{
        'requestId': r['requestId'], 'userId': r['userId'], 'itemId': r['itemId'],
        'qty': r['qty'], 'stationId': r['stationId'], 'status': r['status'],
        'reviewStatus': required ? 'needs_review' : 'not_required',
        'requiresReview': required, 'anomalyReasons': reasons,
        'flaggedReasons': reasons.isEmpty ? _storedReasons(r) : reasons,
        'maxRequestQty': maxRequestQty,
        'reviewedBy': r['reviewedBy'], 'reviewedAt': r['reviewedAt'], 'reviewNote': r['reviewNote'],
      };
    }).toList();
  });

  Future<Map<String, dynamic>> reviewSupplyRequest({
    required int adminId, required String requestId,
    required String decision, required String note,
  }) async {
    if (!['approve', 'defer'].contains(decision) || note.trim().isEmpty) {
      throw InventoryException('decision 必須為 approve/defer，note 不可空白', 400);
    }
    final result = db.stationTransferTransaction<Map<String, dynamic>>((sql) {
      _requireAdmin(sql, adminId);
      final r = _request(sql, requestId);
      if (r['status'] != 'pending' || r['stationId'] != communityStationId ||
          r['volunteerId'] != null || r['claimedAt'] != null ||
          r['assignmentType'] != null || r['assignedBy'] != null) {
        throw InventoryException('僅能審核 OFFICE001 尚未預留的 pending 任務', 409);
      }
      final reasons = _anomalies(sql, r);
      final snapshot = reasons.isEmpty ? _storedReasons(r) : reasons;
      if (decision == 'approve' && reasons.any((v) =>
          ['INCOMPLETE_DATA', 'INVENTORY_INVALID', 'INSUFFICIENT_STOCK'].contains(v['code']))) {
        return Map<String, dynamic>.from(_flagReview(sql, r, reasons));
      }
      Map<String, dynamic>? reservation;
      if (decision == 'approve') {
        reservation = _reserve(sql, requestId, manuallyApproved: true);
      }
      final now = DateTime.now().toUtc().toIso8601String();
      sql.execute('''
        UPDATE supply_requests SET reviewStatus=?,reviewReasons=?,reviewedBy=?,reviewedAt=?,reviewNote=?
        WHERE requestId=? AND status=?
      ''', [decision == 'approve' ? 'approved' : 'needs_review', jsonEncode(snapshot), adminId, now, note,
        requestId, decision == 'approve' ? 'reserved' : 'pending']);
      if (sql.updatedRows != 1) throw InventoryException('需求狀態已變更，審核未寫入', 409);
      return {
        if (reservation != null) ...reservation,
        'requestId': requestId, 'status': decision == 'approve' ? 'reserved' : 'pending',
        'reviewStatus': decision == 'approve' ? 'approved' : 'needs_review',
        'reviewedBy': adminId, 'reviewedAt': now, 'reviewNote': note,
        'reviewReasons': snapshot,
      };
    });
    return _reservationResult(result);
  }

  Future<Map<String, Object?>> batchSupplyRequests({
    required int adminId, required String action, required List<String> requestIds,
  }) async {
    if (!['reserve', 'dispatch', 'complete'].contains(action) ||
        requestIds.isEmpty || requestIds.length > 100 || requestIds.any((id) => id.trim().isEmpty)) {
      throw InventoryException('批次必須為 1～100 個非空 requestId', 400);
    }
    final results = <Map<String, Object?>>[];
    final seen = <String>{};
    for (final id in requestIds) {
      if (!seen.add(id)) {
        results.add({'requestId': id, 'success': false, 'code': 'DUPLICATE_REQUEST_ID', 'message': '同批 requestId 重複，未再次操作'});
        continue;
      }
      try {
        Map<String, Object?> data;
        if (action == 'reserve') {
          data = _reservationResult(db.stationTransferTransaction((sql) {
            _requireAdmin(sql, adminId);
            return _reserve(sql, id);
          }));
        } else if (action == 'dispatch') {
          data = await adminDispatchSupplyRequest(requestId: id, adminId: adminId);
        } else {
          data = await adminCompleteSupplyRequest(requestId: id, adminId: adminId);
        }
        results.add({'requestId': id, 'success': true, 'message': '處理成功', 'data': data});
      } catch (e) {
        results.add({
          'requestId': id, 'success': false,
          'code': e is SupplyReviewRequired ? 'REVIEW_REQUIRED' : 'OPERATION_REJECTED',
          'message': e.toString(), if (e is SupplyReviewRequired) 'anomalyReasons': e.reasons,
        });
      }
    }
    final succeeded = results.where((r) => r['success'] == true).length;
    return {'transactionMode': 'per_request', 'total': results.length,
      'succeeded': succeeded, 'failed': results.length - succeeded, 'results': results};
  }

  Map<String, Object?> _offlineRequest(
    Database sql, String requestId, int adminId, String expectedStatus,
  ) {
    if (sql.select('SELECT id FROM admins WHERE id = ?', [adminId]).isEmpty) {
      throw InventoryException('管理員帳號已不存在', 403);
    }
    final request = _request(sql, requestId);
    if (request['stationId'] != communityStationId ||
        request['status'] != expectedStatus ||
        request['volunteerId'] != null || request['claimedAt'] != null ||
        request['assignmentType'] != null || request['assignedBy'] != null) {
      throw InventoryException('任務狀態不符或屬歷史義工流程，請先人工核對', 409);
    }
    if (expectedStatus == 'reserved' &&
        (request['dispatchedAt'] != null || request['dispatchedBy'] != null ||
         request['completedAt'] != null || request['completedBy'] != null)) {
      throw InventoryException('任務已有出庫或完成紀錄，不可再次出庫', 409);
    }
    if (expectedStatus == 'dispatched' &&
        (request['dispatchedAt'] == null || request['dispatchedBy'] == null ||
         request['completedAt'] != null || request['completedBy'] != null)) {
      throw InventoryException('非新管理員流程出庫紀錄或已結案，請先人工核對', 409);
    }
    return request;
  }

  Future<Map<String, Object?>> adminDispatchSupplyRequest({
    required String requestId, required int adminId,
  }) async => db.stationTransferTransaction((sql) {
    final request = _offlineRequest(sql, requestId, adminId, 'reserved');
    final qty = _quantity(request['qty']);
    final now = DateTime.now().toUtc().toIso8601String();
    sql.execute('''
      UPDATE station_inventory
      SET stockQty = stockQty - ?, reservedQty = reservedQty - ?, updatedAt = ?
      WHERE stationId = ? AND itemId = ? AND stockQty >= ? AND reservedQty >= ?
        AND stockQty >= reservedQty
        AND typeof(stockQty) = 'integer' AND typeof(reservedQty) = 'integer'
        AND EXISTS (SELECT 1 FROM inventory WHERE id = ?)
    ''', [qty, qty, now, communityStationId, request['itemId'], qty, qty, request['itemId']]);
    if (sql.updatedRows != 1) {
      throw InventoryException('OFFICE001 庫存／預留不足、異常或物資不存在', 409);
    }
    sql.execute('''
      UPDATE supply_requests
      SET status = 'dispatched', dispatchedAt = ?, dispatchedBy = ?
      WHERE requestId = ? AND status = 'reserved' AND volunteerId IS NULL
        AND dispatchedAt IS NULL AND dispatchedBy IS NULL
    ''', [now, adminId, requestId]);
    if (sql.updatedRows != 1) {
      throw InventoryException('任務狀態已變更，未執行出庫', 409);
    }
    return {
      'requestId': requestId, 'stationId': communityStationId,
      'itemId': request['itemId'], 'qty': qty, 'status': 'dispatched',
      'dispatchedAt': now, 'dispatchedBy': adminId,
    };
  });

  Future<Map<String, Object?>> adminCompleteSupplyRequest({
    required String requestId, required int adminId,
  }) async => db.stationTransferTransaction((sql) {
    _offlineRequest(sql, requestId, adminId, 'dispatched');
    final now = DateTime.now().toUtc().toIso8601String();
    sql.execute('''
      UPDATE supply_requests SET status = 'completed', completedAt = ?, completedBy = ?
      WHERE requestId = ? AND status = 'dispatched'
        AND dispatchedBy IS NOT NULL AND completedAt IS NULL
    ''', [now, adminId, requestId]);
    if (sql.updatedRows != 1) {
      throw InventoryException('任務狀態已變更，未執行結案', 409);
    }
    return {
      'requestId': requestId, 'stationId': communityStationId,
      'status': 'completed', 'completedAt': now, 'completedBy': adminId,
    };
  });

  Future<void> claimSupplyRequest({
    required String requestId,
    required String volunteerId,
    required String stationId,
  }) async {
    _claim(requestId: requestId, volunteerId: volunteerId, stationId: stationId);
  }

  /// Called only by the authenticated admin HTTP handler.
  Future<Map<String, Object?>> assignSupplyRequestVolunteer({
    required String requestId,
    required String volunteerId,
    required int adminId,
  }) async => _claim(
    requestId: requestId,
    volunteerId: volunteerId,
    stationId: communityStationId,
    adminId: adminId,
  );

  Map<String, Object?> _claim({
    required String requestId,
    required String volunteerId,
    required String stationId,
    int? adminId,
  }) {
    if (volunteerId.trim().isEmpty || stationId.trim().isEmpty) {
      throw Exception('volunteerId、stationId 不可為空');
    }
    return db.stationTransferTransaction((sql) {
      if (adminId != null &&
          sql.select('SELECT id FROM admins WHERE id = ?', [adminId]).isEmpty) {
        throw Exception('管理員不存在');
      }
      final request = _request(sql, requestId);
      if (request['status'] != 'reserved') {
        throw Exception('這筆需求目前無法認領');
      }
      if (request['stationId'] == null || request['stationId'] != stationId) {
        throw Exception('需求據點與義工據點不符');
      }
      if (request['volunteerId'] != null) {
        throw Exception('任務已有認領者，不可覆蓋');
      }
      final assignmentType = adminId == null ? 'self_claimed' : 'admin_assigned';
      final claimedAt = DateTime.now().toUtc().toIso8601String();
      sql.execute(
        '''
        UPDATE supply_requests SET status = 'claimed', volunteerId = ?, claimedAt = ?,
          assignmentType = ?, assignedBy = ?
        WHERE requestId = ? AND status = 'reserved' AND volunteerId IS NULL
      ''',
        [volunteerId, claimedAt, assignmentType, adminId, requestId],
      );
      if (sql.updatedRows != 1) {
        throw Exception('需求狀態已變更，無法認領');
      }
      return {
        'requestId': requestId,
        'volunteerId': volunteerId,
        'stationId': stationId,
        'status': 'claimed',
        'claimedAt': claimedAt,
        'assignmentType': assignmentType,
        'assignedBy': adminId,
      };
    });
  }

  Future<List<Map<String, Object?>>> getPendingSupplyRequests({
    required String stationId,
  }) async {
    final result = await db.select(
      '''

      SELECT

        sr.requestId,

        sr.userId,

        sr.itemId,

        i.name AS itemName,

        i.unit,

        sr.qty,

        sr.lat,

        sr.lng,

        sr.address,

        sr.status,

        sr.createdAt,

        sr.stationId,

        s.name AS stationName

      FROM supply_requests sr

      LEFT JOIN inventory i

        ON sr.itemId = i.id

      LEFT JOIN stations s

        ON sr.stationId = s.stationId

      WHERE sr.status = ?

        AND sr.stationId = ?

      ORDER BY sr.createdAt ASC

      ''',

      ['reserved', stationId],
    );

    return result.toList();
  }

  // =========================================================

  // 4. 取得某位義工「我的配送」

  // =========================================================

  Future<List<Map<String, Object?>>> getVolunteerClaims({
    required String volunteerId,
    required String stationId,
  }) async {
    final result = await db.select(
      '''
      SELECT
        sr.requestId, sr.userId, sr.itemId,
        i.name AS itemName, i.unit, sr.qty, sr.lat, sr.lng, sr.address,
        sr.status, sr.createdAt, sr.claimedAt, sr.stationId,
        sr.volunteerId, sr.assignmentType, sr.assignedBy, sr.completedAt,
        st.name AS stationName
      FROM supply_requests sr
      LEFT JOIN inventory i ON sr.itemId = i.id
      LEFT JOIN stations st ON sr.stationId = st.stationId
      WHERE sr.volunteerId = ?
        AND sr.stationId = ?
        AND sr.status IN ('claimed', 'dispatched', 'completed')
      ORDER BY sr.claimedAt DESC
      ''',
      [volunteerId, stationId],
    );
    return result.toList();
  }

  Future<List<Map<String, Object?>>> getVolunteerHistory({
    required String volunteerId,
    required String stationId,
  }) async {
    final result = await db.select(
      '''
      SELECT
        sr.requestId,
        sr.userId,
        sr.itemId,
        i.name AS itemName,
        i.unit,
        sr.qty,
        sr.lat,
        sr.lng,
        sr.address,
        sr.status,
        sr.createdAt,
        sr.claimedAt,
        sr.completedAt,
        sr.volunteerId,
        sr.assignmentType,
        sr.assignedBy,
        sr.stationId,
        st.name AS stationName
      FROM supply_requests sr
      LEFT JOIN inventory i
        ON sr.itemId = i.id
      LEFT JOIN stations st
        ON sr.stationId = st.stationId
      WHERE sr.volunteerId = ?
        AND sr.stationId = ?
        AND sr.status = 'completed'
      ORDER BY sr.completedAt DESC
      ''',
      [volunteerId, stationId],
    );

    return result.toList();
  }

  // =========================================================

  // 5. 義工取消認領

  // claimed → reserved

  // 不改 stockQty，也不改 reservedQty

  // 因為物資仍然保留給這筆需求

  // =========================================================

  Map<String, Object?> _ownedRequest(
    Database sql,
    String requestId,
    String volunteerId,
    String stationId,
    String expectedStatus,
  ) {
    if (volunteerId.trim().isEmpty || stationId.trim().isEmpty) {
      throw Exception('volunteerId、stationId 不可為空');
    }
    final request = _request(sql, requestId);
    if (request['status'] != expectedStatus) {
      throw Exception('需求狀態不符，不能重複操作或跳過階段');
    }
    if (request['volunteerId'] != volunteerId) {
      throw Exception('無法處理其他義工的配送任務');
    }
    if (request['stationId'] != stationId) {
      throw Exception('無法處理其他據點的任務');
    }
    return request;
  }

  Future<void> cancelClaim({
    required String requestId,
    required String volunteerId,
    required String stationId,
  }) async {
    db.stationTransferTransaction((sql) {
      _ownedRequest(sql, requestId, volunteerId, stationId, 'claimed');
      sql.execute(
        '''
        UPDATE supply_requests SET status = 'reserved', volunteerId = NULL, claimedAt = NULL,
          assignmentType = NULL, assignedBy = NULL
        WHERE requestId = ?
      ''',
        [requestId],
      );
    });
  }

  Future<Map<String, dynamic>> dispatchSupplyRequest({
    required String requestId,
    required String volunteerId,
    required String stationId,
  }) async => db.stationTransferTransaction((sql) {
    // Old assigned tasks keep their original station; newly inserted tasks are OFFICE001.
    final request = _ownedRequest(
      sql,
      requestId,
      volunteerId,
      stationId,
      'claimed',
    );
    final qty = _quantity(request['qty']);
    final itemId = request['itemId'] as int;
    final items = sql.select('SELECT name, unit FROM inventory WHERE id = ?', [
      itemId,
    ]);
    if (items.isEmpty) {
      throw Exception('找不到物資主檔');
    }
    final now = DateTime.now().toUtc().toIso8601String();
    sql.execute(
      '''
      UPDATE station_inventory
      SET stockQty = stockQty - ?, reservedQty = reservedQty - ?, updatedAt = ?
      WHERE stationId = ? AND itemId = ? AND stockQty >= ? AND reservedQty >= ?
        AND stockQty >= reservedQty
        AND typeof(stockQty) = 'integer' AND typeof(reservedQty) = 'integer'
    ''',
      [qty, qty, now, stationId, itemId, qty, qty],
    );
    if (sql.updatedRows != 1) {
      throw Exception('據點實際庫存或預留量不足／異常，無法取貨');
    }
    sql.execute(
      "UPDATE supply_requests SET status = 'dispatched' WHERE requestId = ? AND status = 'claimed'",
      [requestId],
    );
    if (sql.updatedRows != 1) {
      throw Exception('需求狀態已變更，未執行取貨');
    }
    return {
      'requestId': requestId,
      'stationId': stationId,
      'itemId': itemId,
      'itemName': items.first['name'],
      'unit': items.first['unit'],
      'qty': qty,
      'status': 'dispatched',
    };
  });

  Future<Map<String, dynamic>> completeSupplyRequest({
    required String requestId,
    required String volunteerId,
    required String stationId,
  }) async => db.stationTransferTransaction((sql) {
    _ownedRequest(sql, requestId, volunteerId, stationId, 'dispatched');
    sql.execute(
      '''
      UPDATE supply_requests SET status = 'completed', completedAt = ?
      WHERE requestId = ? AND status = 'dispatched'
    ''',
      [DateTime.now().toUtc().toIso8601String(), requestId],
    );
    if (sql.updatedRows != 1) {
      throw Exception('需求狀態已變更，無法完成');
    }
    return {'requestId': requestId, 'status': 'completed'};
  });
}
