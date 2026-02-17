import 'dart:async';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter/foundation.dart';
import 'package:nip59/nip59.dart';

import '../models/nostr_event.dart';
import 'nostr_service.dart';

/// Service for sending and receiving NIP-59 Gift Wrap encrypted messages.
///
/// Gift Wrap provides three-layer encryption (Rumor → Seal → Wrap)
/// to protect both content and metadata of messages.
class GiftWrapService extends ChangeNotifier {
  /// Reference to the NostrService for relay communication.
  final NostrService _nostrService;

  /// Stream controller for unwrapped incoming events.
  final StreamController<NostrEventModel> _unwrappedEventController =
      StreamController<NostrEventModel>.broadcast();

  /// Subscription ID for gift wrap events.
  static const String _giftWrapSubscriptionName = 'gift_wrap_inbox';

  /// NIP-59 wrap event kind.
  static const int _wrapKind = 1059;

  /// Creates a [GiftWrapService] bound to a [NostrService].
  GiftWrapService({required NostrService nostrService})
    : _nostrService = nostrService;

  /// Stream of unwrapped (decrypted) incoming events.
  Stream<NostrEventModel> get unwrappedEvents =>
      _unwrappedEventController.stream;

  /// Starts listening for incoming gift-wrapped messages addressed to [myPubkey].
  ///
  /// The [myPrivateKey] is used to decrypt incoming messages.
  /// Call this after the user has authenticated and keys are available.
  void startListening({
    required String myPubkey,
    required String myPrivateKey,
  }) {
    _nostrService.subscriptionManager.subscribe(
      name: _giftWrapSubscriptionName,
      filters: [
        NostrFilter(kinds: const [_wrapKind], p: [myPubkey]),
      ],
      onEvent: (event) => _handleIncomingWrap(event, myPrivateKey),
    );

    debugPrint('GiftWrapService: Listening for gift wraps to $myPubkey');
  }

  /// Stops listening for incoming gift-wrapped messages.
  void stopListening() {
    _nostrService.subscriptionManager.close(_giftWrapSubscriptionName);
  }

  /// Sends a gift-wrapped message to a recipient.
  ///
  /// Parameters:
  /// - [recipientPubkey]: The recipient's public key (hex).
  /// - [content]: The message content to encrypt.
  /// - [senderPrivateKey]: The sender's private key (hex).
  /// - [kind]: The inner event kind (defaults to 1 for text note).
  ///
  /// Returns the wrapped [NostrEvent] that was published.
  Future<NostrEvent> sendGiftWrap({
    required String recipientPubkey,
    required String content,
    required String senderPrivateKey,
    int kind = 1,
  }) async {
    final nostr = _nostrService.nostr;

    final wrapEvent = await Nip59.createNIP59Event(
      content,
      recipientPubkey,
      senderPrivateKey,
      generateKeyPairFromPrivateKey:
          nostr.services.keys.generateKeyPairFromExistingPrivateKey,
      generateKeyPair: nostr.services.keys.generateKeyPair,
      isValidPrivateKey: nostr.services.keys.isValidPrivateKey,
    );

    await _nostrService.sendEvent(wrapEvent);

    debugPrint(
      'GiftWrapService: Sent gift wrap to ${recipientPubkey.substring(0, 8)}...',
    );

    return wrapEvent;
  }

  /// Handles an incoming gift-wrapped event by decrypting it.
  Future<void> _handleIncomingWrap(
    NostrEventModel wrappedEvent,
    String privateKey,
  ) async {
    try {
      // Reconstruct the NostrEvent from our model for the nip59 library.
      final nostrEvent = NostrEvent(
        id: wrappedEvent.id,
        kind: wrappedEvent.kind,
        content: wrappedEvent.content,
        sig: wrappedEvent.sig,
        pubkey: wrappedEvent.pubkey,
        createdAt: wrappedEvent.createdAt,
        tags: wrappedEvent.tags,
        subscriptionId: wrappedEvent.subscriptionId ?? '',
      );

      final nostr = _nostrService.nostr;

      final decrypted = await Nip59.decryptNIP59Event(
        nostrEvent,
        privateKey,
        isValidPrivateKey: nostr.services.keys.isValidPrivateKey,
      );

      final model = NostrService.toEventModel(decrypted);

      if (!_unwrappedEventController.isClosed) {
        _unwrappedEventController.add(model);
      }
      notifyListeners();

      debugPrint(
        'GiftWrapService: Unwrapped event from '
        '${model.pubkey.substring(0, 8)}...',
      );
    } catch (e) {
      debugPrint('GiftWrapService: Failed to unwrap event: $e');
    }
  }

  /// Decrypts a single gift-wrapped event manually.
  ///
  /// Useful for decrypting cached events from local storage.
  Future<NostrEventModel?> decryptEvent({
    required NostrEventModel wrappedEvent,
    required String privateKey,
  }) async {
    try {
      final nostrEvent = NostrEvent(
        id: wrappedEvent.id,
        kind: wrappedEvent.kind,
        content: wrappedEvent.content,
        sig: wrappedEvent.sig,
        pubkey: wrappedEvent.pubkey,
        createdAt: wrappedEvent.createdAt,
        tags: wrappedEvent.tags,
        subscriptionId: wrappedEvent.subscriptionId ?? '',
      );

      final nostr = _nostrService.nostr;

      final decrypted = await Nip59.decryptNIP59Event(
        nostrEvent,
        privateKey,
        isValidPrivateKey: nostr.services.keys.isValidPrivateKey,
      );

      return NostrService.toEventModel(decrypted);
    } catch (e) {
      debugPrint('GiftWrapService: Failed to decrypt event: $e');
      return null;
    }
  }

  @override
  void dispose() {
    stopListening();
    _unwrappedEventController.close();
    super.dispose();
  }
}
