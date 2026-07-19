import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_profile_provider.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _displayNameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final user = authProvider.user;
    if (user == null) return;

    await context.read<UserProfileProvider>().completeOnboarding(
          uid: user.uid,
          email: user.email ?? '',
          displayName: _displayNameController.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<UserProfileProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Set up profile')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const Text('Tell us your name to finish setting up Ora Forma.'),
              const SizedBox(height: 24),
              TextFormField(
                controller: _displayNameController,
                decoration: const InputDecoration(labelText: 'Display name'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter your display name.'
                    : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: profileProvider.isLoading ? null : _submit,
                child: profileProvider.isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}