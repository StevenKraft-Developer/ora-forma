import 'package:flutter/material.dart';
import 'colors.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: const _PhoneScreen(),
      ),
    );
  }
}

// ---------------- PHONE SCREEN ----------------

class _PhoneScreen extends StatelessWidget {
  const _PhoneScreen();

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
            const _StatusRow(),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: const [
                    _HeroCard(),
                    SizedBox(height: 12),
                    _TodaySection(),
                    SizedBox(height: 12),
                    _WeeklySection(),
                    SizedBox(height: 12),
                    _MeetingSection(),
                    SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow();

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

class _HeroCard extends StatelessWidget {
  const _HeroCard();

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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Friday · Ordinary Time',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: OraColors.gold,
                    ),
                  ),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFF4E7AB5), Color(0xFF3D6394)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    padding: const EdgeInsets.all(5),
                    child: Image.asset(
                      'assets/logo_ora_forma.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Good morning, brothers.',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Begin with prayer, keep watch over your habits, and stay rooted in discipline.',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white.withOpacity(0.8),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: OraColors.primary,
                      height: 1.5,
                    ),
                    children: [
                      const TextSpan(
                        text:
                            '"Be watchful, stand firm in the faith, act like men, be strong."',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const TextSpan(text: ' '),
                      TextSpan(
                        text: '— 1 Corinthians 16:13',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: OraColors.gold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------- TODAY SECTION & HABITS ----------------

class _TodaySection extends StatefulWidget {
  const _TodaySection();

  @override
  State<_TodaySection> createState() => _TodaySectionState();
}

class _TodaySectionState extends State<_TodaySection> {
  final List<bool> _habitStates = [
    true,
    true,
    false,
    true,
    false,
  ];

  void _toggleHabit(int index) {
    setState(() {
      _habitStates[index] = !_habitStates[index];
    });
  }

  int get _completedCount => _habitStates.where((state) => state).length;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Today’s rule of life'.toUpperCase(),
                style: textTheme.bodySmall?.copyWith(
                  fontSize: 13,
                  letterSpacing: 0.12,
                  color: const Color(0xFF606A5F),
                ),
              ),
              Text(
                '$_completedCount of 5 complete',
                style: textTheme.bodySmall?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: OraColors.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _HabitCard(
          icon: '🙏',
          iconBackground: const LinearGradient(
            colors: [Color(0xFFF7F1D9), Color(0xFFEFE4BB)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          title: 'Morning Prayer',
          subtitle: 'Completed at 6:20 AM · Scripture and intercessions',
          isCompleted: _habitStates[0],
          onTap: () => _toggleHabit(0),
        ),
        const SizedBox(height: 10),
        _HabitCard(
          icon: '📖',
          iconBackground: const LinearGradient(
            colors: [Color(0xFFF7F1D9), Color(0xFFEFE4BB)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          title: 'Bible Reading',
          subtitle: '10 minutes today · Gospel of Matthew',
          isCompleted: _habitStates[1],
          onTap: () => _toggleHabit(1),
        ),
        const SizedBox(height: 10),
        _HabitCard(
          icon: '🥣',
          iconBackground: const LinearGradient(
            colors: [Color(0xFFEFE7D8), Color(0xFFE3D4BF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          title: 'Clean Eating',
          subtitle: 'No snacking after 8 PM · Stay intentional today',
          isCompleted: _habitStates[2],
          onTap: () => _toggleHabit(2),
        ),
        const SizedBox(height: 10),
        _HabitCard(
          icon: '🏃',
          iconBackground: const LinearGradient(
            colors: [Color(0xFFDCE8DF), Color(0xFFCFE0D0)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          title: '30-Minute Exercise',
          subtitle: 'Completed · Strength and incline walk',
          isCompleted: _habitStates[3],
          onTap: () => _toggleHabit(3),
        ),
        const SizedBox(height: 10),
        _HabitCard(
          icon: '🌙',
          iconBackground: const LinearGradient(
            colors: [Color(0xFFF7F1D9), Color(0xFFEFE4BB)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          title: 'Evening Reflection',
          subtitle: 'Still ahead · Quiet review before bed',
          isCompleted: _habitStates[4],
          onTap: () => _toggleHabit(4),
        ),
      ],
    );
  }
}

class _HabitCard extends StatelessWidget {
  final String icon;
  final LinearGradient iconBackground;
  final String title;
  final String subtitle;
  final bool isCompleted;
  final VoidCallback onTap;

  const _HabitCard({
    required this.icon,
    required this.iconBackground,
    required this.title,
    required this.subtitle,
    required this.isCompleted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final cardColor =
        isCompleted ? const Color(0xFFECF3EC) : Colors.white.withOpacity(0.72);

    final stateIcon = isCompleted ? '✓' : '○';
    final stateBg =
        isCompleted ? const Color(0xFF4F7A45) : const Color(0xFFE8E8E8);
    final stateText = isCompleted ? Colors.white : const Color(0xFFA0A0A0);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isCompleted
                ? const Color(0x1A4F7A45)
                : const Color(0x14313A2E),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(31, 38, 30, 0.10),
              blurRadius: 45,
              offset: Offset(0, 18),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: iconBackground,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Text(icon, style: const TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      decoration:
                          isCompleted ? TextDecoration.lineThrough : null,
                      color: isCompleted
                          ? const Color(0xFF667063)
                          : const Color(0xFF1F261E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: textTheme.bodySmall?.copyWith(
                      fontSize: 13,
                      color: const Color(0xFF667063),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: stateBg,
                borderRadius: BorderRadius.circular(15),
              ),
              alignment: Alignment.center,
              child: Text(
                stateIcon,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: stateText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- WEEKLY STATS ----------------

class _WeeklySection extends StatelessWidget {
  const _WeeklySection();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

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
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'This week'.toUpperCase(),
                style: textTheme.bodySmall?.copyWith(
                  fontSize: 13,
                  letterSpacing: 0.12,
                  color: const Color(0xFF606A5F),
                ),
              ),
              Text(
                '11-day streak',
                style: textTheme.bodySmall?.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: OraColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: const [
              Expanded(
                child: _MiniStat(value: '5/7', label: 'Prayer rhythm'),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _MiniStat(value: '4/7', label: 'Meals on plan'),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _MiniStat(value: '3/5', label: 'Workouts'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String value;
  final String label;

  const _MiniStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.54),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x0D313A2E)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: textTheme.titleMedium?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: OraColors.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              fontSize: 12,
              color: const Color(0xFF667063),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------- MEETING SECTION ----------------

class _MeetingSection extends StatelessWidget {
  const _MeetingSection();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [OraColors.primary, OraColors.primaryDeep],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(41, 68, 58, 0.22),
            blurRadius: 40,
            offset: Offset(0, 18),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Men’s Group',
                  style: textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: const Color(0xFFF1E6BB),
                  ),
                ),
              ),
              Row(
                children: const [
                  _AttendanceDot(color: Color(0xFFC9A757)),
                  SizedBox(width: 8),
                  _AttendanceDot(color: Color(0xFFC9A757)),
                  SizedBox(width: 8),
                  _AttendanceDot(color: Color(0xFFD7D0B2)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Next meeting · June 12',
            style: textTheme.titleMedium?.copyWith(
              fontSize: 20,
              fontFamily: 'Fraunces',
              letterSpacing: -0.02,
              color: const Color(0xFFF8F4E8),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Monthly formation night with shared meal, discussion, and commitments for the next month.',
            style: textTheme.bodySmall?.copyWith(
              fontSize: 13,
              height: 1.55,
              color: const Color(0xC8F8F4E8),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceDot extends StatelessWidget {
  final Color color;
  const _AttendanceDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(5),
      ),
    );
  }
}