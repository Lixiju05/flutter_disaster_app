import 'package:admin_server/database/database_service.dart';

class DispatchService {
  final DatabaseService db;

  DispatchService(this.db);

  // 出貨（核心）
  Future<void> dispatch({
    required int allocationId,
  }) async {

    // 找 allocation
    final allocResult =await DatabaseService.instance.select(
      'SELECT * FROM allocations WHERE id = ?',
      [allocationId],
    );

    if (allocResult.isEmpty) {
      throw Exception("找不到 allocation");
    }

    final allocation = allocResult.first;

    final itemId = allocation['itemId'] as int;
    final qty = allocation['quantity'] as int;
    final status = allocation['status'] as String;

    if (status == 'shipped') {
      throw Exception("已經出貨過了");
    }

    // 找 inventory
    final itemResult =await DatabaseService.instance.select(
      'SELECT * FROM inventory WHERE id = ?',
      [itemId],
    );

    if (itemResult.isEmpty) {
      throw Exception("物資不存在");
    }

    final item = itemResult.first;

    final stock = item['stockQty'] as int;
    final reserved = item['reservedQty'] as int;

    // 安全檢查
    if (stock < qty) {
      throw Exception("庫存不足(stock異常)");
    }

    if (reserved < qty) {
      throw Exception("預留數量不足(reserved異常)");
    }

    // 更新 inventory（真正扣庫存）
    DatabaseService.instance.execute(
      '''
      UPDATE inventory
      SET stockQty = stockQty - ?,
          reservedQty = reservedQty - ?,
          updatedAt = ?
      WHERE id = ?
      ''',
      [
        qty,
        qty,
        DateTime.now().toIso8601String(),
        itemId,
      ],
    );

    // 更新 allocation 狀態
    DatabaseService.instance.execute(
      '''
      UPDATE allocations
      SET status = 'shipped'
      WHERE id = ?
      ''',
      [allocationId],
    );
  }

  //查出貨紀錄
  Future <List<Map<String, Object?>>> getAllDispatch() async{
    return (await DatabaseService.instance.select('''
      SELECT * FROM allocations
      WHERE status = 'shipped'
      ORDER BY id DESC
    ''')).toList();
  }
}