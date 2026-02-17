import 'package:criptocracia_app/services/gift_wrap_service.dart';
import 'package:criptocracia_app/services/nostr_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GiftWrapService', () {
    late NostrService nostrService;
    late GiftWrapService giftWrapService;

    setUp(() {
      nostrService = NostrService();
      giftWrapService = GiftWrapService(nostrService: nostrService);
    });

    tearDown(() {
      giftWrapService.dispose();
      nostrService.dispose();
    });

    test('unwrappedEvents is a broadcast stream', () {
      expect(giftWrapService.unwrappedEvents.isBroadcast, isTrue);
    });

    test('stopListening does not throw when not listening', () {
      expect(() => giftWrapService.stopListening(), returnsNormally);
    });

    test('dispose does not throw', () {
      // Create separate instances to dispose.
      final service = NostrService();
      final gws = GiftWrapService(nostrService: service);
      expect(() => gws.dispose(), returnsNormally);
      service.dispose();
    });

    test('sendGiftWrap requires valid parameters', () async {
      // Without relay connection, this should fail gracefully.
      expect(
        () => giftWrapService.sendGiftWrap(
          recipientPubkey: 'a' * 64,
          content: 'test',
          senderPrivateKey: 'invalid',
        ),
        throwsA(anything),
      );
    });
  });
}
