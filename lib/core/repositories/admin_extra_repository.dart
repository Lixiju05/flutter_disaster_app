import '../models/prepared_supply.dart';
import '../models/rescue_request.dart';

class AdminExtraRepository {
  // 假預備物資
  final List<PreparedSupply> _preparedSupplies = [
    PreparedSupply(
      citizenId: "C001",
      itemName: "急救包",
      quantity: 2,
      lastUpdated: DateTime.now(),
    ),
    PreparedSupply(
      citizenId: "C002",
      itemName: "飲用水",
      quantity: 10,
      lastUpdated: DateTime.now(),
    ),
  ];

  // 假救援請求
  final List<RescueRequest> _rescueRequests = [
    RescueRequest(
      id: "R001",
      userId: "C001",
      latitude: 24.15,
      longitude: 120.67,
      status: "等待救援",
      time: DateTime.now(),
    ),
    RescueRequest(
      id: "R002",
      userId: "C002",
      latitude: 24.16,
      longitude: 120.66,
      status: "已派出救援隊",
      time: DateTime.now(),
    ),
  ];

  List<PreparedSupply> getPreparedSupplies() {
    return _preparedSupplies;
  }

  List<RescueRequest> getRescueRequests() {
    return _rescueRequests;
  }
}