import 'dart:math';
import 'package:binde_gg/core/errors/result.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../config/supabase_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/route_paths.dart';
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
  int _selectedTab = 0;
  bool _isSteamLinking = false;
  bool _isRefreshingSteam = false;

  String get _userId => SupabaseConfig.auth.currentUser!.id;

  static const _tabs = [
    (icon: Icons.person_rounded, label: 'Account'),
    (icon: Icons.verified_user_rounded, label: 'Verification'),
    (icon: Icons.notifications_rounded, label: 'Notifications'),
    (icon: Icons.gamepad_rounded, label: 'Game Settings'),
    (icon: Icons.extension_rounded, label: 'Integrations'),
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _subscribeProfileChanges();
  }

  @override
  void dispose() {
    SupabaseConfig.client.channel('settings:profile').unsubscribe();
    super.dispose();
  }

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
            if (newData['steam_id'] != null && _profile?.steamId == null) {
              _loadProfile();
              setState(() => _isSteamLinking = false);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Steam account linked successfully!'),
                  backgroundColor: AppColors.success,
                ),
              );
            }
          },
        )
        .subscribe();
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

  Future<void> _updateField(String key, dynamic value) async {
    await _profileRepo.updateProfile(_userId, {key: value});
    _loadProfile();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _profile == null) {
      return const Scaffold(
        backgroundColor: AppColors.bgBase,
        body:
            Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return GlassPage(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Left Sidebar ───────────────────────────
          SizedBox(
            width: 240,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Settings', style: AppTextStyles.h2),
                  const SizedBox(height: 4),
                  Text('Manage your account',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textTertiary)),
                  const SizedBox(height: 28),

                  // Profile mini card
                  _buildProfileCard(),
                  const SizedBox(height: 20),

                  // Tab items
                  ...List.generate(_tabs.length, (i) => _buildTabItem(i)),

                  const Spacer(),

                  // Logout
                  _buildTabItem(-1,
                      icon: Icons.logout_rounded,
                      label: 'Log out',
                      color: AppColors.danger,
                      onTap: _logout),
                ],
              ),
            ),
          ),

          // Divider
          Container(width: 1, color: AppColors.border.withValues(alpha: 0.3)),

          // ── Right Content ──────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: _buildTabContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    final p = _profile!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: AppColors.primary.withValues(alpha: 0.12),
              image: p.steamAvatarUrl != null
                  ? DecorationImage(
                      image: NetworkImage(p.steamAvatarUrl!), fit: BoxFit.cover)
                  : null,
            ),
            child: p.steamAvatarUrl == null
                ? Center(
                    child: Text(p.username[0].toUpperCase(),
                        style: AppTextStyles.label
                            .copyWith(color: AppColors.primary)))
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.username,
                    style: AppTextStyles.label.copyWith(fontSize: 13),
                    overflow: TextOverflow.ellipsis),
                Text('Edit profile',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textTertiary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index,
      {IconData? icon, String? label, Color? color, VoidCallback? onTap}) {
    final isSelected = index == _selectedTab;
    final tabIcon = icon ?? _tabs[index].icon;
    final tabLabel = label ?? _tabs[index].label;
    final tabColor =
        color ?? (isSelected ? AppColors.primary : AppColors.textSecondary);

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap ?? () => setState(() => _selectedTab = index),
          borderRadius: BorderRadius.circular(8),
          hoverColor: AppColors.bgSurfaceHover,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color:
                  isSelected ? AppColors.primary.withValues(alpha: 0.08) : null,
              border: isSelected
                  ? Border.all(color: AppColors.primary.withValues(alpha: 0.2))
                  : null,
            ),
            child: Row(
              children: [
                Icon(tabIcon, size: 18, color: tabColor),
                const SizedBox(width: 10),
                Text(tabLabel,
                    style: AppTextStyles.bodySmall.copyWith(
                        color: tabColor,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 0:
        return _AccountTab(
            profile: _profile!, onUpdate: _updateField, onReload: _loadProfile);
      case 1:
        return _VerificationTab(profile: _profile!);
      case 2:
        return _NotificationsTab();
      case 3:
        return _GameSettingsTab(
            profile: _profile!,
            isSteamLinking: _isSteamLinking,
            isRefreshingSteam: _isRefreshingSteam,
            onLinkSteam: _linkSteam,
            onRefreshSteam: _refreshSteamProfile,
            onUpdate: _updateField);
      case 4:
        return _IntegrationsTab(profile: _profile!, onUpdate: _updateField);
      default:
        return const SizedBox.shrink();
    }
  }

  // ── Steam methods ──────────────────────────────────

  String _generateLinkToken() {
    final rng = Random.secure();
    return List.generate(32, (_) => rng.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  Future<void> _linkSteam() async {
    setState(() => _isSteamLinking = true);
    try {
      final token = _generateLinkToken();
      await SupabaseConfig.client.rpc('fn_set_steam_link_token', params: {
        'p_token': token,
      });
      final steamAuthUrl = Uri.parse(
          '${SupabaseConfig.client.rest.url.replaceAll('/rest/v1', '')}/functions/v1/steam-auth?token=$token');
      if (await canLaunchUrl(steamAuthUrl)) {
        await launchUrl(steamAuthUrl, mode: LaunchMode.externalApplication);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Complete Steam login in your browser.'),
            backgroundColor: AppColors.info,
            duration: Duration(seconds: 8)));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSteamLinking = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed: $e'), backgroundColor: AppColors.danger));
      }
    }
  }

  Future<void> _refreshSteamProfile() async {
    setState(() => _isRefreshingSteam = true);
    try {
      final session = SupabaseConfig.auth.currentSession;
      if (session == null) throw Exception('Not authenticated');
      await SupabaseConfig.client.functions.invoke('steam-auth',
          queryParameters: {'action': 'refresh'},
          method: HttpMethod.post,
          headers: {'Authorization': 'Bearer ${session.accessToken}'});
      await _loadProfile();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Steam profile updated!'),
            backgroundColor: AppColors.success));
      }
    } catch (_) {}
    if (mounted) setState(() => _isRefreshingSteam = false);
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgSurface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.border)),
        title: Text('Log out?', style: AppTextStyles.h3),
        content: Text('Are you sure?',
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Cancel',
                  style: AppTextStyles.button
                      .copyWith(color: AppColors.textTertiary))),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text('Log out',
                  style:
                      AppTextStyles.button.copyWith(color: AppColors.danger))),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await _authRepo.logout();
      if (mounted) context.go(Routes.login);
    }
  }
}

// ═══════════════════════════════════════════════════════════
// ACCOUNT TAB
// ═══════════════════════════════════════════════════════════

class _AccountTab extends StatelessWidget {
  final ProfileModel profile;
  final Future<void> Function(String, dynamic) onUpdate;
  final VoidCallback onReload;
  const _AccountTab(
      {required this.profile, required this.onUpdate, required this.onReload});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
            title: 'Account Information', icon: Icons.person_rounded),
        const SizedBox(height: 20),
        _EditableRow(
            label: 'Username',
            value: profile.username,
            field: 'username',
            onUpdate: onUpdate),
        _EditableRow(
            label: 'First Name',
            value: profile.firstName ?? 'Not set',
            field: 'first_name',
            onUpdate: onUpdate),
        _EditableRow(
            label: 'Last Name',
            value: profile.lastName ?? 'Not set',
            field: 'last_name',
            onUpdate: onUpdate),
        _EditableRow(
            label: 'Email',
            value: profile.email ?? 'Not set',
            field: null,
            onUpdate: onUpdate),
        _DateRow(
            label: 'Birth Date',
            value: profile.birthDate,
            onUpdate: (d) {
              onUpdate('birth_date',
                  '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}');
            }),
        _DropdownRow(
          label: 'Country',
          value: profile.country ?? 'Not set',
          items: _countries,
          onChanged: (v) => onUpdate('country', v),
        ),
        const SizedBox(height: 28),
        _SectionHeader(title: 'Bio', icon: Icons.edit_note_rounded),
        const SizedBox(height: 12),
        _BioEditor(bio: profile.bio ?? '', onSave: (v) => onUpdate('bio', v)),
        const SizedBox(height: 28),
        _SectionHeader(title: 'Language', icon: Icons.language_rounded),
        const SizedBox(height: 12),
        _DropdownRow(
          label: 'Language',
          value: profile.language,
          items: const [
            ('en', 'English'),
            ('de', 'German'),
            ('ro', 'Romanian'),
            ('es', 'Spanish'),
            ('fr', 'French'),
            ('pt', 'Portuguese')
          ],
          onChanged: (v) => onUpdate('language', v),
        ),
        const SizedBox(height: 28),
        _SectionHeader(title: 'Session', icon: Icons.logout_rounded),
        const SizedBox(height: 12),
        _InfoRow(label: 'Role', value: profile.role.toUpperCase()),
        _InfoRow(
            label: 'Member since',
            value:
                '${profile.createdAt.day}/${profile.createdAt.month}/${profile.createdAt.year}'),
      ],
    );
  }

  static const _countries = [
    ('Not set', 'Not set'),
    ('DE', '🇩🇪 Germany'),
    ('RO', '🇷🇴 Romania'),
    ('US', '🇺🇸 United States'),
    ('GB', '🇬🇧 United Kingdom'),
    ('FR', '🇫🇷 France'),
    ('ES', '🇪🇸 Spain'),
    ('IT', '🇮🇹 Italy'),
    ('PT', '🇵🇹 Portugal'),
    ('NL', '🇳🇱 Netherlands'),
    ('BE', '🇧🇪 Belgium'),
    ('AT', '🇦🇹 Austria'),
    ('CH', '🇨🇭 Switzerland'),
    ('PL', '🇵🇱 Poland'),
    ('CZ', '🇨🇿 Czechia'),
    ('SE', '🇸🇪 Sweden'),
    ('NO', '🇳🇴 Norway'),
    ('DK', '🇩🇰 Denmark'),
    ('FI', '🇫🇮 Finland'),
    ('BR', '🇧🇷 Brazil'),
    ('TR', '🇹🇷 Turkey'),
    ('RU', '🇷🇺 Russia'),
    ('UA', '🇺🇦 Ukraine'),
    ('BG', '🇧🇬 Bulgaria'),
    ('HR', '🇭🇷 Croatia'),
    ('RS', '🇷🇸 Serbia'),
    ('GR', '🇬🇷 Greece'),
    ('HU', '🇭🇺 Hungary'),
    ('SK', '🇸🇰 Slovakia'),
    ('LT', '🇱🇹 Lithuania'),
  ];
}

// ═══════════════════════════════════════════════════════════
// VERIFICATION TAB
// ═══════════════════════════════════════════════════════════

class _VerificationTab extends StatelessWidget {
  final ProfileModel profile;
  const _VerificationTab({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
            title: 'Identity Verification', icon: Icons.verified_user_rounded),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: profile.isKycVerified
                ? AppColors.successMuted
                : AppColors.warningMuted,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: profile.isKycVerified
                    ? AppColors.success.withValues(alpha: 0.3)
                    : AppColors.warning.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(
                profile.isKycVerified
                    ? Icons.check_circle_rounded
                    : Icons.pending_rounded,
                color: profile.isKycVerified
                    ? AppColors.success
                    : AppColors.warning,
                size: 32,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.isKycVerified ? 'Verified' : 'Not Verified',
                      style: AppTextStyles.h3.copyWith(
                          color: profile.isKycVerified
                              ? AppColors.success
                              : AppColors.warning),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profile.isKycVerified
                          ? 'Your identity has been verified. You can participate in wagered matches.'
                          : 'Identity verification is required for real-money matches. Complete KYC to unlock wagering.',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textTertiary),
                    ),
                  ],
                ),
              ),
              if (!profile.isKycVerified)
                ElevatedButton(
                  onPressed: () {}, // TODO: KYC flow
                  child: const Text('Start Verification'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _InfoRow(
            label: 'KYC Status',
            value: profile.kycStatus.toUpperCase(),
            valueColor:
                profile.isKycVerified ? AppColors.success : AppColors.warning),
        _InfoRow(
            label: 'Account Status',
            value: profile.isBanned ? 'BANNED' : 'ACTIVE',
            valueColor:
                profile.isBanned ? AppColors.danger : AppColors.success),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// NOTIFICATIONS TAB
// ═══════════════════════════════════════════════════════════

class _NotificationsTab extends StatelessWidget {
  const _NotificationsTab();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
            title: 'Notifications', icon: Icons.notifications_rounded),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Icon(Icons.notifications_off_rounded,
                  size: 40, color: AppColors.textTertiary),
              const SizedBox(height: 12),
              Text('Coming Soon',
                  style: AppTextStyles.h3
                      .copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              Text(
                  'Notification preferences will be available in a future update.',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textTertiary),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// GAME SETTINGS TAB
// ═══════════════════════════════════════════════════════════

class _GameSettingsTab extends StatelessWidget {
  final ProfileModel profile;
  final bool isSteamLinking;
  final bool isRefreshingSteam;
  final VoidCallback onLinkSteam;
  final VoidCallback onRefreshSteam;
  final Future<void> Function(String, dynamic) onUpdate;

  const _GameSettingsTab(
      {required this.profile,
      required this.isSteamLinking,
      required this.isRefreshingSteam,
      required this.onLinkSteam,
      required this.onRefreshSteam,
      required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: 'Steam Integration', icon: Icons.gamepad_rounded),
        const SizedBox(height: 20),
        if (profile.hasSteam) ...[
          _InfoRow(label: 'Steam ID', value: profile.steamId!),
          Row(
            children: [
              SizedBox(
                  width: 160,
                  child: Text('Steam Username',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textTertiary))),
              Expanded(
                  child: Text(profile.steamUsername ?? 'Unknown',
                      style: AppTextStyles.bodyMedium
                          .copyWith(fontWeight: FontWeight.w500))),
              SizedBox(
                width: 32,
                height: 32,
                child: IconButton(
                  onPressed: isRefreshingSteam ? null : onRefreshSteam,
                  padding: EdgeInsets.zero,
                  icon: isRefreshingSteam
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.textTertiary))
                      : const Icon(Icons.refresh_rounded, size: 18),
                  color: AppColors.textTertiary,
                  tooltip: 'Refresh from Steam',
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _InfoRow(
              label: 'Status', value: 'LINKED', valueColor: AppColors.success),
          if (profile.vacBanned)
            _InfoRow(
                label: 'VAC Status',
                value: 'VAC BAN (${profile.vacBanCount})',
                valueColor: AppColors.danger)
          else
            _InfoRow(
                label: 'VAC Status',
                value: 'CLEAN',
                valueColor: AppColors.success),
          const SizedBox(height: 8),
          Text('Changed your Steam name? Hit the refresh icon above.',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textTertiary)),
        ] else ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
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
                    Text('Required to play matches. Permanent once linked.',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textTertiary)),
                  ],
                )),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: isSteamLinking ? null : onLinkSteam,
                  child: isSteamLinking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Link Steam'),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 28),
        _SectionHeader(title: 'Game Preferences', icon: Icons.tune_rounded),
        const SizedBox(height: 12),
        _DropdownRow(
            label: 'Region',
            value: profile.preferredRegion,
            items: const [
              ('EU', 'Europe'),
              ('NA', 'North America'),
              ('SA', 'South America'),
              ('AS', 'Asia'),
              ('OC', 'Oceania')
            ],
            onChanged: (v) => onUpdate('preferred_region', v)),
        const SizedBox(height: 8),
        _DropdownRow(
            label: 'Mode',
            value: profile.preferredMode,
            items: const [('1v1', '1v1'), ('2v2', '2v2'), ('5v5', '5v5')],
            onChanged: (v) => onUpdate('preferred_mode', v)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// INTEGRATIONS TAB
// ═══════════════════════════════════════════════════════════

class _IntegrationsTab extends StatelessWidget {
  final ProfileModel profile;
  final Future<void> Function(String, dynamic) onUpdate;
  const _IntegrationsTab({required this.profile, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
            title: 'Social Integrations', icon: Icons.extension_rounded),
        const SizedBox(height: 8),
        Text('Share more about yourself and where to find you.',
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textTertiary)),
        const SizedBox(height: 24),
        _IntegrationRow(
            icon: Icons.live_tv_rounded,
            color: const Color(0xFF9146FF),
            label: 'Twitch',
            value: profile.twitchUrl,
            hint: 'https://twitch.tv/yourname',
            field: 'twitch_url',
            onUpdate: onUpdate),
        _IntegrationRow(
            icon: Icons.play_circle_fill_rounded,
            color: const Color(0xFFFF0000),
            label: 'YouTube',
            value: profile.youtubeUrl,
            hint: 'https://youtube.com/@yourname',
            field: 'youtube_url',
            onUpdate: onUpdate),
        _IntegrationRow(
            icon: Icons.facebook_rounded,
            color: const Color(0xFF1877F2),
            label: 'Facebook',
            value: profile.facebookUrl,
            hint: 'https://facebook.com/yourname',
            field: 'facebook_url',
            onUpdate: onUpdate),
        _IntegrationRow(
            icon: Icons.alternate_email_rounded,
            color: AppColors.textPrimary,
            label: 'X (Twitter)',
            value: profile.twitterUrl,
            hint: 'https://x.com/yourname',
            field: 'twitter_url',
            onUpdate: onUpdate),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// SHARED WIDGETS
// ═══════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 10),
        Text(title, style: AppTextStyles.h3),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  final Color? valueColor;
  const _InfoRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
              width: 160,
              child: Text(label,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textTertiary))),
          Expanded(
              child: Text(value,
                  style: AppTextStyles.bodyMedium.copyWith(
                      color: valueColor ?? AppColors.textPrimary,
                      fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}

class _EditableRow extends StatelessWidget {
  final String label, value;
  final String? field;
  final Future<void> Function(String, dynamic) onUpdate;
  const _EditableRow(
      {required this.label,
      required this.value,
      required this.field,
      required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
              width: 160,
              child: Text(label,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textTertiary))),
          Expanded(
              child: Text(value,
                  style: AppTextStyles.bodyMedium
                      .copyWith(fontWeight: FontWeight.w500))),
          if (field != null)
            TextButton(
              onPressed: () => _showEditDialog(context),
              style: TextButton.styleFrom(foregroundColor: AppColors.accent),
              child: Text('EDIT',
                  style: AppTextStyles.caption.copyWith(
                      color: AppColors.accent, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    final ctrl = TextEditingController(text: value == 'Not set' ? '' : value);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgSurface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.border)),
        title: Text('Edit $label', style: AppTextStyles.h3),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: AppTextStyles.bodyMedium,
          decoration: InputDecoration(hintText: 'Enter $label'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: TextStyle(color: AppColors.textTertiary))),
          TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                if (field != null && ctrl.text.trim().isNotEmpty) {
                  onUpdate(field!, ctrl.text.trim());
                }
              },
              child: Text('Save', style: TextStyle(color: AppColors.primary))),
        ],
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onUpdate;
  const _DateRow(
      {required this.label, required this.value, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    final display = value != null
        ? '${value!.day}/${value!.month}/${value!.year}'
        : 'Not set';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
              width: 160,
              child: Text(label,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textTertiary))),
          Expanded(
              child: Text(display,
                  style: AppTextStyles.bodyMedium
                      .copyWith(fontWeight: FontWeight.w500))),
          TextButton(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: value ?? DateTime(2000, 1, 1),
                firstDate: DateTime(1950),
                lastDate: DateTime.now(),
              );
              if (picked != null) onUpdate(picked);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.accent),
            child: Text('EDIT',
                style: AppTextStyles.caption.copyWith(
                    color: AppColors.accent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _DropdownRow extends StatelessWidget {
  final String label, value;
  final List<(String, String)> items;
  final ValueChanged<String> onChanged;
  const _DropdownRow(
      {required this.label,
      required this.value,
      required this.items,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
              width: 160,
              child: Text(label,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textTertiary))),
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
                  value:
                      items.any((i) => i.$1 == value) ? value : items.first.$1,
                  isExpanded: true,
                  dropdownColor: AppColors.bgElevated,
                  style: AppTextStyles.bodyMedium,
                  icon: const Icon(Icons.expand_more_rounded,
                      size: 18, color: AppColors.textTertiary),
                  items: items
                      .map((i) =>
                          DropdownMenuItem(value: i.$1, child: Text(i.$2)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) onChanged(v);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BioEditor extends StatefulWidget {
  final String bio;
  final ValueChanged<String> onSave;
  const _BioEditor({required this.bio, required this.onSave});
  @override
  State<_BioEditor> createState() => _BioEditorState();
}

class _BioEditorState extends State<_BioEditor> {
  late final TextEditingController _ctrl;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.bio);
  }

  @override
  Widget build(BuildContext context) {
    if (!_editing) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
              child: Text(
            widget.bio.isEmpty ? 'No bio set.' : widget.bio,
            style: AppTextStyles.bodyMedium.copyWith(
                color: widget.bio.isEmpty
                    ? AppColors.textTertiary
                    : AppColors.textSecondary),
          )),
          TextButton(
            onPressed: () => setState(() => _editing = true),
            style: TextButton.styleFrom(foregroundColor: AppColors.accent),
            child: Text(widget.bio.isEmpty ? 'ADD' : 'EDIT',
                style: AppTextStyles.caption.copyWith(
                    color: AppColors.accent, fontWeight: FontWeight.w700)),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        TextField(
          controller: _ctrl,
          maxLines: 4,
          maxLength: 500,
          style: AppTextStyles.bodyMedium,
          decoration: InputDecoration(
            hintText: 'Tell others about yourself...',
            counterText: '${_ctrl.text.length}/500',
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
                onPressed: () => setState(() => _editing = false),
                child: Text('Cancel',
                    style: TextStyle(color: AppColors.textTertiary))),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                widget.onSave(_ctrl.text.trim());
                setState(() => _editing = false);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ],
    );
  }
}

class _IntegrationRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String? value;
  final String hint, field;
  final Future<void> Function(String, dynamic) onUpdate;
  const _IntegrationRow(
      {required this.icon,
      required this.color,
      required this.label,
      required this.value,
      required this.hint,
      required this.field,
      required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.label.copyWith(fontSize: 14)),
                const SizedBox(height: 2),
                Text(hasValue ? value! : 'Not set',
                    style: AppTextStyles.bodySmall.copyWith(
                        color: hasValue
                            ? AppColors.textSecondary
                            : AppColors.textTertiary)),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _showEditDialog(context),
            style: TextButton.styleFrom(foregroundColor: AppColors.accent),
            child: Text(hasValue ? 'EDIT' : 'ADD',
                style: AppTextStyles.caption.copyWith(
                    color: AppColors.accent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    final ctrl = TextEditingController(text: value ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgSurface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.border)),
        title: Text(label, style: AppTextStyles.h3),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: AppTextStyles.bodyMedium,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: TextStyle(color: AppColors.textTertiary))),
          if (value != null && value!.isNotEmpty)
            TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  onUpdate(field, null);
                },
                child:
                    Text('Remove', style: TextStyle(color: AppColors.danger))),
          TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                if (ctrl.text.trim().isNotEmpty) {
                  onUpdate(field, ctrl.text.trim());
                }
              },
              child: Text('Save', style: TextStyle(color: AppColors.primary))),
        ],
      ),
    );
  }
}
