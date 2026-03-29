import 'package:binde_gg/core/errors/result.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/profile_model.dart';
import '../../../data/repositories/friends_repository.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/level_badge.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});
  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _repo = FriendsRepository();
  int _tab = 0;
  int _pendingCount = 0;

  // Friends
  List<ProfileModel> _friends = [];
  bool _friendsLoading = true;

  // Requests
  List<Map<String, dynamic>> _incoming = [];
  List<Map<String, dynamic>> _outgoing = [];
  bool _requestsLoading = true;

  // Search
  final _searchCtrl = TextEditingController();
  List<ProfileModel> _searchResults = [];
  bool _isSearching = false;
  Map<String, String?> _searchStatuses = {};

  // Blocked
  List<ProfileModel> _blocked = [];
  bool _blockedLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFriends();
    _loadRequests();
    _loadBlocked();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    setState(() => _friendsLoading = true);
    final result = await _repo.getFriends();
    if (!mounted) return;
    result.when(
      success: (list) => setState(() {
        _friends = list;
        _friendsLoading = false;
      }),
      failure: (_, __) => setState(() => _friendsLoading = false),
    );
  }

  Future<void> _loadRequests() async {
    setState(() => _requestsLoading = true);
    final inc = await _repo.getIncomingRequests();
    final out = await _repo.getOutgoingRequests();
    if (!mounted) return;
    setState(() {
      _incoming = inc.isSuccess ? inc.data! : [];
      _outgoing = out.isSuccess ? out.data! : [];
      _pendingCount = _incoming.length;
      _requestsLoading = false;
    });
  }

  Future<void> _loadBlocked() async {
    setState(() => _blockedLoading = true);
    final result = await _repo.getBlockedUsers();
    if (!mounted) return;
    result.when(
      success: (list) => setState(() {
        _blocked = list;
        _blockedLoading = false;
      }),
      failure: (_, __) => setState(() => _blockedLoading = false),
    );
  }

  Future<void> _search(String query) async {
    if (query.trim().length < 2) {
      setState(() {
        _searchResults = [];
        _searchStatuses = {};
      });
      return;
    }
    setState(() => _isSearching = true);
    final result = await _repo.searchUsers(query.trim());
    if (!mounted) return;
    if (result.isSuccess) {
      final statuses = <String, String?>{};
      for (final p in result.data!) {
        statuses[p.id] = await _repo.getFriendshipStatus(p.id);
      }
      setState(() {
        _searchResults = result.data!;
        _searchStatuses = statuses;
        _isSearching = false;
      });
    } else {
      setState(() => _isSearching = false);
    }
  }

  void _snack(String msg, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg), backgroundColor: color ?? AppColors.success));
  }

  @override
  Widget build(BuildContext context) {
    return GlassPage(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Sidebar ──────────────────────────────
          SizedBox(
            width: 220,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.people_rounded,
                        size: 22, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Text('Friends', style: AppTextStyles.h2),
                  ]),
                  const SizedBox(height: 24),
                  _tabItem(0, Icons.people_rounded, 'Friends',
                      count: _friends.length),
                  _tabItem(1, Icons.mail_rounded, 'Requests',
                      count: _pendingCount, highlight: _pendingCount > 0),
                  _tabItem(2, Icons.search_rounded, 'Find Players'),
                  _tabItem(3, Icons.block_rounded, 'Blocked',
                      count: _blocked.length),
                ],
              ),
            ),
          ),
          Container(width: 1, color: AppColors.border.withValues(alpha: 0.3)),
          // ── Content ──────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: _buildContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabItem(int index, IconData icon, String label,
      {int? count, bool highlight = false}) {
    final active = _tab == index;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => setState(() => _tab = index),
          borderRadius: BorderRadius.circular(8),
          hoverColor: AppColors.bgSurfaceHover,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: active ? AppColors.primary.withValues(alpha: 0.08) : null,
              border: active
                  ? Border.all(color: AppColors.primary.withValues(alpha: 0.2))
                  : null,
            ),
            child: Row(
              children: [
                Icon(icon,
                    size: 16,
                    color: active ? AppColors.primary : AppColors.textTertiary),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(label,
                        style: AppTextStyles.bodySmall.copyWith(
                            color: active
                                ? AppColors.primary
                                : AppColors.textSecondary,
                            fontWeight:
                                active ? FontWeight.w600 : FontWeight.w400))),
                if (count != null && count > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: highlight
                          ? AppColors.accent
                          : AppColors.bgSurfaceActive,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('$count',
                        style: AppTextStyles.caption.copyWith(
                            color: highlight
                                ? Colors.white
                                : AppColors.textTertiary,
                            fontSize: 10,
                            fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_tab) {
      case 0:
        return _buildFriendsList();
      case 1:
        return _buildRequests();
      case 2:
        return _buildSearch();
      case 3:
        return _buildBlockedList();
      default:
        return const SizedBox.shrink();
    }
  }

  // ═══════════════════════════════════════════════════
  // FRIENDS LIST
  // ═══════════════════════════════════════════════════

  Widget _buildFriendsList() {
    if (_friendsLoading) return _loading();
    if (_friends.isEmpty) {
      return _empty(Icons.people_outline_rounded, 'No friends yet',
          'Search for players and send friend requests.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Your Friends', '${_friends.length}'),
        const SizedBox(height: 12),
        ..._friends.map((f) => _FriendTile(
              profile: f,
              trailing: _friendActions(f),
              onTap: () => context.go('/profile/${f.id}'),
            )),
      ],
    );
  }

  Widget _friendActions(ProfileModel friend) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded,
          size: 18, color: AppColors.textTertiary),
      color: AppColors.bgElevated,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.border)),
      itemBuilder: (_) => [
        _menuItem('profile', Icons.person_rounded, 'View Profile'),
        _menuItem('invite', Icons.send_rounded, 'Invite to Lobby'),
        const PopupMenuDivider(),
        _menuItem('report', Icons.flag_rounded, 'Report',
            color: AppColors.warning),
        _menuItem('block', Icons.block_rounded, 'Block',
            color: AppColors.danger),
        _menuItem('remove', Icons.person_remove_rounded, 'Unfriend',
            color: AppColors.danger),
      ],
      onSelected: (action) async {
        switch (action) {
          case 'profile':
            context.go('/profile/${friend.id}');
          case 'invite':
            _snack('Lobby invite coming soon', color: AppColors.info);
          case 'report':
            _showReportDialog(friend);
          case 'block':
            await _confirmBlock(friend);
          case 'remove':
            await _confirmUnfriend(friend);
        }
      },
    );
  }

  // ═══════════════════════════════════════════════════
  // REQUESTS
  // ═══════════════════════════════════════════════════

  Widget _buildRequests() {
    if (_requestsLoading) return _loading();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_incoming.isNotEmpty) ...[
          _sectionTitle('Incoming Requests', '${_incoming.length}'),
          const SizedBox(height: 12),
          ..._incoming.map((req) {
            final sender = req['sender'] as Map<String, dynamic>;
            return _RequestTile(
              username: sender['username'] as String,
              avatarUrl: sender['steam_avatar_url'] as String?,
              elo: sender['elo_rating'] as int? ?? 100,
              onAccept: () async {
                await _repo.acceptRequest(req['id'] as String);
                _loadRequests();
                _loadFriends();
                _snack('Friend request accepted!');
              },
              onDecline: () async {
                await _repo.declineRequest(req['id'] as String);
                _loadRequests();
              },
              onTap: () => context.go('/profile/${sender['id']}'),
            );
          }),
          const SizedBox(height: 24),
        ],
        if (_outgoing.isNotEmpty) ...[
          _sectionTitle('Sent Requests', '${_outgoing.length}'),
          const SizedBox(height: 12),
          ..._outgoing.map((req) {
            final receiver = req['receiver'] as Map<String, dynamic>;
            return _FriendTile(
              profile: ProfileModel.fromJson({
                ...receiver,
                'created_at': DateTime.now().toIso8601String(),
                'updated_at': DateTime.now().toIso8601String(),
              }),
              trailing: TextButton(
                onPressed: () async {
                  await _repo.cancelRequest(req['id'] as String);
                  _loadRequests();
                  _snack('Request cancelled', color: AppColors.info);
                },
                child: Text('CANCEL',
                    style: AppTextStyles.caption.copyWith(
                        color: AppColors.danger, fontWeight: FontWeight.w700)),
              ),
              onTap: () => context.go('/profile/${receiver['id']}'),
            );
          }),
        ],
        if (_incoming.isEmpty && _outgoing.isEmpty)
          _empty(Icons.mail_outline_rounded, 'No pending requests',
              'Friend requests will appear here.'),
      ],
    );
  }

  // ═══════════════════════════════════════════════════
  // SEARCH
  // ═══════════════════════════════════════════════════

  Widget _buildSearch() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Find Players', null),
        const SizedBox(height: 4),
        Text('Search by username, real name, or Steam name.',
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textTertiary)),
        const SizedBox(height: 16),

        // Search bar
        TextField(
          controller: _searchCtrl,
          style: AppTextStyles.bodyMedium,
          decoration: InputDecoration(
            hintText: 'Search players...',
            prefixIcon: const Icon(Icons.search_rounded,
                size: 20, color: AppColors.textTertiary),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() {
                        _searchResults = [];
                      });
                    },
                  )
                : null,
          ),
          onChanged: (q) => _search(q),
        ),

        const SizedBox(height: 20),

        if (_isSearching)
          _loading()
        else if (_searchResults.isNotEmpty)
          ..._searchResults.map((p) {
            final status = _searchStatuses[p.id];
            return _FriendTile(
              profile: p,
              trailing: _searchAction(p, status),
              onTap: () => context.go('/profile/${p.id}'),
            );
          })
        else if (_searchCtrl.text.length >= 2)
          _empty(Icons.search_off_rounded, 'No players found',
              'Try a different search term.'),
      ],
    );
  }

  Widget _searchAction(ProfileModel user, String? status) {
    return switch (status) {
      'friends' => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6)),
          child: Text('FRIENDS',
              style: AppTextStyles.caption.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.w700,
                  fontSize: 10))),
      'request_sent' => Text('PENDING',
          style: AppTextStyles.caption.copyWith(
              color: AppColors.warning,
              fontWeight: FontWeight.w700,
              fontSize: 10)),
      'request_received' => TextButton(
          onPressed: () async {
            // Find and accept the request
            final inc = await _repo.getIncomingRequests();
            if (inc.isSuccess) {
              final req = inc.data!
                  .where((r) => (r['sender'] as Map)['id'] == user.id)
                  .firstOrNull;
              if (req != null) {
                await _repo.acceptRequest(req['id'] as String);
                _search(_searchCtrl.text);
                _loadFriends();
                _loadRequests();
                _snack('Accepted!');
              }
            }
          },
          child: Text('ACCEPT',
              style: AppTextStyles.caption.copyWith(
                  color: AppColors.success, fontWeight: FontWeight.w700))),
      'blocked' => Text('BLOCKED',
          style: AppTextStyles.caption.copyWith(
              color: AppColors.danger,
              fontWeight: FontWeight.w700,
              fontSize: 10)),
      _ => ElevatedButton.icon(
          onPressed: () async {
            final result = await _repo.sendFriendRequest(user.id);
            if (result.isSuccess) {
              _snack('Friend request sent!');
              _search(_searchCtrl.text);
              _loadRequests();
            } else {
              _snack(result.error ?? 'Failed', color: AppColors.danger);
            }
          },
          icon: const Icon(Icons.person_add_rounded, size: 16),
          label: const Text('Add'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            textStyle:
                AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
    };
  }

  // ═══════════════════════════════════════════════════
  // BLOCKED LIST
  // ═══════════════════════════════════════════════════

  Widget _buildBlockedList() {
    if (_blockedLoading) return _loading();
    if (_blocked.isEmpty) {
      return _empty(Icons.block_rounded, 'No blocked users',
          'Users you block will appear here.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Blocked Users', '${_blocked.length}'),
        const SizedBox(height: 12),
        ..._blocked.map((p) => _FriendTile(
              profile: p,
              trailing: TextButton(
                onPressed: () async {
                  await _repo.unblockUser(p.id);
                  _loadBlocked();
                  _snack('User unblocked', color: AppColors.info);
                },
                child: Text('UNBLOCK',
                    style: AppTextStyles.caption.copyWith(
                        color: AppColors.primary, fontWeight: FontWeight.w700)),
              ),
              onTap: () => context.go('/profile/${p.id}'),
            )),
      ],
    );
  }

  // ═══════════════════════════════════════════════════
  // DIALOGS
  // ═══════════════════════════════════════════════════

  void _showReportDialog(ProfileModel user) {
    String? selectedReason;
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.bgSurface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.border)),
          title: Row(children: [
            const Icon(Icons.flag_rounded, color: AppColors.warning, size: 20),
            const SizedBox(width: 8),
            Text('Report ${user.username}', style: AppTextStyles.h3),
          ]),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Reason',
                    style: AppTextStyles.label.copyWith(fontSize: 12)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    'cheating',
                    'toxic',
                    'griefing',
                    'smurfing',
                    'scam',
                    'other'
                  ]
                      .map((r) => ChoiceChip(
                            label: Text(r.toUpperCase()),
                            selected: selectedReason == r,
                            selectedColor:
                                AppColors.warning.withValues(alpha: 0.2),
                            onSelected: (v) => setDialogState(
                                () => selectedReason = v ? r : null),
                            labelStyle: AppTextStyles.caption.copyWith(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: selectedReason == r
                                    ? AppColors.warning
                                    : AppColors.textTertiary),
                            backgroundColor: AppColors.bgSurfaceActive,
                            side: BorderSide(
                                color: selectedReason == r
                                    ? AppColors.warning.withValues(alpha: 0.4)
                                    : AppColors.border),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  maxLength: 500,
                  style: AppTextStyles.bodySmall,
                  decoration:
                      const InputDecoration(hintText: 'Details (optional)...'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel',
                    style: TextStyle(color: AppColors.textTertiary))),
            TextButton(
              onPressed: selectedReason == null
                  ? null
                  : () async {
                      Navigator.pop(ctx);
                      await _repo.reportUser(user.id, selectedReason!,
                          description: descCtrl.text.trim());
                      _snack('Report submitted. Thank you.',
                          color: AppColors.info);
                    },
              child: Text('Submit Report',
                  style: TextStyle(
                      color: selectedReason != null
                          ? AppColors.warning
                          : AppColors.textTertiary)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmBlock(ProfileModel user) async {
    final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              backgroundColor: AppColors.bgSurface,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.border)),
              title: Text('Block ${user.username}?', style: AppTextStyles.h3),
              content: Text(
                  'They won\'t be able to see your profile or send you requests. This also removes them from your friends list.',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textTertiary)),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text('Cancel',
                        style: TextStyle(color: AppColors.textTertiary))),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text('Block',
                        style: TextStyle(color: AppColors.danger))),
              ],
            ));
    if (confirm == true) {
      await _repo.blockUser(user.id);
      _loadFriends();
      _loadBlocked();
      _snack('${user.username} blocked', color: AppColors.danger);
    }
  }

  Future<void> _confirmUnfriend(ProfileModel user) async {
    final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              backgroundColor: AppColors.bgSurface,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.border)),
              title: Text('Remove ${user.username}?', style: AppTextStyles.h3),
              content: Text('They will be removed from your friends list.',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textTertiary)),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text('Cancel',
                        style: TextStyle(color: AppColors.textTertiary))),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text('Remove',
                        style: TextStyle(color: AppColors.danger))),
              ],
            ));
    if (confirm == true) {
      await _repo.removeFriend(user.id);
      _loadFriends();
      _snack('${user.username} removed');
    }
  }

  // ═══════════════════════════════════════════════════
  // SHARED WIDGETS
  // ═══════════════════════════════════════════════════

  PopupMenuItem<String> _menuItem(String value, IconData icon, String label,
      {Color? color}) {
    return PopupMenuItem(
        value: value,
        child: Row(children: [
          Icon(icon, size: 16, color: color ?? AppColors.textSecondary),
          const SizedBox(width: 10),
          Text(label,
              style: AppTextStyles.bodySmall
                  .copyWith(color: color ?? AppColors.textPrimary)),
        ]));
  }

  Widget _sectionTitle(String title, String? count) {
    return Row(children: [
      Text(title, style: AppTextStyles.h3),
      if (count != null) ...[
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
              color: AppColors.bgSurfaceActive,
              borderRadius: BorderRadius.circular(10)),
          child: Text(count,
              style: AppTextStyles.mono
                  .copyWith(fontSize: 11, color: AppColors.textTertiary)),
        ),
      ],
    ]);
  }

  Widget _loading() => const Padding(
        padding: EdgeInsets.all(40),
        child:
            Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );

  Widget _empty(IconData icon, String title, String subtitle) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border)),
      child: Column(children: [
        Icon(icon,
            size: 40, color: AppColors.textTertiary.withValues(alpha: 0.4)),
        const SizedBox(height: 12),
        Text(title,
            style: AppTextStyles.h3.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Text(subtitle,
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textTertiary)),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// FRIEND TILE
// ═══════════════════════════════════════════════════════════

class _FriendTile extends StatelessWidget {
  final ProfileModel profile;
  final Widget? trailing;
  final VoidCallback? onTap;
  const _FriendTile({required this.profile, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final isOnline = p.lastOnline != null &&
        DateTime.now().toUtc().difference(p.lastOnline!).inMinutes < 5;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        hoverColor: AppColors.bgSurfaceHover,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          child: Row(
            children: [
              // Avatar + online dot
              Stack(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: AppColors.primary.withValues(alpha: 0.12),
                      image: p.steamAvatarUrl != null
                          ? DecorationImage(
                              image: NetworkImage(p.steamAvatarUrl!),
                              fit: BoxFit.cover)
                          : null,
                    ),
                    child: p.steamAvatarUrl == null
                        ? Center(
                            child: Text(p.username[0].toUpperCase(),
                                style: AppTextStyles.label.copyWith(
                                    color: AppColors.primary, fontSize: 14)))
                        : null,
                  ),
                  if (isOnline)
                    Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: AppColors.bgBase, width: 2),
                          ),
                        )),
                ],
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(p.username,
                          style: AppTextStyles.label.copyWith(fontSize: 13)),
                      const SizedBox(width: 8),
                      LevelBadge.compact(elo: p.eloRating),
                    ]),
                    const SizedBox(height: 2),
                    Text(
                      isOnline
                          ? 'Online'
                          : (p.lastOnline != null
                              ? 'Last seen ${Formatters.timeAgo(p.lastOnline!)}'
                              : 'Offline'),
                      style: AppTextStyles.caption.copyWith(
                          color: isOnline
                              ? AppColors.success
                              : AppColors.textTertiary,
                          fontSize: 10),
                    ),
                  ],
                ),
              ),

              // Trailing action
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// REQUEST TILE (with accept/decline buttons)
// ═══════════════════════════════════════════════════════════

class _RequestTile extends StatelessWidget {
  final String username;
  final String? avatarUrl;
  final int elo;
  final VoidCallback onAccept, onDecline;
  final VoidCallback? onTap;
  const _RequestTile(
      {required this.username,
      this.avatarUrl,
      required this.elo,
      required this.onAccept,
      required this.onDecline,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        hoverColor: AppColors.bgSurfaceHover,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: AppColors.primary.withValues(alpha: 0.12),
                  image: avatarUrl != null
                      ? DecorationImage(
                          image: NetworkImage(avatarUrl!), fit: BoxFit.cover)
                      : null,
                ),
                child: avatarUrl == null
                    ? Center(
                        child: Text(username[0].toUpperCase(),
                            style: AppTextStyles.label.copyWith(
                                color: AppColors.primary, fontSize: 14)))
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(username,
                        style: AppTextStyles.label.copyWith(fontSize: 13)),
                    const SizedBox(width: 8),
                    LevelBadge.compact(elo: elo),
                  ]),
                  Text('Wants to be your friend',
                      style: AppTextStyles.caption.copyWith(
                          color: AppColors.textTertiary, fontSize: 10)),
                ],
              )),
              IconButton(
                onPressed: onAccept,
                icon: const Icon(Icons.check_circle_rounded, size: 22),
                color: AppColors.success,
                tooltip: 'Accept',
              ),
              IconButton(
                onPressed: onDecline,
                icon: const Icon(Icons.cancel_rounded, size: 22),
                color: AppColors.danger,
                tooltip: 'Decline',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
