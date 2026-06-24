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
  bool _looping = false;

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    _configured = true;
    // Low-latency mode is ideal for short, repeated alert sounds.
    try {
      await _player.setPlayerMode(PlayerMode.lowLatency);
    } catch (_) {/* best-effort */}
  }

  /// Plays the "new order" chime once. Never throws.
  Future<void> playNewOrder() async {
    try {
      await _ensureConfigured();
      _looping = false;
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.play(AssetSource('sounds/do_doo_tone.mp3'));
    } catch (e) {
      debugPrint('SoundService.playNewOrder failed: $e');
    }
  }

  /// Starts the new-order alert on a LOOP — it keeps ringing until
  /// [stopAlert] is called (i.e. until the rider accepts/rejects the offer or
  /// it's taken by someone else). Calling it again while already looping is a
  /// no-op so it doesn't restart mid-ring.
  Future<void> startAlertLoop() async {
    if (_looping) return;
    try {
      await _ensureConfigured();
      _looping = true;
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.stop();
      await _player.play(AssetSource('sounds/do_doo_tone.mp3'));
    } catch (e) {
      _looping = false;
      debugPrint('SoundService.startAlertLoop failed: $e');
    }
  }

  /// Stops the looping alert (and any one-shot chime). Safe to call anytime.
  Future<void> stopAlert() async {
    _looping = false;
    try {
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.stop);
    } catch (_) {/* best-effort */}
  }

  bool get isAlerting => _looping;

  Future<void> dispose() async {
    try {
      await _player.dispose();
    } catch (_) {}
  }
}
