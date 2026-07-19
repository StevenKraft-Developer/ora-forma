import 'package:flutter/material.dart';

import '../../colors.dart';
import '../../services/onboarding_storage.dart';

/// Placeholder habit-onboarding screen wired in by AppGate (Task 5).
///
/// This is intentionally minimal. Task 6 replaces this with the full
/// three-page PageView onboarding experience (purpose → habit selection →
/// confirmation). Everything here is temporary scaffolding.
///
/// Completion contract:
///   When the user taps "Get Started", this screen:
///     1. Writes the completion flag via [OnboardingStorage].
///     2. Calls [onCompleted] to notify AppGate.
///   AppGate then re-evaluates its routing and shows [MainNavigationScreen].
///   No navigation is pushed from inside this screen — AppGate owns routing.
class HabitOnboardingScreen extends StatefulWidget {
  /// Called after the completion flag has been persisted. AppGate uses this
  /// to flip its local [_habitOnboardingComplete] state and rebuild.
  final VoidCallback onCompleted;

  const HabitOnboardingScreen({super.key, required this.onCompleted});

  @override
  State<HabitOnboardingScreen> createState() => _HabitOnboardingScreenState();
}

class _HabitOnboardingScreenState extends State<HabitOnboardingScreen> {
  bool _isSaving = false;

  Future<void> _complete() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    await OnboardingStorage().saveOnboardingComplete(true);

    // Call the AppGate callback — do not push/pop routes here.
    widget.onCompleted();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: OraColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Logo / branding mark ──────────────────────────────────────
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [OraColors.primary, OraColors.primaryDeep],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(height: 32),

              // ── Headline ─────────────────────────────────────────────────
              Text(
                'Welcome to Ora Forma',
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: OraColors.text,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 16),

              // ── Body copy ─────────────────────────────────────────────────
              Text(
                'Ora Forma helps you build a faithful rule of life — '
                'daily habits rooted in prayer, discipline, and brotherhood.',
                style: textTheme.bodyLarge?.copyWith(
                  color: OraColors.muted,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'In the next step you will choose the habits that make up '
                'your daily rule. You can always adjust them later.',
                style: textTheme.bodyLarge?.copyWith(
                  color: OraColors.muted,
                  height: 1.55,
                ),
              ),

              const Spacer(),

              // ── Primary action ────────────────────────────────────────────
              // TODO(Task 6): replace with PageView onboarding flow.
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _isSaving ? null : _complete,
                  style: FilledButton.styleFrom(
                    backgroundColor: OraColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Get Started',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
