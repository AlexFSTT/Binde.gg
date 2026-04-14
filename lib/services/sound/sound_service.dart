import 'package:audioplayers/audioplayers.dart';
import '../../core/utils/logger.dart';

/// Centralized sound service for notification and match sounds.
///
/// Uses a single shared AudioPlayer instance — match sounds never overlap
/// (match_found and match_ready are minutes apart), and this reduces the
/// number of platform channels which minimizes the audioplayers_windows
/// threading warnings.
class SoundService {
  SoundService._();

  static final _player = AudioPlayer();

  /// Play the match ready sound (server provisioned, players can connect).
  static Future<void> playMatchReady() async {
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/match_ready.wav'));
      Log.d('Sound: match_ready played');
    } catch (e) {
      Log.e('Sound: failed to play match_ready', error: e);
    }
  }

  /// Play the match found sound (matchmaking found opponents, accept dialog about to show).
  static Future<void> playMatchFound() async {
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/match_found.wav'));
      Log.d('Sound: match_found played');
    } catch (e) {
      Log.e('Sound: failed to play match_found', error: e);
    }
  }

  /// Dispose the audio player (call on app shutdown if needed).
  static Future<void> dispose() async {
    await _player.dispose();
  }
}
