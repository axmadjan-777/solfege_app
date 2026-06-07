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
      _showSnack('Введите имя');
      return;
    }
    if (age == null || age < 6 || age > 90) {
      _showSnack('Введите возраст от 6 до 90');
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
      _showSnack('Профиль сохранён');
    } on StateError catch (error) {
      _showSnack(error.message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _changeEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showSnack('Введите корректный email');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _authService.updateEmail(email);
      if (!mounted) return;
      _showSnack(
        'Запрос отправлен. Подтвердите новый email по ссылке из письма.',
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
    if (password.length < 6) {
      _showSnack('Пароль должен быть не короче 6 символов');
      return;
    }
    if (password != confirm) {
      _showSnack('Пароли не совпадают');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _authService.updatePassword(password);
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      if (!mounted) return;
      _showSnack('Пароль обновлён');
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
                    'Профиль',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: 24),
                  if (_profile?.musicianLevel != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Уровень: ${_profile!.musicianLevel!.labelRu}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  _SectionCard(
                    title: 'Данные',
                    children: [
                      AuthTextField(
                        controller: _nameController,
                        label: 'Имя',
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 12),
                      AuthTextField(
                        controller: _ageController,
                        label: 'Возраст',
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Пол',
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
                        label: 'Сохранить',
                        isLoading: _isSaving,
                        onPressed: _saveProfile,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: 'Контакты',
                    children: [
                      _InfoRow(
                        label: 'Email',
                        value: user?.email ?? '—',
                      ),
                      const SizedBox(height: 8),
                      _InfoRow(
                        label: 'Телефон',
                        value: user?.phone ?? '—',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: 'Смена email',
                    children: [
                      AuthTextField(
                        controller: _emailController,
                        label: 'Новый email',
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 12),
                      PrimaryAuthButton(
                        label: 'Сменить email',
                        isLoading: _isSaving,
                        onPressed: _changeEmail,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: 'Смена пароля',
                    children: [
                      AuthTextField(
                        controller: _newPasswordController,
                        label: 'Новый пароль',
                        obscureText: true,
                      ),
                      const SizedBox(height: 12),
                      AuthTextField(
                        controller: _confirmPasswordController,
                        label: 'Подтвердите пароль',
                        obscureText: true,
                      ),
                      const SizedBox(height: 12),
                      PrimaryAuthButton(
                        label: 'Сменить пароль',
                        isLoading: _isSaving,
                        onPressed: _changePassword,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  PrimaryAuthButton(
                    label: 'Выйти из аккаунта',
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
          width: 72,
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
