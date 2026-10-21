import 'package:flutter/material.dart';

import '../../../app/di.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/primary_button.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();

  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _loading = false;

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      await AppDi.profileRepository.changePassword(
        currentPassword: _currentPasswordController.text.trim(),
        newPassword: _newPasswordController.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пароль успешно изменен')),
      );
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось изменить пароль')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Смена пароля'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              AppTextField(
                controller: _currentPasswordController,
                hintText: 'Текущий пароль',
                obscureText: true,
                validator: Validators.validatePassword,
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _newPasswordController,
                hintText: 'Новый пароль',
                obscureText: true,
                validator: Validators.validatePasswordWithStrength,
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _confirmPasswordController,
                hintText: 'Подтверждение нового пароля',
                obscureText: true,
                validator: (value) {
                  final validation = Validators.validatePasswordWithStrength(value);
                  if (validation != null) return validation;
                  if (value != _newPasswordController.text) {
                    return 'Пароли не совпадают';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                text: 'Сохранить',
                isLoading: _loading,
                onPressed: _changePassword,
              ),
            ],
          ),
        ),
      ),
    );
  }
}