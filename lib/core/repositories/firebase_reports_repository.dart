import '../../admin_APP/services/firebase_reports_client.dart';
import '../models/firebase_report.dart';

class FirebaseReportsRepository {
  final FirebaseReportsClient client;
  final int maxPages;
  FirebaseReportsRepository(this.client, {this.maxPages = 20});

  /// A complete bounded refresh, published atomically by the ViewModel. Empty
  /// SOS pages do not terminate traversal. Never falls back to SQLite.
  Future<List<FirebaseReport>> fetch({required bool sosOnly}) async {
    final initialToken = client.tokenProvider();
    final byUid = <String, FirebaseReport>{};
    final seenCursors = <String>{};
    String? cursor;
    for (var page = 0; page < maxPages; page++) {
      if (client.tokenProvider() != initialToken) {
        throw const FirebaseReportsClientException(
            '登入狀態已變更，請重新登入', 'SESSION_CHANGED', 401);
      }
      final result = await client.page(sosOnly: sosOnly, pageToken: cursor);
      for (final report in result.reports) {
        byUid[report.uid] = report;
      }
      cursor = result.nextPageToken;
      if (cursor == null) {
        final reports = byUid.values.toList();
        reports.sort((a, b) {
          if (a.reportTime == null) {
            return b.reportTime == null ? a.uid.compareTo(b.uid) : 1;
          }
          if (b.reportTime == null) return -1;
          final order = b.reportTime!.compareTo(a.reportTime!);
          return order == 0 ? a.uid.compareTo(b.uid) : order;
        });
        return reports;
      }
      if (!seenCursors.add(cursor)) break;
    }
    throw const FirebaseReportsClientException(
        '分頁尚未完整完成，保留上次資料；請稍後重試或縮小查詢範圍', 'INCOMPLETE_REFRESH');
  }

  void close() => client.close();
}
