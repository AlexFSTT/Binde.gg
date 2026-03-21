/// User profile — maps to `profiles` table.
class ProfileModel {
  final String id;
  final String username;
  final String? email;
  final String? avatarUrl;
  final String? steamId;
  final String? steamUsername;
  final String? steamAvatarUrl;
  final String? steamProfileUrl;
  final bool vacBanned;
  final int vacBanCount;
  final String role;
  final String kycStatus;
  final bool isBanned;
  final String? banReason;
  final DateTime? bannedUntil;
  final int eloRating;
  final int eloPeak;
  final int matchesPlayed;
  final int matchesWon;
  final int matchesLost;
  final int winStreak;
  final int bestWinStreak;
  final double totalEarnings;
  final String preferredRegion;
  final String preferredMode;
  final DateTime? lastOnline;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProfileModel({
    required this.id,
    required this.username,
    this.email,
    this.avatarUrl,
    this.steamId,
    this.steamUsername,
    this.steamAvatarUrl,
    this.steamProfileUrl,
    this.vacBanned = false,
    this.vacBanCount = 0,
    this.role = 'player',
    this.kycStatus = 'none',
    this.isBanned = false,
    this.banReason,
    this.bannedUntil,
    this.eloRating = 100,
    this.eloPeak = 100,
    this.matchesPlayed = 0,
    this.matchesWon = 0,
    this.matchesLost = 0,
    this.winStreak = 0,
    this.bestWinStreak = 0,
    this.totalEarnings = 0.0,
    this.preferredRegion = 'EU',
    this.preferredMode = '5v5',
    this.lastOnline,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get hasSteam => steamId != null;
  bool get isAdmin => role == 'admin';
  bool get isModerator => role == 'moderator';
  bool get isStaff => isAdmin || isModerator;
  bool get isKycVerified => kycStatus == 'verified';
  double get winRate => matchesPlayed == 0 ? 0 : matchesWon / matchesPlayed * 100;

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as String,
      username: json['username'] as String,
      email: json['email'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      steamId: json['steam_id'] as String?,
      steamUsername: json['steam_username'] as String?,
      steamAvatarUrl: json['steam_avatar_url'] as String?,
      steamProfileUrl: json['steam_profile_url'] as String?,
      vacBanned: json['vac_banned'] as bool? ?? false,
      vacBanCount: json['vac_ban_count'] as int? ?? 0,
      role: json['role'] as String? ?? 'player',
      kycStatus: json['kyc_status'] as String? ?? 'none',
      isBanned: json['is_banned'] as bool? ?? false,
      banReason: json['ban_reason'] as String?,
      bannedUntil: json['banned_until'] != null ? DateTime.parse(json['banned_until']) : null,
      eloRating: json['elo_rating'] as int? ?? 100,
      eloPeak: json['elo_peak'] as int? ?? 100,
      matchesPlayed: json['matches_played'] as int? ?? 0,
      matchesWon: json['matches_won'] as int? ?? 0,
      matchesLost: json['matches_lost'] as int? ?? 0,
      winStreak: json['win_streak'] as int? ?? 0,
      bestWinStreak: json['best_win_streak'] as int? ?? 0,
      totalEarnings: (json['total_earnings'] as num?)?.toDouble() ?? 0.0,
      preferredRegion: json['preferred_region'] as String? ?? 'EU',
      preferredMode: json['preferred_mode'] as String? ?? '5v5',
      lastOnline: json['last_online'] != null ? DateTime.parse(json['last_online']) : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'email': email,
    'avatar_url': avatarUrl,
    'preferred_region': preferredRegion,
    'preferred_mode': preferredMode,
  };
}
