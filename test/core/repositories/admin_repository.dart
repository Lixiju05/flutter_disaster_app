import '../models/citizen.dart';
import '../models/prepared_supply.dart';
import '../models/emergency_request.dart';
import '../models/supply.dart';
import '../models/rescue_request.dart';

class AdminRepository { //先放假訊息
  //假民眾
  final List<Citizen> _citizens = [  // _ -> private
  Citizen(
    id: "C001",
    name: "王小明",
    latitude: 24.15,
    longitude: 120.67,
    isRescued: false,
  ),
  Citizen(
    id: "C002",
    name: "李小龍",
    latitude: 24.16,
    longitude: 120.66,
    isRescued: false,
    ),
  ];
//假求救訊息
  final List<EmergencyRequest> _emergencies = [
    EmergencyRequest(
      id: "E001",
      citizenId: "C001",
      latitude: 24.15,
      longitude: 120.67,
      type: "sos",
      createdAt: DateTime.now(),
    ),
  ];
  //假庫存
  final List<AdminSupply> _adminSupplies = [
    AdminSupply(itemName: "Water", totalQuantity: 100),
    AdminSupply(itemName: "Food", totalQuantity: 50),
  ];

//取得民眾列表
List<Citizen> getCitizens(){
  return _citizens;
}
//取得求救列表
List<EmergencyRequest> getEmergencies() {
  return _emergencies;
}
//取得庫存列表
List<AdminSupply> getAdminSupplies() {
  return _adminSupplies;
}
}
