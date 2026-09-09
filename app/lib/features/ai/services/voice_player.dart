import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

/// 语音播放单例（S2）：just_audio，同一时刻只播一条语音。
/// 全局唯一 → 聊天页间共享，点新语音自动顶掉上一条（微信行为）。
///
/// just_audio 无 AudioSource.bytes → 把内存字节落临时 wav 文件再播
/// （wav 为 PCM，ExoPlayer 原生解码）。内容不可变，同一 id 只写一次。
///
/// [playingId]/[position]/[duration] 用 ChangeNotifier 广播，
/// VoiceBubble 据此驱动播放/暂停图标、波形动画与进度遮罩。
class VoicePlayer extends ChangeNotifier {
  VoicePlayer._() {
    _player.positionStream.listen((p) {
      _position = p;
      notifyListeners();
    });
    _player.durationStream.listen((d) {
      _duration = d;
      notifyListeners();
    });
    _player.playerStateStream.listen((s) {
      _isPlaying = s.playing;
      if (s.processingState == ProcessingState.completed) {
        // 自然播完：清当前音源，等下次点按从头播（微信行为）
        _currentId = null;
        _isPlaying = false;
        _position = Duration.zero;
      }
      notifyListeners();
    });
  }

  static final VoicePlayer instance = VoicePlayer._();

  final AudioPlayer _player = AudioPlayer();

  String? _currentId; // 当前已加载音源 id（本地临时 id / media_asset_id）
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration? _duration;
  Directory? _tempDir;
  final Map<String, String> _pathCache = {};

  String? get playingId => _currentId;
  bool get isPlaying => _isPlaying;
  Duration get position => _position;
  Duration? get duration => _duration;

  bool isLoaded(String id) => _currentId == id;
  bool isPlayingFor(String id) => _currentId == id && _isPlaying;

  /// 内存字节 → 临时 wav 路径（同一 id 只写一次，内容不可变）。
  Future<String> _resolvePath(String id, List<int> bytes) async {
    final cached = _pathCache[id];
    if (cached != null && File(cached).existsSync()) return cached;
    final dir = _tempDir ??= await getTemporaryDirectory();
    final safe = id.replaceAll(RegExp(r'[^\w.-]'), '_');
    final isWav = bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46;
    final path = '${dir.path}/lh_voice_$safe.${isWav ? 'wav' : 'mp3'}';
    await File(path).writeAsBytes(bytes, flush: true);
    _pathCache[id] = path;
    return path;
  }

  /// 播放/暂停切换：同一条语音 → 暂停/继续；不同 → 顶掉旧源播新的。
  Future<void> toggle(String id, List<int> bytes) async {
    if (_currentId == id) {
      if (_isPlaying) {
        await _player.pause();
      } else {
        await _player.play();
      }
      return;
    }
    try {
      await _player.stop();
      final path = await _resolvePath(id, bytes);
      await _player.setAudioSource(AudioSource.file(path, tag: id),
          preload: true);
      _currentId = id;
      _position = Duration.zero;
      notifyListeners();
      await _player.play();
    } catch (e) {
      // 解码/播放失败：静默复位，不打断聊天
      debugPrint('[voice] play failed: $e');
      _currentId = null;
      _isPlaying = false;
      notifyListeners();
    }
  }

  /// 离开聊天页时停播（防止切走仍在响）。
  Future<void> stopAll() async {
    _currentId = null;
    _isPlaying = false;
    _position = Duration.zero;
    notifyListeners();
    try {
      await _player.stop();
    } catch (_) {}
  }
}

/// 全局语音播放器单例（聊天页 + 语音气泡共用）。
final voicePlayer = VoicePlayer.instance;
