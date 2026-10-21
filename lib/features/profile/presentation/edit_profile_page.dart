import 'package:flutter/material.dart';

import 'package:dio/dio.dart';

import '../../../app/di.dart';
import '../../../core/utils/humanize_error.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../data/models/user_model.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key, this.initialUser});

  final UserModel? initialUser;

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isInitialLoading = true;
  bool _isLoading = false;
  String _initialPhone = '';

  @override
  void initState() {
    super.initState();
    _loadInitialProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialProfile() async {
    final initialUser = widget.initialUser;
    if (initialUser != null) {
      _nameController.text = initialUser.fullName;
      _phoneController.text = initialUser.phone;
      _initialPhone = initialUser.phone.trim();
      _emailController.text = initialUser.email ?? '';
      if (mounted) {
        setState(() => _isInitialLoading = false);
      }
      return;
    }

    try {
      final profile = await AppDi.profileRepository.getProfile();
      if (!mounted) return;

      _nameController.text = profile.fullName;
      _phoneController.text = profile.phone;
      _initialPhone = profile.phone.trim();
      _emailController.text = profile.email ?? '';
    } finally {
      if (mounted) {
        setState(() => _isInitialLoading = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final phoneTrim = _phoneController.text.trim();
    final phoneChanged = phoneTrim != _initialPhone;
    if (phoneChanged) {
      final pwd = _confirmPasswordController.text.trim();
      if (pwd.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Для смены номера телефона введите текущий пароль в поле ниже.',
            ),
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      await AppDi.profileRepository.updateProfile(
        fullName: _nameController.text.trim(),
        phone: phoneTrim,
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        confirmPassword: phoneChanged
            ? _confirmPasswordController.text.trim()
            : null,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Профиль обновлен')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      var msg = humanizeError(e, fallback: 'Не удалось обновить профиль.');
      if (e is DioException && e.response?.data is Map) {
        final err = (e.response!.data as Map)['error']?.toString();
        if (err != null && err.isNotEmpty) msg = err;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Редактировать профиль'),
      ),
      body: _isInitialLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    AppTextField(
                      controller: _nameController,
                      hintText: 'Имя',
                      validator: Validators.validateName,
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      controller: _phoneController,
                      hintText: 'Телефон',
                      keyboardType: TextInputType.phone,
                      validator: Validators.validatePhone,
                      onChanged: (_) => setState(() {}),
                    ),
                    if (_phoneController.text.trim() != _initialPhone) ...[
                      const SizedBox(height: 14),
                      AppTextField(
                        controller: _confirmPasswordController,
                        hintText: 'Текущий пароль (для смены номера)',
                        obscureText: true,
                        validator: (v) {
                          if (_phoneController.text.trim() == _initialPhone) {
                            return null;
                          }
                          return Validators.validatePassword(v);
                        },
                      ),
                    ],
                    const SizedBox(height: 14),
                    AppTextField(
                      controller: _emailController,
                      hintText: 'Email',
                      keyboardType: TextInputType.emailAddress,
                      validator: Validators.validateEmail,
                    ),
                    const SizedBox(height: 20),
                    PrimaryButton(
                      text: 'Сохранить',
                      isLoading: _isLoading,
                      onPressed: _saveProfile,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}