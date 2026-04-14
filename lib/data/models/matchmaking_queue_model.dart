/// Matchmaking queue entry — maps to `matchmaking_queue` table.
class MatchmakingQueueModel {
  final String id;
  final String userId;
  final String mode;
  final int entryFee;
  final int eloRating;
  final double kdRatio;
  final double adr;
  final int matchesPlayed;
  final int subscriptionTier;
  final String status;
  final String? matchId;
  final int searchTier;
  final DateTime? priorityBoostUntil;
  final DateTime joinedAt;
  final DateTime expiresAt;
  final DateTime? matchedAt;
  final DateTime updatedAt;

  const MatchmakingQueueModel({
    required this.id,
    required this.userId,
    required this.mode,
    required this.entryFee,
    required this.eloRating,
    required this.kdRatio,
    required this.adr,
    required this.matchesPlayed,
    required this.subscriptionTier,
    required this.status,
    this.matchId,
    this.searchTier = 0,
    this.priorityBoostUntil,
    required this.joinedAt,
    required this.expiresAt,
    this.matchedAt,
    required this.updatedAt,
  });

  bool get isSearching => status == 'searching';
  bool get isMatched => status == 'matched';
  bool get isExpired => status == 'expired';
  bool get isCancelled => status == 'cancelled';
  bool get isAccepted => status == 'accepted';
  bool get isDeclined => status == 'declined';

  /// Seconds elapsed since enqueue.
  int get waitSeconds =>
      DateTime.now().difference(joinedAt).inSeconds;

  /// Seconds until this queue entry expires.
  int get secondsUntilExpiry =>
      expiresAt.difference(DateTime.now()).inSeconds.clamp(0, 600);

  /// Human label for current search tier.
  String get searchTierLabel => switch (searchTier) {
        2 => 'Plus-only',
        1 => 'Premium+',
        _ => 'All players',
      };

  factory MatchmakingQueueModel.fromJson(Map<String, dynamic> json) {
    return MatchmakingQueueModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      mode: json['mode'] as String,
      entryFee: json['entry_fee'] as int,
      eloRating: json['elo_rating'] as int,
      kdRatio: (json['kd_ratio'] as num?)?.toDouble() ?? 0.0,
      adr: (json['adr'] as num?)?.toDouble() ?? 0.0,
      matchesPlayed: json['matches_played'] as int? ?? 0,
      subscriptionTier: json['subscription_tier'] as int? ?? 0,
      status: json['status'] as String,
      matchId: json['match_id'] as String?,
      searchTier: json['search_tier'] as int? ?? 0,
      priorityBoostUntil: json['priority_boost_until'] != null
          ? DateTime.parse(json['priority_boost_until'])
          : null,
      joinedAt: DateTime.parse(json['joined_at']),
      expiresAt: DateTime.parse(json['expires_at']),
      matchedAt: json['matched_at'] != null
          ? DateTime.parse(json['matched_at'])
          : null,
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}
