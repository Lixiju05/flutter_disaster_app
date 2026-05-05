import 'package:flutter_disaster_app/core/repositories/admin_repository.dart';

Future<void> testRepository() async {
  final repo = AdminRepository();

  final citizens = await repo.getCitizens();
<<<<<<< HEAD

  final emergencies = await repo.getEmergencies();

  final inventory = await repo.getInventory();

  print(citizens.length);

  print(emergencies.length);

  print(inventory.length);
=======
  print('Citizens count: ${citizens.length}');

  final emergencies = await repo.getEmergencies();
  print('Emergencies count: ${emergencies.length}');

  final supplies = await repo.getAdminSupplies();
  print('Supplies count: ${supplies.length}');
>>>>>>> f69460cd2207e884a63750829a091e7e38ece7cf
}