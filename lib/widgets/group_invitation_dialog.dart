import 'package:flutter/material.dart';

import '../models/group_invitation.dart';

class GroupInvitationDialog extends StatelessWidget {
  const GroupInvitationDialog({
    super.key,
    required this.groupName,
    required this.invitation,
  });

  final String groupName;
  final GroupInvitation invitation;

  @override
  Widget build(BuildContext context) {
    final localExpiry = invitation.expiresAt.toLocal();
    final date = MaterialLocalizations.of(
      context,
    ).formatMediumDate(localExpiry);
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(localExpiry),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );

    return AlertDialog(
      title: const Text('Group invitation'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(groupName, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              const Text(
                'Share this code privately with one person you want '
                'to invite. They can paste it into “Join a group”.',
              ),
              const SizedBox(height: 16),
              const Text('Invitation code'),
              const SizedBox(height: 8),
              SelectableText(
                invitation.code,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
              const SizedBox(height: 16),
              Text('Expires: $date at $time (your local time).'),
              const SizedBox(height: 12),
              const Text(
                'This invitation can admit one new member. '
                'Closing this dialog does not revoke it. '
                'The code is not displayed again by this screen.',
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
