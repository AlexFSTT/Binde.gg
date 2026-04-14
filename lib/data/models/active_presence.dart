/// Represents a user's current "active presence" state across the app.
///
/// Exactly one of these is shown in the top bar pill. Priority order:
///   1. matchLive       — user is in an active match (veto/ready_check/live)
///   2. lobbyActive     — user is in an active lobby
///   3. matchmaking     — user is searching for a match
///   null               — nothing active
enum PresenceType {
  matchmaking,
  lobbyActive,
  matchLive,
  matchFound, // Special transient state: searching → matched (queue row)
}

class ActivePresence {
  final PresenceType type;
  final String targetId; // match_id or lobby_id or queue_id
  final String targetRoute; // e.g. "/match/abc", "/lobby/abc", "/play"
  final String label; // "SEARCHING" / "MATCH FOUND" / "IN LOBBY" / "LIVE MATCH"
  final String? subtitle; // extra context like "1v1 · 0:45" or "5v5 Gold Pro"
  final DateTime? startedAt; // for duration display (matchmaking, live)

  const ActivePresence({
    required this.type,
    required this.targetId,
    required this.targetRoute,
    required this.label,
    this.subtitle,
    this.startedAt,
  });

  /// Numeric priority: higher = more important. Used to pick the
  /// one to display if multiple are active simultaneously.
  int get priority => switch (type) {
        PresenceType.matchFound => 100,
        PresenceType.matchLive => 90,
        PresenceType.lobbyActive => 50,
        PresenceType.matchmaking => 30,
      };

  /// Whether this presence uses a pulsing/attention-grabbing style.
  bool get isUrgent =>
      type == PresenceType.matchFound || type == PresenceType.matchLive;

  ActivePresence copyWith({
    PresenceType? type,
    String? targetId,
    String? targetRoute,
    String? label,
    String? subtitle,
    DateTime? startedAt,
  }) {
    return ActivePresence(
      type: type ?? this.type,
      targetId: targetId ?? this.targetId,
      targetRoute: targetRoute ?? this.targetRoute,
      label: label ?? this.label,
      subtitle: subtitle ?? this.subtitle,
      startedAt: startedAt ?? this.startedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ActivePresence &&
      other.type == type &&
      other.targetId == targetId &&
      other.label == label &&
      other.subtitle == subtitle;

  @override
  int get hashCode => Object.hash(type, targetId, label, subtitle);
}
