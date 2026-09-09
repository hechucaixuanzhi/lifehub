// ASR 冒烟测试（宿主 Windows 上跑真实链路，非 CI 常跑）。
//
// 覆盖 S2 从未真正执行过的关键路径：
//   1) 真实从 hf-mirror 下载 4 个模型文件（Dart http 走 302/307 重定向 → 200）
//   2) sherpa_onnx OnlineRecognizer 真加载 zipformer 模型（onnxruntime 初始化）
//   3) 16k mono wav → 整段喂流 → 解码不崩溃（正弦波识别结果可为空，不 assert 内容）
//   4) VoiceAsr 生产代码路径（注入 modelDirProvider 绕开 path_provider）
//
// 默认跳过（网络+55MB 下载）；宿主冒烟时：
//   flutter test test/voice_asr_smoke_test.dart --dart-define=ASR_SMOKE=true
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:lifehub/features/ai/services/voice_asr.dart';

const _enabled = bool.fromEnvironment('ASR_SMOKE');

void main() {
  test('ASR: hf-mirror 下载模型 + 真加载 + 转写正弦 wav 不崩溃', () async {
    final dir = await Directory.systemTemp.createTemp('lh_asr_smoke_');
    final asr = VoiceAsr(modelDirProvider: () async => dir.path);
    try {
      await asr.ensureModel();
      expect(await asr.isReady(), isTrue,
          reason: '4 个模型文件应下载齐全');
      // 1s 440Hz 正弦 wav：只验证加载/解码链路，不验证转写内容
      final wavPath = '${dir.path}/tone.wav';
      await File(wavPath).writeAsBytes(_sineWavBytes(seconds: 1.0));
      final text = await asr.transcribe(wavPath);
      expect(text, isA<String>());
      // 连测两次：verify 并发去重/模型复用不炸
      final text2 = await asr.transcribe(wavPath);
      expect(text2, isA<String>());
    } finally {
      try {
        await dir.delete(recursive: true);
      } catch (_) {}
    }
  }, skip: _enabled ? false : '宿主冒烟测试：flutter test --dart-define=ASR_SMOKE=true');
}

/// 16k mono PCM16 正弦波 wav（RIFF 标准头）。
Uint8List _sineWavBytes({required double seconds}) {
  const sr = 16000;
  final n = (sr * seconds).round();
  final dataSize = n * 2;
  final b = ByteData(44 + dataSize);
  void w4(int o, int v) => b.setUint32(o, v, Endian.little);
  void w2(int o, int v) => b.setUint16(o, v, Endian.little);
  b.setUint8(0, 0x52); b.setUint8(1, 0x49); b.setUint8(2, 0x46); b.setUint8(3, 0x46); // RIFF
  w4(4, 36 + dataSize);
  b.setUint8(8, 0x57); b.setUint8(9, 0x41); b.setUint8(10, 0x56); b.setUint8(11, 0x45); // WAVE
  b.setUint8(12, 0x66); b.setUint8(13, 0x6d); b.setUint8(14, 0x74); b.setUint8(15, 0x20); // fmt
  w4(16, 16); // fmt chunk size
  w2(20, 1); // PCM
  w2(22, 1); // mono
  w4(24, sr);
  w4(28, sr * 2); // byteRate
  w2(32, 2); // blockAlign
  w2(34, 16); // bits
  b.setUint8(36, 0x64); b.setUint8(37, 0x61); b.setUint8(38, 0x74); b.setUint8(39, 0x61); // data
  w4(40, dataSize);
  for (var i = 0; i < n; i++) {
    final v = (12000 * math.sin(2 * math.pi * 440 * i / sr)).round();
    w2(44 + i * 2, v);
  }
  return b.buffer.asUint8List();
}
