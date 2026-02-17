/// A candidate in an election.
class Candidate {
  /// Unique candidate identifier.
  final int id;

  /// Display name of the candidate.
  final String name;

  const Candidate({required this.id, required this.name});

  /// Creates a [Candidate] from a JSON map.
  factory Candidate.fromMap(Map<String, dynamic> map) {
    return Candidate(id: map['id'] as int, name: map['name'] as String);
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
