import 'package:admin_server/database/database_service.dart';

class AllocationService {
  // 建議 C：統一使用構造函數注入的實例，不直接調用靜態變數
  final DatabaseService db;

  AllocationService(this.db);

  /// 分配物資（核心邏輯）
  Future<void> allocate({
    required int itemId,
    required String zoneId,
    required int qty,
  }) async {
    // 建議 A：使用 Transaction 確保原子性（Atomicity）
    // 確保庫存更新與紀錄新增「要嘛全成功，要嘛全回滾」
    await db.transaction(() async {
      // 1. 查詢最新庫存狀況
      final result = await db.select(
        'SELECT stockQty, reservedQty FROM inventory WHERE id = ?',
        [itemId],
      );

      if (result.isEmpty) {
        throw Exception("物資不存在 (ID: $itemId)");
      }

      final item = result.first;
      final stock = item['stockQty'] as int;
      final reserved = item['reservedQty'] as int;
      final available = stock - reserved;

      // 2. 檢查可用庫存
      if (available < qty) {
        throw Exception("庫存不足！目前可用：$available，請求分配：$qty");
      }

      final now = DateTime.now().toIso8601String();

      // 3. 更新預留庫存 (使用實例變數 db)
      await db.execute(
        '''
        UPDATE inventory 
        SET reservedQty = reservedQty + ?, 
            updatedAt = ? 
        WHERE id = ?
        ''',
        [qty, now, itemId],
      );
      

      // 4. 建立分配紀錄
      await db.execute(
        '''
        INSERT INTO allocations (itemId, zoneId, quantity, status, createdAt) 
        VALUES (?, ?, ?, ?, ?)
        ''',
        [itemId, zoneId, qty, 'reserved', now],
      );
    });
  }

  /// 取得所有分配紀錄
  Future<List<Map<String, Object?>>> getAllAllocations() async {
    // 建議 C：移除對 DatabaseService.db 的依賴
    final results = await db.select(
      'SELECT * FROM allocations ORDER BY createdAt DESC'
    );
    return results.toList();
  }

  /// 取消分配
  Future<void> cancelAllocation(int allocationId) async {
    await db.transaction(() async {
      // 1. 查找該筆紀錄
      final result = await db.select(
        'SELECT itemId, quantity, status FROM allocations WHERE id = ?',
        [allocationId],
      );

      if (result.isEmpty) return;

      final alloc = result.first;
      
      // 檢查是否已經取消過，避免重複釋放庫存
      if (alloc['status'] == 'cancelled') return;

      final itemId = alloc['itemId'] as int;
      final qty = alloc['quantity'] as int;

      // 2. 釋放預留庫存
      await db.execute(
        'UPDATE inventory SET reservedQty = reservedQty - ? WHERE id = ?',
        [qty, itemId],
      );

      // 3. 更新分配狀態為已取消
      await db.execute(
        "UPDATE allocations SET status = 'cancelled' WHERE id = ?",
        [allocationId],
      );
    });
  }
}