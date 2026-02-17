/// Simplified Nostr event model for the application layer.
///
/// Wraps the essential fields of a Nostr event in a convenient model
/// that is decoupled from the dart_nostr library internals.
class NostrEventModel {
  /// The event ID (32-byte hex).
  final String id;

  /// The public key of the event author (32-byte hex).
  final String pubkey;

  /// Unix timestamp of event creation.
  final DateTime createdAt;

  /// The event kind number.
  final int kind;

  /// The event content (may be encrypted).
  final String content;

  /// Event tags as a list of string lists.
  final List<List<String>> tags;

  /// The event signature.
  final String sig;

  /// The subscription ID this event was received on (if any).
  final String? subscriptionId;

  const NostrEventModel({
    required this.id,
    required this.pubkey,
    required this.createdAt,
    required this.kind,
    required this.content,
    required this.tags,
    required this.sig,
    this.subscriptionId,
  });

  /// Extracts all values for a given tag name (single-letter tags).
  ///
  /// For example, `getTagValues('p')` returns all pubkeys tagged.
  List<String> getTagValues(String tagName) {
    return tags
        .where((t) => t.isNotEmpty && t[0] == tagName)
        .map((t) => t.length > 1 ? t[1] : '')
        .toList();
  }

  /// Returns the first value for a given tag, or null.
  String? getFirstTagValue(String tagName) {
    final values = getTagValues(tagName);
    return values.isNotEmpty ? values.first : null;
  }

  /// Serializes to a map.
  Map<String, dynamic> toMap() => {
    'id': id,
    'pubkey': pubkey,
    'created_at': createdAt.millisecondsSinceEpoch ~/ 1000,
    'kind': kind,
    'content': content,
    'tags': tags,
    'sig': sig,
  };

  /// Deserializes from a map.
  factory NostrEventModel.fromMap(Map<String, dynamic> map) {
    return NostrEventModel(
      id: map['id'] as String,
      pubkey: map['pubkey'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['created_at'] as int) * 1000,
      ),
      kind: map['kind'] as int,
      content: map['content'] as String,
      tags: (map['tags'] as List)
          .map((t) => (t as List).map((e) => e.toString()).toList())
          .toList(),
      sig: map['sig'] as String? ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NostrEventModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'NostrEventModel(id: ${id.substring(0, 8)}..., kind: $kind, '
      'pubkey: ${pubkey.substring(0, 8)}...)';
}
