import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/models/firebase_report.dart';
import '../viewModels/firebase_reports_view_model.dart';

/// Dashboard owns this VM; the SOS page borrows it without closing or polling twice.
class FirebaseSosScope extends InheritedWidget {
  final FirebaseReportsViewModel model;
  const FirebaseSosScope(
      {super.key, required this.model, required super.child});
  @override
  bool updateShouldNotify(FirebaseSosScope oldWidget) =>
      oldWidget.model != model;
}

String firestoreSosCount(FirebaseReportsViewModel model) => model.hasLoaded
    ? '${model.reports.where((r) => r.sos == true).length}'
    : '尚未取得資料';

String dashboardSosCount(
        bool firestore, FirebaseReportsViewModel model, int sqliteCount) =>
    firestore ? firestoreSosCount(model) : '$sqliteCount';

/// Keeps source selection explicit. SQLite builders never consume Firebase DTOs.
class DashboardSosContent extends StatelessWidget {
  final bool firestore;
  final FirebaseReportsViewModel model;
  final WidgetBuilder sqliteBuilder;
  final VoidCallback onViewAll;
  final Widget Function(List<FirebaseReport>)? mapBuilder;
  const DashboardSosContent(
      {super.key,
      required this.firestore,
      required this.model,
      required this.sqliteBuilder,
      required this.onViewAll,
      this.mapBuilder});
  @override
  Widget build(BuildContext context) => firestore
      ? DashboardFirestoreSos(
          model: model, onViewAll: onViewAll, mapBuilder: mapBuilder)
      : sqliteBuilder(context);
}

class DashboardFirestoreSos extends StatelessWidget {
  final FirebaseReportsViewModel model;
  final VoidCallback onViewAll;

  /// Tests can inspect markers without making tile HTTP requests.
  final Widget Function(List<FirebaseReport>)? mapBuilder;
  const DashboardFirestoreSos(
      {super.key,
      required this.model,
      required this.onViewAll,
      this.mapBuilder});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: model,
      builder: (context, _) {
        final events = model.reports.where((r) => r.sos == true).toList();
        final located = events.where((r) => r.hasCoordinates).toList();
        return Container(
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB))),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text('Firestore 居民回報（唯讀）',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('SOS ${firestoreSosCount(model)}'),
                        const Text('查詢範圍：整個 Firebase Project；非已確認轄區'),
                        TextButton(
                            onPressed: model.loading ? null : model.refresh,
                            child: const Text('重新整理')),
                        TextButton(
                            onPressed: onViewAll,
                            child: const Text('查看全部緊急事件')),
                      ])),
              if (model.loading) const LinearProgressIndicator(),
              if (model.error != null)
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                        model.hasLoaded
                            ? '更新失敗，資料可能過期：${model.error}'
                            : '無法取得資料：${model.error}',
                        style: const TextStyle(color: Colors.red))),
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(model.updatedAt == null
                      ? '尚未成功更新'
                      : '最近成功更新：${model.updatedAt!.toLocal().toString().split('.').first}')),
              const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('GPS 精度與取得時間未知，可能為舊位置；回報時間不等於定位時間。',
                      style: TextStyle(fontSize: 12))),
              const Divider(height: 12),
              Expanded(
                  child: Row(children: [
                Expanded(
                    flex: 7,
                    child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: !model.hasLoaded
                            ? const Center(child: Text('尚未取得 SOS 資料'))
                            : located.isEmpty
                                ? const Center(child: Text('目前沒有可標示的 SOS 位置'))
                                : mapBuilder?.call(located) ??
                                    _FirestoreSosMap(events: located))),
                const VerticalDivider(width: 1),
                Expanded(
                    flex: 4,
                    child: !model.hasLoaded
                        ? const Center(child: Text('尚未取得資料'))
                        : events.isEmpty
                            ? const Center(child: Text('目前沒有 SOS'))
                            : ListView.builder(
                                itemCount: events.length,
                                itemBuilder: (context, index) {
                                  final report = events[index];
                                  return ListTile(
                                      title: Text(
                                          report.name?.isNotEmpty == true
                                              ? report.name!
                                              : '未提供姓名'),
                                      subtitle: Text(
                                          '${report.hasCoordinates ? '有回報座標（轄區未確認）' : '位置未知／轄區未確認'}\n健康狀態：${report.status ?? '未知'}'),
                                      trailing: const Icon(Icons.chevron_right),
                                      onTap: () => showFirestoreSosDetails(
                                          context, model, report.uid));
                                })),
              ])),
            ]));
      });
}

Future<void> showFirestoreSosDetails(
        BuildContext context, FirebaseReportsViewModel model, String uid) =>
    showDialog<void>(
        context: context,
        builder: (ctx) => AnimatedBuilder(
            animation: model,
            builder: (_, __) {
              final matches =
                  model.reports.where((r) => r.uid == uid && r.sos == true);
              final report = matches.isEmpty ? null : matches.first;
              return AlertDialog(
                  title: const Text('Firestore SOS 詳細資料（唯讀）'),
                  content: SizedBox(
                      width: 440,
                      child: SingleChildScrollView(
                          child: report == null
                              ? const Text('此回報已更新或無權檢視，請返回清單')
                              : Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                      if (model.error != null)
                                        const Text('更新失敗，顯示上次成功資料'),
                                      Text('姓名：${report.name ?? '未提供'}'),
                                      Text('健康狀態：${report.status ?? '未知'}'),
                                      const Text('SOS：是'),
                                      Text(
                                          '回報時間：${report.reportTime?.toLocal() ?? '未知'}'),
                                      Text('內容：${report.description ?? '未提供'}'),
                                      Text(report.hasCoordinates
                                          ? 'GPS：${report.latitude}, ${report.longitude}'
                                          : '位置未知'),
                                      const Text('位置精度與取得時間未知，回報時間不等於定位時間。'),
                                      const Text(
                                          '資料來源：Firestore health_reports 最新狀態；不支援 SQLite 處理操作。'),
                                    ]))),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('關閉'))
                  ]);
            }));

class _FirestoreSosMap extends StatelessWidget {
  final List<FirebaseReport> events;
  const _FirestoreSosMap({required this.events});
  @override
  Widget build(BuildContext context) {
    final points =
        events.map((r) => LatLng(r.latitude!, r.longitude!)).toList();
    // Key changes refit the camera when positions change; never invent a point.
    return FlutterMap(
        key: ValueKey(
            points.map((p) => '${p.latitude},${p.longitude}').join(';')),
        options: MapOptions(
            initialCenter: points.first,
            initialZoom: 15,
            initialCameraFit: points.length > 1
                ? CameraFit.bounds(
                    bounds: LatLngBounds.fromPoints(points),
                    padding: const EdgeInsets.all(30),
                    maxZoom: 16)
                : null),
        children: [
          TileLayer(
              urlTemplate:
                  'https://wmts.nlsc.gov.tw/wmts/EMAP/default/GoogleMapsCompatible/{z}/{y}/{x}',
              userAgentPackageName: 'com.example.flutter_disaster_app',
              maxNativeZoom: 16),
          MarkerLayer(markers: [
            for (final point in points)
              Marker(
                  point: point,
                  width: 44,
                  height: 44,
                  child: const Tooltip(
                      message: '居民回報位置（精度與取得時間未知）',
                      child:
                          Icon(Icons.location_on, color: Colors.red, size: 40)))
          ]),
        ]);
  }
}
