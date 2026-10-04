import 'package:admin_server/database/database_service.dart';
import 'package:admin_server/services/supply/supply_request_service.dart';

Future<void> main() async {
  await DatabaseService.init();

  final service = SupplyRequestService(
    DatabaseService.instance,
  );

  try {
    final requests =
        await service.getPendingSupplyRequests();

    print('===== 待認領物資需求 =====');

    if (requests.isEmpty) {
      print('目前沒有待認領需求');
      return;
    }

    for (final request in requests) {
      print('--------------------------');
      print('需求編號：${request['requestId']}');
      print('物資：${request['itemName']}');
      print('數量：${request['qty']} ${request['unit']}');
      print('地址：${request['address']}');
      print('狀態：${request['status']}');
    }
  } catch (e) {
    print('❌ 測試失敗：$e');
  }
}