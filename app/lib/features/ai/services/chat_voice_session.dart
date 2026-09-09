import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'voice_asr.dart';
import 'voice_recorder.dart';

/// Shared recording and offline-ASR lifecycle for single and group chat.
///
/// Gesture state and timers stay in each page because they drive UI feedback;
/// recorder/model ownership and temporary-file cleanup live here.
class ChatVoiceSession {
  ChatVoiceSession({VoiceRecorder? recorder, VoiceAsr? asr})
      : _recorder = recorder ?? VoiceRecorder(),
        _asr = asr ?? VoiceAsr();

  final VoiceRecorder _recorder;
  final VoiceAsr _asr;

  Future<bool> ensurePermission() => _recorder.ensurePermission();

  Future<String> start() async {
    final dir = await getApplicationDocumentsDirectory();
    final path =
        '${dir.path}/chat_audio/${DateTime.now().millisecondsSinceEpoch}.wav';
    await File(path).parent.create(recursive: true);
    await _recorder.start(path);
    return path;
  }

  Future<void> stop() async {
    await _recorder.stop();
  }

  Future<void> cancel({String? path}) async {
    try {
      await _recorder.cancel();
    } finally {
      await deleteTemporaryFile(path);
    }
  }

  Future<void> deleteTemporaryFile(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } on Object {
      // Temporary-file cleanup is best effort.
    }
  }

  Future<bool> isAsrReady() => _asr.isReady();

  Future<void> ensureAsrModel() => _asr.ensureModel();

  Future<String> transcribe(String path) => _asr.transcribe(path);

  Future<void> dispose() => _recorder.dispose();
}
