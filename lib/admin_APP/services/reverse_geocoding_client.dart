import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_disaster_app/core/api_config.dart';

/// Memory only: re-login after browser refresh or backend restart.
class AdminApiSession {
  static String? token;
}

class AddressLookupException implements Exception {
  final String message;
  final int? retryAfterSeconds;
  const AddressLookupException(this.message, [this.retryAfterSeconds]);
}

class ReverseGeocodingClient {
  final http.Client client;
  final String baseUrl;
  ReverseGeocodingClient(this.client, {this.baseUrl = ApiConfig.baseUrl});

  Future<Map<String, dynamic>> lookup(double lat, double lng) async {
    final token = AdminApiSession.token;
    if (token == null || token.isEmpty) {
      throw const AddressLookupException('請重新登入管理員帳號');
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
                'type': 'reverseGeocode',
                'latitude': lat,
                'longitude': lng
              }))
          .timeout(const Duration(seconds: 9));
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      if (json is! Map<String, dynamic>) {
        throw const AddressLookupException('後端回應無效');
      }
      if (response.statusCode != 200 || json['success'] != true) {
        throw AddressLookupException(
            json['message']?.toString() ?? '地址無法取得',
            json['retryAfterSeconds'] is int
                ? json['retryAfterSeconds'] as int
                : null);
      }
      final data = json['data'];
      if (data is! Map<String, dynamic> ||
          data['status'] != 'resolved' ||
          data['address'] is! String ||
          (data['address'] as String).trim().isEmpty) {
        throw const AddressLookupException('後端未提供地址');
      }
      return data;
    } on AddressLookupException {
      rethrow;
    } on TimeoutException {
      throw const AddressLookupException('地址查詢逾時');
    } catch (_) {
      throw const AddressLookupException('無法連線至後端');
    }
  }
}
