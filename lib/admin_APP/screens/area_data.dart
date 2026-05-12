// ══════════════════════════════════════════════════════════
//  area_data.dart
//  全台 22 縣市地區資料
//  用途：轄區災防地圖地標、座標資訊、防空避難清單、警報篩選關鍵字
// ══════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

// ── 地標類型 ─────────────────────────────────────────────
enum LandmarkType { shelter, supply, monitor, government }

class AreaLandmark {
  final String name;
  final LandmarkType type;
  final double relX;
  final double relY;

  const AreaLandmark({
    required this.name,
    required this.type,
    required this.relX,
    required this.relY,
  });

  Color get color {
    switch (type) {
      case LandmarkType.shelter:
        return const Color(0xFF16A34A);
      case LandmarkType.supply:
        return const Color(0xFF7C3AED);
      case LandmarkType.monitor:
        return const Color(0xFF2563EB);
      case LandmarkType.government:
        return const Color(0xFFF59E0B);
    }
  }
}

// ── 防空 / 避難收容資料 ───────────────────────────────────
class ShelterInfo {
  final String name;
  final String address;
  final int capacity;

  const ShelterInfo({
    required this.name,
    required this.address,
    required this.capacity,
  });
}

// ── 縣市完整資料 ─────────────────────────────────────────
class AreaData {
  final String name;
  final List<String> keywords;
  final String coordHud;
  final String zoomHud;
  final List<AreaLandmark> landmarks;
  final List<ShelterInfo> shelters;

  const AreaData({
    required this.name,
    required this.keywords,
    required this.coordHud,
    required this.zoomHud,
    required this.landmarks,
    required this.shelters,
  });
}

// ══════════════════════════════════════════════════════════
//  全台 22 縣市資料
// ══════════════════════════════════════════════════════════
const List<AreaData> kAllAreaData = [
  AreaData(
    name: '台北市',
    keywords: ['台北', '北市', '信義', '大安', '中山', '松山', '內湖', '士林', '北投', '文山', '南港', '中正', '萬華', '大同'],
    coordHud: '25.0330°N, 121.5654°E',
    zoomHud: '台北都會區',
    landmarks: [
      AreaLandmark(name: '台北市政府', type: LandmarkType.government, relX: 0.70, relY: 0.30),
      AreaLandmark(name: '大安森林公園避難點', type: LandmarkType.shelter, relX: 0.42, relY: 0.56),
      AreaLandmark(name: '信義區活動中心', type: LandmarkType.shelter, relX: 0.62, relY: 0.44),
      AreaLandmark(name: '台北市消防局', type: LandmarkType.supply, relX: 0.28, relY: 0.38),
      AreaLandmark(name: '淡水河水位監測站', type: LandmarkType.monitor, relX: 0.18, relY: 0.64),
      AreaLandmark(name: '基隆河水位監測站', type: LandmarkType.monitor, relX: 0.56, relY: 0.22),
    ],
    shelters: [
      ShelterInfo(name: '台北市立體育場', address: '信義區市府路周邊', capacity: 3000),
      ShelterInfo(name: '大安運動中心', address: '大安區', capacity: 1500),
      ShelterInfo(name: '士林國中體育館', address: '士林區', capacity: 800),
      ShelterInfo(name: '中正紀念堂廣場', address: '中正區', capacity: 5000),
      ShelterInfo(name: '松山文創園區', address: '信義區', capacity: 2000),
    ],
  ),

  AreaData(
    name: '新北市',
    keywords: ['新北', '板橋', '三重', '中和', '永和', '新莊', '新店', '樹林', '鶯歌', '三峽', '淡水', '汐止', '瑞芳', '土城', '蘆洲', '五股', '泰山', '林口', '烏來'],
    coordHud: '25.0169°N, 121.4627°E',
    zoomHud: '新北轄區',
    landmarks: [
      AreaLandmark(name: '新北市政府', type: LandmarkType.government, relX: 0.48, relY: 0.40),
      AreaLandmark(name: '板橋體育館', type: LandmarkType.shelter, relX: 0.40, relY: 0.55),
      AreaLandmark(name: '三重綜合體育館', type: LandmarkType.shelter, relX: 0.62, relY: 0.30),
      AreaLandmark(name: '新北市消防局', type: LandmarkType.supply, relX: 0.30, relY: 0.44),
      AreaLandmark(name: '淡水河板橋水位站', type: LandmarkType.monitor, relX: 0.20, relY: 0.62),
      AreaLandmark(name: '新店溪水位監測站', type: LandmarkType.monitor, relX: 0.55, relY: 0.70),
    ],
    shelters: [
      ShelterInfo(name: '板橋體育館', address: '板橋區', capacity: 2500),
      ShelterInfo(name: '三重綜合體育館', address: '三重區', capacity: 1800),
      ShelterInfo(name: '新莊體育館', address: '新莊區', capacity: 1200),
      ShelterInfo(name: '淡水國中活動中心', address: '淡水區', capacity: 900),
      ShelterInfo(name: '中和國民運動中心', address: '中和區', capacity: 1500),
    ],
  ),

  AreaData(
    name: '桃園市',
    keywords: ['桃園', '中壢', '平鎮', '八德', '楊梅', '蘆竹', '大溪', '龜山', '龍潭', '新屋', '觀音', '復興'],
    coordHud: '24.9937°N, 121.3010°E',
    zoomHud: '桃園轄區',
    landmarks: [
      AreaLandmark(name: '桃園市政府', type: LandmarkType.government, relX: 0.55, relY: 0.35),
      AreaLandmark(name: '桃園體育園區', type: LandmarkType.shelter, relX: 0.44, relY: 0.50),
      AreaLandmark(name: '中壢區運動中心', type: LandmarkType.shelter, relX: 0.65, relY: 0.60),
      AreaLandmark(name: '桃園市消防局', type: LandmarkType.supply, relX: 0.28, relY: 0.40),
      AreaLandmark(name: '老街溪水位監測站', type: LandmarkType.monitor, relX: 0.70, relY: 0.25),
      AreaLandmark(name: '石門水庫水位站', type: LandmarkType.monitor, relX: 0.20, relY: 0.65),
    ],
    shelters: [
      ShelterInfo(name: '桃園體育園區', address: '桃園區', capacity: 4000),
      ShelterInfo(name: '中壢家商體育館', address: '中壢區', capacity: 1200),
      ShelterInfo(name: '楊梅高中體育館', address: '楊梅區', capacity: 800),
      ShelterInfo(name: '大溪國中活動中心', address: '大溪區', capacity: 600),
      ShelterInfo(name: '蘆竹區公所', address: '蘆竹區', capacity: 500),
    ],
  ),

  AreaData(
    name: '台中市',
    keywords: ['台中', '中市', '西屯', '北屯', '南屯', '豐原', '大甲', '清水', '梧棲', '沙鹿', '烏日', '大里', '太平', '霧峰', '潭子', '神岡', '后里', '東勢', '和平'],
    coordHud: '24.1477°N, 120.6736°E',
    zoomHud: '台中轄區',
    landmarks: [
      AreaLandmark(name: '台中市政府', type: LandmarkType.government, relX: 0.55, relY: 0.38),
      AreaLandmark(name: '台中洲際棒球場', type: LandmarkType.shelter, relX: 0.68, relY: 0.28),
      AreaLandmark(name: '豐原體育館', type: LandmarkType.shelter, relX: 0.38, relY: 0.24),
      AreaLandmark(name: '台中市消防局', type: LandmarkType.supply, relX: 0.28, relY: 0.55),
      AreaLandmark(name: '大甲溪水位監測站', type: LandmarkType.monitor, relX: 0.18, relY: 0.40),
      AreaLandmark(name: '旱溪水位監測站', type: LandmarkType.monitor, relX: 0.62, relY: 0.65),
    ],
    shelters: [
      ShelterInfo(name: '台中洲際棒球場', address: '北屯區', capacity: 5000),
      ShelterInfo(name: '豐原體育館', address: '豐原區', capacity: 1500),
      ShelterInfo(name: '沙鹿體育場', address: '沙鹿區', capacity: 1000),
      ShelterInfo(name: '霧峰區公所', address: '霧峰區', capacity: 600),
      ShelterInfo(name: '大甲國中體育館', address: '大甲區', capacity: 800),
    ],
  ),

  AreaData(
    name: '台南市',
    keywords: ['台南', '南市', '永康', '仁德', '歸仁', '新化', '玉井', '楠西', '善化', '新市', '安定', '新營', '麻豆', '佳里', '安平', '安南'],
    coordHud: '22.9998°N, 120.2269°E',
    zoomHud: '台南轄區',
    landmarks: [
      AreaLandmark(name: '台南市政府', type: LandmarkType.government, relX: 0.58, relY: 0.38),
      AreaLandmark(name: '台南體育公園', type: LandmarkType.shelter, relX: 0.44, relY: 0.52),
      AreaLandmark(name: '永康體育館', type: LandmarkType.shelter, relX: 0.70, relY: 0.28),
      AreaLandmark(name: '台南市消防局', type: LandmarkType.supply, relX: 0.26, relY: 0.44),
      AreaLandmark(name: '曾文溪水位監測站', type: LandmarkType.monitor, relX: 0.16, relY: 0.35),
      AreaLandmark(name: '鹽水溪水位監測站', type: LandmarkType.monitor, relX: 0.60, relY: 0.68),
    ],
    shelters: [
      ShelterInfo(name: '台南體育公園體育館', address: '北區', capacity: 3000),
      ShelterInfo(name: '永康體育館', address: '永康區', capacity: 1500),
      ShelterInfo(name: '善化體育場', address: '善化區', capacity: 800),
      ShelterInfo(name: '新營體育場', address: '新營區', capacity: 1200),
      ShelterInfo(name: '安平國中活動中心', address: '安平區', capacity: 700),
    ],
  ),

  AreaData(
    name: '高雄市',
    keywords: ['高雄', '高市', '左營', '楠梓', '三民', '鼓山', '旗津', '前鎮', '苓雅', '鳳山', '岡山', '旗山', '美濃', '六龜'],
    coordHud: '22.6273°N, 120.3014°E',
    zoomHud: '高雄轄區',
    landmarks: [
      AreaLandmark(name: '高雄市政府', type: LandmarkType.government, relX: 0.55, relY: 0.40),
      AreaLandmark(name: '高雄巨蛋', type: LandmarkType.shelter, relX: 0.34, relY: 0.34),
      AreaLandmark(name: '鳳山體育館', type: LandmarkType.shelter, relX: 0.70, relY: 0.55),
      AreaLandmark(name: '高雄市消防局', type: LandmarkType.supply, relX: 0.24, relY: 0.60),
      AreaLandmark(name: '高屏溪水位監測站', type: LandmarkType.monitor, relX: 0.75, relY: 0.28),
      AreaLandmark(name: '愛河水位監測站', type: LandmarkType.monitor, relX: 0.42, relY: 0.65),
    ],
    shelters: [
      ShelterInfo(name: '高雄巨蛋', address: '左營區', capacity: 15000),
      ShelterInfo(name: '鳳山體育館', address: '鳳山區', capacity: 2000),
      ShelterInfo(name: '三民家商體育館', address: '三民區', capacity: 1000),
      ShelterInfo(name: '岡山體育場', address: '岡山區', capacity: 1500),
      ShelterInfo(name: '前鎮運動中心', address: '前鎮區', capacity: 1200),
    ],
  ),

  AreaData(
    name: '基隆市',
    keywords: ['基隆', '七堵', '暖暖', '安樂', '仁愛', '中山', '中正'],
    coordHud: '25.1276°N, 121.7392°E',
    zoomHud: '基隆轄區',
    landmarks: [
      AreaLandmark(name: '基隆市政府', type: LandmarkType.government, relX: 0.50, relY: 0.44),
      AreaLandmark(name: '基隆體育館', type: LandmarkType.shelter, relX: 0.36, relY: 0.56),
      AreaLandmark(name: '七堵國中活動中心', type: LandmarkType.shelter, relX: 0.65, relY: 0.30),
      AreaLandmark(name: '基隆市消防局', type: LandmarkType.supply, relX: 0.26, relY: 0.38),
      AreaLandmark(name: '基隆河水位監測站', type: LandmarkType.monitor, relX: 0.70, relY: 0.60),
      AreaLandmark(name: '暖暖水位站', type: LandmarkType.monitor, relX: 0.20, relY: 0.65),
    ],
    shelters: [
      ShelterInfo(name: '基隆體育館', address: '仁愛區', capacity: 2000),
      ShelterInfo(name: '七堵國民運動中心', address: '七堵區', capacity: 800),
      ShelterInfo(name: '暖暖高中體育館', address: '暖暖區', capacity: 600),
      ShelterInfo(name: '安樂高中體育館', address: '安樂區', capacity: 700),
      ShelterInfo(name: '基隆港務大樓', address: '中正區', capacity: 1000),
    ],
  ),

  AreaData(
    name: '新竹市',
    keywords: ['新竹市', '竹市', '香山'],
    coordHud: '24.8066°N, 120.9686°E',
    zoomHud: '新竹市轄區',
    landmarks: [
      AreaLandmark(name: '新竹市政府', type: LandmarkType.government, relX: 0.52, relY: 0.42),
      AreaLandmark(name: '新竹體育館', type: LandmarkType.shelter, relX: 0.38, relY: 0.58),
      AreaLandmark(name: '香山區公所避難點', type: LandmarkType.shelter, relX: 0.65, relY: 0.34),
      AreaLandmark(name: '新竹市消防局', type: LandmarkType.supply, relX: 0.28, relY: 0.42),
      AreaLandmark(name: '頭前溪水位監測站', type: LandmarkType.monitor, relX: 0.20, relY: 0.38),
      AreaLandmark(name: '客雅溪水位站', type: LandmarkType.monitor, relX: 0.68, relY: 0.65),
    ],
    shelters: [
      ShelterInfo(name: '新竹體育館', address: '東區', capacity: 2500),
      ShelterInfo(name: '新竹高中體育館', address: '東區', capacity: 1000),
      ShelterInfo(name: '香山國中活動中心', address: '香山區', capacity: 700),
      ShelterInfo(name: '建功高中體育館', address: '北區', capacity: 800),
      ShelterInfo(name: '新竹市文化局廣場', address: '東區', capacity: 600),
    ],
  ),

  AreaData(
    name: '嘉義市',
    keywords: ['嘉義市', '嘉市'],
    coordHud: '23.4800°N, 120.4491°E',
    zoomHud: '嘉義市轄區',
    landmarks: [
      AreaLandmark(name: '嘉義市政府', type: LandmarkType.government, relX: 0.52, relY: 0.40),
      AreaLandmark(name: '嘉義體育館', type: LandmarkType.shelter, relX: 0.36, relY: 0.56),
      AreaLandmark(name: '嘉義棒球場', type: LandmarkType.shelter, relX: 0.65, relY: 0.34),
      AreaLandmark(name: '嘉義市消防局', type: LandmarkType.supply, relX: 0.28, relY: 0.44),
      AreaLandmark(name: '北港溪水位監測站', type: LandmarkType.monitor, relX: 0.18, relY: 0.60),
      AreaLandmark(name: '八掌溪水位站', type: LandmarkType.monitor, relX: 0.70, relY: 0.65),
    ],
    shelters: [
      ShelterInfo(name: '嘉義體育館', address: '東區', capacity: 2000),
      ShelterInfo(name: '嘉義棒球場', address: '東區', capacity: 5000),
      ShelterInfo(name: '嘉義高中體育館', address: '東區', capacity: 900),
      ShelterInfo(name: '西區公所活動中心', address: '西區', capacity: 500),
      ShelterInfo(name: '仁義潭水庫管理站', address: '東區', capacity: 300),
    ],
  ),

  AreaData(
    name: '新竹縣',
    keywords: ['新竹縣', '竹縣', '竹北', '竹東', '新豐', '新埔', '關西', '芎林', '寶山', '北埔', '峨眉', '尖石', '五峰', '湖口'],
    coordHud: '24.8387°N, 121.0177°E',
    zoomHud: '新竹縣轄區',
    landmarks: [
      AreaLandmark(name: '新竹縣政府', type: LandmarkType.government, relX: 0.55, relY: 0.40),
      AreaLandmark(name: '竹北體育館', type: LandmarkType.shelter, relX: 0.42, relY: 0.52),
      AreaLandmark(name: '竹東綜合體育場', type: LandmarkType.shelter, relX: 0.65, relY: 0.30),
      AreaLandmark(name: '新竹縣消防局', type: LandmarkType.supply, relX: 0.26, relY: 0.46),
      AreaLandmark(name: '頭前溪水位監測站', type: LandmarkType.monitor, relX: 0.18, relY: 0.60),
      AreaLandmark(name: '鳳山溪水位站', type: LandmarkType.monitor, relX: 0.68, relY: 0.68),
    ],
    shelters: [
      ShelterInfo(name: '竹北體育館', address: '竹北市', capacity: 2000),
      ShelterInfo(name: '竹東高中體育館', address: '竹東鎮', capacity: 900),
      ShelterInfo(name: '關西國中活動中心', address: '關西鎮', capacity: 500),
      ShelterInfo(name: '新豐高中體育館', address: '新豐鄉', capacity: 600),
      ShelterInfo(name: '湖口鄉公所', address: '湖口鄉', capacity: 400),
    ],
  ),

  AreaData(
    name: '苗栗縣',
    keywords: ['苗栗', '頭份', '竹南', '後龍', '通霄', '苑裡', '造橋', '頭屋', '公館', '銅鑼', '三義', '西湖', '大湖', '獅潭', '南庄', '泰安'],
    coordHud: '24.5602°N, 120.8214°E',
    zoomHud: '苗栗轄區',
    landmarks: [
      AreaLandmark(name: '苗栗縣政府', type: LandmarkType.government, relX: 0.52, relY: 0.40),
      AreaLandmark(name: '苗栗體育場', type: LandmarkType.shelter, relX: 0.38, relY: 0.55),
      AreaLandmark(name: '頭份體育館', type: LandmarkType.shelter, relX: 0.65, relY: 0.30),
      AreaLandmark(name: '苗栗縣消防局', type: LandmarkType.supply, relX: 0.26, relY: 0.44),
      AreaLandmark(name: '中港溪水位監測站', type: LandmarkType.monitor, relX: 0.16, relY: 0.62),
      AreaLandmark(name: '後龍溪水位站', type: LandmarkType.monitor, relX: 0.68, relY: 0.65),
    ],
    shelters: [
      ShelterInfo(name: '苗栗體育場', address: '苗栗市', capacity: 2000),
      ShelterInfo(name: '頭份體育館', address: '頭份市', capacity: 1200),
      ShelterInfo(name: '竹南國中體育館', address: '竹南鎮', capacity: 700),
      ShelterInfo(name: '苑裡高中體育館', address: '苑裡鎮', capacity: 600),
      ShelterInfo(name: '三義鄉公所', address: '三義鄉', capacity: 300),
    ],
  ),

  AreaData(
    name: '彰化縣',
    keywords: ['彰化', '和美', '鹿港', '溪湖', '田中', '員林', '二林', '北斗', '芳苑', '溪州'],
    coordHud: '24.0735°N, 120.5364°E',
    zoomHud: '彰化轄區',
    landmarks: [
      AreaLandmark(name: '彰化縣政府', type: LandmarkType.government, relX: 0.52, relY: 0.38),
      AreaLandmark(name: '彰化體育館', type: LandmarkType.shelter, relX: 0.38, relY: 0.52),
      AreaLandmark(name: '員林體育場', type: LandmarkType.shelter, relX: 0.65, relY: 0.34),
      AreaLandmark(name: '彰化縣消防局', type: LandmarkType.supply, relX: 0.26, relY: 0.46),
      AreaLandmark(name: '濁水溪水位監測站', type: LandmarkType.monitor, relX: 0.16, relY: 0.65),
      AreaLandmark(name: '舊濁水溪水位站', type: LandmarkType.monitor, relX: 0.68, relY: 0.68),
    ],
    shelters: [
      ShelterInfo(name: '彰化體育館', address: '彰化市', capacity: 2500),
      ShelterInfo(name: '員林體育場', address: '員林市', capacity: 1500),
      ShelterInfo(name: '鹿港國中體育館', address: '鹿港鎮', capacity: 800),
      ShelterInfo(name: '北斗國中體育館', address: '北斗鎮', capacity: 600),
      ShelterInfo(name: '二林高中體育館', address: '二林鎮', capacity: 700),
    ],
  ),

  AreaData(
    name: '南投縣',
    keywords: ['南投', '埔里', '草屯', '竹山', '集集', '名間', '鹿谷', '中寮', '魚池', '國姓', '水里', '信義鄉', '仁愛', '眉溪', '濁水'],
    coordHud: '23.9609°N, 120.9718°E',
    zoomHud: '南投埔里轄區',
    landmarks: [
      AreaLandmark(name: '南投縣政府', type: LandmarkType.government, relX: 0.42, relY: 0.36),
      AreaLandmark(name: '埔里鎮公所', type: LandmarkType.government, relX: 0.68, relY: 0.34),
      AreaLandmark(name: '宏仁國中', type: LandmarkType.shelter, relX: 0.78, relY: 0.56),
      AreaLandmark(name: '埔里國中活動中心', type: LandmarkType.shelter, relX: 0.66, relY: 0.50),
      AreaLandmark(name: '消防局埔里分隊', type: LandmarkType.supply, relX: 0.58, relY: 0.60),
      AreaLandmark(name: '眉溪水位監測站', type: LandmarkType.monitor, relX: 0.48, relY: 0.68),
      AreaLandmark(name: '埔里基督教醫院', type: LandmarkType.shelter, relX: 0.72, relY: 0.46),
      AreaLandmark(name: '國道六號埔里交流道', type: LandmarkType.monitor, relX: 0.74, relY: 0.42),
    ],
    shelters: [
      ShelterInfo(name: '宏仁國中', address: '南投縣埔里鎮', capacity: 600),
      ShelterInfo(name: '埔里國中活動中心', address: '南投縣埔里鎮', capacity: 800),
      ShelterInfo(name: '埔里鎮公所', address: '南投縣埔里鎮中山路', capacity: 500),
      ShelterInfo(name: '南投縣體育場', address: '南投縣南投市', capacity: 2000),
      ShelterInfo(name: '草屯國中體育館', address: '南投縣草屯鎮', capacity: 700),
      ShelterInfo(name: '埔里高工活動中心', address: '南投縣埔里鎮', capacity: 900),
    ],
  ),

  AreaData(
    name: '雲林縣',
    keywords: ['雲林', '斗六', '斗南', '虎尾', '西螺', '土庫', '北港', '古坑', '林內', '麥寮', '口湖'],
    coordHud: '23.7086°N, 120.5313°E',
    zoomHud: '雲林轄區',
    landmarks: [
      AreaLandmark(name: '雲林縣政府', type: LandmarkType.government, relX: 0.52, relY: 0.40),
      AreaLandmark(name: '斗六體育場', type: LandmarkType.shelter, relX: 0.38, relY: 0.52),
      AreaLandmark(name: '虎尾綜合體育館', type: LandmarkType.shelter, relX: 0.65, relY: 0.34),
      AreaLandmark(name: '雲林縣消防局', type: LandmarkType.supply, relX: 0.26, relY: 0.46),
      AreaLandmark(name: '濁水溪水位監測站', type: LandmarkType.monitor, relX: 0.16, relY: 0.35),
      AreaLandmark(name: '北港溪水位站', type: LandmarkType.monitor, relX: 0.70, relY: 0.68),
    ],
    shelters: [
      ShelterInfo(name: '斗六體育場', address: '斗六市', capacity: 2000),
      ShelterInfo(name: '虎尾綜合體育館', address: '虎尾鎮', capacity: 1500),
      ShelterInfo(name: '北港體育館', address: '北港鎮', capacity: 900),
      ShelterInfo(name: '西螺國中體育館', address: '西螺鎮', capacity: 600),
      ShelterInfo(name: '林內鄉公所', address: '林內鄉', capacity: 350),
    ],
  ),

  AreaData(
    name: '嘉義縣',
    keywords: ['嘉義縣', '嘉縣', '太保', '朴子', '布袋', '大林', '民雄', '新港', '水上', '中埔', '竹崎', '阿里山'],
    coordHud: '23.4518°N, 120.2554°E',
    zoomHud: '嘉義縣轄區',
    landmarks: [
      AreaLandmark(name: '嘉義縣政府', type: LandmarkType.government, relX: 0.52, relY: 0.38),
      AreaLandmark(name: '太保體育場', type: LandmarkType.shelter, relX: 0.38, relY: 0.52),
      AreaLandmark(name: '民雄國中活動中心', type: LandmarkType.shelter, relX: 0.65, relY: 0.34),
      AreaLandmark(name: '嘉義縣消防局', type: LandmarkType.supply, relX: 0.26, relY: 0.46),
      AreaLandmark(name: '八掌溪水位監測站', type: LandmarkType.monitor, relX: 0.16, relY: 0.35),
      AreaLandmark(name: '北港溪水位站', type: LandmarkType.monitor, relX: 0.70, relY: 0.65),
    ],
    shelters: [
      ShelterInfo(name: '太保體育場', address: '太保市', capacity: 2500),
      ShelterInfo(name: '民雄國中體育館', address: '民雄鄉', capacity: 800),
      ShelterInfo(name: '大林國中體育館', address: '大林鎮', capacity: 700),
      ShelterInfo(name: '朴子國中體育館', address: '朴子市', capacity: 600),
      ShelterInfo(name: '水上國中活動中心', address: '水上鄉', capacity: 500),
    ],
  ),

  AreaData(
    name: '屏東縣',
    keywords: ['屏東', '潮州', '東港', '恆春', '里港', '高樹', '內埔', '萬丹', '枋寮', '琉球', '三地門'],
    coordHud: '22.6723°N, 120.4876°E',
    zoomHud: '屏東轄區',
    landmarks: [
      AreaLandmark(name: '屏東縣政府', type: LandmarkType.government, relX: 0.52, relY: 0.38),
      AreaLandmark(name: '屏東體育場', type: LandmarkType.shelter, relX: 0.38, relY: 0.52),
      AreaLandmark(name: '東港體育館', type: LandmarkType.shelter, relX: 0.65, relY: 0.34),
      AreaLandmark(name: '屏東縣消防局', type: LandmarkType.supply, relX: 0.26, relY: 0.46),
      AreaLandmark(name: '高屏溪水位監測站', type: LandmarkType.monitor, relX: 0.16, relY: 0.35),
      AreaLandmark(name: '東港溪水位站', type: LandmarkType.monitor, relX: 0.70, relY: 0.65),
    ],
    shelters: [
      ShelterInfo(name: '屏東體育場', address: '屏東市', capacity: 2500),
      ShelterInfo(name: '東港體育館', address: '東港鎮', capacity: 1000),
      ShelterInfo(name: '潮州高中體育館', address: '潮州鎮', capacity: 800),
      ShelterInfo(name: '恆春體育館', address: '恆春鎮', capacity: 600),
      ShelterInfo(name: '里港國中體育館', address: '里港鄉', capacity: 500),
    ],
  ),

  AreaData(
    name: '宜蘭縣',
    keywords: ['宜蘭', '羅東', '蘇澳', '頭城', '礁溪', '壯圍', '員山', '冬山', '五結', '三星', '大同', '南澳'],
    coordHud: '24.7020°N, 121.7378°E',
    zoomHud: '宜蘭轄區',
    landmarks: [
      AreaLandmark(name: '宜蘭縣政府', type: LandmarkType.government, relX: 0.50, relY: 0.40),
      AreaLandmark(name: '宜蘭運動公園', type: LandmarkType.shelter, relX: 0.36, relY: 0.56),
      AreaLandmark(name: '羅東體育場', type: LandmarkType.shelter, relX: 0.65, relY: 0.34),
      AreaLandmark(name: '宜蘭縣消防局', type: LandmarkType.supply, relX: 0.26, relY: 0.44),
      AreaLandmark(name: '蘭陽溪水位監測站', type: LandmarkType.monitor, relX: 0.18, relY: 0.35),
      AreaLandmark(name: '冬山河水位站', type: LandmarkType.monitor, relX: 0.70, relY: 0.65),
    ],
    shelters: [
      ShelterInfo(name: '宜蘭運動公園體育館', address: '宜蘭市', capacity: 2000),
      ShelterInfo(name: '羅東體育場', address: '羅東鎮', capacity: 1500),
      ShelterInfo(name: '蘇澳國中體育館', address: '蘇澳鎮', capacity: 700),
      ShelterInfo(name: '頭城國中體育館', address: '頭城鎮', capacity: 600),
      ShelterInfo(name: '冬山鄉公所', address: '冬山鄉', capacity: 400),
    ],
  ),

  AreaData(
    name: '花蓮縣',
    keywords: ['花蓮', '吉安', '新城', '秀林', '壽豐', '光復', '豐濱', '瑞穗', '玉里', '富里', '卓溪', '萬榮'],
    coordHud: '23.9872°N, 121.6015°E',
    zoomHud: '花蓮轄區',
    landmarks: [
      AreaLandmark(name: '花蓮縣政府', type: LandmarkType.government, relX: 0.52, relY: 0.38),
      AreaLandmark(name: '花蓮體育場', type: LandmarkType.shelter, relX: 0.38, relY: 0.52),
      AreaLandmark(name: '吉安體育館', type: LandmarkType.shelter, relX: 0.65, relY: 0.34),
      AreaLandmark(name: '花蓮縣消防局', type: LandmarkType.supply, relX: 0.26, relY: 0.46),
      AreaLandmark(name: '秀姑巒溪水位站', type: LandmarkType.monitor, relX: 0.16, relY: 0.65),
      AreaLandmark(name: '花蓮溪水位監測站', type: LandmarkType.monitor, relX: 0.70, relY: 0.62),
    ],
    shelters: [
      ShelterInfo(name: '花蓮體育場', address: '花蓮市', capacity: 3000),
      ShelterInfo(name: '吉安體育館', address: '吉安鄉', capacity: 1000),
      ShelterInfo(name: '玉里體育館', address: '玉里鎮', capacity: 800),
      ShelterInfo(name: '光復鄉公所', address: '光復鄉', capacity: 400),
      ShelterInfo(name: '新城國中體育館', address: '新城鄉', capacity: 500),
    ],
  ),

  AreaData(
    name: '台東縣',
    keywords: ['台東', '成功', '關山', '卑南', '鹿野', '池上', '東河', '長濱', '太麻里', '大武', '綠島', '蘭嶼'],
    coordHud: '22.7583°N, 121.1444°E',
    zoomHud: '台東轄區',
    landmarks: [
      AreaLandmark(name: '台東縣政府', type: LandmarkType.government, relX: 0.52, relY: 0.38),
      AreaLandmark(name: '台東體育場', type: LandmarkType.shelter, relX: 0.38, relY: 0.52),
      AreaLandmark(name: '關山體育館', type: LandmarkType.shelter, relX: 0.65, relY: 0.34),
      AreaLandmark(name: '台東縣消防局', type: LandmarkType.supply, relX: 0.26, relY: 0.46),
      AreaLandmark(name: '卑南溪水位監測站', type: LandmarkType.monitor, relX: 0.16, relY: 0.62),
      AreaLandmark(name: '秀姑巒溪水位站', type: LandmarkType.monitor, relX: 0.70, relY: 0.62),
    ],
    shelters: [
      ShelterInfo(name: '台東體育場', address: '台東市', capacity: 2000),
      ShelterInfo(name: '關山體育館', address: '關山鎮', capacity: 700),
      ShelterInfo(name: '成功高中體育館', address: '成功鎮', capacity: 500),
      ShelterInfo(name: '台東大學體育場', address: '台東市', capacity: 1500),
      ShelterInfo(name: '池上鄉公所', address: '池上鄉', capacity: 300),
    ],
  ),

  AreaData(
    name: '澎湖縣',
    keywords: ['澎湖', '馬公', '西嶼', '望安', '七美', '白沙', '湖西'],
    coordHud: '23.5711°N, 119.5793°E',
    zoomHud: '澎湖轄區',
    landmarks: [
      AreaLandmark(name: '澎湖縣政府', type: LandmarkType.government, relX: 0.52, relY: 0.40),
      AreaLandmark(name: '馬公體育場', type: LandmarkType.shelter, relX: 0.38, relY: 0.56),
      AreaLandmark(name: '馬公國中體育館', type: LandmarkType.shelter, relX: 0.65, relY: 0.30),
      AreaLandmark(name: '澎湖縣消防局', type: LandmarkType.supply, relX: 0.28, relY: 0.44),
      AreaLandmark(name: '海象觀測站', type: LandmarkType.monitor, relX: 0.18, relY: 0.62),
      AreaLandmark(name: '澎湖氣象站', type: LandmarkType.monitor, relX: 0.70, relY: 0.65),
    ],
    shelters: [
      ShelterInfo(name: '馬公體育場', address: '馬公市', capacity: 1500),
      ShelterInfo(name: '馬公國中體育館', address: '馬公市', capacity: 800),
      ShelterInfo(name: '湖西鄉公所', address: '湖西鄉', capacity: 300),
      ShelterInfo(name: '白沙鄉公所', address: '白沙鄉', capacity: 300),
      ShelterInfo(name: '西嶼鄉公所', address: '西嶼鄉', capacity: 250),
    ],
  ),

  AreaData(
    name: '金門縣',
    keywords: ['金門', '金城', '金湖', '金沙', '金寧', '烈嶼', '烏坵'],
    coordHud: '24.4493°N, 118.3767°E',
    zoomHud: '金門轄區',
    landmarks: [
      AreaLandmark(name: '金門縣政府', type: LandmarkType.government, relX: 0.52, relY: 0.40),
      AreaLandmark(name: '金門體育館', type: LandmarkType.shelter, relX: 0.36, relY: 0.56),
      AreaLandmark(name: '金湖體育場', type: LandmarkType.shelter, relX: 0.65, relY: 0.30),
      AreaLandmark(name: '金門縣消防局', type: LandmarkType.supply, relX: 0.26, relY: 0.44),
      AreaLandmark(name: '太湖水位監測站', type: LandmarkType.monitor, relX: 0.18, relY: 0.60),
      AreaLandmark(name: '金門氣象站', type: LandmarkType.monitor, relX: 0.70, relY: 0.65),
    ],
    shelters: [
      ShelterInfo(name: '金門體育館', address: '金城鎮', capacity: 1500),
      ShelterInfo(name: '金湖體育場', address: '金湖鎮', capacity: 800),
      ShelterInfo(name: '金沙鎮公所', address: '金沙鎮', capacity: 300),
      ShelterInfo(name: '金寧鄉公所', address: '金寧鄉', capacity: 250),
      ShelterInfo(name: '烈嶼鄉公所', address: '烈嶼鄉', capacity: 200),
    ],
  ),

  AreaData(
    name: '連江縣',
    keywords: ['連江', '馬祖', '南竿', '北竿', '莒光', '東引'],
    coordHud: '26.1605°N, 119.9529°E',
    zoomHud: '連江轄區',
    landmarks: [
      AreaLandmark(name: '連江縣政府', type: LandmarkType.government, relX: 0.52, relY: 0.40),
      AreaLandmark(name: '南竿體育場', type: LandmarkType.shelter, relX: 0.38, relY: 0.56),
      AreaLandmark(name: '北竿體育場', type: LandmarkType.shelter, relX: 0.65, relY: 0.30),
      AreaLandmark(name: '連江縣消防局', type: LandmarkType.supply, relX: 0.26, relY: 0.44),
      AreaLandmark(name: '南竿氣象站', type: LandmarkType.monitor, relX: 0.18, relY: 0.62),
      AreaLandmark(name: '東引氣象測站', type: LandmarkType.monitor, relX: 0.70, relY: 0.65),
    ],
    shelters: [
      ShelterInfo(name: '南竿鄉公所活動中心', address: '南竿鄉', capacity: 500),
      ShelterInfo(name: '北竿鄉公所', address: '北竿鄉', capacity: 300),
      ShelterInfo(name: '莒光鄉公所', address: '莒光鄉', capacity: 200),
      ShelterInfo(name: '東引鄉公所', address: '東引鄉', capacity: 150),
      ShelterInfo(name: '馬祖酒廠倉儲中心', address: '南竿鄉', capacity: 800),
    ],
  ),
];

// ══════════════════════════════════════════════════════════
//  AreaDataHelper
// ══════════════════════════════════════════════════════════
class AreaDataHelper {
  static const Map<String, String> _townToCity = {
    // 台北市
    '中正區': '台北市',
    '大同區': '台北市',
    '中山區': '台北市',
    '松山區': '台北市',
    '大安區': '台北市',
    '萬華區': '台北市',
    '信義區': '台北市',
    '士林區': '台北市',
    '北投區': '台北市',
    '內湖區': '台北市',
    '南港區': '台北市',
    '文山區': '台北市',

    // 新北市
    '板橋區': '新北市',
    '三重區': '新北市',
    '中和區': '新北市',
    '永和區': '新北市',
    '新莊區': '新北市',
    '新店區': '新北市',
    '樹林區': '新北市',
    '鶯歌區': '新北市',
    '三峽區': '新北市',
    '淡水區': '新北市',
    '汐止區': '新北市',
    '瑞芳區': '新北市',
    '土城區': '新北市',
    '蘆洲區': '新北市',
    '五股區': '新北市',
    '泰山區': '新北市',
    '林口區': '新北市',
    '深坑區': '新北市',
    '石碇區': '新北市',
    '坪林區': '新北市',
    '三芝區': '新北市',
    '石門區': '新北市',
    '八里區': '新北市',
    '平溪區': '新北市',
    '雙溪區': '新北市',
    '貢寮區': '新北市',
    '金山區': '新北市',
    '萬里區': '新北市',
    '烏來區': '新北市',

    // 桃園市
    '桃園區': '桃園市',
    '中壢區': '桃園市',
    '平鎮區': '桃園市',
    '八德區': '桃園市',
    '楊梅區': '桃園市',
    '蘆竹區': '桃園市',
    '大溪區': '桃園市',
    '龜山區': '桃園市',
    '龍潭區': '桃園市',
    '新屋區': '桃園市',
    '觀音區': '桃園市',
    '復興區': '桃園市',

    // 台中市
    '西屯區': '台中市',
    '南屯區': '台中市',
    '北屯區': '台中市',
    '豐原區': '台中市',
    '大甲區': '台中市',
    '清水區': '台中市',
    '梧棲區': '台中市',
    '沙鹿區': '台中市',
    '烏日區': '台中市',
    '大里區': '台中市',
    '太平區': '台中市',
    '霧峰區': '台中市',
    '潭子區': '台中市',
    '神岡區': '台中市',
    '后里區': '台中市',
    '東勢區': '台中市',
    '新社區': '台中市',
    '石岡區': '台中市',
    '和平區': '台中市',
    '大肚區': '台中市',
    '龍井區': '台中市',
    '大安區-台中': '台中市',

    // 台南市
    '中西區': '台南市',
    '安平區': '台南市',
    '安南區': '台南市',
    '永康區': '台南市',
    '仁德區': '台南市',
    '歸仁區': '台南市',
    '新化區': '台南市',
    '左鎮區': '台南市',
    '玉井區': '台南市',
    '楠西區': '台南市',
    '南化區': '台南市',
    '善化區': '台南市',
    '大內區': '台南市',
    '山上區': '台南市',
    '新市區': '台南市',
    '安定區': '台南市',
    '西港區': '台南市',
    '七股區': '台南市',
    '將軍區': '台南市',
    '學甲區': '台南市',
    '北門區': '台南市',
    '新營區': '台南市',
    '後壁區': '台南市',
    '白河區': '台南市',
    '東山區': '台南市',
    '六甲區': '台南市',
    '下營區': '台南市',
    '柳營區': '台南市',
    '鹽水區': '台南市',
    '麻豆區': '台南市',
    '佳里區': '台南市',
    '官田區': '台南市',
    '關廟區': '台南市',
    '龍崎區': '台南市',

    // 高雄市
    '楠梓區': '高雄市',
    '左營區': '高雄市',
    '鼓山區': '高雄市',
    '三民區': '高雄市',
    '鹽埕區': '高雄市',
    '前金區': '高雄市',
    '新興區': '高雄市',
    '苓雅區': '高雄市',
    '前鎮區': '高雄市',
    '旗津區': '高雄市',
    '小港區': '高雄市',
    '鳳山區': '高雄市',
    '仁武區': '高雄市',
    '大社區': '高雄市',
    '岡山區': '高雄市',
    '路竹區': '高雄市',
    '橋頭區': '高雄市',
    '梓官區': '高雄市',
    '彌陀區': '高雄市',
    '永安區': '高雄市',
    '湖內區': '高雄市',
    '林園區': '高雄市',
    '大寮區': '高雄市',
    '大樹區': '高雄市',
    '旗山區': '高雄市',
    '美濃區': '高雄市',
    '六龜區': '高雄市',
    '甲仙區': '高雄市',
    '杉林區': '高雄市',
    '內門區': '高雄市',
    '茂林區': '高雄市',
    '桃源區': '高雄市',
    '那瑪夏區': '高雄市',
    '阿蓮區': '高雄市',
    '田寮區': '高雄市',
    '燕巢區': '高雄市',
    '茄萣區': '高雄市',

    // 其他縣市
    '基隆市': '基隆市',
    '七堵區': '基隆市',
    '暖暖區': '基隆市',
    '安樂區': '基隆市',
    '新竹市': '新竹市',
    '香山區': '新竹市',
    '嘉義市': '嘉義市',

    '竹北市': '新竹縣',
    '竹東鎮': '新竹縣',
    '新埔鎮': '新竹縣',
    '關西鎮': '新竹縣',
    '湖口鄉': '新竹縣',
    '新豐鄉': '新竹縣',
    '芎林鄉': '新竹縣',
    '橫山鄉': '新竹縣',
    '北埔鄉': '新竹縣',
    '寶山鄉': '新竹縣',
    '峨眉鄉': '新竹縣',
    '尖石鄉': '新竹縣',
    '五峰鄉': '新竹縣',

    '苗栗市': '苗栗縣',
    '頭份市': '苗栗縣',
    '竹南鎮': '苗栗縣',
    '後龍鎮': '苗栗縣',
    '通霄鎮': '苗栗縣',
    '苑裡鎮': '苗栗縣',
    '造橋鄉': '苗栗縣',
    '頭屋鄉': '苗栗縣',
    '公館鄉': '苗栗縣',
    '銅鑼鄉': '苗栗縣',
    '三義鄉': '苗栗縣',
    '西湖鄉': '苗栗縣',
    '大湖鄉': '苗栗縣',
    '獅潭鄉': '苗栗縣',
    '南庄鄉': '苗栗縣',
    '泰安鄉': '苗栗縣',

    '彰化市': '彰化縣',
    '和美鎮': '彰化縣',
    '鹿港鎮': '彰化縣',
    '溪湖鎮': '彰化縣',
    '田中鎮': '彰化縣',
    '員林市': '彰化縣',
    '二林鎮': '彰化縣',
    '北斗鎮': '彰化縣',

    '南投市': '南投縣',
    '埔里鎮': '南投縣',
    '草屯鎮': '南投縣',
    '竹山鎮': '南投縣',
    '集集鎮': '南投縣',
    '名間鄉': '南投縣',
    '鹿谷鄉': '南投縣',
    '中寮鄉': '南投縣',
    '魚池鄉': '南投縣',
    '國姓鄉': '南投縣',
    '水里鄉': '南投縣',
    '信義鄉': '南投縣',
    '仁愛鄉': '南投縣',

    '斗六市': '雲林縣',
    '斗南鎮': '雲林縣',
    '虎尾鎮': '雲林縣',
    '西螺鎮': '雲林縣',
    '土庫鎮': '雲林縣',
    '北港鎮': '雲林縣',
    '古坑鄉': '雲林縣',
    '林內鄉': '雲林縣',
    '麥寮鄉': '雲林縣',

    '太保市': '嘉義縣',
    '朴子市': '嘉義縣',
    '布袋鎮': '嘉義縣',
    '大林鎮': '嘉義縣',
    '民雄鄉': '嘉義縣',
    '新港鄉': '嘉義縣',
    '水上鄉': '嘉義縣',
    '中埔鄉': '嘉義縣',
    '竹崎鄉': '嘉義縣',
    '阿里山鄉': '嘉義縣',

    '屏東市': '屏東縣',
    '潮州鎮': '屏東縣',
    '東港鎮': '屏東縣',
    '恆春鎮': '屏東縣',
    '里港鄉': '屏東縣',
    '高樹鄉': '屏東縣',
    '內埔鄉': '屏東縣',
    '萬丹鄉': '屏東縣',
    '琉球鄉': '屏東縣',
    '三地門鄉': '屏東縣',

    '宜蘭市': '宜蘭縣',
    '羅東鎮': '宜蘭縣',
    '蘇澳鎮': '宜蘭縣',
    '頭城鎮': '宜蘭縣',
    '礁溪鄉': '宜蘭縣',
    '冬山鄉': '宜蘭縣',
    '南澳鄉': '宜蘭縣',

    '花蓮市': '花蓮縣',
    '吉安鄉': '花蓮縣',
    '新城鄉': '花蓮縣',
    '秀林鄉': '花蓮縣',
    '壽豐鄉': '花蓮縣',
    '玉里鎮': '花蓮縣',

    '台東市': '台東縣',
    '成功鎮': '台東縣',
    '關山鎮': '台東縣',
    '卑南鄉': '台東縣',
    '鹿野鄉': '台東縣',
    '池上鄉': '台東縣',
    '綠島鄉': '台東縣',
    '蘭嶼鄉': '台東縣',

    '馬公市': '澎湖縣',
    '湖西鄉': '澎湖縣',
    '白沙鄉': '澎湖縣',
    '西嶼鄉': '澎湖縣',
    '望安鄉': '澎湖縣',
    '七美鄉': '澎湖縣',

    '金城鎮': '金門縣',
    '金湖鎮': '金門縣',
    '金沙鎮': '金門縣',
    '金寧鄉': '金門縣',
    '烈嶼鄉': '金門縣',

    '南竿鄉': '連江縣',
    '北竿鄉': '連江縣',
    '莒光鄉': '連江縣',
    '東引鄉': '連江縣',
  };

  static String toCityName(String areaName) {
    final clean = areaName.trim();

    if (clean.isEmpty) return '南投縣';

    final direct = kAllAreaData.where((e) => e.name == clean).toList();
    if (direct.isNotEmpty) return direct.first.name;

    if (_townToCity.containsKey(clean)) return _townToCity[clean]!;

    for (final entry in _townToCity.entries) {
      if (clean.contains(entry.key)) return entry.value;
    }

    for (final area in kAllAreaData) {
      if (clean.contains(area.name) || area.name.contains(clean)) {
        return area.name;
      }
    }

    return '南投縣';
  }

  static AreaData findByName(String areaName) {
    final cityName = toCityName(areaName);

    return kAllAreaData.firstWhere(
      (area) => area.name == cityName,
      orElse: () => kAllAreaData.firstWhere((area) => area.name == '南投縣'),
    );
  }

  static List<ShelterInfo> sheltersByArea(String areaName) {
    return findByName(areaName).shelters;
  }

  static List<AreaLandmark> landmarksByArea(String areaName) {
    return findByName(areaName).landmarks;
  }
}
