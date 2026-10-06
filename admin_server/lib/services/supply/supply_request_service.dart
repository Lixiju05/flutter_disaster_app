import 'package:admin_server/database/database_service.dart';

class SupplyRequestService {
  final DatabaseService db;

  SupplyRequestService(this.db);

  // =========================================================
  // 1. 預留物資
  // pending → reserved
  // reservedQty += qty
  // =========================================================
  Future<void> reserveSupplyRequest({
    required String requestId,
  }) async {
    await db.transaction(() async {
      // 找需求
      final requestResult = await db.select(
        '''
        SELECT *
        FROM supply_requests
        WHERE requestId = ?
        ''',
        [requestId],
      );

      if (requestResult.isEmpty) {
        throw Exception('找不到這筆物資需求');
      }

      final request = requestResult.first;
      final status = request['status']?.toString();

      // 只有 pending 可以預留
      if (status != 'pending') {
        throw Exception('這筆需求目前無法預留');
      }

      final itemId = request['itemId'] as int;
      final qty = request['qty'] as int;

      if (qty <= 0) {
        throw Exception('需求數量無效');
      }

      // 查庫存
      final itemResult = await db.select(
        '''
        SELECT *
        FROM inventory
        WHERE id = ?
        ''',
        [itemId],
      );

      if (itemResult.isEmpty) {
        throw Exception('找不到這項物資');
      }

      final item = itemResult.first;

      final stockQty = item['stockQty'] as int;
      final reservedQty = item['reservedQty'] as int;

      // 可用庫存 = 實際庫存 - 已預留
      final availableQty = stockQty - reservedQty;

      if (availableQty < qty) {
        throw Exception(
          '可用庫存不足，目前可用：$availableQty，需要：$qty',
        );
      }

      final now = DateTime.now().toIso8601String();

      // 增加預留數量
      await db.execute(
        '''
        UPDATE inventory
        SET reservedQty = reservedQty + ?,
            updatedAt = ?
        WHERE id = ?
        ''',
        [
          qty,
          now,
          itemId,
        ],
      );

      // 需求變成 reserved
      await db.execute(
        '''
        UPDATE supply_requests
        SET status = 'reserved'
        WHERE requestId = ?
        ''',
        [requestId],
      );
    });
  }

  // =========================================================
  // 2. 義工認領
  // reserved → claimed
  // 這裡不扣 stockQty，因為物資只是被認領，還沒有真正出庫
  // =========================================================
  Future<void> claimSupplyRequest({
    required String requestId,
    required String volunteerId,
  }) async {
    await db.transaction(() async {
      final requestResult = await db.select(
        '''
        SELECT *
        FROM supply_requests
        WHERE requestId = ?
        ''',
        [requestId],
      );

      if (requestResult.isEmpty) {
        throw Exception('找不到這筆物資需求');
      }

      final request = requestResult.first;
      final status = request['status']?.toString();

      // 只有已經預留物資的需求可以認領
      if (status != 'reserved') {
        throw Exception('這筆需求目前無法認領');
      }

      final now = DateTime.now().toIso8601String();

      await db.execute(
        '''
        UPDATE supply_requests
        SET status = 'claimed',
            volunteerId = ?,
            claimedAt = ?
        WHERE requestId = ?
        ''',
        [
          volunteerId,
          now,
          requestId,
        ],
      );
    });
  }

  // =========================================================
  // 3. 取得等待義工認領的任務
  // 注意：現在要抓 reserved，不是 pending
  // =========================================================
  Future<List<Map<String, Object?>>>
      getPendingSupplyRequests() async {
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
        sr.createdAt
      FROM supply_requests sr
      LEFT JOIN inventory i
        ON sr.itemId = i.id
      WHERE sr.status = ?
      ORDER BY sr.createdAt ASC
      ''',
      ['reserved'],
    );

    return result.toList();
  }

  // =========================================================
  // 4. 取得某位義工「我的配送」
  // =========================================================
  Future<List<Map<String, Object?>>> getVolunteerClaims(
    String volunteerId,
  ) async {
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
        sr.claimedAt
      FROM supply_requests sr
      LEFT JOIN inventory i
        ON sr.itemId = i.id
      WHERE sr.volunteerId = ?
        AND sr.status = 'claimed'
      ORDER BY sr.claimedAt DESC
      ''',
      [volunteerId],
    );

    return result.toList();
  }

  // =========================================================
  // 5. 義工取消認領
  // claimed → reserved
  // 不改 stockQty，也不改 reservedQty
  // 因為物資仍然保留給這筆需求
  // =========================================================
  Future<void> cancelClaim({
    required String requestId,
    required String volunteerId,
  }) async {
    await db.transaction(() async {
      final requestResult = await db.select(
        '''
        SELECT *
        FROM supply_requests
        WHERE requestId = ?
        ''',
        [requestId],
      );

      if (requestResult.isEmpty) {
        throw Exception('找不到這筆物資需求');
      }

      final request = requestResult.first;

      final status =
          request['status']?.toString();

      final currentVolunteerId =
          request['volunteerId']?.toString();

      // 只有 claimed 可以取消認領
      if (status != 'claimed') {
        throw Exception('這筆需求目前不是已認領狀態');
      }

      // 只能取消自己的任務
      if (currentVolunteerId != volunteerId) {
        throw Exception('你無法取消其他義工的配送任務');
      }

      // 回到 reserved，等待其他義工認領
      await db.execute(
        '''
        UPDATE supply_requests
        SET status = 'reserved',
            volunteerId = NULL,
            claimedAt = NULL
        WHERE requestId = ?
        ''',
        [requestId],
      );
    });
  }
}