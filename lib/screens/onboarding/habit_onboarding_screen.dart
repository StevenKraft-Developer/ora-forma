import 'package:flutter/material.dart';

import '../../colors.dart';
import '../../models/habit.dart';

class HabitOnboardingScreen extends StatefulWidget {
  const HabitOnboardingScreen({
    super.key,
    required this.initialHabits,
    required this.onSave,
    required this.onCompleted,
  });

  final List<Habit> initialHabits;
  final Future<bool> Function(List<Habit> habits) onSave;
  final VoidCallback onCompleted;

  @override
  State<HabitOnboardingScreen> createState() => _HabitOnboardingScreenState();
}

class _HabitOnboardingScreenState extends State<HabitOnboardingScreen> {
  final _pageController = PageController();

  late final List<Habit> _catalog;
  late final Set<String> _selectedIds;

  int _page = 0;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    // An empty account may explicitly choose a new starting routine.
    _catalog = List<Habit>.from(
      widget.initialHabits.isEmpty
          ? kDefaultCatholicHabitSet
          : widget.initialHabits,
    );

    _selectedIds = _catalog
        .where((habit) => !habit.isArchived)
        .map((habit) => habit.id)
        .toSet();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    if (_isSaving) return;

    setState(() => _error = null);

    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  void _next() {
    if (_page == 1 && _selectedIds.isEmpty) {
      setState(() {
        _error = 'Choose at least one habit to continue.';
      });
      return;
    }

    _goToPage(_page + 1);
  }

  List<Habit> _buildCatalog() {
    var activeOrder = 0;

    return [
      for (final habit in _catalog)
        if (_selectedIds.contains(habit.id))
          habit.copyWith(isArchived: false, sortOrder: activeOrder++)
        else
          habit.copyWith(isArchived: true),
    ];
  }

  Future<void> _complete() async {
    if (_isSaving) return;

    if (_selectedIds.isEmpty) {
      setState(() {
        _error = 'Choose at least one habit to continue.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final saved = await widget.onSave(_buildCatalog());

      if (!mounted) return;

      if (!saved) {
        setState(() {
          _error =
              'Your routine could not be saved for this session. '
              'Please try again.';
        });
        return;
      }

      widget.onCompleted();
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'Your routine could not be saved. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _purposePage(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Icon(
          Icons.auto_awesome_rounded,
          size: 56,
          color: OraColors.primary,
        ),
        const SizedBox(height: 24),
        Text(
          'Begin your rule of life',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 16),
        const Text(
          'Build a faithful daily routine through prayer, '
          'discipline, and small consistent actions.',
        ),
        const SizedBox(height: 16),
        const Text(
          'Review your habits, choose what you want to practice, '
          'and begin tracking your daily progress.',
        ),
      ],
    );
  }

  Widget _selectionPage(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Choose your habits',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 12),
        const Text(
          'Choose at least one habit. Unselected habits will be archived; '
          'their existing progress history will not be deleted.',
        ),
        const SizedBox(height: 16),
        for (final habit in _catalog)
          CheckboxListTile(
            key: ValueKey('onboarding-habit-${habit.id}'),
            contentPadding: EdgeInsets.zero,
            title: Text(habit.title),
            subtitle: habit.isArchived
                ? const Text('Archived — select to restore')
                : null,
            value: _selectedIds.contains(habit.id),
            onChanged: _isSaving
                ? null
                : (selected) {
                    setState(() {
                      if (selected == true) {
                        _selectedIds.add(habit.id);
                      } else {
                        _selectedIds.remove(habit.id);
                      }
                      _error = null;
                    });
                  },
          ),
      ],
    );
  }

  Widget _confirmationPage(BuildContext context) {
    final selected = _catalog
        .where((habit) => _selectedIds.contains(habit.id))
        .toList();

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Your daily rule',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 12),
        const Text(
          'Start with consistency, not perfection. '
          'These are the habits you will see on Home.',
        ),
        const SizedBox(height: 16),
        for (final habit in selected)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              Icons.check_circle_outline,
              color: OraColors.primary,
            ),
            title: Text(habit.title),
          ),
        const SizedBox(height: 12),
        const Text('Nothing is saved until you start your daily rule.'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OraColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) {
                  setState(() => _page = page);
                },
                children: [
                  _purposePage(context),
                  _selectionPage(context),
                  _confirmationPage(context),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Step ${_page + 1} of 3'),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (_page > 0) ...[
                        TextButton(
                          onPressed: _isSaving
                              ? null
                              : () => _goToPage(_page - 1),
                          child: const Text('Back'),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: FilledButton(
                          onPressed: _isSaving
                              ? null
                              : _page == 2
                              ? _complete
                              : _next,
                          child: Text(
                            _isSaving
                                ? 'Saving...'
                                : _page == 2
                                ? 'Start my daily rule'
                                : 'Next',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
