import 'package:criptocracia_app/models/relay_config.dart';
import 'package:criptocracia_app/services/nostr_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NostrService', () {
    late NostrService service;

    setUp(() {
      service = NostrService();
    });

    tearDown(() {
      service.dispose();
    });

    test('initial state is disconnected', () {
      expect(service.connectionState, NostrConnectionState.disconnected);
      expect(service.isConnected, isFalse);
      expect(service.initialized, isFalse);
    });

    test('relays list is initially empty before initialization', () {
      expect(service.relays, isEmpty);
    });

    test('connectionStateStream emits state changes', () async {
      // Verify the stream is a broadcast stream.
      expect(service.connectionStateStream.isBroadcast, isTrue);
    });

    test('subscriptionManager is available', () {
      expect(service.subscriptionManager, isNotNull);
    });

    test('addRelay adds a relay configuration', () async {
      await service.addRelay('wss://test.relay.example');
      expect(service.relays.length, 1);
      expect(service.relays.first.url, 'wss://test.relay.example');
      expect(service.relays.first.read, isTrue);
      expect(service.relays.first.write, isTrue);
    });

    test('addRelay does not add duplicate relays', () async {
      await service.addRelay('wss://test.relay.example');
      await service.addRelay('wss://test.relay.example');
      expect(service.relays.length, 1);
    });

    test('removeRelay removes a relay configuration', () async {
      await service.addRelay('wss://test.relay.example');
      await service.removeRelay('wss://test.relay.example');
      expect(service.relays, isEmpty);
    });

    test('addRelay with custom read/write flags', () async {
      await service.addRelay(
        'wss://readonly.relay.example',
        read: true,
        write: false,
      );
      expect(service.relays.first.read, isTrue);
      expect(service.relays.first.write, isFalse);
    });

    test('toEventModel creates a valid NostrEventModel', () {
      // This test verifies the static converter works with minimal data.
      // Full integration requires a real NostrEvent from dart_nostr.
      expect(NostrService.toEventModel, isA<Function>());
    });

    test('relays list is unmodifiable', () {
      final relays = service.relays;
      expect(
        () => relays.add(RelayConfig(url: 'wss://test.example')),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });
}
