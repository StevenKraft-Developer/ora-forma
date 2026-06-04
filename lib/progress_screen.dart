import 'package:flutter/material.dart';
import 'colors.dart';

class ProgressSummary {
  final int currentStreak;
  final int longestStreak;
  final int completedThisWeek;
  final int totalThisWeek;
  final List<bool> weekCompletion;

  const ProgressSummary({
    required this.currentStreak,
    required this.longestStreak,
    required this.completedThisWeek,
    required this.totalThisWeek,
    required this.weekCompletion,
  });

  double get weeklyProgress =>
      totalThisWeek == 0 ? 0 : completedThisWeek / totalThisWeek;
}

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: const _ProgressPhoneScreen(),
      ),
    );
  }
}

class _ProgressPhoneScreen extends StatelessWidget {
  const _ProgressPhoneScreen();

  @override
  Widget build(BuildContext context) {
    const summary = ProgressSummary(
      currentStreak: 5,
      longestStreak: 12,
      completedThisWeek: 12,
      totalThisWeek: 15,
      weekCompletion: [true, true, false, true, true, true, false],
    );

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
            const _ProgressStatusRow(),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: [
                  const _ProgressHeroCard(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: StatCard(
                          title: 'Current Streak',
                          value: '${summary.currentStreak} days',
                          icon: Icons.local_fire_department,
                          iconColor: OraColors.gold,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatCard(
                          title: 'Best Streak',
                          value: '${summary.longestStreak} days',
                          icon: Icons.emoji_events,
                          iconColor: OraColors.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  WeeklyProgressCard(summary: summary),
                  const SizedBox(height: 12),
                  WeeklyCard(weekCompletion: summary.weekCompletion),
                  const SizedBox(height: 12),
                  InsightCard(
                    message:
                        'You completed ${summary.completedThisWeek} of ${summary.totalThisWeek} habits this week. Keep building consistency.',
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- STATUS + HERO ----------

class _ProgressStatusRow extends StatelessWidget {
  const _ProgressStatusRow();

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

class _ProgressHeroCard extends StatelessWidget {
  const _ProgressHeroCard();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
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
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your progress this week',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Streaks, consistency, and small faithfulness over time.',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white.withOpacity(0.8),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------- CARDS ----------

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData? icon;
  final Color? iconColor;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: OraColors.surface,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Icon(icon, color: iconColor ?? OraColors.gold, size: 28),
              const SizedBox(height: 12),
            ],
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                color: OraColors.muted,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                color: OraColors.text,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WeeklyProgressCard extends StatelessWidget {
  final ProgressSummary summary;

  const WeeklyProgressCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final progressPercent = (summary.weeklyProgress * 100).round();

    return Card(
      color: OraColors.surface,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Weekly Progress',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: OraColors.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${summary.completedThisWeek} of ${summary.totalThisWeek} habits completed',
              style: const TextStyle(fontSize: 14, color: OraColors.muted),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: summary.weeklyProgress,
                minHeight: 10,
                backgroundColor: OraColors.background,
                valueColor: const AlwaysStoppedAnimation<Color>(OraColors.gold),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '$progressPercent% complete',
              style: const TextStyle(
                fontSize: 14,
                color: OraColors.text,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WeeklyCard extends StatelessWidget {
  final List<bool> weekCompletion;

  const WeeklyCard({super.key, required this.weekCompletion});

  @override
  Widget build(BuildContext context) {
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Card(
      color: OraColors.surface,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This Week',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: OraColors.text,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Your recent consistency',
              style: TextStyle(fontSize: 14, color: OraColors.muted),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(labels.length, (index) {
                final completed = weekCompletion[index];

                return Column(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: completed
                            ? OraColors.gold
                            : OraColors.background,
                        border: Border.all(
                          color: completed
                              ? OraColors.gold
                              : OraColors.muted.withOpacity(0.35),
                          width: 1.5,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        completed ? Icons.check : Icons.remove,
                        size: 18,
                        color: completed ? Colors.white : OraColors.muted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      labels[index],
                      style: const TextStyle(
                        fontSize: 12,
                        color: OraColors.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class InsightCard extends StatelessWidget {
  final String message;

  const InsightCard({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: OraColors.surface,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.insights, color: OraColors.primary, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  color: OraColors.text,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}