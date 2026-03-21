import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
import '../../../services/realtime/realtime_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _profileRepo = ProfileRepository();
  final _authRepo = AuthRepository();
  final _realtime = RealtimeService();

  ProfileModel? _profile;
  bool _isLoading = true;
  bool _isSteamLinking = false;
  bool _isRefreshingSteam = false;

  String get _userId => SupabaseConfig.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _subscribeProfileChanges();
  }

  @override
  void dispose() {
    _realtime.unsubscribe('settings:profile');
    super.dispose();
  }

  /// Listen for profile updates (Steam link completion via Realtime)
  void _subscribeProfileChanges() {
    SupabaseConfig.client
        .channel('settings:profile')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'profiles',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: _userId,
          ),
          callback: (payload) {
            if (!mounted) return;
            final newData = payload.newRecord;
            // If steam_id just appeared, refresh the profile
            if (newData['steam_id'] != null && _profile?.steamId == null) {
              _loadProfile();
              if (mounted) {
                setState(() => _isSteamLinking = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Steam account linked successfully!'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            }
          },
        )
        .subscribe();
  }

  /// Generate a unique link token for Steam OpenID flow
  String _generateLinkToken() {
    final rng = Random.secure();
    final bytes = List.generate(32, (_) => rng.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Initiate Steam linking: save token → open browser
  Future<void> _linkSteam() async {
    setState(() => _isSteamLinking = true);

    try {
      // Generate and save link token
      final token = _generateLinkToken();

      await SupabaseConfig.client
          .from('profiles')
          .update({'steam_link_token': token})
          .eq('id', _userId);

      // Open browser to Edge Function
      final steamAuthUrl = Uri.parse(
        '${SupabaseConfig.client.rest.url.replaceAll('/rest/v1', '')}/functions/v1/steam-auth?token=$token',
      );

      if (await canLaunchUrl(steamAuthUrl)) {
        await launchUrl(steamAuthUrl, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Could not open browser');
      }

      // Show waiting message (Realtime will detect completion)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Complete the Steam login in your browser. This page will update automatically.'),
            backgroundColor: AppColors.info,
            duration: Duration(seconds: 8),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSteamLinking = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start Steam linking: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  /// Refresh Steam username/avatar from Steam Web API
  Future<void> _refreshSteamProfile() async {
    setState(() => _isRefreshingSteam = true);

    try {
      final session = SupabaseConfig.auth.currentSession;
      if (session == null) throw Exception('Not authenticated');

      final response = await SupabaseConfig.client.functions.invoke(
        'steam-auth',
        queryParameters: {'action': 'refresh'},
        method: HttpMethod.post,
        headers: {'Authorization': 'Bearer ${session.accessToken}'},
      );

      if (!mounted) return;

      if (response.status == 200) {
        await _loadProfile();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Steam profile updated!'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else {
        final errorMsg = response.data?['error'] ?? 'Failed to refresh';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMsg.toString()),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Refresh failed: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRefreshingSteam = false);
    }
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
                  Row(
                    children: [
                      SizedBox(
                        width: 140,
                        child: Text('Steam Username',
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary)),
                      ),
                      Expanded(
                        child: Text(p.steamUsername ?? 'Unknown',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w500,
                            )),
                      ),
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: IconButton(
                          onPressed: _isRefreshingSteam ? null : _refreshSteamProfile,
                          padding: EdgeInsets.zero,
                          icon: _isRefreshingSteam
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.textTertiary,
                                  ),
                                )
                              : const Icon(Icons.refresh_rounded, size: 18),
                          color: AppColors.textTertiary,
                          tooltip: 'Refresh from Steam',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _InfoRow(label: 'Status', value: 'LINKED', valueColor: AppColors.success),
                  if (p.vacBanned) ...[
                    const SizedBox(height: 6),
                    _InfoRow(
                      label: 'VAC Status',
                      value: 'VAC BAN (${p.vacBanCount})',
                      valueColor: AppColors.danger,
                    ),
                  ] else ...[
                    const SizedBox(height: 6),
                    _InfoRow(label: 'VAC Status', value: 'CLEAN', valueColor: AppColors.success),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'Changed your Steam name? Hit the refresh icon to update it here.',
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
                          onPressed: _isSteamLinking ? null : _linkSteam,
                          child: _isSteamLinking
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Link Steam'),
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
