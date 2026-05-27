
/*import 'core/models/rescue_request.dart';
import 'core/models/citizen.dart';
import 'core/models/prepared_supply.dart';
import 'core/models/emergency_request.dart';
import 'core/models/supply.dart';

void testAdminSupply() { 
    var adminSupply = AdminSupply(
    itemName: "Water",
    totalQuantity: 100,
  );

  adminSupply.allocate(20);

  print("Remaining: ${adminSupply.remainingQuantity}");
}
void testEmergencyRequest() {
  var emergency = EmergencyRequest(
    id: "E001",
    citizenId: "C001",
    userName: "測試用戶",
    phone: "",
    latitude: 24.15,
    longitude: 120.67,
    type: "sos",
    description: "",
    createdAt: DateTime.now(),
  );

  print("Emergency type: ${emergency.type}");
}
void testCitizen() {
  var citizen = Citizen(
    id: "C001",
    name: "王小明",
    latitude: 24.15,
    longitude: 120.67,
    needsRescue: false,
  );

  print("Citizen test: ${citizen.name}");
}
void testPreparedSupply() {
  var supply = PreparedSupply(
    citizenId: "C001",
    itemName: "Water",
    quantity: 10,
    lastUpdated: DateTime.now(),
  );

  print("Supply: ${supply.itemName} ${supply.quantity}");
}

void runAllTests() {
  testCitizen();
  testPreparedSupply();
  testEmergencyRequest();
  testAdminSupply();
}*/