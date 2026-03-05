import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/supabase_config.dart';
import '../../core/errors/result.dart';
import '../models/profile_model.dart';

/// Handles authentication operations.
class AuthRepository {
  final _client = SupabaseConfig.client;
  final _auth = SupabaseConfig.auth;

  /// Current session user ID
  String? get currentUserId => _auth.currentUser?.id;
  bool get isAuthenticated => _auth.currentUser != null;

  /// Listen to auth state changes
  Stream<AuthState> get authStateChanges => _auth.onAuthStateChange;

  /// Register with email + password, then create profile
  Future<Result<ProfileModel>> register({
    required String email,
    required String password,
    required String username,
  }) async {
    try {
      final authResponse = await _auth.signUp(email: email, password: password);
      if (authResponse.user == null) return const Failure('Registration failed');

      final profile = await _client
          .from('profiles')
          .insert({'id': authResponse.user!.id, 'username': username, 'email': email})
          .select()
          .single();

      return Success(ProfileModel.fromJson(profile));
    } on AuthException catch (e) {
      return Failure(e.message, code: e.statusCode);
    } catch (e) {
      return Failure(e.toString());
    }
  }

  /// Login with email + password
  Future<Result<void>> login({required String email, required String password}) async {
    try {
      await _auth.signInWithPassword(email: email, password: password);
      return const Success(null);
    } on AuthException catch (e) {
      return Failure(e.message, code: e.statusCode);
    } catch (e) {
      return Failure(e.toString());
    }
  }

  /// Logout
  Future<void> logout() async {
    await _auth.signOut();
  }
}
