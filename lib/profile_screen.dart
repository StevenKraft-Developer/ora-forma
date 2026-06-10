import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'colors.dart';
import 'providers/progress_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _notificationsEnabled = true;
  bool _dailyReminderEnabled = true;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          children: [
            const _ProfileHeaderCard(),
            const SizedBox(height: 20),

            Text(
              'Preferences',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: OraColors.text,
              ),
            ),
            const SizedBox(height: 12),

            Card(
              child: Column(
                children: [
                  SwitchListTile.adaptive(
                    value: _notificationsEnabled,
                    onChanged: (value) {
                      setState(() {
                        _notificationsEnabled = value;
                      });
                    },
                    title: const Text('Notifications'),
                    subtitle: const Text(
                      'Receive encouragement and app updates',
                    ),
                    secondary: const Icon(
                      Icons.notifications_none_rounded,
                      color: OraColors.primary,
                    ),
                  ),
                  const Divider(height: 1),
                  SwitchListTile.adaptive(
                    value: _dailyReminderEnabled,
                    onChanged: (value) {
                      setState(() {
                        _dailyReminderEnabled = value;
                      });
                    },
                    title: const Text('Daily Reminder'),
                    subtitle: const Text(
                      'Stay consistent with your daily check-in',
                    ),
                    secondary: const Icon(
                      Icons.alarm_rounded,
                      color: OraColors.gold,
                    ),
                  ),
                  const Divider(height: 1),
                  _SettingsTile(
                    icon: Icons.palette_outlined,
                    iconColor: OraColors.primary,
                    title: 'Appearance',
                    subtitle: 'Light mode for now',
                    onTap: () {
                      _showSimpleSheet(
                        context,
                        title: 'Appearance',
                        message:
                            'Theme settings can be wired in once dark mode or theme preferences are added.',
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            Text(
              'Account',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: OraColors.text,
              ),
            ),
            const SizedBox(height: 12),

            Card(
              child: Column(
                children: [
                  _SettingsTile(
                    icon: Icons.person_outline_rounded,
                    iconColor: OraColors.primary,
                    title: 'Profile Details',
                    subtitle: 'Name, email, and account info',
                    onTap: () {
                      _showSimpleSheet(
                        context,
                        title: 'Profile Details',
                        message:
                            'Profile editing can be connected once user accounts are added.',
                      );
                    },
                  ),
                  const Divider(height: 1),
                  _SettingsTile(
                    icon: Icons.info_outline_rounded,
                    iconColor: OraColors.gold,
                    title: 'About Ora Forma',
                    subtitle: 'Version, mission, and app information',
                    onTap: () {
                      _showSimpleSheet(
                        context,
                        title: 'About Ora Forma',
                        message:
                            'Ora Forma is your Catholic habit companion for consistency, discipline, and formation.',
                      );
                    },
                  ),
                  const Divider(height: 1),
                  _SettingsTile(
                    icon: Icons.help_outline_rounded,
                    iconColor: OraColors.muted,
                    title: 'Help & Support',
                    subtitle: 'Get help with using the app',
                    onTap: () {
                      _showSimpleSheet(
                        context,
                        title: 'Help & Support',
                        message:
                            'Support options can be added later, such as email, FAQ, or mentor resources.',
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            Text(
              'Danger Zone',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: OraColors.text,
              ),
            ),
            const SizedBox(height: 12),

            Card(
              child: Column(
                children: [
                  _SettingsTile(
                    icon: Icons.restart_alt_rounded,
                    iconColor: OraColors.destructive,
                    title: 'Reset Progress',
                    subtitle: 'Clear saved habits and history',
                    destructive: true,
                    onTap: _confirmResetProgress,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmResetProgress() async {
    final provider = context.read<ProgressProvider>();
    final messenger = ScaffoldMessenger.of(context);

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Reset Progress?'),
              content: const Text(
                'This will permanently clear your saved habit progress and history on this device.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text(
                    'Reset',
                    style: TextStyle(color: OraColors.destructive),
                  ),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed || !mounted) return;

    await provider.clearAllProgress();

    if (!mounted) return;

    messenger.showSnackBar(
      const SnackBar(content: Text('Progress reset successfully.')),
    );
  }

  void _showSimpleSheet(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final textTheme = Theme.of(context).textTheme;

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: textTheme.titleLarge?.copyWith(
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
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [OraColors.primary, OraColors.primaryDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: OraColors.primary.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: const Icon(
              Icons.person_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Profile',
                  style: textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Manage your preferences, account details, and app settings.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.88),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: iconColor),
      title: Text(
        title,
        style: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: destructive ? OraColors.destructive : OraColors.text,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: textTheme.bodySmall?.copyWith(color: OraColors.muted),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: destructive ? OraColors.destructive : OraColors.muted,
      ),
    );
  }
}
