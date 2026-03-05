/// App-wide constant values.
/// Single source of truth for magic numbers and config.
class AppConstants {
  AppConstants._();

  // ── App Info ────────────────────────────────────────
  static const String appName = 'BINDE.GG';
  static const String appVersion = '0.1.0';

  // ── ELO ─────────────────────────────────────────────
  static const int defaultElo = 1000;
  static const int minElo = 100;
  static const int maxElo = 5000;

  // ── Financials ──────────────────────────────────────
  static const double rakePercentage = 10.0;
  static const double minEntryFee = 0.50;
  static const double maxEntryFee = 100.00;

  // ── Pagination ──────────────────────────────────────
  static const int defaultPageSize = 20;
  static const int leaderboardPageSize = 50;

  // ── Timeouts ────────────────────────────────────────
  static const int vetoTimeoutSeconds = 30;
  static const int readyCheckTimeoutSeconds = 30;
  static const int lobbyIdleTimeoutMinutes = 30;

  // ── Username Validation ─────────────────────────────
  static const int usernameMinLength = 3;
  static const int usernameMaxLength = 24;
  static final RegExp usernameRegex = RegExp(r'^[a-zA-Z0-9_-]+$');
}
