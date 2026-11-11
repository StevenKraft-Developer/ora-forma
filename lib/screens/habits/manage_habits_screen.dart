import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/habit.dart';
import '../../providers/auth_provider.dart';
import '../../providers/habit_provider.dart';

class ManageHabitsScreen extends StatefulWidget {
  const ManageHabitsScreen({
    super.key,
    required this.uid,
    required this.sessionVersion,
  });

  final String uid;
  final int sessionVersion;

  @override
  State<ManageHabitsScreen> createState() => _ManageHabitsScreenState();
}

class _ManageHabitsScreenState extends State<ManageHabitsScreen> {
  bool _matchesSession(AuthProvider auth) {
    return auth.user?.uid == widget.uid &&
        auth.sessionVersion == widget.sessionVersion;
  }

  bool get _isCurrentSession {
    return mounted && _matchesSession(context.read<AuthProvider>());
  }

  Future<void> _openForm([Habit? habit]) async {
    if (!_isCurrentSession) return;

    final provider = context.read<HabitProvider>();
    if (!provider.isLoaded || provider.isSaving) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _HabitFormSheet(
        uid: widget.uid,
        sessionVersion: widget.sessionVersion,
        habit: habit,
        onSave: (title, description) {
          if (!_isCurrentSession) return Future.value(false);

          if (habit == null) {
            return provider.addHabit(
              uid: widget.uid,
              title: title,
              description: description,
            );
          }

          return provider.updateHabit(
            uid: widget.uid,
            habitId: habit.id,
            title: title,
            description: description,
          );
        },
      ),
    );
  }

  Future<void> _setArchived(Habit habit) async {
    if (!_isCurrentSession) return;

    final provider = context.read<HabitProvider>();
    if (!provider.isLoaded || provider.isSaving) return;

    try {
      final saved = habit.isArchived
          ? await provider.unarchiveHabit(habit.id, uid: widget.uid)
          : await provider.archiveHabit(habit.id, uid: widget.uid);

      if (!mounted) return;
      if (!_isCurrentSession) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saved
                ? habit.isArchived
                      ? 'Habit restored.'
                      : 'Habit archived. Progress history was preserved.'
                : 'The habit could not be changed. Please try again.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      if (!_isCurrentSession) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The habit could not be saved. Please try again.'),
        ),
      );
    }
  }

  Widget _habitTile(Habit habit, bool busy) {
    return ListTile(
      key: ValueKey('manage-habit-${habit.id}'),
      title: Text(habit.title),
      subtitle: habit.description == null ? null : Text(habit.description!),
      trailing: PopupMenuButton<String>(
        tooltip: 'Actions for ${habit.title}',
        enabled: !busy,
        onSelected: (action) {
          if (action == 'edit') {
            _openForm(habit);
          } else {
            _setArchived(habit);
          }
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'edit', child: Text('Edit')),
          PopupMenuItem(
            value: 'archive',
            child: Text(habit.isArchived ? 'Restore' : 'Archive'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!_matchesSession(auth)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Manage Habits')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Your account session changed. '
              'Close this screen and reopen Manage Habits.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final provider = context.watch<HabitProvider>();
    final ready = provider.isLoaded && !provider.isLoading;
    final busy = provider.isSaving;
    final active = provider.activeHabits;
    final archived = provider.archivedHabits;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Habits'),
        actions: [
          IconButton(
            key: const ValueKey('add-habit'),
            tooltip: 'Add habit',
            onPressed: ready && !busy ? () => _openForm() : null,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: !ready
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                if (busy) const LinearProgressIndicator(),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Active',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ),
                if (active.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'No active habits. Add a habit or restore one below.',
                    ),
                  )
                else
                  for (final habit in active) _habitTile(habit, busy),
                if (archived.isNotEmpty) ...[
                  const Divider(height: 32),
                  const Text(
                    'Archived',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Archived habits stay out of your daily routine. '
                    'Their progress history is preserved.',
                  ),
                  const SizedBox(height: 8),
                  for (final habit in archived) _habitTile(habit, busy),
                ],
              ],
            ),
    );
  }
}

class _HabitFormSheet extends StatefulWidget {
  const _HabitFormSheet({
    required this.uid,
    required this.sessionVersion,
    required this.habit,
    required this.onSave,
  });

  final String uid;
  final int sessionVersion;
  final Habit? habit;
  final Future<bool> Function(String title, String? description) onSave;

  @override
  State<_HabitFormSheet> createState() => _HabitFormSheetState();
}

class _HabitFormSheetState extends State<_HabitFormSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _title;
  late final TextEditingController _description;

  bool _saving = false;
  String? _error;

  bool _matchesSession(AuthProvider auth) {
    return auth.user?.uid == widget.uid &&
        auth.sessionVersion == widget.sessionVersion;
  }

  bool get _isCurrentSession {
    return mounted && _matchesSession(context.read<AuthProvider>());
  }

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.habit?.title ?? '');
    _description = TextEditingController(text: widget.habit?.description ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving || !_isCurrentSession) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final description = _description.text.trim();

      final saved = await widget.onSave(
        _title.text.trim(),
        description.isEmpty ? null : description,
      );

      if (!mounted) return;
      if (!_isCurrentSession) return;

      if (saved) {
        Navigator.of(context).pop();
      } else {
        setState(() {
          _error = 'The habit could not be saved. Please try again.';
        });
      }
    } catch (_) {
      if (!_isCurrentSession) return;

      setState(() {
        _error = 'The habit could not be saved. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!_matchesSession(auth)) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Your account session changed. Close this form and try again.',
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        8,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.habit == null ? 'Add habit' : 'Edit habit',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const ValueKey('habit-title'),
              controller: _title,
              enabled: !_saving,
              maxLength: 100,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (value) {
                final title = value?.trim() ?? '';

                if (title.isEmpty) return 'Enter a habit title.';
                if (title.length > 100) {
                  return 'Use no more than 100 characters.';
                }

                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('habit-description'),
              controller: _description,
              enabled: !_saving,
              maxLength: 300,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
              ),
              validator: (value) {
                if ((value?.trim().length ?? 0) > 300) {
                  return 'Use no more than 300 characters.';
                }

                return null;
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              key: const ValueKey('save-habit'),
              onPressed: _saving ? null : _submit,
              child: Text(_saving ? 'Saving...' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}
