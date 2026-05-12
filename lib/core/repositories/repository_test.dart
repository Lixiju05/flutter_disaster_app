import 'package:flutter_disaster_app/core/repositories/admin_repository.dart';

Future<void> testRepository() async {
  final repo = AdminRepository();

  // 1. 獲取民眾資料
  final citizens = await repo.getCitizens();
  print('Citizens count: ${citizens.length}');

  // 2. 獲取緊急求救資料
  final emergencies = await repo.getEmergencies();
  print('Emergencies count: ${emergencies.length}');

  // 3. 獲取物資庫存資料 (統一使用最新的方法名)
  final supplies = await repo.getAdminSupplies();
  print('Supplies count: ${supplies.length}');
}