import 'package:criptocracia_app/services/nostr_service.dart';
import 'package:criptocracia_app/services/subscription_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SubscriptionManager', () {
    late NostrService nostrService;
    late SubscriptionManager manager;

    setUp(() {
      nostrService = NostrService();
      manager = nostrService.subscriptionManager;
    });

    tearDown(() {
      nostrService.dispose();
    });

    test('initially has no active subscriptions', () {
      expect(manager.activeSubscriptions, isEmpty);
    });

    test('hasSubscription returns false for unknown names', () {
      expect(manager.hasSubscription('nonexistent'), isFalse);
    });

    test('eventStream is a broadcast stream', () {
      expect(manager.eventStream.isBroadcast, isTrue);
    });

    test('closeAll does not throw when empty', () {
      expect(() => manager.closeAll(), returnsNormally);
    });

    test('clearDeduplicationCache does not throw', () {
      expect(() => manager.clearDeduplicationCache(), returnsNormally);
    });

    test('dispose does not throw', () {
      // Create a separate instance to dispose.
      final service = NostrService();
      final mgr = service.subscriptionManager;
      expect(() => mgr.dispose(), returnsNormally);
      service.dispose();
    });
  });
}
