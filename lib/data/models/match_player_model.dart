/// Player stats within a match — maps to `match_players` table.
class MatchPlayerModel {
  final String id;
  final String matchId;
  final String playerId;
  final String team;
  final bool isCaptain;
  final int kills;
  final int deaths;
  final int assists;
  final int headshots;
  final double adr;
  final double hltvRating;
  final int mvps;
  final int firstKills;
  final int clutchesWon;
  final double payout;
  final int eloChange;

  const MatchPlayerModel({
    required this.id,
    required this.matchId,
    required this.playerId,
    required this.team,
    this.isCaptain = false,
    this.kills = 0,
    this.deaths = 0,
    this.assists = 0,
    this.headshots = 0,
    this.adr = 0.0,
    this.hltvRating = 0.0,
    this.mvps = 0,
    this.firstKills = 0,
    this.clutchesWon = 0,
    this.payout = 0.0,
    this.eloChange = 0,
  });

  String get kda => '$kills/$deaths/$assists';
  double get kdRatio => deaths == 0 ? kills.toDouble() : kills / deaths;
  double get hsPercentage => kills == 0 ? 0 : headshots / kills * 100;

  factory MatchPlayerModel.fromJson(Map<String, dynamic> json) {
    return MatchPlayerModel(
      id: json['id'] as String,
      matchId: json['match_id'] as String,
      playerId: json['player_id'] as String,
      team: json['team'] as String,
      isCaptain: json['is_captain'] as bool? ?? false,
      kills: json['kills'] as int? ?? 0,
      deaths: json['deaths'] as int? ?? 0,
      assists: json['assists'] as int? ?? 0,
      headshots: json['headshots'] as int? ?? 0,
      adr: (json['adr'] as num?)?.toDouble() ?? 0.0,
      hltvRating: (json['hltv_rating'] as num?)?.toDouble() ?? 0.0,
      mvps: json['mvps'] as int? ?? 0,
      firstKills: json['first_kills'] as int? ?? 0,
      clutchesWon: json['clutches_won'] as int? ?? 0,
      payout: (json['payout'] as num?)?.toDouble() ?? 0.0,
      eloChange: json['elo_change'] as int? ?? 0,
    );
  }
}
