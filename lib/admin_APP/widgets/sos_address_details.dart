import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../services/reverse_geocoding_client.dart';

/// Mount ONLY inside a user-opened single SOS detail dialog, never in lists.
class SosAddressDetails extends StatefulWidget {
  final double? latitude, longitude;
  final String? providedAddress;
  final Future<Map<String, dynamic>> Function(double, double)? lookup;
  const SosAddressDetails(
      {super.key,
      required this.latitude,
      required this.longitude,
      this.providedAddress,
      this.lookup});
  @override
  State<SosAddressDetails> createState() => _SosAddressDetailsState();
}

class _SosAddressDetailsState extends State<SosAddressDetails> {
  final _http = http.Client();
  bool _loading = false;
  Map<String, dynamic>? _result;
  String? _error;
  Timer? _cooldown;
  bool _retryAllowed = true;
  int _generation = 0;

  bool get _hasAddress => widget.providedAddress?.trim().isNotEmpty == true;
  bool get _validGps {
    final lat = widget.latitude, lng = widget.longitude;
    return lat != null &&
        lng != null &&
        lat.isFinite &&
        lng.isFinite &&
        lat.abs() <= 90 &&
        lng.abs() <= 180 &&
        !(lat == 0 && lng == 0);
  }

  @override
  void initState() {
    super.initState();
    if (!_hasAddress && _validGps) _load();
  }

  @override
  void didUpdateWidget(covariant SosAddressDetails oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude ||
        oldWidget.providedAddress != widget.providedAddress) {
      _generation++;
      _cooldown?.cancel();
      _retryAllowed = true;
      _result = null;
      _error = null;
      _loading = false;
      if (!_hasAddress && _validGps) _load();
    }
  }

  @override
  void dispose() {
    _generation++;
    _cooldown?.cancel();
    _http.close();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading || !_retryAllowed || !_validGps || _hasAddress) return;
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final lookup = widget.lookup ?? ReverseGeocodingClient(_http).lookup;
      final result = await lookup(widget.latitude!, widget.longitude!);
      if (mounted && generation == _generation) {
        setState(() => _result = result);
      }
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = error is AddressLookupException ? error.message : '地址無法取得';
        _retryAllowed = !(error is AddressLookupException &&
            (error.retryAfterSeconds ?? 0) > 0);
      });
      if (!_retryAllowed && error is AddressLookupException) {
        _cooldown = Timer(Duration(seconds: error.retryAfterSeconds!), () {
          if (mounted && generation == _generation) {
            setState(() => _retryAllowed = true);
          }
        }); // Enables a manual button only. Never performs an automatic retry.
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final address = _hasAddress
        ? widget.providedAddress!.trim()
        : _result?['address']?.toString();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SelectableText(
          'GPS：${widget.latitude ?? '未知'}, ${widget.longitude ?? '未知'}'),
      const SizedBox(height: 8),
      if (_loading)
        const Row(children: [
          SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 8),
          Text('正在查詢附近地址…'),
        ])
      else if (address != null) ...[
        SelectableText(address),
        Text('地址來源：${_hasAddress ? '使用者 App' : _result?['source']}'),
        const Text('地址僅供參考'),
        if (!_hasAddress)
          TextButton(
            onPressed: () =>
                launchUrl(Uri.parse('https://www.openstreetmap.org/copyright')),
            child: const Text('© OpenStreetMap contributors (ODbL)'),
          ),
      ] else ...[
        const Text('地址無法取得'),
        if (!_validGps) const Text('缺少有效 GPS，未進行地址查詢'),
        if (_error != null) Text(_error!, style: const TextStyle(fontSize: 12)),
        if (_validGps)
          TextButton(
            onPressed: _retryAllowed ? _load : null,
            child: Text(_retryAllowed ? '重試查詢附近地址' : '服務冷卻中，請稍後重試'),
          ),
      ],
    ]);
  }
}
