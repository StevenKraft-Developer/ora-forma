import 'package:flutter/material.dart';

class LeaveGroupDialog extends StatelessWidget {
  const LeaveGroupDialog({super.key, required this.groupName});

  final String groupName;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Leave group?'),
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
                'You will lose access to this group. '
                'The group and other memberships will not be deleted.',
              ),
              const SizedBox(height: 12),
              const Text(
                'To join again, you will need an available invitation '
                'from the group owner.',
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Leave group'),
        ),
      ],
    );
  }
}
