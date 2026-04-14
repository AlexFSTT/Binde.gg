import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../config/supabase_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Security penetration test screen — DEBUG ONLY.
///
/// Runs a battery of attacks against the database that a malicious
/// client could attempt. Each test should FAIL (= secure).
///
/// Usage:
///   1. Add to router temporarily: GoRoute(path: '/sec-test', builder: (_,__) => SecurityTestScreen())
///   2. Navigate to /sec-test in debug build
///   3. Tap "Run All Tests"
///   4. All rows should show RED ✓ "BLOCKED (good)"
///   5. Any GREEN ✗ "ALLOWED (BAD)" is a security hole
class SecurityTestScreen extends StatefulWidget {
  const SecurityTestScreen({super.key});

  @override
  State<SecurityTestScreen> createState() => _SecurityTestScreenState();
}

class _SecurityTestScreenState extends State<SecurityTestScreen> {
  final _client = SupabaseConfig.client;
  final List<_TestResult> _results = [];
  bool _running = false;

  String get _userId => SupabaseConfig.auth.currentUser!.id;

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return const Scaffold(
        backgroundColor: AppColors.bgBase,
        body: Center(
          child: Text('Security tests are debug-only.',
              style: TextStyle(color: AppColors.danger)),
        ),
      );
    }

    final blocked = _results.where((r) => r.blocked).length;
    final allowed = _results.where((r) => !r.blocked).length;

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        backgroundColor: AppColors.bgSurface,
        title: Text('Security Tests', style: AppTextStyles.h3),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Status header ─────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Icon(
                    allowed == 0 && _results.isNotEmpty
                        ? Icons.shield_rounded
                        : Icons.warning_amber_rounded,
                    color: allowed == 0 && _results.isNotEmpty
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
                          _results.isEmpty
                              ? 'Ready to run tests'
                              : 'Blocked: $blocked  ·  Allowed: $allowed',
                          style: AppTextStyles.h3,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _results.isEmpty
                              ? 'Tap below to start the security audit.'
                              : allowed == 0
                                  ? '✓ All attacks blocked. Database is secure.'
                                  : '⚠ $allowed attacks succeeded. CRITICAL.',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: allowed == 0 && _results.isNotEmpty
                                ? AppColors.success
                                : AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Run button ────────────────────────
            ElevatedButton.icon(
              onPressed: _running ? null : _runAllTests,
              icon: _running
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.security_rounded, size: 18),
              label: Text(_running ? 'Running...' : 'Run All Tests'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),

            const SizedBox(height: 16),

            // ── Results list ──────────────────────
            Expanded(
              child: _results.isEmpty
                  ? Center(
                      child: Text(
                        'No tests run yet.',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _results.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _ResultTile(_results[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // TEST RUNNER
  // ═══════════════════════════════════════════════════════

  Future<void> _runAllTests() async {
    setState(() {
      _running = true;
      _results.clear();
    });

    // ── PROFILES — protected columns ─────────────

    // ── DEBUG: what does the trigger actually see? ──
    await _attempt(
      'DEBUG: auth context as seen by triggers',
      () async {
        final ctx = await _client.rpc('debug_auth_context');
        // Afișez contextul în label-ul următorului test prin throw
        throw Exception('CTX: $ctx');
      },
    );

    await _attempt(
      'profiles.bcoins → 999999999',
      () async => _client
          .from('profiles')
          .update({'bcoins': 999999999}).eq('id', _userId),
    );
    await _attempt(
      'profiles.elo_rating → 15000 (instant Elite 50)',
      () async => _client
          .from('profiles')
          .update({'elo_rating': 15000}).eq('id', _userId),
    );
    await _attempt(
      'profiles.elo_peak → 99999',
      () async => _client
          .from('profiles')
          .update({'elo_peak': 99999}).eq('id', _userId),
    );
    await _attempt(
      'profiles.subscription_tier → 2 (free Premium Plus)',
      () async => _client
          .from('profiles')
          .update({'subscription_tier': 2}).eq('id', _userId),
    );
    await _attempt(
      'profiles.is_banned → false (self-unban)',
      () async => _client
          .from('profiles')
          .update({'is_banned': false}).eq('id', _userId),
    );
    await _attempt(
      'profiles.vac_banned → false (clear VAC)',
      () async => _client
          .from('profiles')
          .update({'vac_banned': false}).eq('id', _userId),
    );
    await _attempt(
      'profiles.steam_id → fake (account hijack)',
      () async => _client
          .from('profiles')
          .update({'steam_id': '76561198000000000'}).eq('id', _userId),
    );
    await _attempt(
      'profiles.matches_won → 99999 (fake stats)',
      () async => _client
          .from('profiles')
          .update({'matches_won': 99999}).eq('id', _userId),
    );
    await _attempt(
      'profiles.total_earnings → 999999.99',
      () async => _client
          .from('profiles')
          .update({'total_earnings': 999999.99}).eq('id', _userId),
    );
    await _attempt(
      'profiles.role → admin (privilege escalation)',
      () async =>
          _client.from('profiles').update({'role': 'admin'}).eq('id', _userId),
    );
    await _attempt(
      'profiles.kyc_status → verified (skip KYC)',
      () async => _client
          .from('profiles')
          .update({'kyc_status': 'verified'}).eq('id', _userId),
    );

    await _attempt(
      'profiles.bio direct UPDATE (must be BLOCKED now)',
      () async => _client
          .from('profiles')
          .update({'bio': 'Security test bio'}).eq('id', _userId),
    );

    await _attempt(
      'fn_update_profile RPC (should be ALLOWED)',
      () async => _client.rpc('fn_update_profile', params: {
        'p_bio': 'Security test bio',
      }),
      shouldSucceed: true,
    );

    // ── WALLETS — real money ─────────────────────
    await _attempt(
      'wallets.balance → 999999 (real money inflation)',
      () async => _client
          .from('wallets')
          .update({'balance': 999999}).eq('user_id', _userId),
    );
    await _attempt(
      'wallets.total_deposited → 999999',
      () async => _client
          .from('wallets')
          .update({'total_deposited': 999999}).eq('user_id', _userId),
    );

    // ── WALLET_TRANSACTIONS — fake txs ───────────
    await _attempt(
      'wallet_transactions: insert fake deposit',
      () async => _client.from('wallet_transactions').insert({
        'user_id': _userId,
        'type': 'deposit',
        'amount': 9999.99,
        'balance_before': 0,
        'balance_after': 9999.99,
        'status': 'completed',
      }),
    );

    // ── LOBBIES — direct insert with bogus values ─
    await _attempt(
      'lobbies: direct INSERT with negative entry_fee',
      () async => _client.from('lobbies').insert({
        'name': 'Hacked lobby',
        'mode': '5v5',
        'region': 'EU',
        'entry_fee': -999999,
        'max_players': 99,
        'status': 'open',
        'created_by': _userId,
      }),
    );
    await _attempt(
      'lobbies: direct UPDATE on existing lobby',
      () async => _client
          .from('lobbies')
          .update({'entry_fee': 0}).eq('created_by', _userId),
    );

    // ── LOBBY_PLAYERS — make self captain ────────
    await _attempt(
      'lobby_players.is_captain → true (self-promote)',
      () async => _client
          .from('lobby_players')
          .update({'is_captain': true}).eq('player_id', _userId),
    );
    await _attempt(
      'lobby_players.team → team_a (force team)',
      () async => _client
          .from('lobby_players')
          .update({'team': 'team_a'}).eq('player_id', _userId),
    );

    // ── MATCHES — direct write ───────────────────
    await _attempt(
      'matches: direct INSERT (skip lobby/matchmaking)',
      () async => _client.from('matches').insert({
        'mode': '1v1',
        'status': 'finished',
        'team_a_score': 16,
        'team_b_score': 0,
        'winner': 'team_a',
        'entry_fee': 0,
      }),
    );
    await _attempt(
      'matches: UPDATE winner on existing match',
      () async => _client
          .from('matches')
          .update({'winner': 'team_a', 'team_a_score': 16}).limit(1),
    );

    // ── MATCH_PLAYERS — fake stats ───────────────
    await _attempt(
      'match_players.kills → 999 (fake KDA)',
      () async => _client
          .from('match_players')
          .update({'kills': 999, 'deaths': 0}).eq('player_id', _userId),
    );
    await _attempt(
      'match_players.elo_change → 9999',
      () async => _client
          .from('match_players')
          .update({'elo_change': 9999}).eq('player_id', _userId),
    );

    // ── MATCHMAKING_QUEUE — bypass RPC ───────────
    await _attempt(
      'matchmaking_queue: direct INSERT (bypass enqueue RPC)',
      () async => _client.from('matchmaking_queue').insert({
        'user_id': _userId,
        'mode': '5v5',
        'entry_fee': 0,
        'elo_rating': 15000,
        'status': 'searching',
      }),
    );
    await _attempt(
      'matchmaking_queue: UPDATE elo_rating to inflate matchmaking',
      () async => _client
          .from('matchmaking_queue')
          .update({'elo_rating': 15000}).eq('user_id', _userId),
    );

    // ── NOTIFICATIONS — read someone else's ──────
    await _attempt(
      'notifications: read another user\'s notifications',
      () async => _client
          .from('notifications')
          .select()
          .neq('user_id', _userId)
          .limit(1),
      // This is a SELECT; we expect empty result, not exception
      checkEmpty: true,
    );

    // ── USER_REPORTS — self-report ───────────────
    await _attempt(
      'user_reports: report self (should fail)',
      () async => _client.from('user_reports').insert({
        'reporter_id': _userId,
        'reported_id': _userId,
        'reason': 'cheating',
      }),
    );

    // ── FRIEND_REQUESTS — fake sender ────────────
    await _attempt(
      'friend_requests: insert as fake sender',
      () async => _client.from('friend_requests').insert({
        'sender_id': '00000000-0000-0000-0000-000000000000',
        'receiver_id': _userId,
      }),
    );

    setState(() => _running = false);

    // After tests, refund any state we may have mutated by accident
    await _cleanupSafeBio();
  }

  // ═══════════════════════════════════════════════════════
  // INDIVIDUAL ATTEMPT
  // ═══════════════════════════════════════════════════════

  /// Runs an attack and records whether it was blocked.
  ///
  /// [shouldSucceed]: if true, the test PASSES when the operation succeeds
  /// (used for legitimate operations to confirm they still work).
  ///
  /// [checkEmpty]: if true, the operation should return an empty result set
  /// (used for SELECT queries that should be filtered out by RLS).
  Future<void> _attempt(
    String label,
    Future<dynamic> Function() op, {
    bool shouldSucceed = false,
    bool checkEmpty = false,
  }) async {
    String? error;
    bool actuallyBlocked = false;
    bool wasEmpty = false;

    try {
      final result = await op();
      if (checkEmpty) {
        if (result is List && result.isEmpty) {
          wasEmpty = true;
          actuallyBlocked = true;
        }
      }
    } catch (e) {
      error = e.toString();
      actuallyBlocked = true;
    }

    final blocked = shouldSucceed ? !actuallyBlocked : actuallyBlocked;
    final passLabel = shouldSucceed
        ? (actuallyBlocked ? 'BROKEN (legit op fails)' : 'ALLOWED (correct)')
        : (checkEmpty
            ? (wasEmpty ? 'EMPTY (good)' : 'LEAKED DATA (BAD)')
            : (actuallyBlocked ? 'BLOCKED (good)' : 'ALLOWED (BAD)'));

    setState(() {
      _results.add(_TestResult(
        label: label,
        blocked: blocked,
        message: passLabel,
        error: error,
      ));
    });
  }

  /// Restore bio to empty after the safe-edit test
  Future<void> _cleanupSafeBio() async {
    try {
      await _client.from('profiles').update({'bio': ''}).eq('id', _userId);
    } catch (_) {}
  }
}

// ═══════════════════════════════════════════════════════════
// MODELS / WIDGETS
// ═══════════════════════════════════════════════════════════

class _TestResult {
  final String label;
  final bool blocked;
  final String message;
  final String? error;

  _TestResult({
    required this.label,
    required this.blocked,
    required this.message,
    this.error,
  });
}

class _ResultTile extends StatelessWidget {
  final _TestResult r;
  const _ResultTile(this.r);

  @override
  Widget build(BuildContext context) {
    final color = r.blocked ? AppColors.success : AppColors.danger;
    final icon = r.blocked ? Icons.check_circle_rounded : Icons.cancel_rounded;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.label,
                    style: AppTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    )),
                const SizedBox(height: 2),
                Text(r.message,
                    style: AppTextStyles.caption
                        .copyWith(color: color, fontWeight: FontWeight.w700)),
                if (r.error != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    r.error!.length > 200
                        ? '${r.error!.substring(0, 200)}...'
                        : r.error!,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textTertiary,
                      fontSize: 9,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
