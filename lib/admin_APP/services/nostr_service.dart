import 'dart:async';
import 'package:dart_nostr/dart_nostr.dart';

class NostrService {
  final Nostr nostr = Nostr.instance;
  StreamSubscription<NostrEvent>? _subscription;

  /// 初始化 relay
  Future<void> init(List<String> relays) async {
    await nostr.services.relays.init(
      relaysUrl: relays,
    );
    print('Relays initialized: $relays');
  }

  /// 訂閱健康報告
  void subscribeHealthReports({required String pubkey, List<int>? kinds}) {
    final request = NostrRequest(
      filters: [
        NostrFilter(
          kinds: kinds ?? [40001],
          authors: [pubkey],
        ),
      ],
    );

    final eventsStream = nostr.services.relays.startEventsSubscription(
      request: request,
    );

    // 注意這裡，要用 stream.listen
    _subscription = eventsStream.stream.listen((event) {
      print('收到健康回報: ${event.content}');
      // 你可以在這裡再加通知 ViewModel 或其他處理
    });
  }

  /// 停止訂閱
  void stopSubscription() {
    _subscription?.cancel();
    _subscription = null;
  }
}