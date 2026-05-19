class GeoHelper {
  static String getGridId(double lat, double lng) {
    // 埔里大約中心
    const centerLat = 23.966;
    const centerLng = 120.969;

    // 市區中心
    if ((lat - centerLat).abs() <= 0.015 &&
        (lng - centerLng).abs() <= 0.015) {
      return "PULI_C";
    }

    // 北區
    if (lat > centerLat + 0.015) {
      return "PULI_N";
    }

    // 南區
    if (lat < centerLat - 0.015) {
      return "PULI_S";
    }

    // 東區
    if (lng > centerLng + 0.015) {
      return "PULI_E";
    }

    // 西區
    if (lng < centerLng - 0.015) {
      return "PULI_W";
    }

    return "PULI_C";
  }

  static String getZone(double lat, double lng) {
    return "埔里鎮";
  }

  static String getDistributionPoint(String gridId) {
    switch (gridId) {
      case "PULI_C":
        return "埔里鎮公所";
      case "PULI_N":
        return "埔里國中";
      case "PULI_S":
        return "埔里國小";
      case "PULI_E":
        return "埔里消防分隊";
      case "PULI_W":
        return "埔里轉運站";
      default:
        return "待指定集中點";
    }
  }
}