/// Match — maps to `matches` table.
class MatchModel {
  final String id;
  final String? lobbyId;
  final String mode;
  final String status;
  final String? map;
  final double entryFee;
  final double totalPot;
  final double rakeAmount;
  final double rakePercentage;
  final String? serverIp;
  final int? serverPort;
  final String? serverPassword;
  final int teamAScore;
  final int teamBScore;
  final String? winner;
  final int overtimeRounds;
  final String? demoUrl;
  final DateTime? readyCheckAt;
  final DateTime? vetoStartedAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final DateTime? cancelledAt;
  final String? cancelReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MatchModel({
    required this.id,
    this.lobbyId,
    required this.mode,
    this.status = 'waiting',
    this.map,
    this.entryFee = 0.0,
    this.totalPot = 0.0,
    this.rakeAmount = 0.0,
    this.rakePercentage = 10.0,
    this.serverIp,
    this.serverPort,
    this.serverPassword,
    this.teamAScore = 0,
    this.teamBScore = 0,
    this.winner,
    this.overtimeRounds = 0,
    this.demoUrl,
    this.readyCheckAt,
    this.vetoStartedAt,
    this.startedAt,
    this.finishedAt,
    this.cancelledAt,
    this.cancelReason,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isLive => status == 'live';
  bool get isFinished => status == 'finished';
  bool get isCancelled => status == 'cancelled';
  String get score => '$teamAScore - $teamBScore';

  factory MatchModel.fromJson(Map<String, dynamic> json) {
    return MatchModel(
      id: json['id'] as String,
      lobbyId: json['lobby_id'] as String?,
      mode: json['mode'] as String,
      status: json['status'] as String? ?? 'waiting',
      map: json['map'] as String?,
      entryFee: (json['entry_fee'] as num?)?.toDouble() ?? 0.0,
      totalPot: (json['total_pot'] as num?)?.toDouble() ?? 0.0,
      rakeAmount: (json['rake_amount'] as num?)?.toDouble() ?? 0.0,
      rakePercentage: (json['rake_percentage'] as num?)?.toDouble() ?? 10.0,
      serverIp: json['server_ip'] as String?,
      serverPort: json['server_port'] as int?,
      serverPassword: json['server_password'] as String?,
      teamAScore: json['team_a_score'] as int? ?? 0,
      teamBScore: json['team_b_score'] as int? ?? 0,
      winner: json['winner'] as String?,
      overtimeRounds: json['overtime_rounds'] as int? ?? 0,
      demoUrl: json['demo_url'] as String?,
      readyCheckAt: json['ready_check_at'] != null ? DateTime.parse(json['ready_check_at']) : null,
      vetoStartedAt: json['veto_started_at'] != null ? DateTime.parse(json['veto_started_at']) : null,
      startedAt: json['started_at'] != null ? DateTime.parse(json['started_at']) : null,
      finishedAt: json['finished_at'] != null ? DateTime.parse(json['finished_at']) : null,
      cancelledAt: json['cancelled_at'] != null ? DateTime.parse(json['cancelled_at']) : null,
      cancelReason: json['cancel_reason'] as String?,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}
