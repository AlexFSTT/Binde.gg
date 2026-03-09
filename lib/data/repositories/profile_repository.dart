import '../../config/supabase_config.dart';
import '../../core/errors/result.dart';
import '../models/profile_model.dart';

/// Profile CRUD operations.
class ProfileRepository {
  final _client = SupabaseConfig.client;

  Future<Result<ProfileModel>> getProfile(String userId) async {
    try {
      final data = await _client.from('profiles').select().eq('id', userId).single();
      return Success(ProfileModel.fromJson(data));
    } catch (e) {
      return Failure(e.toString());
    }
  }

  Future<Result<ProfileModel>> getProfileByUsername(String username) async {
    try {
      final data = await _client.from('profiles').select().eq('username', username).single();
      return Success(ProfileModel.fromJson(data));
    } catch (e) {
      return Failure(e.toString());
    }
  }

  Future<Result<ProfileModel>> updateProfile(String userId, Map<String, dynamic> updates) async {
    try {
      final data = await _client.from('profiles').update(updates).eq('id', userId).select().single();
      return Success(ProfileModel.fromJson(data));
    } catch (e) {
      return Failure(e.toString());
    }
  }

  Future<Result<List<ProfileModel>>> getLeaderboard({int limit = 50, int offset = 0}) async {
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
