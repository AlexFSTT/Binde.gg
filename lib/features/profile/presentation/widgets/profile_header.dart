import 'package:binde_gg/core/errors/result.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/profile_model.dart';
import '../../../../data/repositories/friends_repository.dart';
import '../../../../shared/widgets/level_badge.dart';
import '../../../../shared/widgets/status_badge.dart';

class ProfileHeader extends StatelessWidget {
  final ProfileModel profile;
  final bool isOwnProfile;
  const ProfileHeader(
      {super.key, required this.profile, this.isOwnProfile = false});

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final realName = '${p.firstName ?? ''} ${p.lastName ?? ''}'.trim();
    final hasCountry =
        p.country != null && p.country!.isNotEmpty && p.country != 'Not set';
    final socials = _getSocials(p);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Row 1: Avatar + Identity + Earnings ─────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      width: 2),
                  image: p.steamAvatarUrl != null
                      ? DecorationImage(
                          image: NetworkImage(p.steamAvatarUrl!),
                          fit: BoxFit.cover)
                      : null,
                ),
                child: p.steamAvatarUrl == null
                    ? Center(
                        child: Text(
                            p.username.isNotEmpty
                                ? p.username[0].toUpperCase()
                                : '?',
                            style: AppTextStyles.h1.copyWith(
                                color: AppColors.primary, fontSize: 28)))
                    : null,
              ),
              const SizedBox(width: 20),

              // Identity
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Username + badges
                    Row(
                      children: [
                        Text(p.username, style: AppTextStyles.h2),
                        const SizedBox(width: 12),
                        LevelBadge.full(elo: p.eloRating),
                        if (p.isStaff) ...[
                          const SizedBox(width: 8),
                          StatusBadge(
                              label: p.role.toUpperCase(),
                              color: p.isAdmin
                                  ? AppColors.danger
                                  : AppColors.warning),
                        ],
                        if (p.isKycVerified) ...[
                          const SizedBox(width: 8),
                          const StatusBadge(
                              label: 'VERIFIED', color: AppColors.success),
                        ],
                        if (p.hasSteam) ...[
                          const SizedBox(width: 8),
                          _VacBadge(vacBanned: p.vacBanned),
                        ],
                      ],
                    ),

                    // Real name (subtle, under username)
                    if (realName.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(realName,
                          style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textTertiary, fontSize: 12)),
                    ],

                    const SizedBox(height: 10),

                    // Info chips
                    Wrap(
                      spacing: 14,
                      runSpacing: 6,
                      children: [
                        // Country with real flag
                        if (hasCountry) _CountryChip(code: p.country!),

                        if (p.hasSteam)
                          _Chip(
                              Icons.gamepad_rounded,
                              p.steamUsername ?? 'Steam',
                              AppColors.textSecondary),
                        _Chip(Icons.public_rounded, p.preferredRegion,
                            AppColors.textTertiary),
                        _Chip(Icons.groups_rounded, p.preferredMode,
                            AppColors.textTertiary),
                        _Chip(
                            Icons.calendar_today_rounded,
                            'Joined ${Formatters.date(p.createdAt)}',
                            AppColors.textTertiary),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 16),

              // Right column: Level + Earnings + Bcoins
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  LevelBadge.full(elo: p.eloRating),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _BcoinBlock(bcoins: p.bcoins),
                      const SizedBox(width: 8),
                      _EarningsBlock(
                          earnings: p.totalEarnings,
                          isOwnProfile: isOwnProfile),
                    ],
                  ),
                ],
              ),
            ],
          ),

          // ── Divider ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Container(
                height: 1, color: AppColors.border.withValues(alpha: 0.3)),
          ),

          // ── Row 2: Quick stats + Socials ────────────
          Row(
            children: [
              _MiniStat(label: 'Played', value: '${p.matchesPlayed}'),
              _MiniStat(
                  label: 'Won',
                  value: '${p.matchesWon}',
                  color: AppColors.success),
              _MiniStat(
                  label: 'Lost',
                  value: '${p.matchesLost}',
                  color: AppColors.danger),
              _MiniStat(
                  label: 'Win Rate',
                  value: p.matchesPlayed > 0
                      ? '${(p.matchesWon / p.matchesPlayed * 100).toStringAsFixed(0)}%'
                      : '-',
                  color: AppColors.info),
              _MiniStat(
                  label: 'Streak',
                  value: '${p.winStreak}',
                  color: AppColors.accent),
              _MiniStat(
                  label: 'Best',
                  value: '${p.bestWinStreak}',
                  color: AppColors.warning),

              // Socials (right-aligned)
              if (socials.isNotEmpty) ...[
                const Spacer(),
                ...socials.map((s) => Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: _SocialBtn(social: s),
                    )),
              ],

              // Actions for other profiles
              if (!isOwnProfile) ...[
                if (socials.isEmpty) const Spacer(),
                if (socials.isNotEmpty) const SizedBox(width: 12),
                _ProfileActions(userId: p.id),
              ],
            ],
          ),
        ],
      ),
    );
  }

  static List<_Social> _getSocials(ProfileModel p) {
    final list = <_Social>[];
    if (p.twitchUrl?.isNotEmpty ?? false) {
      list.add(_Social(Icons.live_tv_rounded, const Color(0xFF9146FF), 'Twitch',
          p.twitchUrl!));
    }
    if (p.youtubeUrl?.isNotEmpty ?? false) {
      list.add(_Social(Icons.play_circle_fill_rounded, const Color(0xFFFF0000),
          'YouTube', p.youtubeUrl!));
    }
    if (p.facebookUrl?.isNotEmpty ?? false) {
      list.add(_Social(Icons.facebook_rounded, const Color(0xFF1877F2),
          'Facebook', p.facebookUrl!));
    }
    if (p.twitterUrl?.isNotEmpty ?? false) {
      list.add(_Social(Icons.alternate_email_rounded, AppColors.textPrimary,
          'X', p.twitterUrl!));
    }
    return list;
  }
}

// ═══════════════════════════════════════════════════════════
// EARNINGS BLOCK (top-right corner)
// ═══════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════
// BCOIN BLOCK
// ═══════════════════════════════════════════════════════════

class _BcoinBlock extends StatelessWidget {
  final int bcoins;
  const _BcoinBlock({required this.bcoins});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bgBase.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFE8A33E), Color(0xFFD4891F)],
              ),
              borderRadius: BorderRadius.circular(7),
              boxShadow: [
                BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.2),
                    blurRadius: 6)
              ],
            ),
            child: const Center(
                child: Text('B',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900))),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Bcoins',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textTertiary, fontSize: 9)),
              Text('$bcoins',
                  style: AppTextStyles.mono.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent)),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// EARNINGS BLOCK (top-right corner)
// ═══════════════════════════════════════════════════════════

class _EarningsBlock extends StatelessWidget {
  final double earnings;
  final bool isOwnProfile;
  const _EarningsBlock({required this.earnings, required this.isOwnProfile});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bgBase.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Icon(Icons.paid_rounded,
                    size: 14, color: AppColors.success),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Total Earnings',
                      style: AppTextStyles.caption.copyWith(
                          color: AppColors.textTertiary, fontSize: 9)),
                  Text(Formatters.currency(earnings),
                      style: AppTextStyles.mono.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: earnings > 0
                              ? AppColors.success
                              : AppColors.textSecondary)),
                ],
              ),
            ],
          ),
          if (isOwnProfile) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: AppColors.bgSurfaceActive,
                  borderRadius: BorderRadius.circular(4)),
              child: Text('YOUR PROFILE',
                  style: AppTextStyles.caption.copyWith(
                      color: AppColors.textTertiary,
                      fontSize: 8,
                      letterSpacing: 0.8)),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// COUNTRY CHIP — real flag image from flagcdn.com
// ═══════════════════════════════════════════════════════════

class _CountryChip extends StatelessWidget {
  final String code;
  const _CountryChip({required this.code});

  @override
  Widget build(BuildContext context) {
    final lower = code.toLowerCase();
    final name = _names[code] ?? code;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: Image.network(
            'https://flagcdn.com/w40/$lower.png',
            width: 18,
            height: 13,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Icon(Icons.flag_rounded,
                size: 13, color: AppColors.textTertiary),
          ),
        ),
        const SizedBox(width: 5),
        Text(name,
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary, fontSize: 12)),
      ],
    );
  }

  static const _names = {
    'DE': 'Germany',
    'RO': 'Romania',
    'US': 'USA',
    'GB': 'UK',
    'FR': 'France',
    'ES': 'Spain',
    'IT': 'Italy',
    'PT': 'Portugal',
    'NL': 'Netherlands',
    'BE': 'Belgium',
    'AT': 'Austria',
    'CH': 'Switzerland',
    'PL': 'Poland',
    'CZ': 'Czechia',
    'SE': 'Sweden',
    'NO': 'Norway',
    'DK': 'Denmark',
    'FI': 'Finland',
    'BR': 'Brazil',
    'TR': 'Turkey',
    'RU': 'Russia',
    'UA': 'Ukraine',
    'BG': 'Bulgaria',
    'HR': 'Croatia',
    'RS': 'Serbia',
    'GR': 'Greece',
    'HU': 'Hungary',
    'SK': 'Slovakia',
    'LT': 'Lithuania',
  };
}

// ═══════════════════════════════════════════════════════════
// MINI STAT
// ═══════════════════════════════════════════════════════════

class _MiniStat extends StatelessWidget {
  final String label, value;
  final Color? color;
  const _MiniStat({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 20),
      child: Column(
        children: [
          Text(value,
              style: AppTextStyles.mono.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: color ?? AppColors.textPrimary)),
          const SizedBox(height: 1),
          Text(label,
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textTertiary, fontSize: 10)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// SHARED
// ═══════════════════════════════════════════════════════════

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Chip(this.icon, this.label, this.color);
  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label,
              style:
                  AppTextStyles.bodySmall.copyWith(color: color, fontSize: 12)),
        ],
      );
}

class _VacBadge extends StatelessWidget {
  final bool vacBanned;
  const _VacBadge({required this.vacBanned});
  @override
  Widget build(BuildContext context) {
    final c = vacBanned ? AppColors.danger : AppColors.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: c.withValues(alpha: 0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(vacBanned ? Icons.gpp_bad_rounded : Icons.verified_user_rounded,
            size: 11, color: c),
        const SizedBox(width: 3),
        Text(vacBanned ? 'VAC BAN' : 'VAC CLEAN',
            style: AppTextStyles.caption
                .copyWith(color: c, fontWeight: FontWeight.w700, fontSize: 9)),
      ]),
    );
  }
}

class _SocialBtn extends StatefulWidget {
  final _Social social;
  const _SocialBtn({required this.social});
  @override
  State<_SocialBtn> createState() => _SocialBtnState();
}

class _SocialBtnState extends State<_SocialBtn> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    final s = widget.social;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () async {
          final url = Uri.parse(s.url);
          if (await canLaunchUrl(url)) {
            await launchUrl(url, mode: LaunchMode.externalApplication);
          }
        },
        child: Tooltip(
          message: s.label,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _hovered
                  ? s.color.withValues(alpha: 0.15)
                  : AppColors.bgSurfaceActive,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: _hovered
                      ? s.color.withValues(alpha: 0.3)
                      : AppColors.border),
            ),
            child: Icon(s.icon,
                size: 13, color: _hovered ? s.color : AppColors.textTertiary),
          ),
        ),
      ),
    );
  }
}

class _Social {
  final IconData icon;
  final Color color;
  final String label, url;
  const _Social(this.icon, this.color, this.label, this.url);
}

// ═══════════════════════════════════════════════════════════
// PROFILE ACTIONS (Add Friend / Report / Block) for other users
// ═══════════════════════════════════════════════════════════

class _ProfileActions extends StatefulWidget {
  final String userId;
  const _ProfileActions({required this.userId});
  @override
  State<_ProfileActions> createState() => _ProfileActionsState();
}

class _ProfileActionsState extends State<_ProfileActions> {
  final _repo = FriendsRepository();
  String?
      _status; // null, 'friends', 'request_sent', 'request_received', 'blocked'
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final status = await _repo.getFriendshipStatus(widget.userId);
    if (mounted) {
      setState(() {
        _status = status;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // ignore: curly_braces_in_flow_control_structures
    if (_loading) {
      return const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: AppColors.textTertiary));
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Main action button
        if (_status == null) // Not connected
          _actionBtn(Icons.person_add_rounded, 'Add Friend', AppColors.primary,
              () async {
            final result = await _repo.sendFriendRequest(widget.userId);
            if (result.isSuccess) {
              setState(() => _status = 'request_sent');
              _snack('Friend request sent!');
            } else {
              _snack(result.error ?? 'Failed', color: AppColors.danger);
            }
          })
        else if (_status == 'friends')
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border:
                  Border.all(color: AppColors.success.withValues(alpha: 0.25)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.check_rounded,
                  size: 12, color: AppColors.success),
              const SizedBox(width: 4),
              Text('FRIENDS',
                  style: AppTextStyles.caption.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w700,
                      fontSize: 10)),
            ]),
          )
        else if (_status == 'request_sent')
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6)),
            child: Text('PENDING',
                style: AppTextStyles.caption.copyWith(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w700,
                    fontSize: 10)),
          )
        else if (_status == 'request_received')
          _actionBtn(Icons.check_circle_rounded, 'Accept', AppColors.success,
              () async {
            final inc = await _repo.getIncomingRequests();
            if (inc.isSuccess) {
              final req = inc.data!
                  .where((r) => (r['sender'] as Map)['id'] == widget.userId)
                  .firstOrNull;
              if (req != null) {
                await _repo.acceptRequest(req['id'] as String);
                setState(() => _status = 'friends');
                _snack('Friend added!');
              }
            }
          }),

        const SizedBox(width: 6),

        // More actions menu
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_horiz_rounded,
              size: 18, color: AppColors.textTertiary),
          color: AppColors.bgElevated,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: AppColors.border)),
          itemBuilder: (_) => [
            if (_status == 'friends')
              PopupMenuItem(
                  value: 'unfriend',
                  child: Row(children: [
                    const Icon(Icons.person_remove_rounded,
                        size: 14, color: AppColors.danger),
                    const SizedBox(width: 8),
                    Text('Unfriend',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.danger)),
                  ])),
            PopupMenuItem(
                value: 'report',
                child: Row(children: [
                  const Icon(Icons.flag_rounded,
                      size: 14, color: AppColors.warning),
                  const SizedBox(width: 8),
                  Text('Report',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.warning)),
                ])),
            PopupMenuItem(
                value: 'block',
                child: Row(children: [
                  const Icon(Icons.block_rounded,
                      size: 14, color: AppColors.danger),
                  const SizedBox(width: 8),
                  Text('Block',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.danger)),
                ])),
          ],
          onSelected: (action) async {
            switch (action) {
              case 'unfriend':
                await _repo.removeFriend(widget.userId);
                setState(() => _status = null);
                _snack('Unfriended');
              case 'report':
                _snack('Use Friends → Find Players to report',
                    color: AppColors.info);
              case 'block':
                await _repo.blockUser(widget.userId);
                setState(() => _status = 'blocked');
                _snack('User blocked', color: AppColors.danger);
            }
          },
        ),
      ],
    );
  }

  Widget _actionBtn(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(label,
                style: AppTextStyles.caption.copyWith(
                    color: color, fontWeight: FontWeight.w700, fontSize: 10)),
          ]),
        ),
      ),
    );
  }

  void _snack(String msg, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg), backgroundColor: color ?? AppColors.success));
  }
}
