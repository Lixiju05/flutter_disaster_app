import 'package:admin_server/database/database_service.dart';
import 'package:admin_server/services/supply/supply_request_service.dart';

Future<void> main() async {
  print('開始測試義工認領');

  await DatabaseService.init();

  final db = DatabaseService.instance;
  final service = SupplyRequestService(db);

  const requestId = 'AUTO_TEST001';

  try {
    await service.claimSupplyRequest(
      requestId: requestId,
      volunteerId: 'V001',
      stationId: 'S001',
    );

    print('✅ 認領成功');

    final request = await db.select(
      '''
      SELECT *
      FROM supply_requests
      WHERE requestId = ?
      ''',
      [requestId],
    );

    print('需求資料：');
    print(request);

    final inventory = await db.select(
      '''
      SELECT si.*, i.name, i.unit
      FROM station_inventory si
      JOIN inventory i
        ON si.itemId = i.id
      WHERE si.stationId = ?
        AND si.itemId = ?
      ''',
      ['S001', 2],
    );

    print('S001 庫存資料：');
    print(inventory);
  } catch (e) {
    print('❌ 認領失敗：$e');
  }
}