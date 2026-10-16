import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Service responsible for realistic call lifecycle audio cues.
///
/// Lifecycle sound rules:
/// - [playConnecting]: Plays looping ringing/connection tone while establishing the call.
/// - [stopConnecting]: Stops the connection tone immediately when call becomes active or ends.
/// - [playConnected]: Plays a short, subtle connected chime once when call transitions to active.
/// - [playCallEnded]: Plays a single short disconnect chime when call ends.
/// - [stopAll]: Halts all audio immediately.
class CallSoundService {
  final AudioPlayer? _ringPlayer;
  final AudioPlayer? _effectPlayer;
  final bool _disabled;

  bool _isPlayingConnecting = false;
  int _connectingPlayCount = 0;
  int _connectedPlayCount = 0;
  int _callEndedPlayCount = 0;
  String? _lastPlayedEffect;

  bool get isPlayingConnecting => _isPlayingConnecting;
  int get connectingPlayCount => _connectingPlayCount;
  int get connectedPlayCount => _connectedPlayCount;
  int get callEndedPlayCount => _callEndedPlayCount;

  CallSoundService({
    AudioPlayer? ringPlayer,
    AudioPlayer? effectPlayer,
    bool? disabled,
  }) : _disabled = disabled ?? (ringPlayer == null && _isRunningInTest()),
       _ringPlayer =
           (disabled == true || (ringPlayer == null && _isRunningInTest()))
           ? null
           : (ringPlayer ?? AudioPlayer()),
       _effectPlayer =
           (disabled == true || (effectPlayer == null && _isRunningInTest()))
           ? null
           : (effectPlayer ?? AudioPlayer()) {
    _effectPlayer?.onPlayerComplete.listen((_) {
      if (_lastPlayedEffect == 'connected') {
        debugPrint('[SOUND] connected playback completed');
      } else if (_lastPlayedEffect == 'ended') {
        debugPrint('[SOUND] ended playback completed');
      }
    });
  }

  factory CallSoundService.noop() => CallSoundService(disabled: true);

  static bool _isRunningInTest() {
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  /// Starts the looping connecting/ringing tone.
  Future<void> playConnecting() async {
    _connectingPlayCount++;
    _isPlayingConnecting = true;
    debugPrint('[SOUND] connecting started');
    if (_disabled || _ringPlayer == null) return;
    try {
      await _ringPlayer.stop();
      await _ringPlayer.setReleaseMode(ReleaseMode.loop);
      await _ringPlayer.play(AssetSource('sounds/call_connecting.wav'));
    } catch (e) {
      debugPrint('[SOUND] playConnecting error (handled): $e');
    }
  }

  /// Immediately stops the connecting tone.
  Future<void> stopConnecting() async {
    if (_isPlayingConnecting) {
      _isPlayingConnecting = false;
      debugPrint('[SOUND] connecting stopped');
    }
    if (_disabled || _ringPlayer == null) return;
    try {
      await _ringPlayer.stop();
    } catch (e) {
      debugPrint('[SOUND] stopConnecting error (handled): $e');
    }
  }

  /// Plays the short, subtle connected chime once.
  Future<void> playConnected() async {
    _connectedPlayCount++;
    debugPrint('[SOUND] connected requested');
    await stopConnecting();
    _lastPlayedEffect = 'connected';
    if (_disabled || _effectPlayer == null) return;
    try {
      await _effectPlayer.stop();
      await _effectPlayer.setVolume(1.0);
      await _effectPlayer.setReleaseMode(ReleaseMode.stop);
      await _effectPlayer.play(AssetSource('sounds/call_connected.wav'));
      debugPrint('[SOUND] playing call connected chime');
    } catch (e) {
      debugPrint('[SOUND] playConnected error (handled): $e');
    }
  }

  /// Plays the short call-ended disconnect chime once.
  Future<void> playCallEnded() async {
    _callEndedPlayCount++;
    await stopConnecting();
    _lastPlayedEffect = 'ended';
    if (_disabled || _effectPlayer == null) return;
    try {
      await _effectPlayer.stop();
      await _effectPlayer.setVolume(1.0);
      await _effectPlayer.setReleaseMode(ReleaseMode.stop);
      await _effectPlayer.play(AssetSource('sounds/call_ended.wav'));
      debugPrint('[SOUND] playing call ended chime');
    } catch (e) {
      debugPrint('[SOUND] playCallEnded error (handled): $e');
    }
  }

  /// Stops all active audio.
  Future<void> stopAll() async {
    _isPlayingConnecting = false;
    if (_disabled) return;
    try {
      await _ringPlayer?.stop();
      await _effectPlayer?.stop();
    } catch (e) {
      debugPrint('[SOUND] stopAll error (handled): $e');
    }
  }

  /// Disposes underlying player resources.
  void dispose() {
    _isPlayingConnecting = false;
    if (_disabled) return;
    try {
      _ringPlayer?.dispose();
      _effectPlayer?.dispose();
    } catch (e) {
      debugPrint('[SOUND] dispose error (handled): $e');
    }
  }
}
