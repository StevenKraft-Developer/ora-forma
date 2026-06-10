import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'colors.dart';
import 'providers/progress_provider.dart';

class GroupScreen extends StatefulWidget {
  const GroupScreen({super.key});

  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> {
  final List<_GroupInfo> _groups = const [
    _GroupInfo(
      id: 'fraternity',
      name: 'Friday Fraternity',
      subtitle: 'Weekly brotherhood and accountability',
      icon: Icons.groups_2_outlined,
      accentColor: OraColors.primary,
      meetingText: 'Friday at 7:00 PM',
      discussionPrompt: 'Share one grace from this week.',
      prayerPrompt: 'Pray for perseverance in daily discipline.',
    ),
    _GroupInfo(
      id: 'early_risers',
      name: 'Early Risers',
      subtitle: 'Men building a faithful morning routine',
      icon: Icons.wb_sunny_outlined,
      accentColor: OraColors.gold,
      meetingText: 'Wednesday at 6:30 AM',
      discussionPrompt: 'What helped you start the day well today?',
      prayerPrompt: 'Offer your morning prayer for another brother.',
    ),
    _GroupInfo(
      id: 'scripture_circle',
      name: 'Scripture Circle',
      subtitle: 'Daily Scripture and reflection together',
      icon: Icons.menu_book_outlined,
      accentColor: OraColors.primaryDeep,
      meetingText: 'Sunday at 8:00 PM',
      discussionPrompt: 'Share a passage that stayed with you this week.',
      prayerPrompt: 'Pray for deeper attentiveness to the Word.',
    ),
  ];

  int _selectedGroupIndex = 0;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final selectedGroup = _groups[_selectedGroupIndex];

    final completedToday = context.select<ProgressProvider, int>(
      (provider) => provider.completedCount,
    );
    final totalHabits = context.select<ProgressProvider, int>(
      (provider) => provider.totalCount,
    );
    final currentStreak = context.select<ProgressProvider, int>(
      (provider) => provider.currentStreak,
    );
    final weeklyPercent = context.select<ProgressProvider, double>(
      (provider) => provider.weeklyCompletionPercent,
    );

    final weeklyPercentLabel = '${(weeklyPercent * 100).round()}%';

    return Scaffold(
      backgroundColor: OraColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          children: [
            Text(
              'Your Groups',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: OraColors.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose a group to view its brotherhood, challenges, and community details.',
              style: textTheme.bodyMedium?.copyWith(
                color: OraColors.muted,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 118,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _groups.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final group = _groups[index];
                  final isSelected = index == _selectedGroupIndex;

                  return _GroupSelectorCard(
                    group: group,
                    isSelected: isSelected,
                    onTap: () {
                      setState(() {
                        _selectedGroupIndex = index;
                      });
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            _GroupHeroCard(
              group: selectedGroup,
              completedToday: completedToday,
              totalHabits: totalHabits,
              currentStreak: currentStreak,
            ),
            const SizedBox(height: 20),
            Text(
              'Group Preview',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: OraColors.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This space shows how accountability, discussion, and shared prayer could work inside ${selectedGroup.name}.',
              style: textTheme.bodyMedium?.copyWith(
                color: OraColors.muted,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              child: Column(
                children: [
                  _GroupMemberTile(
                    icon: Icons.person_outline_rounded,
                    iconColor: selectedGroup.accentColor,
                    name: 'You',
                    status:
                        'Completed $completedToday of $totalHabits habits today',
                    trailingText: currentStreak > 0
                        ? '$currentStreak day streak'
                        : 'Starting fresh',
                  ),
                  const Divider(height: 1),
                  _GroupMemberTile(
                    icon: Icons.groups_outlined,
                    iconColor: selectedGroup.accentColor,
                    name: 'Shared Accountability',
                    status:
                        'Encourage one another, notice consistency, and stay committed together.',
                    trailingText: 'Preview',
                  ),
                  const Divider(height: 1),
                  _GroupMemberTile(
                    icon: Icons.forum_outlined,
                    iconColor: OraColors.primary,
                    name: 'Discussion Space',
                    status:
                        'A place for reflections, check-ins, and weekly conversation.',
                    trailingText: 'Preview',
                  ),
                  const Divider(height: 1),
                  _GroupMemberTile(
                    icon: Icons.favorite_outline_rounded,
                    iconColor: OraColors.gold,
                    name: 'Prayer Support',
                    status:
                        'Members can share intentions and pray for one another here.',
                    trailingText: 'Preview',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Challenges',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: OraColors.text,
              ),
            ),
            const SizedBox(height: 12),
            _ChallengeCard(
              title: '${selectedGroup.name} Weekly Goal',
              subtitle:
                  'You are at $weeklyPercentLabel of your weekly habit goal within this season of formation.',
              icon: Icons.calendar_today_outlined,
              accentColor: selectedGroup.accentColor,
            ),
            const SizedBox(height: 12),
            _ChallengeCard(
              title: completedToday == totalHabits
                  ? 'Daily Rule Complete'
                  : 'Finish Today Strong',
              subtitle: completedToday == totalHabits
                  ? 'You completed all your habits today. Bring that consistency into ${selectedGroup.name}.'
                  : 'You have completed $completedToday of $totalHabits habits today. Stay steady and finish well.',
              icon: completedToday == totalHabits
                  ? Icons.emoji_events_outlined
                  : Icons.flag_outlined,
              accentColor: completedToday == totalHabits
                  ? OraColors.gold
                  : selectedGroup.accentColor,
            ),
            const SizedBox(height: 24),
            Text(
              'What This Group Offers',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: OraColors.text,
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              child: Column(
                children: [
                  const _SimpleActionTile(
                    icon: Icons.forum_outlined,
                    title: 'Discussion',
                    subtitle:
                        'A future space for Scripture reflections, wins, and honest check-ins.',
                  ),
                  const Divider(height: 1),
                  _SimpleActionTile(
                    icon: Icons.event_outlined,
                    title: 'Meeting Rhythm',
                    subtitle: selectedGroup.meetingText,
                  ),
                  const Divider(height: 1),
                  _SimpleActionTile(
                    icon: Icons.volunteer_activism_outlined,
                    title: 'Prayer Intentions',
                    subtitle: selectedGroup.prayerPrompt,
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

class _GroupInfo {
  final String id;
  final String name;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final String meetingText;
  final String discussionPrompt;
  final String prayerPrompt;

  const _GroupInfo({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.meetingText,
    required this.discussionPrompt,
    required this.prayerPrompt,
  });
}

class _GroupSelectorCard extends StatelessWidget {
  final _GroupInfo group;
  final bool isSelected;
  final VoidCallback onTap;

  const _GroupSelectorCard({
    required this.group,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 220,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? group.accentColor : OraColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? group.accentColor
                : OraColors.primary.withOpacity(0.08),
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? group.accentColor.withOpacity(0.18)
                  : Colors.black.withOpacity(0.04),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              group.icon,
              color: isSelected ? Colors.white : group.accentColor,
              size: 24,
            ),
            const Spacer(),
            Text(
              group.name,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : OraColors.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              group.subtitle,
              style: textTheme.bodySmall?.copyWith(
                color: isSelected
                    ? Colors.white.withOpacity(0.86)
                    : OraColors.muted,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupHeroCard extends StatelessWidget {
  final _GroupInfo group;
  final int completedToday;
  final int totalHabits;
  final int currentStreak;

  const _GroupHeroCard({
    required this.group,
    required this.completedToday,
    required this.totalHabits,
    required this.currentStreak,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            group.accentColor,
            OraColors.primaryDeep,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: group.accentColor.withOpacity(0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.name,
                  style: textTheme.labelLarge?.copyWith(
                    color: Colors.white.withOpacity(0.82),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Grow stronger together.',
                  style: textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  currentStreak > 0
                      ? 'You have completed $completedToday of $totalHabits habits today and are on a $currentStreak-day streak in this season of brotherhood.'
                      : 'You have completed $completedToday of $totalHabits habits today. Start building momentum with ${group.name}.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withOpacity(0.88),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.18),
              ),
            ),
            child: Icon(
              group.icon,
              color: Colors.white,
              size: 26,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;

  const _SectionCard({
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: OraColors.surface,
      child: child,
    );
  }
}

class _GroupMemberTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String name;
  final String status;
  final String trailingText;

  const _GroupMemberTile({
    required this.icon,
    required this.iconColor,
    required this.name,
    required this.status,
    required this.trailingText,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ListTile(
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: iconColor.withOpacity(0.12),
        child: Icon(
          icon,
          color: iconColor,
          size: 20,
        ),
      ),
      title: Text(
        name,
        style: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: OraColors.text,
        ),
      ),
      subtitle: Text(
        status,
        style: textTheme.bodySmall?.copyWith(
          color: OraColors.muted,
          height: 1.35,
        ),
      ),
      trailing: Text(
        trailingText,
        style: textTheme.labelMedium?.copyWith(
          color: iconColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;

  const _ChallengeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      color: OraColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: accentColor,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: OraColors.text,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: textTheme.bodyMedium?.copyWith(
                      color: OraColors.muted,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Open preview',
                    style: textTheme.labelLarge?.copyWith(
                      color: accentColor,
                      fontWeight: FontWeight.w700,
                    ),
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

class _SimpleActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SimpleActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ListTile(
      leading: Icon(
        icon,
        color: OraColors.primary,
      ),
      title: Text(
        title,
        style: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: OraColors.text,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: textTheme.bodySmall?.copyWith(
          color: OraColors.muted,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: OraColors.muted,
      ),
    );
  }
}