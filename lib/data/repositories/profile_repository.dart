import '../../config/supabase_config.dart';
import '../../core/errors/result.dart';
import '../models/profile_model.dart';

/// Profile CRUD operations.
class ProfileRepository {
  final _client = SupabaseConfig.client;

  Future<Result<ProfileModel>> getProfile(String userId) async {
    try {
      final data =
          await _client.from('profiles').select().eq('id', userId).single();
      return Success(ProfileModel.fromJson(data));
    } catch (e) {
      return Failure(e.toString());
    }
  }

  Future<Result<ProfileModel>> getProfileByUsername(String username) async {
    try {
      final data = await _client
          .from('profiles')
          .select()
          .eq('username', username)
          .single();
      return Success(ProfileModel.fromJson(data));
    } catch (e) {
      return Failure(e.toString());
    }
  }

  Future<Result<ProfileModel>> updateProfile(
      String userId, Map<String, dynamic> updates) async {
    try {
      // Use SECURITY DEFINER RPC — direct UPDATE on profiles is revoked
      final result = await _client.rpc('fn_update_profile', params: {
        'p_username': updates['username'],
        'p_first_name': updates['first_name'],
        'p_last_name': updates['last_name'],
        'p_birth_date': updates['birth_date'],
        'p_country': updates['country'],
        'p_bio': updates['bio'],
        'p_language': updates['language'],
        'p_avatar_url': updates['avatar_url'],
        'p_twitch_url': updates['twitch_url'],
        'p_youtube_url': updates['youtube_url'],
        'p_facebook_url': updates['facebook_url'],
        'p_twitter_url': updates['twitter_url'],
        'p_preferred_region': updates['preferred_region'],
        'p_preferred_mode': updates['preferred_mode'],
      });

      final data = result as Map<String, dynamic>;
      if (data['success'] != true) {
        return Failure(data['error'] as String? ?? 'Failed to update profile');
      }

      // Reload fresh row after update
      final fresh =
          await _client.from('profiles').select().eq('id', userId).single();
      return Success(ProfileModel.fromJson(fresh));
    } catch (e) {
      return Failure(e.toString());
    }
  }

  Future<Result<List<ProfileModel>>> getLeaderboard(
      {int limit = 50, int offset = 0}) async {
    try {
      final data = await _client
          .from('profiles')
          .select()
          .order('elo_rating', ascending: false)
          .range(offset, offset + limit - 1);
      return Success(data.map((j) => ProfileModel.fromJson(j)).toList());
    } catch (e) {
      return Failure(e.toString());
    }
  }

  Future<Result<List<ProfileModel>>> searchProfiles(String query) async {
    try {
      final data = await _client
          .from('profiles')
          .select()
          .ilike('username', '%$query%')
          .limit(20);
      return Success(data.map((j) => ProfileModel.fromJson(j)).toList());
    } catch (e) {
      return Failure(e.toString());
    }
  }
}
