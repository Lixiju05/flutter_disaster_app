import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';
import 'package:admin_server/database/database_service.dart';

class StationTransferException implements Exception {
  final String message;
  final int statusCode;
  StationTransferException(this.message, [this.statusCode = 400]);
  @override
  String toString() => message;
}

/// Separate from allocations and civilian/volunteer requests.
class StationTransferService {
  final DatabaseService db;
  StationTransferService(this.db);

  Map<String, Object?> _transfer(Database sql, String id) {
    final rows = sql.select(
      'SELECT * FROM station_transfers WHERE transferId = ?',
      [id],
    );
    if (rows.isEmpty) throw StationTransferException('找不到調度單', 404);
    return Map<String, Object?>.from(rows.first);
  }

  void _station(Database sql, String id, String type) {
    final rows = sql.select('SELECT type FROM stations WHERE stationId = ?', [
      id,
    ]);
    if (rows.isEmpty) throw StationTransferException('據點不存在：$id', 404);
    if (rows.first['type'] != type) {
      throw StationTransferException('據點類型不符合調度方向');
    }
  }

  void _item(Database sql, int id) {
    if (sql.select('SELECT id FROM inventory WHERE id = ?', [id]).isEmpty) {
      throw StationTransferException('物資不存在', 404);
    }
  }

  Map<String, Object?> create({
    required String fromStationId,
    required String toStationId,
    required int itemId,
    required int qty,
    required String createdBy,
  }) {
    if (qty <= 0) throw StationTransferException('調度數量必須大於 0');
    if (fromStationId == toStationId) {
      throw StationTransferException('來源與目的據點不能相同');
    }
    if (fromStationId != 'OFFICE001') {
      throw StationTransferException('來源必須是 OFFICE001 物資中心');
    }
    if (!const ['S001', 'S002'].contains(toStationId)) {
      throw StationTransferException('目的據點必須是 S001 或 S002');
    }
    if (createdBy.trim().isEmpty) {
      throw StationTransferException('createdBy 不可為空');
    }
    return db.stationTransferTransaction((sql) {
      _station(sql, fromStationId, 'office');
      _station(sql, toStationId, 'shelter');
      _item(sql, itemId);
      final now = DateTime.now().toUtc().toIso8601String();
      sql.execute(
        '''
        UPDATE station_inventory SET reservedQty = reservedQty + ?, updatedAt = ?
        WHERE stationId = ? AND itemId = ? AND reservedQty >= 0
          AND stockQty >= reservedQty AND stockQty - reservedQty >= ?
      ''',
        [qty, now, fromStationId, itemId, qty],
      );
      if (sql.updatedRows != 1) {
        throw StationTransferException('物資中心可用庫存不足或庫存資料異常', 409);
      }
      final id = const Uuid().v4();
      sql.execute(
        '''
        INSERT INTO station_transfers
          (transferId, fromStationId, toStationId, itemId, qty, status, createdBy, createdAt)
        VALUES (?, ?, ?, ?, ?, 'reserved', ?, ?)
      ''',
        [id, fromStationId, toStationId, itemId, qty, createdBy, now],
      );
      return _transfer(sql, id);
    });
  }

  Map<String, Object?> ship(
    String transferId,
  ) => db.stationTransferTransaction((sql) {
    final transfer = _transfer(sql, transferId);
    if (transfer['status'] != 'reserved') {
      throw StationTransferException('只有 reserved 調度單可以出貨，不能重複出貨', 409);
    }
    _station(sql, transfer['fromStationId'] as String, 'office');
    _item(sql, transfer['itemId'] as int);
    final qty = transfer['qty'] as int;
    final now = DateTime.now().toUtc().toIso8601String();
    sql.execute(
      '''
      UPDATE station_inventory
      SET stockQty = stockQty - ?, reservedQty = reservedQty - ?, updatedAt = ?
      WHERE stationId = ? AND itemId = ? AND stockQty >= ? AND reservedQty >= ?
        AND stockQty >= reservedQty
    ''',
      [qty, qty, now, transfer['fromStationId'], transfer['itemId'], qty, qty],
    );
    if (sql.updatedRows != 1) {
      throw StationTransferException('來源實際庫存或預留量不足，無法出貨', 409);
    }
    sql.execute(
      "UPDATE station_transfers SET status = 'shipped', shippedAt = ? WHERE transferId = ?",
      [now, transferId],
    );
    return _transfer(sql, transferId);
  });

  Map<String, Object?> receive(
    String transferId,
  ) => db.stationTransferTransaction((sql) {
    final transfer = _transfer(sql, transferId);
    if (transfer['status'] != 'shipped') {
      throw StationTransferException('只有 shipped 調度單可以收貨，不能提前或重複收貨', 409);
    }
    final station = transfer['toStationId'] as String;
    final item = transfer['itemId'] as int;
    _station(sql, station, 'shelter');
    _item(sql, item);
    final rows = sql.select(
      'SELECT stockQty, reservedQty FROM station_inventory WHERE stationId = ? AND itemId = ?',
      [station, item],
    );
    if (rows.isNotEmpty) {
      final stock = rows.first['stockQty'] as int;
      final reserved = rows.first['reservedQty'] as int;
      if (stock < 0 || reserved < 0 || stock < reserved) {
        throw StationTransferException('目的據點庫存資料異常，請先核對', 409);
      }
    }
    final now = DateTime.now().toUtc().toIso8601String();
    sql.execute(
      '''
      INSERT INTO station_inventory (stationId, itemId, stockQty, reservedQty, updatedAt)
      VALUES (?, ?, ?, 0, ?)
      ON CONFLICT(stationId, itemId) DO UPDATE SET
        stockQty = station_inventory.stockQty + excluded.stockQty,
        updatedAt = excluded.updatedAt
    ''',
      [station, item, transfer['qty'], now],
    );
    sql.execute(
      "UPDATE station_transfers SET status = 'received', receivedAt = ? WHERE transferId = ?",
      [now, transferId],
    );
    return _transfer(sql, transferId);
  });

  /// Reads the same stock rows used by transfers and volunteer deliveries.
  List<Map<String, Object?>> getStationInventory(String stationId) {
    if (stationId.trim().isEmpty) {
      throw StationTransferException('stationId 必須是非空字串');
    }
    return db.stationTransferTransaction((sql) {
      if (sql.select('SELECT stationId FROM stations WHERE stationId = ?', [
        stationId,
      ]).isEmpty) {
        throw StationTransferException('據點不存在', 404);
      }
      return sql
          .select(
            '''
        SELECT si.stationId, si.itemId, i.name AS itemName, i.unit,
               si.stockQty, si.reservedQty,
               si.stockQty - si.reservedQty AS availableQty, si.updatedAt
        FROM station_inventory si
        JOIN inventory i ON i.id = si.itemId
        WHERE si.stationId = ?
        ORDER BY si.itemId
      ''',
            [stationId],
          )
          .map((row) => Map<String, Object?>.from(row))
          .toList();
    });
  }

  Future<List<Map<String, Object?>>> getTransfers({
    String? stationId,
    String? status,
  }) async {
    if (status != null &&
        !const ['reserved', 'shipped', 'received'].contains(status)) {
      throw StationTransferException('status 必須是 reserved、shipped 或 received');
    }
    if (stationId != null &&
        (await db.select('SELECT stationId FROM stations WHERE stationId = ?', [
          stationId,
        ])).isEmpty) {
      throw StationTransferException('據點不存在', 404);
    }
    final rows = await db.select(
      '''
      SELECT t.*, f.name AS fromStationName, d.name AS toStationName,
             i.name AS itemName, i.unit
      FROM station_transfers t
      LEFT JOIN stations f ON f.stationId = t.fromStationId
      LEFT JOIN stations d ON d.stationId = t.toStationId
      LEFT JOIN inventory i ON i.id = t.itemId
      WHERE (? IS NULL OR t.fromStationId = ? OR t.toStationId = ?)
        AND (? IS NULL OR t.status = ?)
      ORDER BY t.createdAt DESC, t.transferId
    ''',
      [stationId, stationId, stationId, status, status],
    );
    return rows.map((row) => Map<String, Object?>.from(row)).toList();
  }
}
