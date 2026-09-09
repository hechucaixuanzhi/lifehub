import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

/// 离线中文 ASR（S2）：sherpa_onnx 流式 zipformer（zh-14M），
/// 本地识别、不联网不出隐私。模型首次使用时下载到应用支持目录，之后秒载。
///
/// 下载策略（实测调整）：GitHub 在国内网络常超时 → **hf-mirror 单文件直下优先**
/// （hf-mirror 有该模型的 encoder/decoder/joiner/tokens，实测 200/206）；
/// GitHub Release 整包 tar.bz2 只作兜底（国外网络更稳）。
///
/// 推理在后台 isolate 跑（compute），避免长语音解码卡住 UI 线程。
/// 识别失败/模型下载失败 → 返回空串，调用方仍发语音（转写留空）。
class VoiceAsr {
  static const _modelName = 'sherpa-onnx-streaming-zipformer-zh-14M-2023-02-23';
  static const _files = [
    'encoder-epoch-99-avg-1.onnx',
    'decoder-epoch-99-avg-1.onnx',
    'joiner-epoch-99-avg-1.onnx',
    'tokens.txt',
  ];
  static const _mirrorBase =
      'https://hf-mirror.com/csukuangfj/$_modelName/resolve/main';
  static const _tarballUrl =
      'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/'
      '$_modelName.tar.bz2';

  Future<void>? _ensureFuture; // 并发去重：多次调用共享同一次下载

  /// 测试/宿主注入模型目录（`flutter test` 无 path_provider）。空 → 走默认应用支持目录。
  final Future<String> Function()? _modelDirProvider;
  VoiceAsr({Future<String> Function()? modelDirProvider})
      : _modelDirProvider = modelDirProvider;

  Future<String> _modelDirPath() async {
    final p = _modelDirProvider;
    if (p != null) {
      final dir = Directory(await p());
      if (!dir.existsSync()) dir.createSync(recursive: true);
      return dir.path;
    }
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/asr_models/$_modelName');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir.path;
  }

  bool _modelReady(String dir) => _files.every((f) => File('$dir/$f').existsSync());

  /// 模型是否已就绪（已下载）。未就绪返回 false，调用方先 ensureModel。
  Future<bool> isReady() async => _modelReady(await _modelDirPath());

  /// 确保模型就绪：已就绪直接返回；否则下载（hf-mirror 单文件 → GitHub 兜底）。
  /// 并发调用共享同一次下载；失败清缓存，下次可重试。失败抛异常（调用方兜底仍发语音）。
  Future<void> ensureModel() async {
    try {
      return await (_ensureFuture ??= _doEnsureModel());
    } catch (e) {
      _ensureFuture = null; // 失败不缓存：下次调用可重试
      rethrow;
    }
  }

  Future<void> _doEnsureModel() async {
    final dir = await _modelDirPath();
    if (_modelReady(dir)) return;
    Object? lastErr;
    try {
      await _downloadFilesFromMirror(dir);
      if (_modelReady(dir)) return;
    } on Object catch (e) {
      lastErr = e;
      debugPrint('[asr] hf-mirror 下载失败: $e');
    }
    try {
      await _downloadTarball(dir);
      if (_modelReady(dir)) return;
    } on Object catch (e) {
      lastErr = e;
      debugPrint('[asr] GitHub 下载失败: $e');
    }
    throw StateError('语音识别模型下载失败: $lastErr');
  }

  /// hf-mirror 单文件直下（国内可达，实测 200/206）。
  Future<void> _downloadFilesFromMirror(String dir) async {
    for (final f in _files) {
      final resp = await http
          .get(Uri.parse('$_mirrorBase/$f'))
          .timeout(const Duration(minutes: 4));
      if (resp.statusCode != 200) {
        throw StateError('$f HTTP ${resp.statusCode}');
      }
      await File('$dir/$f').writeAsBytes(resp.bodyBytes, flush: true);
    }
    debugPrint('[asr] 模型下载完成（hf-mirror，${_files.length} 个文件）');
  }

  /// GitHub Release 整包 tar.bz2（国外网络兜底）→ bz2 解压 → tar 解包。
  Future<void> _downloadTarball(String dir) async {
    final resp = await http
        .get(Uri.parse(_tarballUrl))
        .timeout(const Duration(minutes: 4));
    if (resp.statusCode != 200) {
      throw StateError('tar.bz2 HTTP ${resp.statusCode}');
    }
    final tarBytes = BZip2Decoder().decodeBytes(resp.bodyBytes);
    final tar = TarDecoder().decodeBytes(tarBytes);
    for (final f in tar.files) {
      if (!f.isFile) continue;
      final name = f.name.split('/').last; // 剥顶层目录，取 basename
      if (name.isEmpty) continue;
      await File('$dir/$name').writeAsBytes(f.content, flush: true);
    }
    debugPrint('[asr] 模型解包完成（GitHub tar.bz2）');
  }

  /// 转写 wav（16k mono PCM16）→ 文字。失败返回空串，不抛。
  Future<String> transcribe(String wavPath) async {
    if (wavPath.isEmpty || !File(wavPath).existsSync()) return '';
    final dir = await _modelDirPath();
    if (!_modelReady(dir)) return '';
    try {
      return await compute(_recognizeInIsolate, _TranscribeArgs(dir, wavPath));
    } on Object catch (e) {
      debugPrint('[asr] transcribe failed: $e');
      return '';
    }
  }
}

class _TranscribeArgs {
  const _TranscribeArgs(this.modelDir, this.wavPath);
  final String modelDir;
  final String wavPath;
}

/// 后台 isolate 内跑完整识别（sherpa_onnx 走 dart:ffi，任意 isolate 可用）。
/// 注意：Dart 静态变量按 isolate 隔离 → 每个新 isolate 都要 initBindings()，
/// 否则 FFI 函数指针为 null 抛「Please initialize sherpa-onnx first」。
String _recognizeInIsolate(_TranscribeArgs a) {
  sherpa.initBindings();
  final rec = sherpa.OnlineRecognizer(
    sherpa.OnlineRecognizerConfig(
      model: sherpa.OnlineModelConfig(
        tokens: '${a.modelDir}/tokens.txt',
        numThreads: 2,
        provider: 'cpu',
        debug: false,
        modelType: 'zipformer',
        transducer: sherpa.OnlineTransducerModelConfig(
          encoder: '${a.modelDir}/encoder-epoch-99-avg-1.onnx',
          decoder: '${a.modelDir}/decoder-epoch-99-avg-1.onnx',
          joiner: '${a.modelDir}/joiner-epoch-99-avg-1.onnx',
        ),
      ),
      decodingMethod: 'greedy_search',
      maxActivePaths: 4,
      enableEndpoint: false, // 整段喂入再解码，不让端点规则提前截断
    ),
  );
  final stream = rec.createStream();
  try {
    final samples = _wavToFloat32(File(a.wavPath).readAsBytesSync());
    if (samples.isEmpty) return '';
    stream.acceptWaveform(samples: samples, sampleRate: 16000);
    stream.inputFinished();
    while (rec.isReady(stream)) {
      rec.decode(stream);
    }
    return rec.getResult(stream).text.trim();
  } finally {
    try {
      stream.free();
    } catch (_) {}
    try {
      rec.free();
    } catch (_) {}
  }
}

/// wav → Float32List(-1..1)：RIFF 子块遍历定位 data，兼容插了 LIST 的 wav。
Float32List _wavToFloat32(Uint8List b) {
  if (b.length < 44 || b[0] != 0x52 || b[1] != 0x49 || b[2] != 0x46 || b[3] != 0x46) {
    return Float32List(0);
  }
  int pos = 12;
  var dataOffset = -1;
  var dataSize = 0;
  final bd = ByteData.sublistView(b);
  while (pos + 8 <= b.length) {
    final cid = String.fromCharCodes(b.sublist(pos, pos + 4));
    final csize = bd.getUint32(pos + 4, Endian.little);
    if (cid == 'data') {
      dataOffset = pos + 8;
      dataSize = csize;
      break;
    }
    pos += 8 + csize + (csize & 1); // 子块按偶数对齐
  }
  if (dataOffset < 0) return Float32List(0);
  if (dataOffset + dataSize > b.length) {
    dataSize = b.length - dataOffset;
  }
  final n = dataSize ~/ 2;
  final out = Float32List(n);
  for (var i = 0; i < n; i++) {
    out[i] = bd.getInt16(dataOffset + i * 2, Endian.little) / 32768.0;
  }
  return out;
}
