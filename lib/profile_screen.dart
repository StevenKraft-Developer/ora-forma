import 'package:flutter/material.dart';
import 'colors.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: const _ProfilePhoneScreen(),
      ),
    );
  }
}

class _ProfilePhoneScreen extends StatelessWidget {
  const _ProfilePhoneScreen();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF7F4ED), Color(0xFFEFE8DB)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Column(
          children: [
            const _ProfileStatusRow(),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: const [
                  _ProfileHeroCard(),
                  SizedBox(height: 12),
                  _IdentityCard(),
                  SizedBox(height: 12),
                  _RuleOfLifeCard(),
                  SizedBox(height: 12),
                  _StatsOverviewCard(),
                  SizedBox(height: 12),
                  _SettingsCard(),
                  SizedBox(height: 12),
                  _AccountCard(),
                  SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileStatusRow extends StatelessWidget {
  const _ProfileStatusRow();

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: Color(0xFF2F352F),
    );

    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('9:41', style: textStyle),
        Text('●●●  5G  🔋', style: textStyle),
      ],
    );
  }
}

class _ProfileHeroCard extends StatelessWidget {
  const _ProfileHeroCard();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [OraColors.primary, OraColors.primaryDeep],
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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(
              radius: 28,
              backgroundColor: Colors.white24,
              child: Icon(Icons.person, color: OraColors.gold, size: 30),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Profile',
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Your personal rule of life, settings, and account details in one place.',
                    style: textTheme.bodyMedium?.copyWith(
                      height: 1.4,
                      color: Colors.white.withOpacity(0.82),
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

class _IdentityCard extends StatelessWidget {
  const _IdentityCard();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: const BoxDecoration(
                color: OraColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shield_outlined,
                color: OraColors.primary,
                size: 30,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Steven',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: OraColors.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Building a daily Catholic rule of life',
                    style: textTheme.bodySmall?.copyWith(
                      color: OraColors.muted,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const _TagChip(label: 'Ora Forma member'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RuleOfLifeCard extends StatelessWidget {
  const _RuleOfLifeCard();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rule of Life',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: OraColors.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'The commitments shaping your day',
              style: textTheme.bodySmall?.copyWith(color: OraColors.muted),
            ),
            const SizedBox(height: 16),
            const _RuleLine(
              icon: Icons.auto_stories_outlined,
              title: 'Daily prayer',
              subtitle: 'Begin and end each day with prayer',
            ),
            const SizedBox(height: 12),
            const _RuleLine(
              icon: Icons.bolt_outlined,
              title: 'Discipline',
              subtitle: 'Practice consistency in habits and routines',
            ),
            const SizedBox(height: 12),
            const _RuleLine(
              icon: Icons.groups_outlined,
              title: 'Brotherhood',
              subtitle: 'Stay accountable and connected',
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsOverviewCard extends StatelessWidget {
  const _StatsOverviewCard();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Overview',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: OraColors.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'A snapshot of your current journey',
              style: textTheme.bodySmall?.copyWith(color: OraColors.muted),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Expanded(
                  child: _ProfileStatCard(
                    icon: Icons.local_fire_department,
                    label: 'Current Streak',
                    value: '4 days',
                    color: OraColors.gold,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _ProfileStatCard(
                    icon: Icons.emoji_events,
                    label: 'Best Streak',
                    value: '9 days',
                    color: OraColors.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Row(
              children: [
                Expanded(
                  child: _ProfileStatCard(
                    icon: Icons.check_circle_outline,
                    label: 'Habits',
                    value: '5 active',
                    color: OraColors.primary,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _ProfileStatCard(
                    icon: Icons.groups_2_outlined,
                    label: 'Group',
                    value: '1 circle',
                    color: OraColors.gold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Column(
        children: [
          _ProfileActionTile(
            icon: Icons.notifications_none,
            title: 'Reminders',
            subtitle: 'Daily prompts and accountability nudges',
          ),
          Divider(height: 1, color: OraColors.background),
          _ProfileActionTile(
            icon: Icons.palette_outlined,
            title: 'Appearance',
            subtitle: 'Theme, colors, and display preferences',
          ),
          Divider(height: 1, color: OraColors.background),
          _ProfileActionTile(
            icon: Icons.lock_outline,
            title: 'Privacy',
            subtitle: 'Control your account visibility and sharing',
          ),
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Column(
        children: [
          _ProfileActionTile(
            icon: Icons.badge_outlined,
            title: 'Account details',
            subtitle: 'View and update your personal information',
          ),
          Divider(height: 1, color: OraColors.background),
          _ProfileActionTile(
            icon: Icons.help_outline,
            title: 'Help and support',
            subtitle: 'Get help with the app and your account',
          ),
          Divider(height: 1, color: OraColors.background),
          _ProfileActionTile(
            icon: Icons.logout,
            title: 'Sign out',
            subtitle: 'Leave your Ora Forma session',
            isDestructive: true,
          ),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;

  const _TagChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: OraColors.gold.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: OraColors.gold,
        ),
      ),
    );
  }
}

class _RuleLine extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _RuleLine({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(
            color: OraColors.primarySoft,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: OraColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: OraColors.text,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: OraColors.muted,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _ProfileStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: OraColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: OraColors.muted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: OraColors.text,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isDestructive;

  const _ProfileActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor = isDestructive ? OraColors.destructive : OraColors.text;
    final iconColor = isDestructive ? OraColors.destructive : OraColors.primary;

    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: titleColor,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 13, color: OraColors.muted),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: isDestructive ? OraColors.destructive : OraColors.muted,
      ),
      onTap: () {},
    );
  }
}
