/// Lobby — maps to `lobbies` table.
class LobbyModel {
  final String id;
  final String createdBy;
  final String name;
  final String mode;
  final double entryFee;
  final String status;
  final int maxPlayers;
  final int currentPlayers;
  final int minElo;
  final int maxElo;
  final String region;
  final bool isPrivate;
  final String? inviteCode;
  final DateTime createdAt;
  final DateTime updatedAt;

  const LobbyModel({
    required this.id,
    required this.createdBy,
    required this.name,
    this.mode = '5v5',
    this.entryFee = 0.0,
    this.status = 'open',
    required this.maxPlayers,
    this.currentPlayers = 0,
    this.minElo = 0,
    this.maxElo = 9999,
    this.region = 'EU',
    this.isPrivate = false,
    this.inviteCode,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isOpen => status == 'open';
  bool get isFull => currentPlayers >= maxPlayers;
  int get spotsLeft => maxPlayers - currentPlayers;

  factory LobbyModel.fromJson(Map<String, dynamic> json) {
    return LobbyModel(
      id: json['id'] as String,
      createdBy: json['created_by'] as String,
      name: json['name'] as String,
      mode: json['mode'] as String? ?? '5v5',
      entryFee: (json['entry_fee'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'open',
      maxPlayers: json['max_players'] as int,
      currentPlayers: json['current_players'] as int? ?? 0,
      minElo: json['min_elo'] as int? ?? 0,
      maxElo: json['max_elo'] as int? ?? 9999,
      region: json['region'] as String? ?? 'EU',
      isPrivate: json['is_private'] as bool? ?? false,
      inviteCode: json['invite_code'] as String?,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'mode': mode,
    'entry_fee': entryFee,
    'max_players': maxPlayers,
    'min_elo': minElo,
    'max_elo': maxElo,
    'region': region,
    'is_private': isPrivate,
  };
}
