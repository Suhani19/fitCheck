import 'dart:convert';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class AgoraTranscriptEvent {
  final String role; // 'candidate' or 'interviewer'
  final String text;
  final int? turnId;
  final bool isFinal;
  final String? messageId;

  const AgoraTranscriptEvent({
    required this.role,
    required this.text,
    this.turnId,
    this.isFinal = true,
    this.messageId,
  });
}

class AgoraAudioDevice {
  final String id;
  final String name;

  const AgoraAudioDevice({
    required this.id,
    required this.name,
  });
}

class AgoraCallService {
  RtcEngine? _engine;
  bool _isLeaving = false;

  bool _micEnabled = true;
  bool _speakerEnabled = true;

  bool get micEnabled => _micEnabled;
  bool get speakerEnabled => _speakerEnabled;

  final Map<String, Map<int, String>> _multipartBuffer = {};

  void resetMultipartBuffer() => _multipartBuffer.clear();

  /// Requests microphone permission from the user if not already granted.
  static Future<bool> requestMicrophonePermission() async {
    if (kIsWeb) {
      // On Web, navigator.mediaDevices manages browser microphone prompts directly upon stream initialization
      return true;
    }
    final status = await Permission.microphone.status;
    if (status.isGranted) {
      return true;
    }
    final result = await Permission.microphone.request();
    return result.isGranted;
  }

  Future<void> join({
    required String appId,
    required String token,
    required String channel,
    required int uid,
    required void Function() onJoined,
    required void Function(int remoteUid) onRemoteUserJoined,
    required void Function(int remoteUid) onRemoteUserLeft,
    required void Function({required int uid, required int volume})
    onAudioVolume,
    required void Function(String message) onError,
    void Function(String role, String text)? onTranscriptTurn,
    void Function(AgoraTranscriptEvent event)? onTranscriptEvent,
  }) async {
    _isLeaving = false;
    final hasMicPermission = await requestMicrophonePermission();
    debugPrint('[AGORA_CALL_SERVICE] join() called with appId=$appId, channel=$channel, uid=$uid, tokenLen=${token.length}, micPermission=$hasMicPermission');
    if (!hasMicPermission) {
      onError('Microphone permission not granted.');
      return;
    }

    debugPrint('[AGORA_CALL_SERVICE] Creating Agora RTC Engine...');
    final engine = createAgoraRtcEngine();
    _engine = engine;

    debugPrint('[AGORA_CALL_SERVICE] Calling RtcEngine.initialize(appId=$appId, profile=channelProfileCommunication)...');
    await engine.initialize(
      RtcEngineContext(
        appId: appId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ),
    );
    debugPrint('[AGORA_CALL_SERVICE] RtcEngine.initialize() completed successfully.');

    debugPrint('[AGORA_CALL_SERVICE] Registering RtcEngineEventHandler...');
    engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) async {
          if (_isLeaving) return;
          debugPrint(
            '[AGORA_CALL_SERVICE] CALLBACK onJoinChannelSuccess: '
            'channel=${connection.channelId} '
            'localUid=${connection.localUid} '
            'elapsed=$elapsed',
          );

          try {
            debugPrint('[AGORA_CALL_SERVICE] Calling setEnableSpeakerphone(true) inside onJoinChannelSuccess...');
            await engine.setEnableSpeakerphone(true);
            debugPrint('[AGORA_CALL_SERVICE] setEnableSpeakerphone(true) inside onJoinChannelSuccess succeeded.');
          } catch (e, st) {
            debugPrint('[AGORA_CALL_SERVICE] setEnableSpeakerphone(true) inside onJoinChannelSuccess FAILED: $e\n$st');
          }

          if (!_isLeaving) {
            onJoined();
          }
        },

        onUserJoined: (connection, remoteUid, elapsed) async {
          if (_isLeaving) return;
          debugPrint(
            '[AGORA_CALL_SERVICE] CALLBACK onUserJoined: '
            'remoteUid=$remoteUid '
            'channel=${connection.channelId} '
            'elapsed=$elapsed',
          );

          try {
            debugPrint('[AGORA_CALL_SERVICE] Calling muteRemoteAudioStream(uid=$remoteUid, mute=false)...');
            await engine.muteRemoteAudioStream(uid: remoteUid, mute: false);
            debugPrint('[AGORA_CALL_SERVICE] muteRemoteAudioStream succeeded for remoteUid=$remoteUid');
          } catch (e, st) {
            debugPrint('[AGORA_CALL_SERVICE] muteRemoteAudioStream FAILED for remoteUid=$remoteUid: $e\n$st');
          }

          if (!_isLeaving) {
            onRemoteUserJoined(remoteUid);
          }
        },

        onUserOffline: (connection, remoteUid, reason) {
          if (_isLeaving) return;
          debugPrint(
            '[AGORA_CALL_SERVICE] CALLBACK onUserOffline: '
            'remoteUid=$remoteUid '
            'channel=${connection.channelId} '
            'reason=$reason',
          );

          onRemoteUserLeft(remoteUid);
        },

        onConnectionStateChanged: (connection, state, reason) {
          if (_isLeaving) return;
          debugPrint(
            '[AGORA_CALL_SERVICE] CALLBACK onConnectionStateChanged: '
            'channel=${connection.channelId} '
            'state=$state '
            'reason=$reason',
          );
        },

        onLeaveChannel: (connection, stats) {
          debugPrint(
            '[AGORA_CALL_SERVICE] CALLBACK onLeaveChannel: '
            'channel=${connection.channelId} '
            'duration=${stats.duration} '
            'txBytes=${stats.txBytes} '
            'rxBytes=${stats.rxBytes}',
          );
        },

        onAudioVolumeIndication:
            (connection, speakers, speakerNumber, totalVolume) {
              if (_isLeaving) return;
              for (final speaker in speakers) {
                debugPrint(
                  '[AGORA_CALL_SERVICE] CALLBACK onAudioVolumeIndication: '
                  'uid=${speaker.uid} '
                  'volume=${speaker.volume}',
                );

                onAudioVolume(uid: speaker.uid!, volume: speaker.volume ?? 0);
              }
            },

        onAudioSubscribeStateChanged:
            (channel, remoteUid, oldState, newState, elapsed) {
              debugPrint(
                '[AGORA_CALL_SERVICE] CALLBACK onAudioSubscribeStateChanged: '
                'channel=$channel '
                'uid=$remoteUid '
                '$oldState -> $newState',
              );
            },

        onLocalAudioStateChanged: (connection, state, error) {
          debugPrint(
            '[AGORA_CALL_SERVICE] CALLBACK onLocalAudioStateChanged: '
            'channel=${connection.channelId} '
            'state=$state '
            'error=$error',
          );
        },

        onRemoteAudioStateChanged:
            (connection, remoteUid, state, reason, elapsed) {
              debugPrint(
                '[AGORA_CALL_SERVICE] CALLBACK onRemoteAudioStateChanged: '
                'channel=${connection.channelId} '
                'uid=$remoteUid '
                'state=$state '
                'reason=$reason '
                'elapsed=$elapsed',
              );
            },

        onStreamMessage: (connection, remoteUid, streamId, data, length, sentTs) {
          if (_isLeaving) return;
          try {
            final event = _parseStreamMessage(data, remoteUid, uid);
            if (event != null && !_isLeaving) {
              debugPrint(
                '[AGORA_CALL_SERVICE] Transcript event: [${event.role}] turnId=${event.turnId} final=${event.isFinal} text=${event.text}',
              );
              if (onTranscriptEvent != null) {
                onTranscriptEvent(event);
              } else {
                onTranscriptTurn?.call(event.role, event.text);
              }
            }
          } catch (e) {
            debugPrint('[AGORA_CALL_SERVICE] Error handling stream message: $e');
          }
        },

        onError: (err, msg) {
          if (_isLeaving) return;
          debugPrint('[AGORA_CALL_SERVICE] CALLBACK onError: code=$err, msg=$msg');
          onError('$err: $msg');
        },
      ),
    );
    debugPrint('[AGORA_CALL_SERVICE] RtcEngineEventHandler registered.');

    debugPrint('[AGORA_CALL_SERVICE] Calling engine.enableAudio()...');
    await engine.enableAudio();
    debugPrint('[AGORA_CALL_SERVICE] enableAudio() completed successfully.');

    debugPrint('[AGORA_CALL_SERVICE] Calling engine.enableAudioVolumeIndication(interval=200, smooth=3, reportVad=true)...');
    await engine.enableAudioVolumeIndication(
      interval: 200,
      smooth: 3,
      reportVad: true,
    );
    debugPrint('[AGORA_CALL_SERVICE] enableAudioVolumeIndication() completed.');

    debugPrint('[AGORA_CALL_SERVICE] Calling engine.joinChannel(tokenLen=${token.length}, channelId=$channel, uid=$uid)...');
    await engine.joinChannel(
      token: token,
      channelId: channel,
      uid: uid,
      options: const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        publishMicrophoneTrack: true,
        autoSubscribeAudio: true,
      ),
    );
    debugPrint('[AGORA_CALL_SERVICE] joinChannel() invocation returned Future.');
  }

  Future<void> setMicEnabled(bool enabled) async {
    final engine = _engine;
    _micEnabled = enabled;

    if (engine == null) {
      debugPrint('[AGORA_CALL_SERVICE] setMicEnabled($enabled) ignored: _engine is null');
      return;
    }

    debugPrint('[AGORA_CALL_SERVICE] Calling muteLocalAudioStream(${!enabled})...');
    await engine.muteLocalAudioStream(!enabled);

    debugPrint('[AGORA_CALL_SERVICE] MIC ${enabled ? 'ENABLED' : 'DISABLED'}');
  }

  Future<void> setSpeakerphoneEnabled(bool enabled) async {
    final engine = _engine;

    if (engine == null) {
      debugPrint('[AGORA_CALL_SERVICE] setSpeakerphoneEnabled($enabled) ignored: _engine is null');
      return;
    }

    try {
      debugPrint('[AGORA_CALL_SERVICE] Calling setEnableSpeakerphone($enabled)...');
      await engine.setEnableSpeakerphone(enabled);
      debugPrint('[AGORA_CALL_SERVICE] SPEAKERPHONE ${enabled ? 'ENABLED' : 'DISABLED'}');
    } catch (e, st) {
      debugPrint('[AGORA_CALL_SERVICE] setEnableSpeakerphone($enabled) FAILED: $e\n$st');
    }
  }

  /// Controls local playback of remote audio streams.
  /// Muting the speaker silences incoming audio locally on this device/tab without
  /// affecting the local microphone or changing audio for other participants.
  Future<void> setSpeakerEnabled(bool enabled) async {
    final engine = _engine;
    _speakerEnabled = enabled;

    if (engine == null) {
      debugPrint('[AGORA_CALL_SERVICE] setSpeakerEnabled($enabled) ignored: _engine is null');
      return;
    }

    try {
      debugPrint('[AGORA_CALL_SERVICE] Calling muteAllRemoteAudioStreams(${!enabled}) and adjustPlaybackSignalVolume(${enabled ? 100 : 0})...');
      await engine.muteAllRemoteAudioStreams(!enabled);
      await engine.adjustPlaybackSignalVolume(enabled ? 100 : 0);
      debugPrint('[AGORA_CALL_SERVICE] REMOTE PLAYBACK ${enabled ? 'ENABLED' : 'MUTED'}');
    } catch (e, st) {
      debugPrint('[AGORA_CALL_SERVICE] setSpeakerEnabled($enabled) FAILED: $e\n$st');
    }
  }

  /// Enumerates available audio recording (microphone) devices where supported.
  Future<List<AgoraAudioDevice>> getRecordingDevices() async {
    final engine = _engine;
    if (engine == null) return const [];
    try {
      final dm = engine.getAudioDeviceManager();
      final devices = await dm.enumerateRecordingDevices();
      return devices
          .where((d) => (d.deviceId ?? '').isNotEmpty)
          .map((d) => AgoraAudioDevice(
                id: d.deviceId!,
                name: (d.deviceName ?? '').isNotEmpty ? d.deviceName! : 'Microphone (${d.deviceId})',
              ))
          .toList();
    } catch (e) {
      debugPrint('[AGORA_CALL_SERVICE] getRecordingDevices notice: $e');
      return const [];
    }
  }

  /// Enumerates available audio playback (speaker/output) devices where supported.
  Future<List<AgoraAudioDevice>> getPlaybackDevices() async {
    final engine = _engine;
    if (engine == null) return const [];
    try {
      final dm = engine.getAudioDeviceManager();
      final devices = await dm.enumeratePlaybackDevices();
      return devices
          .where((d) => (d.deviceId ?? '').isNotEmpty)
          .map((d) => AgoraAudioDevice(
                id: d.deviceId!,
                name: (d.deviceName ?? '').isNotEmpty ? d.deviceName! : 'Speaker (${d.deviceId})',
              ))
          .toList();
    } catch (e) {
      debugPrint('[AGORA_CALL_SERVICE] getPlaybackDevices notice: $e');
      return const [];
    }
  }

  /// Selects the audio recording (microphone) device.
  Future<bool> setRecordingDevice(String deviceId) async {
    final engine = _engine;
    if (engine == null) return false;
    try {
      final dm = engine.getAudioDeviceManager();
      await dm.setRecordingDevice(deviceId);
      debugPrint('[AGORA_CALL_SERVICE] Selected recording device: $deviceId');
      return true;
    } catch (e) {
      debugPrint('[AGORA_CALL_SERVICE] setRecordingDevice failed: $e');
      return false;
    }
  }

  /// Selects the audio playback (speaker/output) device.
  Future<bool> setPlaybackDevice(String deviceId) async {
    final engine = _engine;
    if (engine == null) return false;
    try {
      final dm = engine.getAudioDeviceManager();
      await dm.setPlaybackDevice(deviceId);
      debugPrint('[AGORA_CALL_SERVICE] Selected playback device: $deviceId');
      return true;
    } catch (e) {
      debugPrint('[AGORA_CALL_SERVICE] setPlaybackDevice failed: $e');
      return false;
    }
  }

  AgoraTranscriptEvent? _parseStreamMessage(Uint8List data, int remoteUid, int localUid) {
    String raw;
    try {
      raw = utf8.decode(data, allowMalformed: true);
    } catch (_) {
      return null;
    }

    String? jsonStr;

    // Check for Agora multi-part chunk format: <message_id>|<part_index>|<total_parts>|<base64_data>
    if (raw.contains('|')) {
      final parts = raw.split('|');
      if (parts.length >= 4) {
        final messageId = parts[0];
        final partIndex = int.tryParse(parts[1]);
        final totalParts = int.tryParse(parts[2]);
        final base64Chunk = parts.sublist(3).join('|');

        if (partIndex != null && totalParts != null && partIndex >= 1 && totalParts >= 1) {
          final buffer = _multipartBuffer.putIfAbsent(messageId, () => <int, String>{});
          buffer[partIndex] = base64Chunk;

          if (buffer.length == totalParts) {
            final sortedChunks = <String>[];
            for (var i = 1; i <= totalParts; i++) {
              if (buffer.containsKey(i)) {
                sortedChunks.add(buffer[i]!);
              }
            }
            _multipartBuffer.remove(messageId);

            if (sortedChunks.length == totalParts) {
              var fullBase64 = sortedChunks.join('');
              final rem = fullBase64.length % 4;
              if (rem != 0) {
                fullBase64 += '=' * (4 - rem);
              }
              try {
                final decodedBytes = base64Decode(fullBase64);
                jsonStr = utf8.decode(decodedBytes, allowMalformed: true);
              } catch (e) {
                debugPrint('[AGORA_CALL_SERVICE] Base64 decode failed for message $messageId: $e');
              }
            }
          } else {
            // Still waiting for remaining parts of this multi-part message
            return null;
          }
        }
      }
    }

    if (jsonStr == null) {
      // Check if it's direct JSON
      final trimmed = raw.trim();
      if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
        jsonStr = trimmed;
      }
    }

    if (jsonStr == null) {
      // Not a valid JSON payload or pending multipart - discard! NEVER treat raw bytes as transcript!
      return null;
    }

    try {
      final parsed = jsonDecode(jsonStr);
      if (parsed is! Map<String, dynamic>) {
        return null;
      }

      final objectType = (parsed['object'] ?? '').toString().toLowerCase();
      // Ignore internal protocol events (e.g. message.state, agent.state, ping)
      if (objectType == 'message.state' || objectType == 'agent.state' || objectType == 'ping') {
        return null;
      }

      String role;
      if (objectType == 'user.transcription') {
        role = 'candidate';
      } else if (objectType == 'assistant.transcription') {
        role = 'interviewer';
      } else if (parsed.containsKey('role')) {
        final r = parsed['role'].toString().toLowerCase();
        role = (r == 'user' || r == 'candidate') ? 'candidate' : 'interviewer';
      } else {
        // Fallback based on UID if objectType is generic transcription
        role = (remoteUid == localUid || remoteUid == 0) ? 'candidate' : 'interviewer';
      }

      final text = (parsed['text'] ?? parsed['content'] ?? parsed['message'] ?? '').toString().trim();
      if (text.isEmpty) {
        return null;
      }

      int? turnId;
      if (parsed['turn_id'] is num) {
        turnId = (parsed['turn_id'] as num).toInt();
      } else if (parsed['turn_seq_id'] is num) {
        turnId = (parsed['turn_seq_id'] as num).toInt();
      } else if (parsed['turnId'] is num) {
        turnId = (parsed['turnId'] as num).toInt();
      } else if (parsed['turnSeqId'] is num) {
        turnId = (parsed['turnSeqId'] as num).toInt();
      }

      final turnStatusStr = parsed['turn_status']?.toString().toUpperCase();
      final finalFlag = parsed['final'];
      final isEndStatus = turnStatusStr == 'END' ||
          turnStatusStr == '1' ||
          turnStatusStr == 'INTERRUPTED' ||
          turnStatusStr == '2';
      final isInProgress = turnStatusStr == 'IN_PROGRESS' ||
          turnStatusStr == '0' ||
          finalFlag == false;

      bool isFinal;
      if (finalFlag == true || isEndStatus) {
        isFinal = true;
      } else if (isInProgress) {
        isFinal = false;
      } else {
        isFinal = true;
      }

      final messageId = parsed['message_id']?.toString() ?? parsed['msg_id']?.toString();

      return AgoraTranscriptEvent(
        role: role,
        text: text,
        turnId: turnId,
        isFinal: isFinal,
        messageId: messageId,
      );
    } catch (e) {
      debugPrint('[AGORA_CALL_SERVICE] Error parsing JSON transcript: $e');
      return null;
    }
  }

  Future<void> leave() async {
    debugPrint('[AGORA_CALL_SERVICE] leave() called! _engine is ${_engine == null ? 'NULL' : 'ACTIVE'}');
    _isLeaving = true;
    _multipartBuffer.clear();
    final engine = _engine;
    _engine = null;

    if (engine == null) {
      debugPrint('[AGORA_CALL_SERVICE] leave() aborted: _engine already null');
      return;
    }

    try {
      debugPrint('[AGORA_CALL_SERVICE] Calling engine.leaveChannel()...');
      await engine.leaveChannel();
      debugPrint('[AGORA_CALL_SERVICE] engine.leaveChannel() completed.');
    } catch (e) {
      debugPrint('[AGORA_CALL_SERVICE] engine.leaveChannel() exception (handled): $e');
    }

    try {
      debugPrint('[AGORA_CALL_SERVICE] Calling engine.release()...');
      await engine.release();
      debugPrint('[AGORA_CALL_SERVICE] engine.release() completed.');
    } catch (e) {
      debugPrint('[AGORA_CALL_SERVICE] engine.release() exception (handled): $e');
    }

    _micEnabled = true;
    debugPrint('[AGORA_CALL_SERVICE] leave() cleanup finished cleanly.');
  }
}
