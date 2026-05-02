import 'package:flutter_disaster_app/core/repositories/admin_repository.dart';

Future<void> testRepository() async {
  final repo = AdminRepository();

  final citizens = await repo.getCitizens();
  print('Citizens count: ${citizens.length}');

  final emergencies = await repo.getEmergencies();
  print('Emergencies count: ${emergencies.length}');

  final supplies = await repo.getAdminSupplies();
  print('Supplies count: ${supplies.length}');
}