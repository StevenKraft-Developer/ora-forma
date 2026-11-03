import '../models/group.dart';
import '../models/group_invitation.dart';

enum JoinGroupStatus { joined, alreadyMember }

class JoinGroupResult {
  const JoinGroupResult({required this.groupId, required this.status});

  final String groupId;
  final JoinGroupStatus status;
}

enum LeaveGroupStatus { left, alreadyLeft }

class LeaveGroupResult {
  const LeaveGroupResult({required this.groupId, required this.status});

  final String groupId;
  final LeaveGroupStatus status;
}

abstract interface class GroupService {
  Future<List<Group>> loadGroups(String uid);

  Future<String> createGroup({required String name, String? description});

  Future<GroupInvitation> createGroupInvite({required String groupId});

  Future<JoinGroupResult> joinGroup({required String inviteCode});

  Future<LeaveGroupResult> leaveGroup({required String groupId});
}
