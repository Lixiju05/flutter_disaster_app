class RescueRequest {
  final String id;//救援請求的唯一識別碼
  final String userId;//提出救援請求的使用者 ID
  final double latitude;//地理座標
  final double longitude;//地理座標
  final String status;//請求狀態
  final DateTime time;//請求建立的時間

    //建構子
    RescueRequest({
      required this.id,
      required this.userId,
      required this.latitude,
      required this.longitude,
      required this.status,
      required this.time,
  });
}
