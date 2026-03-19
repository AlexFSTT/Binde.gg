import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../config/supabase_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/game_constants.dart';
import '../../../core/constants/route_paths.dart';
import '../../../core/errors/result.dart';
import '../../../data/models/profile_model.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../shared/widgets/glass_card.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _profileRepo = ProfileRepository();
  final _authRepo = AuthRepository();

  ProfileModel? _profile;
  bool _isLoading = true;

  String get _userId => SupabaseConfig.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    final result = await _profileRepo.getProfile(_userId);
    if (!mounted) return;

    result.when(
      success: (p) => setState(() {
        _profile = p;
        _isLoading = false;
      }),
      failure: (_, __) => setState(() => _isLoading = false),
    );
  }

  Future<void> _updatePreference(String key, dynamic value) async {
    await _profileRepo.updateProfile(_userId, {key: value});
    _loadProfile();
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        title: Text('Log out?', style: AppTextStyles.h3),
        content: Text(
          'Are you sure you want to log out of your account?',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: AppTextStyles.button.copyWith(color: AppColors.textTertiary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Log out', style: AppTextStyles.button.copyWith(color: AppColors.danger)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await _authRepo.logout();
      if (mounted) context.go(Routes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _profile == null) {
      return const Scaffold(
        backgroundColor: AppColors.bgBase,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final p = _profile!;

    return GlassPage(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Settings', style: AppTextStyles.h2),
            const SizedBox(height: 4),
            Text('Manage your account and preferences',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textTertiary)),

            const SizedBox(height: 32),

            // ── Account ────────────────────────────
            _SectionCard(
              title: 'Account',
              icon: Icons.person_rounded,
              children: [
                _InfoRow(label: 'Username', value: p.username),
                _InfoRow(label: 'Email', value: p.email ?? 'Not set'),
                _InfoRow(label: 'Role', value: p.role.toUpperCase()),
                _InfoRow(
                  label: 'KYC Status',
                  value: p.kycStatus.toUpperCase(),
                  valueColor: p.isKycVerified ? AppColors.success : AppColors.warning,
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Steam Integration ──────────────────
            _SectionCard(
              title: 'Steam Integration',
              icon: Icons.gamepad_rounded,
              children: [
                if (p.hasSteam) ...[
                  _InfoRow(label: 'Steam ID', value: p.steamId!),
                  _InfoRow(label: 'Steam Username', value: p.steamUsername ?? 'Unknown'),
                  _InfoRow(label: 'Status', value: 'LINKED', valueColor: AppColors.success),
                  const SizedBox(height: 8),
                  Text(
                    'Steam account cannot be unlinked once connected.',
                    style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
                  ),
                ] else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.gamepad_rounded, color: AppColors.primary, size: 28),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Link your Steam account',
                                  style: AppTextStyles.label.copyWith(fontSize: 14)),
                              const SizedBox(height: 4),
                              Text(
                                'Required to play matches. Your Steam account will be permanently linked.',
                                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: () {
                            // TODO: Implement Steam OpenID flow
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Steam linking will be available soon'),
                                backgroundColor: AppColors.warning,
                              ),
                            );
                          },
                          child: const Text('Link Steam'),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 20),

            // ── Game Preferences ───────────────────
            _SectionCard(
              title: 'Game Preferences',
              icon: Icons.tune_rounded,
              children: [
                // Region
                _DropdownRow(
                  label: 'Preferred Region',
                  value: p.preferredRegion,
                  items: Region.values.map((r) => (r.code, r.label)).toList(),
                  onChanged: (v) => _updatePreference('preferred_region', v),
                ),
                const SizedBox(height: 12),
                // Mode
                _DropdownRow(
                  label: 'Preferred Mode',
                  value: p.preferredMode,
                  items: MatchMode.values.map((m) => (m.label, m.label)).toList(),
                  onChanged: (v) => _updatePreference('preferred_mode', v),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Danger Zone ────────────────────────
            _SectionCard(
              title: 'Session',
              icon: Icons.logout_rounded,
              borderColor: AppColors.danger.withValues(alpha: 0.2),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Log out', style: AppTextStyles.label.copyWith(fontSize: 14)),
                          const SizedBox(height: 2),
                          Text('End your current session',
                              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary)),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _logout,
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                      child: const Text('Log out'),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  final Color? borderColor;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor ?? AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Row(
              children: [
                Icon(icon, size: 18, color: AppColors.textTertiary),
                const SizedBox(width: 8),
                Text(title, style: AppTextStyles.label.copyWith(fontSize: 14)),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderSubtle),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary)),
          ),
          Expanded(
            child: Text(value,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: valueColor ?? AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                )),
          ),
        ],
      ),
    );
  }
}

class _DropdownRow extends StatelessWidget {
  final String label;
  final String value;
  final List<(String code, String label)> items;
  final ValueChanged<String> onChanged;

  const _DropdownRow({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 140,
          child: Text(label,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary)),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.bgSurfaceActive,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                dropdownColor: AppColors.bgElevated,
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
                icon: const Icon(Icons.expand_more_rounded, size: 18, color: AppColors.textTertiary),
                items: items
                    .map((i) => DropdownMenuItem(
                          value: i.$1,
                          child: Text(i.$2),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) onChanged(v);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
