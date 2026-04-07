import 'package:flutter_disaster_app/core/repositories/admin_repository.dart';
void testRepository() {
  final repo = AdminRepository();

  print(repo.getCitizens().length);
  print(repo.getEmergencies().length);
  print(repo.getAdminSupplies().length);
}