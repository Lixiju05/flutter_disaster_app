import 'package:flutter_disaster_app/core/repositories/admin_repository.dart';

Future<void> testRepository() async {
  final repo = AdminRepository();

// 獲取民眾資料
  final citizens = await repo.getCitizens();
<<<<<<< HEAD
  print('Citizens count: ${citizens.length}');

  //  獲取緊急求救資料
  final emergencies = await repo.getEmergencies();
  print('Emergencies count: ${emergencies.length}');

  // 獲取物資庫存資料 (統一使用 getAdminSupplies)
  final supplies = await repo.getAdminSupplies();
  print('Supplies count: ${supplies.length}');
=======

  final emergencies = await repo.getEmergencies();

  final inventory = await repo.getInventory();

  print(citizens.length);

  print(emergencies.length);

  print(inventory.length);
>>>>>>> bfe805c (UI画面)
}