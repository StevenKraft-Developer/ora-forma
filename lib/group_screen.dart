import 'package:flutter/material.dart';
import '../colors.dart';

class GroupScreen extends StatelessWidget {
  const GroupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: const _GroupPhoneScreen(),
      ),
    );
  }
}

class _GroupPhoneScreen extends StatelessWidget {
  const _GroupPhoneScreen();

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
            const _GroupStatusRow(),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: const [
                  _GroupHeroCard(),
                  SizedBox(height: 12),
                  _NextMeetingCard(),
                  SizedBox(height: 12),
                  _GroupStreakCard(),
                  SizedBox(height: 12),
                  _MembersCard(),
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

class _GroupStatusRow extends StatelessWidget {
  const _GroupStatusRow();

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

class _GroupHeroCard extends StatelessWidget {
  const _GroupHeroCard();

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
                'Brotherhood',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Stay accountable, prepare for the next meeting, and walk with your group in discipline.',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white.withOpacity(0.82),
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

class _NextMeetingCard extends StatelessWidget {
  const _NextMeetingCard();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Next Meeting'.toUpperCase(),
            style: textTheme.bodySmall?.copyWith(
              fontSize: 13,
              letterSpacing: 0.12,
              color: const Color(0xFF606A5F),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Thursday · June 12 · 7:00 PM',
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: OraColors.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Shared meal, discussion, and commitments for the next month.',
            style: textTheme.bodySmall?.copyWith(
              fontSize: 13,
              height: 1.5,
              color: const Color(0xFF667063),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupStreakCard extends StatelessWidget {
  const _GroupStreakCard();

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      child: Row(
        children: const [
          Expanded(
            child: _MiniMetric(
              value: '8',
              label: 'Active men',
              icon: Icons.groups,
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: _MiniMetric(
              value: '4 wk',
              label: 'Shared streak',
              icon: Icons.local_fire_department,
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: _MiniMetric(
              value: '92%',
              label: 'Check-ins',
              icon: Icons.check_circle,
            ),
          ),
        ],
      ),
    );
  }
}

class _MembersCard extends StatelessWidget {
  const _MembersCard();

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _MemberRow(
            initials: 'JG',
            name: 'James',
            status: 'Checked in today',
            isActive: true,
          ),
          SizedBox(height: 12),
          _MemberRow(
            initials: 'MT',
            name: 'Matthew',
            status: 'Prayer streak: 6 days',
            isActive: true,
          ),
          SizedBox(height: 12),
          _MemberRow(
            initials: 'LK',
            name: 'Luke',
            status: 'Needs encouragement',
            isActive: false,
          ),
        ],
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  final String initials;
  final String name;
  final String status;
  final bool isActive;

  const _MemberRow({
    required this.initials,
    required this.name,
    required this.status,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = isActive
        ? const Color(0xFF4F7A45)
        : const Color(0xFF9B8F78);

    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.8),
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Text(
            initials,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: OraColors.primary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F261E),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                status,
                style: const TextStyle(fontSize: 13, color: Color(0xFF667063)),
              ),
            ],
          ),
        ),
        Icon(Icons.circle, size: 10, color: statusColor),
      ],
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;

  const _MiniMetric({
    required this.value,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.54),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x0D313A2E)),
      ),
      child: Column(
        children: [
          Icon(icon, color: OraColors.primary, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: OraColors.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Color(0xFF667063)),
          ),
        ],
      ),
    );
  }
}

class _SoftCard extends StatelessWidget {
  final Widget child;

  const _SoftCard({required this.child});

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
