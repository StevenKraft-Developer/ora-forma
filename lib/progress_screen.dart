import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/habit.dart';
import 'colors.dart';
import 'providers/habit_provider.dart';
import 'providers/progress_provider.dart';

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
    final progress = context.watch<ProgressProvider>();

    if (!progress.isLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    final completedCount = progress.completedCount;
    final totalCount = progress.totalCount;
    final completionPercent = progress.completionPercent;

    final currentStreak = progress.currentStreak;
    final longestStreak = progress.longestStreak;
    final completedThisWeek = progress.completedThisWeek;
    final totalThisWeek = progress.totalThisWeek;
    final weeklyCompletionPercent = progress.weeklyCompletionPercent;
    final thisWeekCompletion = progress.thisWeekCompletion;

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
                          value: '$currentStreak days',
                          icon: Icons.local_fire_department,
                          iconColor: OraColors.gold,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatCard(
                          title: 'Best Streak',
                          value: '$longestStreak days',
                          icon: Icons.emoji_events,
                          iconColor: OraColors.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: StatCard(
                          title: 'Completed Today',
                          value: '$completedCount of $totalCount',
                          icon: Icons.check_circle,
                          iconColor: OraColors.gold,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatCard(
                          title: 'Today Rate',
                          value: '${(completionPercent * 100).round()}%',
                          icon: Icons.insights,
                          iconColor: OraColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  WeeklyProgressCard(
                    completedThisWeek: completedThisWeek,
                    totalThisWeek: totalThisWeek,
                    weeklyCompletionPercent: weeklyCompletionPercent,
                  ),
                  const SizedBox(height: 12),
                  WeeklyCard(weekCompletion: thisWeekCompletion),
                  const SizedBox(height: 12),
                  HabitStreaksCard(habits: context.watch<HabitProvider>().activeHabits),
                  const SizedBox(height: 12),
                  InsightCard(
                    message:
                        'You completed $completedThisWeek of $totalThisWeek habits this week. Faithful routines are built one day at a time.',
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
          colors: [OraColors.primary, OraColors.primaryDeep],
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
                'Review streaks, weekly consistency, and the habits that are shaping your rule of life.',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white.withValues(alpha: 0.8),
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
  final int completedThisWeek;
  final int totalThisWeek;
  final double weeklyCompletionPercent;

  const WeeklyProgressCard({
    super.key,
    required this.completedThisWeek,
    required this.totalThisWeek,
    required this.weeklyCompletionPercent,
  });

  @override
  Widget build(BuildContext context) {
    final progressPercent = (weeklyCompletionPercent * 100).round();

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
              'This Week\'s Progress',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: OraColors.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$completedThisWeek of $totalThisWeek habits completed',
              style: const TextStyle(fontSize: 14, color: OraColors.muted),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: weeklyCompletionPercent.clamp(0.0, 1.0),
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
    const labels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    final today = DateTime.now();
    final todayIndex = today.weekday % 7;

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
              'Sunday through Saturday',
              style: TextStyle(fontSize: 14, color: OraColors.muted),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(labels.length, (index) {
                final completed = index < weekCompletion.length
                    ? weekCompletion[index]
                    : false;
                final isToday = index == todayIndex;

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
                          color: isToday
                              ? OraColors.primary
                              : completed
                              ? OraColors.gold
                              : OraColors.muted.withValues(alpha: 0.35),
                          width: isToday ? 2 : 1.5,
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
                      style: TextStyle(
                        fontSize: 12,
                        color: isToday ? OraColors.primary : OraColors.muted,
                        fontWeight: FontWeight.w600,
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

class HabitStreaksCard extends StatelessWidget {
  final List<Habit> habits;

  const HabitStreaksCard({super.key, required this.habits});

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<ProgressProvider>();
    final allHabitIds = habits.map((habit) => habit.id).toList();
    final currentSharedStreak = progress.currentStreakForHabits(allHabitIds);
    final bestSharedStreak = progress.longestStreakForHabits(allHabitIds);

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
              'Habit Streaks',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: OraColors.text,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Track consistency for each habit and your full rule of life together',
              style: TextStyle(fontSize: 14, color: OraColors.muted),
            ),
            const SizedBox(height: 16),
            ...habits.map((habit) {
              final currentStreak = progress.currentStreakForHabit(habit.id);
              final bestStreak = progress.longestStreakForHabit(habit.id);
              final isActiveToday = progress.completedHabitIds.contains(
                habit.id,
              );

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: OraColors.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isActiveToday
                          ? OraColors.gold.withValues(alpha: 0.45)
                          : OraColors.muted.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: isActiveToday
                              ? OraColors.gold.withValues(alpha: 0.16)
                              : OraColors.primary.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isActiveToday
                              ? Icons.local_fire_department
                              : Icons.timeline,
                          color: isActiveToday
                              ? OraColors.gold
                              : OraColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              habit.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: OraColors.text,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              currentStreak == 1
                                  ? '1-day current streak'
                                  : '$currentStreak-day current streak',
                              style: const TextStyle(
                                fontSize: 13,
                                color: OraColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$currentStreak',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: OraColors.primary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Current',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: OraColors.muted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$bestStreak',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: OraColors.gold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Best',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: OraColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [OraColors.primary, OraColors.primaryDeep],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rule of Life Together',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Current and best streak for completing every habit together',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white70,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$currentSharedStreak',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Current',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$bestSharedStreak',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: OraColors.gold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Best',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
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
