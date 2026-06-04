import 'package:flutter/material.dart';
import '../colors.dart';

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
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
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

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: const [
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
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.person,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Profile',
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Keep your rule of life, reminders, and account details in order.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.82),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard();

  @override
  Widget build(BuildContext context) {
    return _ProfileSoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _ProfileRow(
            icon: Icons.badge,
            title: 'Name',
            subtitle: 'John Doe',
          ),
          SizedBox(height: 12),
          _ProfileRow(
            icon: Icons.email,
            title: 'Email',
            subtitle: 'john.doe@example.com',
          ),
          SizedBox(height: 12),
          _ProfileRow(
            icon: Icons.groups_2,
            title: 'Group',
            subtitle: 'Tuesday Brotherhood',
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard();

  @override
  Widget build(BuildContext context) {
    return _ProfileSoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _ProfileRow(
            icon: Icons.notifications_active,
            title: 'Reminders',
            subtitle: 'Daily habit reminders are on',
          ),
          SizedBox(height: 12),
          _ProfileRow(
            icon: Icons.dark_mode,
            title: 'Appearance',
            subtitle: 'System default',
          ),
          SizedBox(height: 12),
          _ProfileRow(
            icon: Icons.menu_book,
            title: 'Rule of Life',
            subtitle: '5 active habits',
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
    return _ProfileSoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _ProfileRow(
            icon: Icons.privacy_tip,
            title: 'Privacy',
            subtitle: 'Group sharing is limited to check-ins',
          ),
          SizedBox(height: 12),
          _ProfileRow(
            icon: Icons.help_outline,
            title: 'Help',
            subtitle: 'FAQs and support',
          ),
          SizedBox(height: 12),
          _ProfileRow(
            icon: Icons.logout,
            title: 'Sign out',
            subtitle: 'End your current session',
            danger: true,
          ),
        ],
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool danger;

  const _ProfileRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor = danger ? const Color(0xFF9A4A3A) : const Color(0xFF1F261E);
    final iconColor = danger ? const Color(0xFF9A4A3A) : OraColors.primary;

    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.65),
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF667063),
                ),
              ),
            ],
          ),
        ),
        const Icon(
          Icons.chevron_right,
          color: Color(0xFF8B8F87),
        ),
      ],
    );
  }
}

class _ProfileSoftCard extends StatelessWidget {
  final Widget child;

  const _ProfileSoftCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.72),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x14313A2E)),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(31, 38, 30, 0.10),
            blurRadius: 45,
            offset: Offset(0, 18),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: child,
    );
  }
}