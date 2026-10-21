import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../app/di.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/services/in_app_notification_sync_service.dart';
import '../../../core/utils/validators.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();

  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  final _codeController = TextEditingController();

  bool _loading = false;
  bool _codeMode = false;
  bool _requestingCode = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    _restoreRememberMeState();
  }

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _restoreRememberMeState() async {
    final rememberMe = await AppDi.sessionService.getRememberMe();
    final rememberedLogin = await AppDi.sessionService.getRememberedLogin();
    if (!mounted) return;
    setState(() {
      _rememberMe = rememberMe;
      _loginController.text = rememberMe ? (rememberedLogin ?? '') : '';
    });
  }

  Future<void> _sendLoginCode() async {
    final emailErr = Validators.validateRequiredEmail(_loginController.text);
    if (emailErr != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(emailErr)));
      return;
    }
    setState(() => _requestingCode = true);
    try {
      await AppDi.authRepository.requestLoginCode(
        email: _loginController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Код отправлен на email.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _requestingCode = false);
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      if (_codeMode) {
        await AppDi.authRepository.loginWithCode(
          email: _loginController.text.trim(),
          code: _codeController.text.trim(),
          rememberMe: _rememberMe,
        );
      } else {
        await AppDi.authRepository.login(
          login: _loginController.text.trim(),
          password: _passwordController.text.trim(),
          rememberMe: _rememberMe,
        );
      }

      if (!mounted) return;
      InAppNotificationSyncService.instance.recordSessionStart();
      if (!mounted) return;
      context.go('/shell');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: AppColors.primaryDark,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.primaryDark,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primaryDark,
                AppColors.primary,
                AppColors.primaryDark,
              ],
              stops: [0.0, 0.42, 1.0],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -120,
                right: -60,
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.07),
                  ),
                ),
              ),
              Positioned(
                top: 90,
                left: -40,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
              ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 24,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: AppColors.borderLight),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.14),
                            blurRadius: 28,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: const Icon(
                                Icons.restaurant_menu_rounded,
                                color: AppColors.primary,
                                size: 32,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'Вход',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontSize: 28,
                                    color: AppColors.textPrimary,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Войдите, чтобы оформить заказ,\nотслеживать статусы и копить бонусы',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: SegmentedButton<bool>(
                                emptySelectionAllowed: false,
                                multiSelectionEnabled: false,
                                segments: const [
                                  ButtonSegment<bool>(
                                    value: false,
                                    label: Text('Пароль'),
                                  ),
                                  ButtonSegment<bool>(
                                    value: true,
                                    label: Text('Код из email'),
                                  ),
                                ],
                                selected: {_codeMode},
                                onSelectionChanged: (Set<bool> next) {
                                  setState(() {
                                    _codeMode = next.first;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (_codeMode) ...[
                              _AuthInput(
                                controller: _loginController,
                                hintText: 'Email',
                                icon: Icons.email_outlined,
                                validator: Validators.validateRequiredEmail,
                                maxLength: 100,
                              ),
                              const SizedBox(height: 14),
                              _AuthInput(
                                controller: _codeController,
                                hintText: 'Код из письма',
                                icon: Icons.password_rounded,
                                validator: Validators.validateRecoveryCode,
                                maxLength: 64,
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: OutlinedButton(
                                  onPressed:
                                      _requestingCode ? null : _sendLoginCode,
                                  child: _requestingCode
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text('Выслать код на email'),
                                ),
                              ),
                            ] else ...[
                              _AuthInput(
                                controller: _loginController,
                                hintText: 'Телефон или email',
                                icon: Icons.person_outline_rounded,
                                validator: Validators.validateLogin,
                                maxLength: 100,
                              ),
                              const SizedBox(height: 14),
                              _AuthInput(
                                controller: _passwordController,
                                hintText: 'Пароль',
                                icon: Icons.lock_outline_rounded,
                                obscureText: _obscurePassword,
                                validator: Validators.validatePassword,
                                maxLength: 50,
                                suffix: IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_rounded
                                        : Icons.visibility_rounded,
                                    color: AppColors.textHint,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 10),
                            if (!_codeMode)
                              Row(
                                children: [
                                  Transform.scale(
                                    scale: 0.95,
                                    alignment: Alignment.centerLeft,
                                    child: Checkbox(
                                      value: _rememberMe,
                                      onChanged: (value) {
                                        setState(() {
                                          _rememberMe = value ?? false;
                                        });
                                      },
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      'Запомнить меня',
                                      maxLines: 2,
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 8,
                                      ),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    onPressed: () {
                                      context.push('/forgot-password');
                                    },
                                    child: const Text(
                                      'Забыли пароль?',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              )
                            else
                              Row(
                                children: [
                                  Transform.scale(
                                    scale: 0.95,
                                    alignment: Alignment.centerLeft,
                                    child: Checkbox(
                                      value: _rememberMe,
                                      onChanged: (value) {
                                        setState(() {
                                          _rememberMe = value ?? false;
                                        });
                                      },
                                    ),
                                  ),
                                  const Expanded(
                                    child: Text(
                                      'Запомнить меня',
                                      maxLines: 2,
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _loading ? null : _login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  elevation: 0,
                                ),
                                child: _loading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Войти',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'Нет аккаунта? ',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    context.push('/register');
                                  },
                                  child: const Text(
                                    'Зарегистрироваться',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                  ),
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

class _AuthInput extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final bool obscureText;
  final String? Function(String?)? validator;
  final Widget? suffix;
  final int? maxLength;

  const _AuthInput({
    required this.controller,
    required this.hintText,
    required this.icon,
    this.obscureText = false,
    this.validator,
    this.suffix,
    this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator,
      maxLength: maxLength,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: Icon(icon, color: AppColors.textHint),
        suffixIcon: suffix,
        filled: true,
        fillColor: AppColors.inputFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: AppColors.primary,
            width: 1.3,
          ),
        ),
        errorMaxLines: 3,
        counterText: '',
      ),
    );
  }
}
