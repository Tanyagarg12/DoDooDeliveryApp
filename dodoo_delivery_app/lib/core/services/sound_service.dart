import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Plays short in-app alert sounds.
///
/// The OS notification (flutter_local_notifications) only reliably plays a
/// sound when the app is in the background. To make sure the rider hears a new
/// order while the app is open (and on web, where notification sounds don't
/// play at all), we actively play a chime here.
class SoundService {
  SoundService._();
  static final SoundService instance = SoundService._();

  final AudioPlayer _player = AudioPlayer(playerId: 'dodoo_alerts');
  bool _configured = false;

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    _configured = true;
    // Low-latency mode is ideal for short, repeated alert sounds.
    try {
      await _player.setPlayerMode(PlayerMode.lowLatency);
      await _player.setReleaseMode(ReleaseMode.stop);
    } catch (_) {/* best-effort */}
  }

  /// Plays the "new order" chime. Restarts if already playing so back-to-back
  /// orders each get an audible cue. Never throws.
  Future<void> playNewOrder() async {
    try {
      await _ensureConfigured();
      await _player.stop();
      await _player.play(AssetSource('sounds/do_doo_tone.mp3'));
    } catch (e) {
      // Audio is a nice-to-have; never let it break the order flow.
      debugPrint('SoundService.playNewOrder failed: $e');
    }
  }

  Future<void> dispose() async {
    try {
      await _player.dispose();
    } catch (_) {}
  }
}
