import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'widgets/create_group_dialog.dart';
import 'colors.dart';
import 'models/group.dart';
import 'providers/group_provider.dart';
import 'widgets/join_group_dialog.dart';
import 'widgets/group_invitation_dialog.dart';
import 'widgets/leave_group_dialog.dart';

class GroupScreen extends StatelessWidget {
  const GroupScreen({super.key});

  static const _useFirebaseEmulators = bool.fromEnvironment(
    'USE_FIREBASE_EMULATORS',
    defaultValue: false,
  );

  Future<void> _createGroup(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final provider = context.read<GroupProvider>();
    final uid = auth.user?.uid;
    final sessionVersion = auth.sessionVersion;

    if (uid == null || provider.isLoading || provider.isSubmitting) {
      return;
    }

    final input = await showDialog<CreateGroupInput>(
      context: context,
      builder: (_) => const CreateGroupDialog(),
    );

    if (!context.mounted || input == null) return;

    // Do not submit a form opened under another signed-in account.
    if (auth.user?.uid != uid || auth.sessionVersion != sessionVersion) {
      return;
    }

    await provider.createGroup(
      name: input.name,
      description: input.description,
    );
  }

  Future<void> _joinGroup(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final provider = context.read<GroupProvider>();
    final uid = auth.user?.uid;
    final sessionVersion = auth.sessionVersion;

    if (uid == null || provider.isLoading || provider.isSubmitting) {
      return;
    }

    final inviteCode = await showDialog<String>(
      context: context,
      builder: (_) => const JoinGroupDialog(),
    );

    if (!context.mounted || inviteCode == null) return;

    // Do not submit a form opened under another signed-in account.
    if (auth.user?.uid != uid || auth.sessionVersion != sessionVersion) {
      return;
    }

    await provider.joinGroup(inviteCode: inviteCode);
  }

  Future<void> _createInvitation(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final provider = context.read<GroupProvider>();
    final uid = auth.user?.uid;
    final sessionVersion = auth.sessionVersion;
    final group = provider.selectedGroup;

    if (uid == null ||
        group == null ||
        !group.isOwner ||
        provider.isLoading ||
        provider.isSubmitting) {
      return;
    }

    final invitation = await provider.createGroupInvite(groupId: group.id);

    if (!context.mounted || invitation == null) return;
    if (auth.user?.uid != uid || auth.sessionVersion != sessionVersion) {
      return;
    }

    final currentGroup = provider.selectedGroup;

    if (currentGroup?.id != group.id || !currentGroup!.isOwner) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final currentAuth = dialogContext.watch<AuthProvider>();
        final currentUid = currentAuth.user?.uid;
        final selected = dialogContext.watch<GroupProvider>().selectedGroup;

        final canDisplay =
            currentUid == uid &&
            currentAuth.sessionVersion == sessionVersion &&
            selected?.id == group.id &&
            selected?.isOwner == true;

        if (!canDisplay) {
          return AlertDialog(
            title: const Text('Invitation hidden'),
            content: const Text(
              'The signed-in account or selected group changed. '
              'This invitation is no longer displayed.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        }

        return GroupInvitationDialog(
          groupName: group.name,
          invitation: invitation,
        );
      },
    );
  }

  Future<void> _leaveGroup(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final provider = context.read<GroupProvider>();
    final uid = auth.user?.uid;
    final sessionVersion = auth.sessionVersion;
    final group = provider.selectedGroup;

    if (uid == null ||
        group == null ||
        group.isOwner ||
        provider.isLoading ||
        provider.isSubmitting) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => LeaveGroupDialog(groupName: group.name),
    );

    if (!context.mounted || confirmed != true) return;
    if (auth.user?.uid != uid || auth.sessionVersion != sessionVersion) {
      return;
    }

    final currentGroup = provider.selectedGroup;

    if (currentGroup == null ||
        currentGroup.id != group.id ||
        currentGroup.isOwner ||
        provider.isLoading ||
        provider.isSubmitting) {
      return;
    }

    await provider.leaveGroup(groupId: group.id);
  }

  @override
  Widget build(BuildContext context) {
    if (!_useFirebaseEmulators) {
      return const Scaffold(
        backgroundColor: OraColors.background,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Groups are not available in this build yet.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }

    final provider = context.watch<GroupProvider>();
    final textTheme = Theme.of(context).textTheme;
    final selectedGroup = provider.selectedGroup;
    final busy = provider.isLoading || provider.isSubmitting;

    return Scaffold(
      backgroundColor: OraColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Your Groups',
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: OraColors.text,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh groups',
                  onPressed: busy
                      ? null
                      : () async {
                          await context.read<GroupProvider>().refresh();
                        },
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'View your memberships and choose a group.',
              style: textTheme.bodyMedium?.copyWith(
                color: OraColors.muted,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: busy
                      ? null
                      : () async {
                          await _createGroup(context);
                        },
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Create a group'),
                ),
                OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () async {
                          await _joinGroup(context);
                        },
                  icon: const Icon(Icons.group_add_outlined),
                  label: const Text('Join a group'),
                ),
              ],
            ),
            if (provider.isSubmitting) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              const Text('Updating your groups…'),
            ],
            const SizedBox(height: 20),
            if (provider.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading your groups…'),
                  ],
                ),
              )
            else if (provider.errorMessage != null)
              _GroupMessageCard(
                icon: Icons.error_outline_rounded,
                title: 'Group request could not be completed',
                message: provider.errorMessage!,
                action: FilledButton.icon(
                  onPressed: busy
                      ? null
                      : () async {
                          await context.read<GroupProvider>().refresh();
                        },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try again'),
                ),
              )
            else if (!provider.isLoaded)
              const _GroupMessageCard(
                icon: Icons.hourglass_empty_rounded,
                title: 'Getting your groups ready',
                message: 'Your membership list has not loaded yet.',
              )
            else if (!provider.hasGroups)
              const _GroupMessageCard(
                icon: Icons.groups_outlined,
                title: 'No groups yet',
                message:
                    'You do not belong to any groups yet. '
                    'Create a group or join using an invitation from its owner.',
              )
            else ...[
              for (final group in provider.groups) ...[
                Card(
                  color: OraColors.surface,
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    selected: group.id == provider.selectedGroupId,
                    selectedTileColor: OraColors.primary.withValues(
                      alpha: 0.08,
                    ),
                    leading: const Icon(
                      Icons.groups_outlined,
                      color: OraColors.primary,
                    ),
                    title: Text(
                      group.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(group.isOwner ? 'Owner' : 'Member'),
                    trailing: group.id == provider.selectedGroupId
                        ? const Icon(
                            Icons.check_circle_rounded,
                            color: OraColors.primary,
                          )
                        : null,
                    onTap: busy
                        ? null
                        : () {
                            context.read<GroupProvider>().selectGroup(group.id);
                          },
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (selectedGroup != null) ...[
                const SizedBox(height: 16),
                _GroupDetailsCard(group: selectedGroup),
                if (selectedGroup.isOwner) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: busy
                          ? null
                          : () async {
                              await _createInvitation(context);
                            },
                      icon: const Icon(Icons.person_add_alt_1_outlined),
                      label: const Text('Create invitation'),
                    ),
                  ),
                ],
                if (!selectedGroup.isOwner) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: busy
                          ? null
                          : () async {
                              await _leaveGroup(context);
                            },
                      icon: const Icon(Icons.exit_to_app_rounded),
                      label: const Text('Leave group'),
                    ),
                  ),
                ],
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _GroupDetailsCard extends StatelessWidget {
  const _GroupDetailsCard({required this.group});

  final Group group;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      color: OraColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selected group',
              style: textTheme.labelLarge?.copyWith(color: OraColors.muted),
            ),
            const SizedBox(height: 8),
            Text(
              group.name,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: OraColors.text,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              group.description.trim().isEmpty
                  ? 'No description provided.'
                  : group.description,
              style: textTheme.bodyMedium?.copyWith(
                color: OraColors.muted,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              group.isOwner ? 'Your role: Owner' : 'Your role: Member',
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: OraColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupMessageCard extends StatelessWidget {
  const _GroupMessageCard({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      color: OraColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: OraColors.primary, size: 32),
            const SizedBox(height: 16),
            Text(
              title,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: OraColors.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: textTheme.bodyMedium?.copyWith(
                color: OraColors.muted,
                height: 1.45,
              ),
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
