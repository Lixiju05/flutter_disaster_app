import 'package:admin_server/database/database_service.dart';

class SupplyRequestService {
  final DatabaseService db;

  SupplyRequestService(this.db);

  Future<void> claimSupplyRequest({
    required String requestId,
    required String volunteerId,
  }) async {
    await db.transaction(() async {
      // 1. 找物資需求
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

      // 2. 確認目前是不是 pending
      final status = request['status']?.toString();

      if (status != 'pending') {
        throw Exception('這筆需求已經被認領或無法認領');
      }

      // 3. 取得需求的物資 ID 和數量
      final itemId = request['itemId'] as int;
      final qty = request['qty'] as int;

      if (qty <= 0) {
        throw Exception('需求數量無效');
      }

      // 4. 查詢庫存
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

      // 5. 確認庫存夠不夠
      if (stockQty < qty) {
        throw Exception(
          '庫存不足，目前庫存：$stockQty，需要：$qty',
        );
      }

      final now = DateTime.now().toIso8601String();

      // 6. 認領後直接扣庫存
      await db.execute(
        '''
        UPDATE inventory
        SET stockQty = stockQty - ?,
            updatedAt = ?
        WHERE id = ?
        ''',
        [qty, now, itemId],
      );

      // 7. 更新需求狀態
      await db.execute(
        '''
        UPDATE supply_requests
        SET status = 'claimed',
            volunteerId = ?,
            claimedAt = ?
        WHERE requestId = ?
        ''',
        [volunteerId, now, requestId],
      );
    });
  }
}