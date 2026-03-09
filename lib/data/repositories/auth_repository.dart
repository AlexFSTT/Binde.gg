import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/supabase_config.dart';
import '../../core/errors/result.dart';

/// Handles authentication operations.
class AuthRepository {
  final _client = SupabaseConfig.client;
  final _auth = SupabaseConfig.auth;

  /// Current session user ID
  String? get currentUserId => _auth.currentUser?.id;
  bool get isAuthenticated => _auth.currentUser != null;

  /// Listen to auth state changes
  Stream<AuthState> get authStateChanges => _auth.onAuthStateChange;

  /// Register with email + password.
  /// Profile is NOT created here — it's created on first login
  /// (because email confirmation blocks the session).
  Future<Result<bool>> register({
    required String email,
    required String password,
    required String username,
  }) async {
    try {
      final authResponse = await _auth.signUp(
        email: email,
        password: password,
        data: {'username': username}, // Store in user_metadata for later
      );

      if (authResponse.user == null) {
        return const Failure('Registration failed');
      }

      // If session exists → email confirmation is disabled → create profile now
      if (authResponse.session != null) {
        await _ensureProfileExists(
          userId: authResponse.user!.id,
          username: username,
          email: email,
        );
      }

      // true = email confirmation pending, false = logged in directly
      return Success(authResponse.session == null);
    } on AuthException catch (e) {
      return Failure(e.message, code: e.statusCode);
    } catch (e) {
      return Failure(e.toString());
    }
  }

  /// Login with email + password.
  /// Also ensures profile exists (handles first login after email confirmation).
  Future<Result<void>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _auth.signInWithPassword(
        email: email,
        password: password,
      );

      // Ensure profile exists on first login
      if (response.user != null) {
        final username = response.user!.userMetadata?['username'] as String? ??
            email.split('@').first;
        await _ensureProfileExists(
          userId: response.user!.id,
          username: username,
          email: email,
        );
      }

      return const Success(null);
    } on AuthException catch (e) {
      return Failure(e.message, code: e.statusCode);
    } catch (e) {
      return Failure(e.toString());
    }
  }

  /// Creates profile if it doesn't exist yet.
  /// Called on login to handle the case where registration
  /// happened but profile wasn't created (email confirmation flow).
  Future<void> _ensureProfileExists({
    required String userId,
    required String username,
    required String email,
  }) async {
    try {
      // Check if profile already exists
      final existing = await _client
          .from('profiles')
          .select('id')
          .eq('id', userId)
          .maybeSingle();

      if (existing == null) {
        // Create profile
        await _client.from('profiles').insert({
          'id': userId,
          'username': username,
          'email': email,
        });
      }
    } catch (_) {
      // Non-fatal: profile might already exist or username taken
      // User can update username later from settings
    }
  }

  /// Logout
  Future<void> logout() async {
    await _auth.signOut();
  }
}
