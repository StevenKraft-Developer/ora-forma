import 'package:flutter/material.dart';

class JoinGroupDialog extends StatefulWidget {
  const JoinGroupDialog({super.key});

  @override
  State<JoinGroupDialog> createState() => _JoinGroupDialogState();
}

class _JoinGroupDialogState extends State<JoinGroupDialog> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.of(context).pop(_codeController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Join a group'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: TextFormField(
              controller: _codeController,
              autofocus: true,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.none,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Invitation code',
                helperText: 'Paste the full code shared by the group owner.',
                helperMaxLines: 2,
              ),
              validator: (value) {
                final code = (value ?? '').trim();

                if (code.isEmpty) {
                  return 'Enter an invitation code.';
                }

                if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(code)) {
                  return 'Use the full 64-character lowercase invitation code.';
                }

                return null;
              },
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Join group')),
      ],
    );
  }
}
