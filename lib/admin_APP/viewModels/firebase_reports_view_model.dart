import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/models/firebase_report.dart';
import '../../core/repositories/firebase_reports_repository.dart';
import '../services/firebase_reports_client.dart';

class FirebaseReportsViewModel extends ChangeNotifier {
  final FirebaseReportsRepository repository;
  final bool sosOnly;
  List<FirebaseReport> reports = const [];
  bool loading = false;
  bool hasLoaded = false;
  bool _disposed = false;
  String? error;
  DateTime? updatedAt;
  FirebaseReportsViewModel(this.repository, {required this.sosOnly});
  Future<void> refresh() async {
    if (_disposed || loading) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final latest = await repository.fetch(sosOnly: sosOnly);
      if (_disposed) return;
      reports = List.unmodifiable(latest);
      hasLoaded = true;
      updatedAt = DateTime.now();
    } on FirebaseReportsClientException catch (e) {
      if (!_disposed) {
        error = e.message;
        if (e.status == 401 || e.status == 403) {
          reports = const [];
          hasLoaded = false;
          updatedAt = null;
        }
      }
    } catch (_) {
      if (!_disposed) error = '回報更新失敗，請重新整理';
    } finally {
      if (!_disposed) {
        loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    repository.close();
    super.dispose();
  }
}

/// One owner per Dashboard session. Offscreen/background views do not poll.
class FirebaseReportsRefreshLoop {
  late final Timer _timer;
  FirebaseReportsRefreshLoop(FirebaseReportsViewModel model,
      {required bool Function() isActive,
      Duration interval = const Duration(seconds: 30)}) {
    _timer = Timer.periodic(interval, (_) {
      if (isActive()) unawaited(model.refresh());
    });
  }
  void close() => _timer.cancel();
}
