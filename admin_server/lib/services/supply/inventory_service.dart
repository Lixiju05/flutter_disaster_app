import 'package:admin_server/database/database_service.dart';

class InventoryService {
  final DatabaseService db;
  InventoryService(this.db);

  /// 取得所有物資 
  Future<List<Map<String, Object?>>> getAllItems() async {
    // 雖然 sqlite3 本身是同步的，但在 Service 層使用 Future 
    // 可以讓外層的 API Handler 平滑對接 async 流程
    final result =await DatabaseService.instance.select(
      'SELECT * FROM inventory ORDER BY updatedAt DESC'
    );
    return result.toList();
  }

  ///  取得單一物資
  Future<Map<String, Object?>?> getItem(int id) async {
    final result =await DatabaseService.instance.select(
      'SELECT * FROM inventory WHERE id = ?',
      [id],
    );
    return result.isEmpty ? null : result.first;
  }

  /// 新增物資 
  Future<void> addItem({
    required String name,
    required String category,
    required String unit,
    required int stockQty,
    int neededQty = 0,
  }) async {
    DatabaseService.instance.execute(
      '''
      INSERT INTO inventory (
        name, category, unit, 
        stockQty, reservedQty, neededQty, 
        updatedAt
      ) 
      VALUES (?, ?, ?, ?, 0, ?, CURRENT_TIMESTAMP)
      ''',
      [name, category, unit, stockQty, neededQty],
    );
  }

  /// 補貨（入庫） 
  Future<void> addStock(int itemId, int qty) async {
    final item = await getItem(itemId);
    if (item == null) throw Exception("找不到該物資 (ID: $itemId)");

    DatabaseService.instance.execute(
      '''
      UPDATE inventory 
      SET stockQty = stockQty + ?, 
          updatedAt = CURRENT_TIMESTAMP 
      WHERE id = ?
      ''',
      [qty, itemId],
    );
  }

  Future<void> updateNeeded(int itemId, int neededQty) async {
    final item = await getItem(itemId);
    if (item == null) throw Exception("找不到該物資，無法更新需求量");

    DatabaseService.instance.execute(
      '''
      UPDATE inventory 
      SET neededQty = ?, 
          updatedAt = CURRENT_TIMESTAMP 
      WHERE id = ?
      ''',
      [neededQty, itemId],
    );
  }

  /// 計算可用庫存 
  Future<int> getAvailable(int itemId) async {
    final result =await DatabaseService.instance.select(
      'SELECT stockQty, reservedQty FROM inventory WHERE id = ?',
      [itemId],
    );

    if (result.isEmpty) return 0;

    final row = result.first;
    final stock = row['stockQty'] as int;
    final reserved = row['reservedQty'] as int;

    return stock - reserved;
  }

  /// 刪除物資 
  Future<void> deleteItem(int itemId) async {
    final item = await getItem(itemId);
    if (item == null) return;

    final stock = item['stockQty'] as int;
    final reserved = item['reservedQty'] as int;

    if (stock > 0 || reserved > 0) {
      throw Exception("該物資尚有庫存或正在分配中，無法刪除。");
    }

    DatabaseService.instance.execute(
      'DELETE FROM inventory WHERE id = ?',
      [itemId],
    );
  }
}