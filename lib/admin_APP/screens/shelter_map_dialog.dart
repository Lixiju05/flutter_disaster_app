import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'dashboard_page.dart' show kBg, kCardBg, kCyan, kGreen, kMuted, kBorder, kBlue, kOrange, kTextMain, kTextSub;
import 'area_data.dart';

// ══════════════════════════════════════════════════════════
//  SHELTER DATA MODEL（保留，供向後相容）
// ══════════════════════════════════════════════════════════

class ShelterData {
  final String name;
  final String address;
  
  final int capacity;
  final String floors;
  final double lat;
  final double lng;

  const ShelterData({
    required this.name,
    required this.address,
    required this.capacity,
    required this.floors,
    required this.lat,
    required this.lng,
  });
}

// ══════════════════════════════════════════════════════════
//  全台防空洞座標資料（補充 area_data.dart 的經緯度）
// ══════════════════════════════════════════════════════════

/// 每個縣市的防空洞（含經緯度）
/// key = 縣市名稱，對應 area_data.dart 的 AreaData.name
const Map<String, List<ShelterData>> kAllShelters = {

  '台北市': [
    ShelterData(name: '台北市立體育場',   address: '信義區市府路50號',       capacity: 3000, floors: 'B1-B2', lat: 25.0408, lng: 121.5678),
    ShelterData(name: '大安運動中心',     address: '大安區建國南路二段256號', capacity: 1500, floors: 'B1',    lat: 25.0270, lng: 121.5393),
    ShelterData(name: '士林國中體育館',   address: '士林區士林街51號',        capacity: 800,  floors: 'B1',    lat: 25.0923, lng: 121.5261),
    ShelterData(name: '中正紀念堂廣場',   address: '中正區中山南路21號',      capacity: 5000, floors: 'B1',    lat: 25.0350, lng: 121.5215),
    ShelterData(name: '松山文創園區',     address: '信義區光復南路133號',     capacity: 2000, floors: 'B1',    lat: 25.0441, lng: 121.5594),
  ],

  '新北市': [
    ShelterData(name: '板橋體育館',       address: '板橋區中山路一段247號',     capacity: 2500, floors: 'B1-B2', lat: 25.0138, lng: 121.4626),
    ShelterData(name: '三重綜合體育館',   address: '三重區重新路五段609巷',     capacity: 1800, floors: 'B1',    lat: 25.0631, lng: 121.4862),
    ShelterData(name: '新莊體育館',       address: '新莊區新泰路388號',         capacity: 1200, floors: 'B1',    lat: 25.0357, lng: 121.4427),
    ShelterData(name: '淡水國中活動中心', address: '淡水區中正路320號',         capacity: 900,  floors: 'B1',    lat: 25.1664, lng: 121.4432),
    ShelterData(name: '中和國民運動中心', address: '中和區景新街448號',         capacity: 1500, floors: 'B1',    lat: 24.9955, lng: 121.4921),
  ],

  '桃園市': [
    ShelterData(name: '桃園體育園區',     address: '桃園區縣府路1號',        capacity: 4000, floors: 'B1-B2', lat: 24.9937, lng: 121.3010),
    ShelterData(name: '中壢家商體育館',   address: '中壢區實踐路113號',      capacity: 1200, floors: 'B1',    lat: 24.9644, lng: 121.2236),
    ShelterData(name: '楊梅高中體育館',   address: '楊梅區校前路90號',       capacity: 800,  floors: 'B1',    lat: 24.9105, lng: 121.1432),
    ShelterData(name: '大溪國中活動中心', address: '大溪區介壽路二段689號',  capacity: 600,  floors: 'B1',    lat: 24.8803, lng: 121.2862),
    ShelterData(name: '蘆竹區公所',       address: '蘆竹區中正路220號',      capacity: 500,  floors: 'B1',    lat: 25.0703, lng: 121.3165),
  ],

  '台中市': [
    ShelterData(name: '台中洲際棒球場',   address: '北屯區崇德路四段900號', capacity: 5000, floors: 'B1-B2', lat: 24.2044, lng: 120.7127),
    ShelterData(name: '豐原體育館',       address: '豐原區圓環北路63號',    capacity: 1500, floors: 'B1',    lat: 24.2526, lng: 120.7189),
    ShelterData(name: '沙鹿體育場',       address: '沙鹿區晉江街29號',      capacity: 1000, floors: 'B1',    lat: 24.2206, lng: 120.5779),
    ShelterData(name: '霧峰區公所',       address: '霧峰區中正路436號',     capacity: 600,  floors: 'B1',    lat: 24.0623, lng: 120.7236),
    ShelterData(name: '大甲國中體育館',   address: '大甲區民生路135號',     capacity: 800,  floors: 'B1',    lat: 24.3495, lng: 120.6218),
  ],

  '台南市': [
    ShelterData(name: '台南體育公園體育館', address: '北區北忠街69號',        capacity: 3000, floors: 'B1-B2', lat: 23.0114, lng: 120.2126),
    ShelterData(name: '永康體育館',         address: '永康區中華路6號',        capacity: 1500, floors: 'B1',    lat: 23.0344, lng: 120.2631),
    ShelterData(name: '善化體育場',         address: '善化區中正路123號',      capacity: 800,  floors: 'B1',    lat: 23.1434, lng: 120.3017),
    ShelterData(name: '新營體育場',         address: '新營區民治路36號',       capacity: 1200, floors: 'B1',    lat: 23.3088, lng: 120.3126),
    ShelterData(name: '安平國中活動中心',   address: '安平區建平七街2號',      capacity: 700,  floors: 'B1',    lat: 22.9989, lng: 120.1601),
  ],

  '高雄市': [
    ShelterData(name: '高雄巨蛋',         address: '左營區博愛二路757號',     capacity: 15000, floors: 'B1-B2', lat: 22.6894, lng: 120.3003),
    ShelterData(name: '鳳山體育館',       address: '鳳山區光復路二段120號',   capacity: 2000,  floors: 'B1',    lat: 22.6271, lng: 120.3573),
    ShelterData(name: '三民家商體育館',   address: '三民區九如二路376號',     capacity: 1000,  floors: 'B1',    lat: 22.6531, lng: 120.3094),
    ShelterData(name: '岡山體育場',       address: '岡山區岡山路261號',       capacity: 1500,  floors: 'B1',    lat: 22.7966, lng: 120.2952),
    ShelterData(name: '前鎮運動中心',     address: '前鎮區中華五路1001號',    capacity: 1200,  floors: 'B1',    lat: 22.5933, lng: 120.3244),
  ],

  '基隆市': [
    ShelterData(name: '基隆體育館',       address: '仁愛區港西街6號',       capacity: 2000, floors: 'B1-B2', lat: 25.1291, lng: 121.7407),
    ShelterData(name: '七堵國民運動中心', address: '七堵區實踐路89號',      capacity: 800,  floors: 'B1',    lat: 25.1003, lng: 121.7126),
    ShelterData(name: '暖暖高中體育館',   address: '暖暖區水源路149號',     capacity: 600,  floors: 'B1',    lat: 25.0888, lng: 121.7444),
    ShelterData(name: '安樂高中體育館',   address: '安樂區安樂路二段164號', capacity: 700,  floors: 'B1',    lat: 25.1121, lng: 121.7159),
    ShelterData(name: '基隆港務大樓',     address: '中正區義一路1號',       capacity: 1000, floors: 'B1',    lat: 25.1310, lng: 121.7416),
  ],

  '新竹市': [
    ShelterData(name: '新竹體育館',       address: '東區公道五路一段78號',  capacity: 2500, floors: 'B1-B2', lat: 24.8020, lng: 120.9877),
    ShelterData(name: '新竹高中體育館',   address: '東區學府路36號',        capacity: 1000, floors: 'B1',    lat: 24.7946, lng: 120.9799),
    ShelterData(name: '香山國中活動中心', address: '香山區牛埔東路125號',   capacity: 700,  floors: 'B1',    lat: 24.7653, lng: 120.9438),
    ShelterData(name: '建功高中體育館',   address: '北區武陵路136號',       capacity: 800,  floors: 'B1',    lat: 24.8155, lng: 120.9705),
    ShelterData(name: '新竹市文化局廣場', address: '東區東大路二段17號',    capacity: 600,  floors: 'B1',    lat: 24.7966, lng: 120.9717),
  ],

  '嘉義市': [
    ShelterData(name: '嘉義體育館',       address: '東區中山路616號',     capacity: 2000, floors: 'B1-B2', lat: 23.4797, lng: 120.4519),
    ShelterData(name: '嘉義棒球場',       address: '東區公園街38號',      capacity: 5000, floors: 'B1',    lat: 23.4871, lng: 120.4424),
    ShelterData(name: '嘉義高中體育館',   address: '東區林森東路254號',   capacity: 900,  floors: 'B1',    lat: 23.4762, lng: 120.4506),
    ShelterData(name: '西區公所活動中心', address: '西區世賢路一段361號', capacity: 500,  floors: 'B1',    lat: 23.4731, lng: 120.4319),
    ShelterData(name: '仁義潭水庫管理站', address: '東區竹圍里鹿寮仔',   capacity: 300,  floors: 'B1',    lat: 23.4430, lng: 120.5012),
  ],

  '新竹縣': [
    ShelterData(name: '竹北體育館',       address: '竹北市縣政二路100號',   capacity: 2000, floors: 'B1-B2', lat: 24.8357, lng: 121.0088),
    ShelterData(name: '竹東高中體育館',   address: '竹東鎮商華路1號',       capacity: 900,  floors: 'B1',    lat: 24.7379, lng: 121.0881),
    ShelterData(name: '關西國中活動中心', address: '關西鎮中山路99號',      capacity: 500,  floors: 'B1',    lat: 24.7906, lng: 121.1717),
    ShelterData(name: '新豐高中體育館',   address: '新豐鄉中正路300號',     capacity: 600,  floors: 'B1',    lat: 24.9217, lng: 121.0281),
    ShelterData(name: '湖口鄉公所',       address: '湖口鄉中正路一段48號',  capacity: 400,  floors: 'B1',    lat: 24.9028, lng: 121.0467),
  ],

  '苗栗縣': [
    ShelterData(name: '苗栗體育場',     address: '苗栗市建功路29號',   capacity: 2000, floors: 'B1-B2', lat: 24.5681, lng: 120.8206),
    ShelterData(name: '頭份體育館',     address: '頭份市中正路608號',  capacity: 1200, floors: 'B1',    lat: 24.6841, lng: 120.8785),
    ShelterData(name: '竹南國中體育館', address: '竹南鎮公義路161號',  capacity: 700,  floors: 'B1',    lat: 24.6877, lng: 120.8680),
    ShelterData(name: '苑裡高中體育館', address: '苑裡鎮學府路2號',   capacity: 600,  floors: 'B1',    lat: 24.4406, lng: 120.6585),
    ShelterData(name: '三義鄉公所',     address: '三義鄉中正路1號',    capacity: 300,  floors: 'B1',    lat: 24.3796, lng: 120.7579),
  ],

  '彰化縣': [
    ShelterData(name: '彰化體育館',     address: '彰化市陳稜路二段586號', capacity: 2500, floors: 'B1-B2', lat: 24.0738, lng: 120.5388),
    ShelterData(name: '員林體育場',     address: '員林市員集路一段389號', capacity: 1500, floors: 'B1',    lat: 23.9581, lng: 120.5761),
    ShelterData(name: '鹿港國中體育館', address: '鹿港鎮中山路601號',    capacity: 800,  floors: 'B1',    lat: 24.0558, lng: 120.4337),
    ShelterData(name: '北斗國中體育館', address: '北斗鎮光復路158號',    capacity: 600,  floors: 'B1',    lat: 23.8742, lng: 120.5284),
    ShelterData(name: '二林高中體育館', address: '二林鎮正義街51號',     capacity: 700,  floors: 'B1',    lat: 23.9165, lng: 120.3802),
  ],

  '南投縣': [
    ShelterData(name: '埔里鎮公所地下停車場', address: '南投縣埔里鎮中山路一段1號',    capacity: 500, floors: 'B1-B2', lat: 23.9609, lng: 120.9683),
    ShelterData(name: '埔里國中防空避難室',   address: '南投縣埔里鎮西安路一段156號',  capacity: 300, floors: 'B1',    lat: 23.9648, lng: 120.9721),
    ShelterData(name: '宏仁國中地下避難所',   address: '南投縣埔里鎮中山路四段1號',    capacity: 250, floors: 'B1',    lat: 23.9572, lng: 120.9654),
    ShelterData(name: '埔里基督教醫院地下室', address: '南投縣埔里鎮鎮山路1號',        capacity: 400, floors: 'B1-B2', lat: 23.9631, lng: 120.9598),
    ShelterData(name: '愛蘭國小禮堂地下層',   address: '南投縣埔里鎮愛蘭里',          capacity: 350, floors: 'B1',    lat: 23.9558, lng: 120.9741),
  ],

  '雲林縣': [
    ShelterData(name: '斗六體育場',     address: '斗六市府文路42號',       capacity: 2000, floors: 'B1-B2', lat: 23.7105, lng: 120.5440),
    ShelterData(name: '虎尾綜合體育館', address: '虎尾鎮博愛路6號',        capacity: 1500, floors: 'B1',    lat: 23.7068, lng: 120.4395),
    ShelterData(name: '北港體育館',     address: '北港鎮光復路35號',       capacity: 900,  floors: 'B1',    lat: 23.5711, lng: 120.3002),
    ShelterData(name: '西螺國中體育館', address: '西螺鎮中興路45號',       capacity: 600,  floors: 'B1',    lat: 23.8010, lng: 120.4666),
    ShelterData(name: '林內鄉公所',     address: '林內鄉林內村中正路97號', capacity: 350,  floors: 'B1',    lat: 23.7583, lng: 120.6179),
  ],

  '嘉義縣': [
    ShelterData(name: '太保體育場',     address: '太保市祥和一路6號',       capacity: 2500, floors: 'B1-B2', lat: 23.4594, lng: 120.3322),
    ShelterData(name: '民雄國中體育館', address: '民雄鄉建國路一段116號',   capacity: 800,  floors: 'B1',    lat: 23.5576, lng: 120.4264),
    ShelterData(name: '大林國中體育館', address: '大林鎮大林路2號',         capacity: 700,  floors: 'B1',    lat: 23.6096, lng: 120.4692),
    ShelterData(name: '朴子國中體育館', address: '朴子市學府路50號',        capacity: 600,  floors: 'B1',    lat: 23.4593, lng: 120.2444),
    ShelterData(name: '水上國中活動中心', address: '水上鄉民族路22號',      capacity: 500,  floors: 'B1',    lat: 23.4479, lng: 120.3864),
  ],

  '屏東縣': [
    ShelterData(name: '屏東體育場',       address: '屏東市大連路68號',       capacity: 2500, floors: 'B1-B2', lat: 22.6720, lng: 120.4883),
    ShelterData(name: '東港體育館',       address: '東港鎮興東路1號',        capacity: 1000, floors: 'B1',    lat: 22.4643, lng: 120.4499),
    ShelterData(name: '潮州高中體育館',   address: '潮州鎮建國路32號',       capacity: 800,  floors: 'B1',    lat: 22.5506, lng: 120.5449),
    ShelterData(name: '恆春體育館',       address: '恆春鎮恆公路1299號',     capacity: 600,  floors: 'B1',    lat: 22.0002, lng: 120.7449),
    ShelterData(name: '里港國中體育館',   address: '里港鄉中正路136號',      capacity: 500,  floors: 'B1',    lat: 22.7626, lng: 120.4863),
  ],

  '宜蘭縣': [
    ShelterData(name: '宜蘭運動公園體育館', address: '宜蘭市凱旋路二段68號', capacity: 2000, floors: 'B1-B2', lat: 24.7016, lng: 121.7350),
    ShelterData(name: '羅東體育場',         address: '羅東鎮公正路325號',    capacity: 1500, floors: 'B1',    lat: 24.6764, lng: 121.7694),
    ShelterData(name: '蘇澳國中體育館',     address: '蘇澳鎮蘇澳路8號',      capacity: 700,  floors: 'B1',    lat: 24.5985, lng: 121.8511),
    ShelterData(name: '頭城國中體育館',     address: '頭城鎮學府路1號',       capacity: 600,  floors: 'B1',    lat: 24.8672, lng: 121.8187),
    ShelterData(name: '冬山鄉公所',         address: '冬山鄉中山路101號',     capacity: 400,  floors: 'B1',    lat: 24.6574, lng: 121.8148),
  ],

  '花蓮縣': [
    ShelterData(name: '花蓮體育場',       address: '花蓮市林森路98號',       capacity: 3000, floors: 'B1-B2', lat: 23.9799, lng: 121.6077),
    ShelterData(name: '吉安體育館',       address: '吉安鄉吉安路二段99號',   capacity: 1000, floors: 'B1',    lat: 23.9688, lng: 121.5889),
    ShelterData(name: '玉里體育館',       address: '玉里鎮中山路3號',        capacity: 800,  floors: 'B1',    lat: 23.3335, lng: 121.3059),
    ShelterData(name: '光復鄉公所',       address: '光復鄉大進村中山路8號',  capacity: 400,  floors: 'B1',    lat: 23.6612, lng: 121.4375),
    ShelterData(name: '新城國中體育館',   address: '新城鄉新城村信義路3號',  capacity: 500,  floors: 'B1',    lat: 24.1294, lng: 121.6527),
  ],

  '台東縣': [
    ShelterData(name: '台東體育場',       address: '台東市中興路二段325號',  capacity: 2000, floors: 'B1-B2', lat: 22.7551, lng: 121.1494),
    ShelterData(name: '關山體育館',       address: '關山鎮中華路51號',       capacity: 700,  floors: 'B1',    lat: 23.0523, lng: 121.1655),
    ShelterData(name: '成功高中體育館',   address: '成功鎮博愛路6號',        capacity: 500,  floors: 'B1',    lat: 23.0990, lng: 121.3728),
    ShelterData(name: '台東大學體育場',   address: '台東市大學路196號',      capacity: 1500, floors: 'B1',    lat: 22.7786, lng: 121.1144),
    ShelterData(name: '池上鄉公所',       address: '池上鄉中山路185號',      capacity: 300,  floors: 'B1',    lat: 23.1147, lng: 121.2204),
  ],

  '澎湖縣': [
    ShelterData(name: '馬公體育場',       address: '馬公市新生路62號',   capacity: 1500, floors: 'B1-B2', lat: 23.5709, lng: 119.5793),
    ShelterData(name: '馬公國中體育館',   address: '馬公市西衛里160號',  capacity: 800,  floors: 'B1',    lat: 23.5657, lng: 119.5682),
    ShelterData(name: '湖西鄉公所',       address: '湖西鄉湖西村5號',   capacity: 300,  floors: 'B1',    lat: 23.6089, lng: 119.6354),
    ShelterData(name: '白沙鄉公所',       address: '白沙鄉赤崁村6號',   capacity: 300,  floors: 'B1',    lat: 23.6704, lng: 119.5933),
    ShelterData(name: '西嶼鄉公所',       address: '西嶼鄉合界村2號',   capacity: 250,  floors: 'B1',    lat: 23.5979, lng: 119.5019),
  ],

  '金門縣': [
    ShelterData(name: '金門體育館',     address: '金城鎮民生路1號',     capacity: 1500, floors: 'B1-B2', lat: 24.4329, lng: 118.3171),
    ShelterData(name: '金湖體育場',     address: '金湖鎮武德新莊1號',   capacity: 800,  floors: 'B1',    lat: 24.4564, lng: 118.3869),
    ShelterData(name: '金沙鎮公所',     address: '金沙鎮汶沙里3號',     capacity: 300,  floors: 'B1',    lat: 24.4906, lng: 118.4183),
    ShelterData(name: '金寧鄉公所',     address: '金寧鄉安岐村8號',     capacity: 250,  floors: 'B1',    lat: 24.4577, lng: 118.3116),
    ShelterData(name: '烈嶼鄉公所',     address: '烈嶼鄉林湖村122號',  capacity: 200,  floors: 'B1',    lat: 24.4164, lng: 118.2313),
  ],

  '連江縣': [
    ShelterData(name: '南竿鄉公所活動中心', address: '南竿鄉介壽村76號', capacity: 500, floors: 'B1-B2', lat: 26.1565, lng: 119.9398),
    ShelterData(name: '北竿鄉公所',         address: '北竿鄉塘岐村2號',  capacity: 300, floors: 'B1',    lat: 26.2239, lng: 120.0019),
    ShelterData(name: '莒光鄉公所',         address: '莒光鄉西莒村2號',  capacity: 200, floors: 'B1',    lat: 25.9712, lng: 119.9249),
    ShelterData(name: '東引鄉公所',         address: '東引鄉樂華村6號',  capacity: 150, floors: 'B1',    lat: 26.3711, lng: 120.4943),
    ShelterData(name: '馬祖酒廠倉儲中心',   address: '南竿鄉仁愛村1號',  capacity: 800, floors: 'B1-B2', lat: 26.1614, lng: 119.9297),
  ],
};

// ── 根據縣市取得防空洞清單 ────────────────────────────────
List<ShelterData> getSheltersForArea(String adminArea) {
  // 完全符合
  if (kAllShelters.containsKey(adminArea)) return kAllShelters[adminArea]!;
  // 模糊符合
  for (final key in kAllShelters.keys) {
    final short = key.replaceAll('市', '').replaceAll('縣', '');
    if (adminArea.contains(short) || short.contains(adminArea)) {
      return kAllShelters[key]!;
    }
  }
  // Fallback：南投縣（埔里原始資料）
  return kAllShelters['南投縣']!;
}

// ── 地圖初始中心（依縣市）───────────────────────────────
LatLng getCenterForArea(String adminArea) {
  final shelters = getSheltersForArea(adminArea);
  if (shelters.isEmpty) return const LatLng(23.9609, 120.9683);
  // 取第一個設施的座標作為中心
  return LatLng(shelters.first.lat, shelters.first.lng);
}

// ══════════════════════════════════════════════════════════
//  SHELTER MAP DIALOG
// ══════════════════════════════════════════════════════════

class ShelterMapDialog extends StatefulWidget {
  /// 傳入 adminArea 讓地圖與清單根據管轄地區切換
  final String adminArea;

  const ShelterMapDialog({
    super.key,
    required this.adminArea,
  });

  @override
  State<ShelterMapDialog> createState() => _ShelterMapDialogState();
}

class _ShelterMapDialogState extends State<ShelterMapDialog> {
  int _selectedIndex = 0;
  final MapController _mapController = MapController();

  // ★ 動態取得當前縣市的防空洞清單
  late List<ShelterData> _shelters;

  @override
  void initState() {
    super.initState();
    _shelters = getSheltersForArea(widget.adminArea);
  }

  int get _totalCapacity => _shelters.fold(0, (sum, s) => sum + s.capacity);

  void _selectShelter(int index) {
    setState(() => _selectedIndex = index);
    _mapController.move(
      LatLng(_shelters[index].lat, _shelters[index].lng),
      15.5,
    );
  }

  Future<void> _openNavigation(ShelterData shelter) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=${shelter.lat},${shelter.lng}'
      '&travelmode=driving',
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) debugPrint('無法開啟 Google Maps 導航');
  }

  String _formatNumber(int value) => value
      .toString()
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');

  /// 顯示用地區名稱（去掉「縣/市」後的短名）
  String get _areaShortName {
    final data = AreaDataHelper.findByName(widget.adminArea);
    return data.name;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      child: Container(
        width: 1000,
        height: 620,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.6),
              blurRadius: 40,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 360,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      border: Border(right: BorderSide(color: kBorder)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          child: Text(
                            '設施清單（${_shelters.length} 處）',
                            style: TextStyle(
                                color: kMuted, fontSize: 11, letterSpacing: 1.2),
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: _shelters.length,
                            itemBuilder: (_, i) => _buildListItem(i),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: _buildMap()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: kBorder)),
      ),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: kOrange.withOpacity(.10),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kOrange.withOpacity(.24)),
            ),
            child: const Icon(Icons.apartment, color: kOrange, size: 19),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '防空避難設施地圖',
                style: TextStyle(color: kTextMain, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                // ★ 動態顯示縣市名稱
                '$_areaShortName 轄區內共 ${_shelters.length} 處避難設施　總容量 ${_formatNumber(_totalCapacity)} 人',
                style: TextStyle(color: kMuted, fontSize: 11),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: kTextSub, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildListItem(int index) {
    final s = _shelters[index];
    final selected = _selectedIndex == index;

    return InkWell(
      onTap: () => _selectShelter(index),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: selected ? kOrange.withOpacity(.08) : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: selected ? kOrange : Colors.transparent,
              width: 3,
            ),
            bottom: BorderSide(color: kBorder),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: selected ? kOrange.withOpacity(.12) : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(Icons.apartment,
                  color: selected ? kOrange : kTextSub, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.name,
                    style: TextStyle(
                      color: kTextMain,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(s.address,
                      style: const TextStyle(color: kMuted, fontSize: 10)),
                  const SizedBox(height: 6),
                  Row(children: [
                    _tag('可容納 ${s.capacity} 人', kGreen),
                    const SizedBox(width: 6),
                    _tag(s.floors, kBlue),
                  ]),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: selected ? kOrange : kTextSub, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _tag(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(.12),
      borderRadius: BorderRadius.circular(3),
      border: Border.all(color: color.withOpacity(.3)),
    ),
    child: Text(text,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
  );

  Widget _buildMap() {
    final center = getCenterForArea(widget.adminArea);

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topRight: Radius.circular(12),
        bottomRight: Radius.circular(12),
      ),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              // ★ 地圖中心根據縣市自動切換
              initialCenter: center,
              initialZoom: 14.5,
              backgroundColor: const Color(0xFFF8FAFC),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.example.disaster_app',
              ),
              MarkerLayer(
                markers: _shelters.asMap().entries.map((entry) {
                  final i = entry.key;
                  final s = entry.value;
                  final selected = _selectedIndex == i;

                  return Marker(
                    point: LatLng(s.lat, s.lng),
                    width: selected ? 52 : 44,
                    height: selected ? 52 : 44,
                    child: GestureDetector(
                      onTap: () => _selectShelter(i),
                      child: Container(
                        decoration: BoxDecoration(
                          color: selected
                              ? kOrange
                              : kOrange.withOpacity(.82),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(.3),
                            width: selected ? 2.5 : 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: kOrange.withOpacity(selected ? .32 : .20),
                              blurRadius: selected ? 16 : 8,
                              spreadRadius: selected ? 3 : 1,
                            ),
                          ],
                        ),
                        child: Icon(Icons.apartment,
                            color: Colors.white, size: selected ? 26 : 20),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          // 圖例
          Positioned(
            bottom: 12, left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.94),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: kBorder),
              ),
              child: Row(children: [
                Container(width: 14, height: 14,
                    decoration: const BoxDecoration(
                        color: kOrange, shape: BoxShape.circle)),
                const SizedBox(width: 7),
                const Text('防空避難設施',
                    style: TextStyle(color: kTextSub, fontSize: 11)),
              ]),
            ),
          ),

          // 總容量
          Positioned(
            bottom: 12, right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.94),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: kOrange.withOpacity(.24)),
              ),
              child: Text(
                '總容量：${_formatNumber(_totalCapacity)} 人',
                style: const TextStyle(
                    color: kOrange, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ),

          // 選中資訊卡
          Positioned(top: 12, right: 12, child: _selectedInfoCard()),
        ],
      ),
    );
  }

  Widget _selectedInfoCard() {
    final s = _shelters[_selectedIndex];

    return Container(
      width: 230,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.96),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kOrange.withOpacity(.24)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(.35), blurRadius: 18, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.name,
              style: const TextStyle(
                  color: kTextMain, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 4),
          Text(s.address,
              style: const TextStyle(color: kMuted, fontSize: 10)),
          const SizedBox(height: 8),
          Row(children: [
            _tag('容 ${s.capacity} 人', kGreen),
            const SizedBox(width: 6),
            _tag(s.floors,kBlue),
          ]),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity, height: 36,
            child: ElevatedButton.icon(
              onPressed: () => _openNavigation(s),
              icon: const Icon(Icons.navigation_rounded, size: 15),
              label: const Text('導航前往',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: kOrange.withOpacity(.10),
                foregroundColor: kOrange,
                elevation: 0,
                side: BorderSide(color: kOrange.withOpacity(.24)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(7)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}