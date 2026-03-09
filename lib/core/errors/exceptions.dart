/// Base exception for all app errors.
class AppException implements Exception {
  const AppException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => 'AppException($code): $message';
}

/// Auth-related errors.
class AuthException extends AppException {
  const AuthException(super.message, {super.code});
}

/// Wallet/transaction errors.
class WalletException extends AppException {
  const WalletException(super.message, {super.code});
}

/// Lobby errors (full, banned, elo mismatch, etc).
class LobbyException extends AppException {
  const LobbyException(super.message, {super.code});
}

/// Match errors.
class MatchException extends AppException {
  const MatchException(super.message, {super.code});
}

/// Network/API errors.
class NetworkException extends AppException {
  const NetworkException(super.message, {super.code});
}

/// Steam integration errors.
class SteamException extends AppException {
  const SteamException(super.message, {super.code});
}
