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

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _authRepo = AuthRepository();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _authRepo.login(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
    );

    if (!mounted) return;

    result.when(
      success: (_) {
        context.go(Routes.dashboard);
      },
      failure: (message, code) {
        setState(() {
          _isLoading = false;
          _errorMessage = _friendlyError(message);
        });
      },
    );
  }

  String _friendlyError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('invalid login credentials') ||
        lower.contains('invalid_credentials')) {
      return 'Invalid email or password. Please try again.';
    }
    if (lower.contains('email not confirmed')) {
      return 'Please verify your email address first.';
    }
    if (lower.contains('too many requests') || lower.contains('rate limit')) {
      return 'Too many attempts. Please wait a moment.';
    }
    return 'Something went wrong. Please try again.';
  }

  void _handleForgotPassword() {
    final resetEmailCtrl = TextEditingController(text: _emailCtrl.text);

    showDialog(
      context: context,
      builder: (ctx) {
        bool sending = false;
        String? message;
        bool success = false;

        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.bgSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.border),
              ),
              title: Row(
                children: [
                  Icon(
                    success ? Icons.check_circle_rounded : Icons.lock_reset_rounded,
                    color: success ? AppColors.success : AppColors.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    success ? 'Email sent' : 'Reset password',
                    style: AppTextStyles.h3,
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (success) ...[
                    Text(
                      'We sent a password reset link to ${resetEmailCtrl.text.trim()}.\n\nCheck your inbox and follow the link to set a new password.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ] else ...[
                    Text(
                      'Enter your email address and we\'ll send you a link to reset your password.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: resetEmailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      style: AppTextStyles.bodyMedium,
                      decoration: const InputDecoration(
                        hintText: 'your@email.com',
                        prefixIcon: Icon(Icons.email_outlined,
                            size: 20, color: AppColors.textTertiary),
                      ),
                    ),
                    if (message != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        message!,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.danger,
                        ),
                      ),
                    ],
                  ],
                ],
              ),
              actions: [
                if (success)
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(
                      'Done',
                      style: AppTextStyles.button.copyWith(color: AppColors.primary),
                    ),
                  )
                else ...[
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(
                      'Cancel',
                      style: AppTextStyles.button.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: sending
                        ? null
                        : () async {
                            final email = resetEmailCtrl.text.trim();
                            if (email.isEmpty || !email.contains('@')) {
                              setDialogState(() =>
                                  message = 'Please enter a valid email.');
                              return;
                            }

                            setDialogState(() {
                              sending = true;
                              message = null;
                            });

                            try {
                              await _authRepo.resetPassword(email: email);
                              setDialogState(() {
                                sending = false;
                                success = true;
                              });
                            } catch (e) {
                              setDialogState(() {
                                sending = false;
                                message =
                                    'Failed to send reset email. Please try again.';
                              });
                            }
                          },
                    child: sending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          )
                        : Text(
                            'Send reset link',
                            style: AppTextStyles.button.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
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

          // ── Right: Login Form (45%) ──────────────────
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
                            'Welcome back',
                            style: AppTextStyles.h2,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Sign in to continue to BINDE.GG',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),

                          const SizedBox(height: 40),

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
                            const SizedBox(height: 24),
                          ],

                          // ── Email Field ──────────────
                          AuthTextField(
                            label: 'EMAIL',
                            hint: 'your@email.com',
                            prefixIcon: Icons.email_outlined,
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            validator: Validators.email,
                          ),

                          const SizedBox(height: 24),

                          // ── Password Field ───────────
                          AuthTextField(
                            label: 'PASSWORD',
                            hint: 'Enter your password',
                            prefixIcon: Icons.lock_outline_rounded,
                            controller: _passwordCtrl,
                            isPassword: true,
                            textInputAction: TextInputAction.done,
                            validator: Validators.password,
                            onSubmit: _handleLogin,
                          ),

                          const SizedBox(height: 12),

                          // ── Forgot Password ──────────
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _handleForgotPassword,
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.textTertiary,
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Forgot password?',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 32),

                          // ── Sign In Button ───────────
                          AppButton(
                            label: 'SIGN IN',
                            onPressed: _handleLogin,
                            isLoading: _isLoading,
                            isExpanded: true,
                            icon: Icons.arrow_forward_rounded,
                          ),

                          const SizedBox(height: 32),

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

                          const SizedBox(height: 32),

                          // ── Register Link ────────────
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Don't have an account?",
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.textTertiary,
                                ),
                              ),
                              TextButton(
                                onPressed: () => context.go(Routes.register),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  padding: const EdgeInsets.only(left: 4),
                                ),
                                child: Text(
                                  'Create one',
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
