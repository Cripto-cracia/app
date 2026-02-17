/// A candidate in an election.
class Candidate {
  /// Unique candidate identifier.
  final int id;

  /// Display name of the candidate.
  final String name;

  const Candidate({required this.id, required this.name});

  /// Creates a [Candidate] from a JSON map.
  ///
  /// Handles both integer and string ID values from external EC servers.
  factory Candidate.fromMap(Map<String, dynamic> map) {
    final rawId = map['id'];
    final int id;
    if (rawId is int) {
      id = rawId;
    } else if (rawId is String) {
      id = int.parse(rawId);
    } else {
      throw FormatException('Candidate id is missing or invalid: $rawId');
    }
    final name = map['name'] as String? ?? '';
    return Candidate(id: id, name: name);
  }

  /// Serializes to a JSON map.
  Map<String, dynamic> toMap() => {'id': id, 'name': name};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Candidate && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Candidate(id: $id, name: $name)';
}
