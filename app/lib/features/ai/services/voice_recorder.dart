import 'package:record/record.dart';

/// 语音录音封装（S2）：record 插件。
/// 录成 wav PCM16 16k 单声道——同一文件直接喂 sherpa ASR + just_audio 播放，
/// 无需转码。录音路径由调用方指定（文档目录 chat_audio/xxx.wav）。
class VoiceRecorder {
  final AudioRecorder _recorder = AudioRecorder();

  /// 请求并返回麦克风权限（Android 首呼弹系统授权框）。
  Future<bool> ensurePermission() => _recorder.hasPermission();

  /// 开始录音到 [path]（wav PCM16 16k mono）。
  Future<void> start(String path) => _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: path,
      );

  /// 停止录音并落盘，返回文件路径（record 返回 Future<String?>）。
  Future<String?> stop() => _recorder.stop();

  /// 取消录音：丢弃本次录音（不落盘），下次 start 可继续。
  Future<void> cancel() => _recorder.cancel();

  Future<void> dispose() => _recorder.dispose();
}
