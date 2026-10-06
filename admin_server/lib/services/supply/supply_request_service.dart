import 'package:admin_server/database/database_service.dart';

import 'dart:math';



class SupplyRequestService {



  double _calculateDistance(

    double lat1,

    double lng1,

    double lat2,

    double lng2,

  ) {

    const earthRadiusKm = 6371.0;



    final dLat = (lat2 - lat1) * pi / 180;

    final dLng = (lng2 - lng1) * pi / 180;



    final a =

        sin(dLat / 2) * sin(dLat / 2) +

        cos(lat1 * pi / 180) *

            cos(lat2 * pi / 180) *

            sin(dLng / 2) *

            sin(dLng / 2);



    final c = 2 * atan2(sqrt(a), sqrt(1 - a));



    return earthRadiusKm * c;

  }

  final DatabaseService db;



  SupplyRequestService(this.db);



  Future<Map<String, dynamic>> findBestStation({

    required int itemId,

    required int qty,

    required double userLat,

    required double userLng,

  }) async {

    if (qty <= 0) {

      throw Exception('需求數量無效');

    }



    // 找出所有 shelter，以及該物資在各 shelter 的庫存

    final result = await db.select(

      '''

      SELECT

        s.stationId,

        s.name,

        s.lat,

        s.lng,

        si.stockQty,

        si.reservedQty

      FROM stations s

      JOIN station_inventory si

        ON s.stationId = si.stationId

      WHERE s.type = 'shelter'

        AND si.itemId = ?

      ''',

      [itemId],

    );



    if (result.isEmpty) {

      throw Exception('目前沒有收容中心提供這項物資');

    }



    Map<String, dynamic>? bestStation;

    double? shortestDistance;



    for (final row in result) {

      final stockQty = row['stockQty'] as int;

      final reservedQty = row['reservedQty'] as int;



      final availableQty = stockQty - reservedQty;



      // 庫存不夠就直接跳過

      if (availableQty < qty) {

        continue;

      }



      final stationLat = (row['lat'] as num).toDouble();

      final stationLng = (row['lng'] as num).toDouble();



      final distance = _calculateDistance(

        userLat,

        userLng,

        stationLat,

        stationLng,

      );



      // 第一間符合，或這間比目前找到的更近

      if (shortestDistance == null ||

          distance < shortestDistance) {

        shortestDistance = distance;



        bestStation = {

          'stationId': row['stationId'],

          'stationName': row['name'],

          'stockQty': stockQty,

          'reservedQty': reservedQty,

          'availableQty': availableQty,

          'distanceKm': distance,

        };

      }

    }



    if (bestStation == null) {

      throw Exception('目前沒有庫存足夠的收容中心');

    }



    return bestStation;

  }



  Future<Map<String, dynamic>> autoAssignSupplyRequest({

    required String requestId,

  }) async {

    // 1. 取得需求

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



    if (status != 'pending') {

      throw Exception('只有 pending 的需求可以自動分配');

    }



    final itemId = request['itemId'] as int;

    final qty = request['qty'] as int;



    final latValue = request['lat'];

    final lngValue = request['lng'];



    if (latValue == null || lngValue == null) {

      throw Exception('需求缺少 GPS 座標，無法自動分配');

    }



    final userLat = (latValue as num).toDouble();

    final userLng = (lngValue as num).toDouble();



    // 2. 找最近且庫存足夠的收容中心

    final bestStation = await findBestStation(

      itemId: itemId,

      qty: qty,

      userLat: userLat,

      userLng: userLng,

    );



    final stationId = bestStation['stationId'].toString();



    // 3. 寫入分配結果

    await db.execute(

      '''

      UPDATE supply_requests

      SET stationId = ?

      WHERE requestId = ?

      ''',

      [

        stationId,

        requestId,

      ],

    );



    // 4. 使用我們剛才已經改好的 reserve

    // 它現在會依 stationId 去操作 station_inventory

    await reserveSupplyRequest(

      requestId: requestId,

    );



    // 5. 回傳結果

    return {

      'requestId': requestId,

      'stationId': stationId,

      'stationName': bestStation['stationName'],

      'distanceKm': bestStation['distanceKm'],

      'availableQtyBeforeReserve':

          bestStation['availableQty'],

      'status': 'reserved',

    };

  }



  // =========================================================

  // 1. 預留物資

  // pending → reserved

  // reservedQty += qty

  // =========================================================

  Future<void> reserveSupplyRequest({

    required String requestId,

  }) async {

    await db.transaction(() async {

      // 1. 找需求

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



      // 2. 只有 pending 可以預留

      if (status != 'pending') {

        throw Exception('這筆需求目前無法預留');

      }



      final itemId = request['itemId'] as int;

      final qty = request['qty'] as int;

      final stationId = request['stationId']?.toString();



      if (qty <= 0) {

        throw Exception('需求數量無效');

      }



      // 3. 必須已經分配收容中心

      if (stationId == null || stationId.isEmpty) {

        throw Exception('這筆需求尚未分配收容中心');

      }



      // 4. 查「指定收容中心」的庫存

      final itemResult = await db.select(

        '''

        SELECT *

        FROM station_inventory

        WHERE stationId = ?

          AND itemId = ?

        ''',

        [

          stationId,

          itemId,

        ],

      );



      if (itemResult.isEmpty) {

        throw Exception('此收容中心沒有這項物資的庫存資料');

      }



      final item = itemResult.first;



      final stockQty = item['stockQty'] as int;

      final reservedQty = item['reservedQty'] as int;



      // 5. 可用庫存 = 實際庫存 - 已預留

      final availableQty = stockQty - reservedQty;



      if (availableQty < qty) {

        throw Exception(

          '收容中心可用庫存不足，目前可用：$availableQty，需要：$qty',

        );

      }



      final now = DateTime.now().toIso8601String();



      // 6. 增加「這個收容中心」的預留數量

      await db.execute(

        '''

        UPDATE station_inventory

        SET reservedQty = reservedQty + ?,

            updatedAt = ?

        WHERE stationId = ?

          AND itemId = ?

        ''',

        [

          qty,

          now,

          stationId,

          itemId,

        ],

      );



      // 7. 需求變成 reserved

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

  required String stationId,

}) async {

  await db.transaction(() async {

    // 1. 找需求

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

    final requestStationId = request['stationId']?.toString();



    // 2. 只有已經預留物資的需求可以認領

    if (status != 'reserved') {

      throw Exception('這筆需求目前無法認領');

    }



    // 3. 需求必須已經分配收容中心

    if (requestStationId == null || requestStationId.isEmpty) {

      throw Exception('這筆需求尚未分配收容中心');

    }



    // 4. 義工只能認領自己所在收容中心的任務

    if (requestStationId != stationId) {

      throw Exception('無法認領其他收容中心的任務');

    }



    final now = DateTime.now().toIso8601String();



    // 5. 認領任務

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

      [

        'reserved',

        stationId,

      ],

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
        st.name AS stationName
      FROM supply_requests sr
      LEFT JOIN inventory i ON sr.itemId = i.id
      LEFT JOIN stations st ON sr.stationId = st.stationId
      WHERE sr.volunteerId = ?
        AND sr.stationId = ?
        AND sr.status = 'claimed'
      ORDER BY sr.claimedAt DESC
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

  Future<void> cancelClaim({
    required String requestId,
    required String volunteerId,
    required String stationId,
  }) async {
    await db.transaction(() async {
      final rows = await db.select(
        'SELECT * FROM supply_requests WHERE requestId = ?',
        [requestId],
      );
      if (rows.isEmpty) throw Exception('找不到這筆物資需求');
      final request = rows.first;
      if (request['status']?.toString() != 'claimed') {
        throw Exception('這筆需求目前不是已認領狀態');
      }
      if (request['volunteerId']?.toString() != volunteerId) {
        throw Exception('你無法取消其他義工的配送任務');
      }
      if (request['stationId']?.toString() != stationId) {
        throw Exception('無法處理其他收容中心的任務');
      }
      await db.execute(
        '''
        UPDATE supply_requests
        SET status = 'reserved', volunteerId = NULL, claimedAt = NULL
        WHERE requestId = ?
        ''',
        [requestId],
      );
    });
  }

  // =========================================================

// 6. 義工確認取貨

// claimed → dispatched

// 這時物資真正離開收容中心

// stockQty -= qty

// reservedQty -= qty

// =========================================================

  Future<Map<String, dynamic>> dispatchSupplyRequest({
    required String requestId,
    required String volunteerId,
    required String stationId,
  }) async {
    Map<String, dynamic>? result;
    await db.transaction(() async {
      final rows = await db.select(
        'SELECT * FROM supply_requests WHERE requestId = ?',
        [requestId],
      );
      if (rows.isEmpty) throw Exception('找不到這筆物資需求');
      final request = rows.first;
      if (request['status']?.toString() != 'claimed') {
        throw Exception('這筆需求目前無法取貨');
      }
      if (request['volunteerId']?.toString() != volunteerId) {
        throw Exception('你無法處理其他義工的配送任務');
      }
      if (request['stationId']?.toString() != stationId) {
        throw Exception('無法處理其他收容中心的任務');
      }
      final itemId = request['itemId'] as int;
      final qty = request['qty'] as int;
      final inv = await db.select(
        '''
        SELECT si.*, i.name, i.unit
        FROM station_inventory si
        JOIN inventory i ON si.itemId = i.id
        WHERE si.stationId = ? AND si.itemId = ?
        ''',
        [stationId, itemId],
      );
      if (inv.isEmpty) throw Exception('此收容中心沒有這項物資');
      final item = inv.first;
      final stockQty = item['stockQty'] as int;
      final reservedQty = item['reservedQty'] as int;
      if (stockQty < qty) throw Exception('收容中心實際庫存不足');
      if (reservedQty < qty) throw Exception('收容中心預留庫存不足');
      final now = DateTime.now().toIso8601String();
      await db.execute(
        '''
        UPDATE station_inventory
        SET stockQty = stockQty - ?, reservedQty = reservedQty - ?, updatedAt = ?
        WHERE stationId = ? AND itemId = ?
        ''',
        [qty, qty, now, stationId, itemId],
      );
      await db.execute(
        "UPDATE supply_requests SET status = 'dispatched' WHERE requestId = ?",
        [requestId],
      );
      result = {
        'requestId': requestId, 'stationId': stationId,
        'itemId': itemId, 'itemName': item['name'], 'unit': item['unit'],
        'qty': qty, 'status': 'dispatched',
      };
    });
    return result!;
  }

  Future<Map<String, dynamic>> completeSupplyRequest({
    required String requestId,
    required String volunteerId,
    required String stationId,
  }) async {
    Map<String, dynamic>? result;
    await db.transaction(() async {
      final rows = await db.select(
        'SELECT * FROM supply_requests WHERE requestId = ?',
        [requestId],
      );
      if (rows.isEmpty) throw Exception('找不到這筆物資需求');
      final request = rows.first;
      if (request['status']?.toString() != 'dispatched') {
        throw Exception('只有配送中的需求可以完成');
      }
      if (request['volunteerId']?.toString() != volunteerId) {
        throw Exception('你無法完成其他義工的配送任務');
      }
      if (request['stationId']?.toString() != stationId) {
        throw Exception('無法處理其他收容中心的任務');
      }
      await db.execute(
        "UPDATE supply_requests SET status = 'completed' WHERE requestId = ?",
        [requestId],
      );
      result = {'requestId': requestId, 'status': 'completed'};
    });
    return result!;
  }

}