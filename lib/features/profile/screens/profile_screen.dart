import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/models/gender.dart';
import '../../auth/models/user_profile.dart';
import '../../auth/services/auth_service.dart';
import '../../auth/services/profile_service.dart';
import '../../auth/widgets/auth_text_field.dart';
import '../../auth/widgets/primary_auth_button.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    this.authService,
    this.profileService,
  });

  final AuthService? authService;
  final ProfileService? profileService;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final AuthService _authService = widget.authService ?? AuthService();
  late final ProfileService _profileService =
      widget.profileService ?? const ProfileService();

  UserProfile? _profile;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isLoggingOut = false;

  late final TextEditingController _nameController = TextEditingController();
  late final TextEditingController _ageController = TextEditingController();
  late final TextEditingController _emailController = TextEditingController();
  late final TextEditingController _newPasswordController =
      TextEditingController();
  late final TextEditingController _confirmPasswordController =
      TextEditingController();

  Gender? _gender;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _emailController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final profile = await _profileService.getCurrentProfile();
      final user = _authService.getCurrentUser();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _nameController.text = profile?.displayName ?? '';
        _ageController.text = profile?.age?.toString() ?? '';
        _emailController.text = user?.email ?? '';
        _gender = profile?.gender;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    final age = int.tryParse(_ageController.text.trim());
    if (name.isEmpty) {
      _showSnack('Namen eingeben');
      return;
    }
    if (age == null || age < 6 || age > 90) {
      _showSnack('Gib ein Alter von 6 bis 90 ein');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final updated = await _profileService.updateEditableFields(
        displayName: name,
        age: age,
        gender: _gender,
      );
      if (!mounted) return;
      setState(() => _profile = updated);
      _showSnack('Profil gespeichert');
    } on StateError catch (error) {
      _showSnack(error.message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _changeEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showSnack('Gib eine gültige E-Mail ein');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _authService.updateEmail(email);
      if (!mounted) return;
      _showSnack(
        'Anfrage gesendet. Bestätige die neue E-Mail über den Link.',
      );
    } on AuthException catch (error) {
      _showSnack(error.message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _changePassword() async {
    final password = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;
    if (password.length < 8) {
      _showSnack('Das Passwort muss mindestens 8 Zeichen haben');
      return;
    }
    if (password != confirm) {
      _showSnack('Die Passwörter stimmen nicht überein');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _authService.updatePassword(password);
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      if (!mounted) return;
      _showSnack('Passwort aktualisiert');
    } on AuthException catch (error) {
      _showSnack(error.message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _logout() async {
    setState(() => _isLoggingOut = true);
    try {
      await _authService.signOut();
    } on AuthException catch (error) {
      _showSnack(error.message);
    } finally {
      if (mounted) setState(() => _isLoggingOut = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.getCurrentUser();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                children: [
                  Text(
                    'Profil',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: 24),
                  if (_profile?.musicianLevel != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Niveau: ${_profile!.musicianLevel!.labelRu}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  _SectionCard(
                    title: 'Angaben',
                    children: [
                      AuthTextField(
                        controller: _nameController,
                        label: 'Name',
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 12),
                      AuthTextField(
                        controller: _ageController,
                        label: 'Alter',
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Geschlecht',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: Gender.values.map((g) {
                          final selected = _gender == g;
                          return ChoiceChip(
                            label: Text(g.labelRu),
                            selected: selected,
                            onSelected: (_) => setState(() => _gender = g),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      PrimaryAuthButton(
                        label: 'Speichern',
                        isLoading: _isSaving,
                        onPressed: _saveProfile,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: 'Kontakt',
                    children: [
                      _InfoRow(
                        label: 'E-Mail',
                        value: user?.email ?? '—',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: 'E-Mail ändern',
                    children: [
                      AuthTextField(
                        controller: _emailController,
                        label: 'Neue E-Mail',
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 12),
                      PrimaryAuthButton(
                        label: 'E-Mail ändern',
                        isLoading: _isSaving,
                        onPressed: _changeEmail,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: 'Passwort ändern',
                    children: [
                      AuthTextField(
                        controller: _newPasswordController,
                        label: 'Neues Passwort',
                        obscureText: true,
                      ),
                      const SizedBox(height: 12),
                      AuthTextField(
                        controller: _confirmPasswordController,
                        label: 'Passwort bestätigen',
                        obscureText: true,
                      ),
                      const SizedBox(height: 12),
                      PrimaryAuthButton(
                        label: 'Passwort ändern',
                        isLoading: _isSaving,
                        onPressed: _changePassword,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  PrimaryAuthButton(
                    label: 'Abmelden',
                    isLoading: _isLoggingOut,
                    onPressed: _logout,
                  ),
                ],
              ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 88,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ],
    );
  }
}
