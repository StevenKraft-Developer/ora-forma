import 'package:flutter/material.dart';
import 'colors.dart';

class GroupScreen extends StatelessWidget {
  const GroupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: OraColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          children: [
            const _GroupHeroCard(),
            const SizedBox(height: 20),
            Text(
              'Brotherhood',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: OraColors.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Stay connected with the men walking this path with you.',
              style: textTheme.bodyMedium?.copyWith(
                color: OraColors.muted,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            const _SectionCard(
              child: Column(
                children: [
                  _GroupMemberTile(
                    icon: Icons.shield_outlined,
                    name: 'Michael R.',
                    status: 'Completed 4 of 5 habits today',
                    trailingText: 'Strong',
                  ),
                  Divider(height: 1),
                  _GroupMemberTile(
                    icon: Icons.auto_awesome_outlined,
                    name: 'David L.',
                    status: 'Prayed the Rosary this morning',
                    trailingText: 'Focused',
                  ),
                  Divider(height: 1),
                  _GroupMemberTile(
                    icon: Icons.menu_book_outlined,
                    name: 'Anthony C.',
                    status: 'Shared a scripture reflection',
                    trailingText: 'Active',
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
            const _ChallengeCard(
              title: '7-Day Morning Prayer',
              subtitle: 'Join 8 men committing to consistent prayer before work.',
              icon: Icons.wb_sunny_outlined,
              accentColor: OraColors.primary,
            ),
            const SizedBox(height: 12),
            const _ChallengeCard(
              title: 'Scripture Before Screen Time',
              subtitle: 'Read one short passage before opening social media.',
              icon: Icons.phone_disabled_outlined,
              accentColor: OraColors.gold,
            ),
            const SizedBox(height: 24),
            Text(
              'Community',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: OraColors.text,
              ),
            ),
            const SizedBox(height: 12),
            const _SectionCard(
              child: Column(
                children: [
                  _SimpleActionTile(
                    icon: Icons.forum_outlined,
                    title: 'Group Discussion',
                    subtitle: '3 new reflections shared today',
                  ),
                  Divider(height: 1),
                  _SimpleActionTile(
                    icon: Icons.event_outlined,
                    title: 'Next Meeting',
                    subtitle: 'Thursday at 7:00 PM',
                  ),
                  Divider(height: 1),
                  _SimpleActionTile(
                    icon: Icons.volunteer_activism_outlined,
                    title: 'Prayer Intentions',
                    subtitle: '5 intentions from the group this week',
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

class _GroupHeroCard extends StatelessWidget {
  const _GroupHeroCard();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [
            OraColors.primary,
            OraColors.primaryDeep,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: OraColors.primary.withOpacity(0.18),
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
                  'Ora Forma Group',
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
                  'Encourage one another, stay accountable, and build habits that last.',
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
            child: const Icon(
              Icons.groups_2_outlined,
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
  final String name;
  final String status;
  final String trailingText;

  const _GroupMemberTile({
    required this.icon,
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
        backgroundColor: OraColors.primary.withOpacity(0.12),
        child: Icon(
          icon,
          color: OraColors.primary,
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
          color: OraColors.primary,
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
                    'View challenge',
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