import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/group.dart';
import '../models/group_invitation.dart';
import 'group_service.dart';

class FirestoreGroupService implements GroupService {
  FirestoreGroupService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions = functions ?? FirebaseFunctions.instance,
       _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;

  static const _serverOnly = GetOptions(source: Source.server);

  void _requireAccount(String uid) {
    if (_auth.currentUser?.uid != uid) {
      throw StateError('The signed-in account changed. Please try again.');
    }
  }

  String _requireSignedInUid() {
    final uid = _auth.currentUser?.uid;

    if (uid == null) {
      throw StateError('Sign in before managing groups.');
    }

    return uid;
  }

  @override
  Future<List<Group>> loadGroups(String uid) async {
    _requireAccount(uid);

    final index = await _firestore
        .collection('users')
        .doc(uid)
        .collection('groupMemberships')
        .get(_serverOnly);

    _requireAccount(uid);

    final groups = <Group>[];

    for (final entry in index.docs) {
      _requireAccount(uid);

      final groupRef = _firestore.collection('groups').doc(entry.id);

      final membership = await groupRef
          .collection('members')
          .doc(uid)
          .get(_serverOnly);

      _requireAccount(uid);

      // Discovery indexes are not proof of membership.
      if (!membership.exists) continue;

      final membershipData = membership.data()!;
      final role = switch (membershipData['role']) {
        'owner' => GroupRole.owner,
        'member' => GroupRole.member,
        _ => throw const FormatException('Invalid group membership role.'),
      };

      final snapshot = await groupRef.get(_serverOnly);

      _requireAccount(uid);

      // Ignore an orphaned membership whose group document is missing.
      if (!snapshot.exists) continue;

      final data = snapshot.data()!;

      groups.add(
        Group(
          id: snapshot.id,
          name: _requiredString(data, 'name'),
          description: _requiredString(data, 'description', allowEmpty: true),
          ownerUid: _requiredString(data, 'ownerUid'),
          role: role,
          createdAt: _optionalDate(data['createdAt']),
          joinedAt: _optionalDate(membershipData['joinedAt']),
        ),
      );
    }

    groups.sort((a, b) {
      final nameComparison = a.name.toLowerCase().compareTo(
        b.name.toLowerCase(),
      );

      return nameComparison != 0 ? nameComparison : a.id.compareTo(b.id);
    });

    _requireAccount(uid);

    return List.unmodifiable(groups);
  }

  @override
  Future<String> createGroup({
    required String name,
    String? description,
  }) async {
    final data = await _call('createGroup', {
      'name': name.trim(),
      if (description != null) 'description': description.trim(),
    });

    return _requiredString(data, 'groupId');
  }

  @override
  Future<GroupInvitation> createGroupInvite({required String groupId}) async {
    final data = await _call('createGroupInvite', {'groupId': groupId});

    final code = _requiredString(data, 'inviteCode');
    final expiresAt = DateTime.tryParse(_requiredString(data, 'expiresAt'));

    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(code) || expiresAt == null) {
      throw const FormatException('Invalid invitation response.');
    }

    return GroupInvitation(code: code, expiresAt: expiresAt.toUtc());
  }

  @override
  Future<JoinGroupResult> joinGroup({required String inviteCode}) async {
    final data = await _call('joinGroup', {'inviteCode': inviteCode.trim()});

    final status = switch (data['status']) {
      'joined' => JoinGroupStatus.joined,
      'already-member' => JoinGroupStatus.alreadyMember,
      _ => throw const FormatException('Invalid join response.'),
    };

    return JoinGroupResult(
      groupId: _requiredString(data, 'groupId'),
      status: status,
    );
  }

  @override
  Future<LeaveGroupResult> leaveGroup({required String groupId}) async {
    final data = await _call('leaveGroup', {'groupId': groupId});

    final status = switch (data['status']) {
      'left' => LeaveGroupStatus.left,
      'already-left' => LeaveGroupStatus.alreadyLeft,
      _ => throw const FormatException('Invalid leave response.'),
    };

    return LeaveGroupResult(
      groupId: _requiredString(data, 'groupId'),
      status: status,
    );
  }

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> arguments,
  ) async {
    final uid = _requireSignedInUid();

    final result = await _functions
        .httpsCallable(name)
        .call<dynamic>(arguments);

    _requireAccount(uid);

    final data = result.data;

    if (data is! Map) {
      throw const FormatException('Invalid group operation response.');
    }

    return Map<String, dynamic>.from(data);
  }

  static String _requiredString(
    Map<String, dynamic> data,
    String field, {
    bool allowEmpty = false,
  }) {
    final value = data[field];

    if (value is! String || (!allowEmpty && value.trim().isEmpty)) {
      throw FormatException('Invalid or missing $field.');
    }

    return value;
  }

  static DateTime? _optionalDate(Object? value) {
    return value is Timestamp ? value.toDate() : null;
  }
}
