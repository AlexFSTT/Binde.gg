import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/route_paths.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../data/repositories/auth_repository.dart';
import 'widgets/auth_text_field.dart';
import '../../../core/errors/result.dart';
import 'widgets/auth_branding_panel.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  final _authRepo = AuthRepository();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordCtrl.text != _confirmPasswordCtrl.text) {
      setState(() => _errorMessage = 'Passwords do not match.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _authRepo.register(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
      username: _usernameCtrl.text.trim(),
    );

    if (!mounted) return;

    result.when(
      success: (emailPending) {
        if (emailPending) {
          // Show confirmation message instead of navigating
          setState(() => _isLoading = false);
          _showEmailConfirmation();
        } else {
          context.go(Routes.dashboard);
        }
      },
      failure: (message, code) {
        setState(() {
          _isLoading = false;
          _errorMessage = _friendlyError(message);
        });
      },
    );
  }

  void _showEmailConfirmation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        title: Row(
          children: [
            Icon(Icons.mark_email_read_rounded,
                color: AppColors.success, size: 28),
            const SizedBox(width: 12),
            Text('Check your email', style: AppTextStyles.h3),
          ],
        ),
        content: Text(
          'We sent a confirmation link to ${_emailCtrl.text.trim()}.\n\nPlease verify your email, then come back and sign in.',
          style:
              AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.go(Routes.login);
            },
            child: Text(
              'Go to Sign In',
              style: AppTextStyles.button.copyWith(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  String _friendlyError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('user already registered') ||
        lower.contains('already been registered')) {
      return 'An account with this email already exists.';
    }
    if (lower.contains('unique') && lower.contains('username')) {
      return 'This username is already taken. Try another one.';
    }
    if (lower.contains('password') && lower.contains('weak')) {
      return 'Password is too weak. Use at least 8 characters.';
    }
    if (lower.contains('rate limit') || lower.contains('too many')) {
      return 'Too many attempts. Please wait a moment.';
    }
    if (lower.contains('valid email')) {
      return 'Please enter a valid email address.';
    }
    return 'Registration failed. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: Row(
        children: [
          // ── Left: Branding Panel (55%) ───────────────
          const Expanded(
            flex: 55,
            child: AuthBrandingPanel(),
          ),

          // ── Right: Register Form (45%) ───────────────
          Expanded(
            flex: 45,
            child: Container(
              color: AppColors.bgSurface,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 56),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Header ───────────────────
                          Text(
                            'Create account',
                            style: AppTextStyles.h2,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Join the arena and start competing',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),

                          const SizedBox(height: 36),

                          // ── Error Banner ─────────────
                          if (_errorMessage != null) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.dangerMuted,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color:
                                      AppColors.danger.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline_rounded,
                                    color: AppColors.danger,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: AppTextStyles.bodySmall.copyWith(
                                        color: AppColors.danger,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // ── Username Field ───────────
                          AuthTextField(
                            label: 'USERNAME',
                            hint: 'Choose a username',
                            prefixIcon: Icons.person_outline_rounded,
                            controller: _usernameCtrl,
                            validator: Validators.username,
                          ),

                          const SizedBox(height: 20),

                          // ── Email Field ──────────────
                          AuthTextField(
                            label: 'EMAIL',
                            hint: 'your@email.com',
                            prefixIcon: Icons.email_outlined,
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            validator: Validators.email,
                          ),

                          const SizedBox(height: 20),

                          // ── Password Field ───────────
                          AuthTextField(
                            label: 'PASSWORD',
                            hint: 'Min. 8 characters',
                            prefixIcon: Icons.lock_outline_rounded,
                            controller: _passwordCtrl,
                            isPassword: true,
                            validator: Validators.password,
                          ),

                          const SizedBox(height: 20),

                          // ── Confirm Password Field ───
                          AuthTextField(
                            label: 'CONFIRM PASSWORD',
                            hint: 'Repeat your password',
                            prefixIcon: Icons.lock_outline_rounded,
                            controller: _confirmPasswordCtrl,
                            isPassword: true,
                            textInputAction: TextInputAction.done,
                            onSubmit: _handleRegister,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please confirm your password';
                              }
                              if (value != _passwordCtrl.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 12),

                          // ── Terms notice ─────────────
                          Text(
                            'By creating an account, you agree to our Terms of Service and Privacy Policy.',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),

                          const SizedBox(height: 28),

                          // ── Create Account Button ────
                          AppButton(
                            label: 'CREATE ACCOUNT',
                            onPressed: _handleRegister,
                            isLoading: _isLoading,
                            isExpanded: true,
                            icon: Icons.arrow_forward_rounded,
                          ),

                          const SizedBox(height: 28),

                          // ── Divider ──────────────────
                          Row(
                            children: [
                              const Expanded(
                                child: Divider(color: AppColors.border),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Text(
                                  'or',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                              ),
                              const Expanded(
                                child: Divider(color: AppColors.border),
                              ),
                            ],
                          ),

                          const SizedBox(height: 28),

                          // ── Login Link ───────────────
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Already have an account?',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.textTertiary,
                                ),
                              ),
                              TextButton(
                                onPressed: () => context.go(Routes.login),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  padding: const EdgeInsets.only(left: 4),
                                ),
                                child: Text(
                                  'Sign in',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
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
    );
  }
}
