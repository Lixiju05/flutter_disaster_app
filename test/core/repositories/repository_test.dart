import 'package:flutter_disaster_app/core/repositories/admin_repository.dart';

Future<void> testRepository() async {
  final repo = AdminRepository();

  final citizens = await repo.getCitizens();

  final emergencies = await repo.getEmergencies();

  final inventory = await repo.getInventory();

  print(citizens.length);

  print(emergencies.length);

  print(inventory.length);
}