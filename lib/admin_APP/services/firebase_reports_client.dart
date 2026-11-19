import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/api_config.dart';
import '../../core/models/firebase_report.dart';
import 'reverse_geocoding_client.dart' show AdminApiSession;

class FirebaseReportsClientException implements Exception {
  final String message;
  final String code;
  final int? status;
  const FirebaseReportsClientException(this.message, this.code, [this.status]);
  @override
  String toString() => code;
}

class FirebaseReportsClient {
  final http.Client client;
  final String baseUrl;
  final String? Function() tokenProvider;
  FirebaseReportsClient(this.client,
      {this.baseUrl = ApiConfig.baseUrl, String? Function()? tokenProvider})
      : tokenProvider = tokenProvider ?? (() => AdminApiSession.token);
  Future<FirebaseReportPage> page(
      {required bool sosOnly, String? pageToken}) async {
    final token = tokenProvider();
    if (token == null || token.isEmpty) {
      throw const FirebaseReportsClientException(
          '請重新登入管理員帳號', 'ADMIN_SESSION_REQUIRED', 401);
    }
    try {
      final response = await client
          .post(Uri.parse(baseUrl),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
                'ngrok-skip-browser-warning': 'true',
              },
              body: jsonEncode({
                'type': sosOnly
                    ? 'getFirebaseSosReports'
                    : 'getFirebaseHealthReports',
                'limit': 25,
                if (pageToken != null) 'pageToken': pageToken
              }))
          .timeout(const Duration(seconds: 15));
      if (tokenProvider() != token) {
        throw const FirebaseReportsClientException(
            '登入狀態已變更，請重新整理', 'SESSION_CHANGED', 401);
      }
      if (response.statusCode != 200) {
        final message = switch (response.statusCode) {
          401 => '登入已失效，請重新登入',
          403 => '此管理員沒有 Firestore 回報查詢權限',
          429 => '查詢忙碌，請稍後重新整理',
          503 => 'Firestore 回報服務尚未啟用或目前無法使用',
          504 => 'Firestore 查詢逾時，請重試',
          _ => '無法取得 Firestore 回報，請確認 API 版本及連線',
        };
        throw FirebaseReportsClientException(
            message, 'REPORT_QUERY_FAILED', response.statusCode);
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      if (decoded['success'] != true) {
        throw const FirebaseReportsClientException(
            '後端未確認查詢成功，請重試', 'REPORT_QUERY_FAILED');
      }
      final data = decoded['data'];
      if (decoded['source'] != 'firestore' ||
          decoded['collection'] != 'health_reports' ||
          data is! Map ||
          data['reports'] is! List ||
          data['semantics'] != 'latest_per_uid') {
        throw const FormatException();
      }
      final next = data['nextPageToken'];
      if (next != null &&
          (next is! String ||
              next.isEmpty ||
              next.length > 8192 ||
              RegExp(r'[\x00-\x1f\x7f]').hasMatch(next))) {
        throw const FormatException();
      }
      final reports = <FirebaseReport>[];
      for (final item in data['reports'] as List) {
        if (item is! Map<String, dynamic>) throw const FormatException();
        final report = FirebaseReport.fromJson(item);
        if (sosOnly && report.sos != true) throw const FormatException();
        reports.add(report);
      }
      return FirebaseReportPage(reports, next as String?);
    } on FirebaseReportsClientException {
      rethrow;
    } on TimeoutException {
      throw const FirebaseReportsClientException('查詢逾時，保留上次資料，請重試', 'TIMEOUT');
    } on FormatException {
      throw const FirebaseReportsClientException(
          '後端回應格式不符，請確認 Firestore API 版本', 'INVALID_RESPONSE');
    } catch (_) {
      throw const FirebaseReportsClientException(
          '無法連線至後端，請確認網路及 API 網址', 'NETWORK_ERROR');
    }
  }

  void close() => client.close();
}
