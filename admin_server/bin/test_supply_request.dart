import 'package:admin_server/database/database_service.dart';
import 'package:admin_server/services/supply/supply_request_service.dart';

Future<void> main() async {
  print('開始測試義工認領');

  await DatabaseService.init();

  final db = DatabaseService.instance;

  final service = SupplyRequestService(db);

  try {
    await service.claimSupplyRequest(
      requestId: 'REQ001',
      volunteerId: 'V001',
    );

    print('✅ 認領成功');

    final request = await db.select(
      '''
      SELECT *
      FROM supply_requests
      WHERE requestId = ?
      ''',
      ['REQ001'],
    );

    print('需求資料：');
    print(request);

    final inventory = await db.select(
      '''
      SELECT *
      FROM inventory
      WHERE id = ?
      ''',
      [1],
    );

    print('庫存資料：');
    print(inventory);

  } catch (e) {
    print('❌ 認領失敗：$e');
  }
}