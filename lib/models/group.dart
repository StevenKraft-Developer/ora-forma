enum GroupRole { owner, member }

class Group {
  const Group({
    required this.id,
    required this.name,
    required this.description,
    required this.ownerUid,
    required this.role,
    this.createdAt,
    this.joinedAt,
  });

  final String id;
  final String name;
  final String description;
  final String ownerUid;

  /// The signed-in user's authoritative membership role.
  final GroupRole role;

  final DateTime? createdAt;
  final DateTime? joinedAt;

  bool get isOwner => role == GroupRole.owner;
}
