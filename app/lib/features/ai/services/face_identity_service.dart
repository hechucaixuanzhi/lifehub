import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../../../core/network/api_client.dart';
import 'face_align.dart';

/// 自我识别（#133，设计稿 docs/DESIGN_SELF_IDENTITY.md）—— 前端本地「检测 + embedding」。
///
/// 核心原则：**LLM 不负责认脸**。本服务只产出结构化事实，后端纯 stdlib 比对三态，
/// 结果由调用方透传给 /ai/chat 注入人格回应。图片不出手机（不上传原图给识别）。
///
/// 链路（全部本地，除最后一步比对）：
///   1. ML Kit FaceDetection —— 只检测：人脸框/微笑/头部角度（不提供 embedding）
///   2. tflite_flutter 跑 mobile_face_net.tflite（assets，192d）—— 逐脸提取 embedding
///   3. POST /ai/self-identity/check —— 后端与身份库做余弦相似度 → 三态 SELF/POSSIBLE_SELF/UNKNOWN
///
/// 兜底：无脸 / 检测或推理异常 / 网络失败 / 身份库未导入（gallery_size=0）
/// → 一律返回 null，调用方降级为普通图片描述（设计稿 §7）。
class FaceIdentityService {
  FaceIdentityService(this._api);

  final ApiClient _api;

  static const String _modelAsset = 'assets/models/mobile_face_net.tflite';
  static const int _inputSize = 112; // mobile_face_net 输入 112×112×3 RGB
  static const int _embedDim = 192; // 实测输出（对齐后端 self_identity.EMBED_DIM）
  static const int _maxFaces = 5; // 合影最多逐脸识别 5 张，防大请求

  FaceDetector? _detector;
  Interpreter? _interpreter;
  Future<void>? _initFuture;

  /// 懒初始化（并发去重）：ML Kit 检测器 + tflite embedding 模型。
  Future<void> _ensureInit() async {
    if (_initFuture != null) return _initFuture!;
    _initFuture = () async {
      _detector = FaceDetector(
        options: FaceDetectorOptions(
          performanceMode: FaceDetectorMode.fast,
          enableClassification: true, // 微笑概率（appearance_summary）
          enableLandmarks: true, // 5 点关键点（对齐 embedding 用）
        ),
      );
      _interpreter = await Interpreter.fromAsset(_modelAsset);
    }();
    return _initFuture!;
  }

  /// 分析一张图 → 后端三态结构化结果（可直接作 /ai/chat 的 self_identity 字段）。
  /// 不可识别 / 未导入身份库 → null（调用方降级普通图片描述）。
  Future<Map<String, dynamic>?> analyze(Uint8List bytes) async {
    try {
      final r = await _detectAndEmbed(bytes);
      if (r == null) return null;
      final resp = await _api.post('/ai/self-identity/check', {
        'faces': [for (final e in r.embeddings) {'embedding': e}],
        if (r.summary.isNotEmpty) 'appearance_summary': r.summary,
      });
      if (resp.statusCode != 200) return null;
      final result = jsonDecode(resp.body) as Map<String, dynamic>;
      // 身份库未导入（gallery_size=0）：UNKNOWN 无信息量，降级不注入
      if ((result['gallery_size'] as num? ?? 0) == 0) return null;
      return result;
    } on Object catch (e) {
      debugPrint('[face-identity] analyze failed: $e');
      return null;
    }
  }

  /// 提取图内人脸 embedding（导入身份库 / 校准用），不含后端比对。无脸/失败 → null。
  Future<List<List<double>>?> embedFaces(Uint8List bytes) async {
    final r = await _detectAndEmbed(bytes);
    return r?.embeddings;
  }

  /// 检测 + 逐脸 embedding 共用管线：解码 → EXIF 对齐 → ML Kit 检测 → tflite 提取。
  /// 无脸 / 解码失败 / 推理失败 → null。
  Future<_FaceEmbedResult?> _detectAndEmbed(Uint8List bytes) async {
    File? tmp;
    try {
      await _ensureInit();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;
      img.bakeOrientation(decoded); // 应用 EXIF 旋转 → 与 ML Kit 直立坐标对齐

      // ML Kit fromFilePath：自行解码 + 处理旋转；Android fromBytes 仅收 YUV，
      // RGB/BGRA 走不了 → 落临时文件最稳（检测坐标返回直立空间，与 baked 解码图一致）。
      tmp = File('${(await getTemporaryDirectory()).path}/'
          'lh_face_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tmp.writeAsBytes(bytes, flush: true);
      final input = InputImage.fromFilePath(tmp.path);
      final faces = await _detector!.processImage(input);
      if (faces.isEmpty) return null; // 无脸 → 普通图片描述

      // 逐脸提取 embedding（前 _maxFaces 张，按左→右稳定序）；
    // 单脸失败跳过不拖垮整批（坏脸/极端姿态只丢一张）
      final embeddings = <List<double>>[];
      final summary = _appearanceSummary(faces);
      final sorted = [...faces]
        ..sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));
      for (final f in sorted.take(_maxFaces)) {
        try {
          final emb = _embedFace(decoded, f);
          if (emb != null) embeddings.add(emb);
        } on Object catch (e) {
          debugPrint('[face-identity] embed face failed: $e');
        }
      }
      if (embeddings.isEmpty) return null;
      return _FaceEmbedResult(embeddings, summary);
    } on Object catch (e) {
      debugPrint('[face-identity] detect/embed failed: $e');
      return null;
    } finally {
      try {
        tmp?.deleteSync();
      } on Object catch (_) {}
    }
  }

  /// 单脸 → 关键点对齐到 112×112 → RGB 归一化 [-1,1] → tflite → L2 归一化 192d。
  /// 对齐（face_align）让 MobileFaceNet 拿到训练时的 canonical 姿态；关键点缺失时
  /// 回退到「人脸框 + 20% 边距」裁剪，保证不崩。
  List<double>? _embedFace(img.Image full, Face face) {
    img.Image? crop;
    final landmarks = _facePoints(face);
    if (landmarks != null) {
      crop = alignFaceToCanonical(full, landmarks, size: _inputSize);
    }
    if (crop == null) {
      final b = face.boundingBox;
      var x = b.left.floor().clamp(0, full.width - 1);
      var y = b.top.floor().clamp(0, full.height - 1);
      var w = b.width.ceil().clamp(1, full.width - x);
      var h = b.height.ceil().clamp(1, full.height - y);
      final pad = math.min((w * 0.2).round(), x);
      x = x - pad;
      y = math.max(0, y - pad);
      w = math.min(full.width - x, w + pad * 2);
      h = math.min(full.height - y, h + pad * 2);
      crop = img.copyCrop(full, x: x, y: y, width: w, height: h);
      crop = img.copyResize(crop, width: _inputSize, height: _inputSize);
    }
    final pixels = crop.getBytes(order: img.ChannelOrder.rgb);

    // 输入必须是 4 维张量 [1,112,112,3]：扁平 Float32List 会被当成 1 维 →
    // CONV_2D 报 input->dims->size != 4 → 用嵌套 List 保留形状（实测修复）。
    final input = List.generate(
      1,
      (_) => List.generate(
        _inputSize,
        (_) => List.generate(
          _inputSize,
          (_) => List<double>.filled(3, 0.0),
        ),
      ),
    );
    var idx = 0;
    for (var i = 0; i < _inputSize; i++) {
      for (var j = 0; j < _inputSize; j++) {
        for (var c = 0; c < 3; c++) {
          input[0][i][j][c] = (pixels[idx++] - 127.5) / 127.5; // 模型要求 [-1,1]
        }
      }
    }
    // 输出 [1,192]，同样用嵌套 List
    final output = List.generate(1, (_) => List<double>.filled(_embedDim, 0.0));
    _interpreter!.run(input, output);
    final vec = output[0];

    // L2 归一化：MobileFaceNet 输出余弦相似度等价，归一化保证与库内向量一致
    var norm = 0.0;
    for (final x in vec) {
      norm += x * x;
    }
    norm = math.sqrt(norm);
    if (norm == 0) return null;
    return [for (final x in vec) x / norm];
  }

  /// ML Kit 5 点关键点（双眼/鼻尖/嘴角），缺任一 → null（走 bbox 裁剪兜底）。
  /// 坐标空间 = ML Kit 直立坐标 = bakeOrientation 后的解码图，与 boundingBox 一致。
  List<math.Point<double>>? _facePoints(Face face) {
    const types = [
      FaceLandmarkType.leftEye,
      FaceLandmarkType.rightEye,
      FaceLandmarkType.noseBase,
      FaceLandmarkType.leftMouth,
      FaceLandmarkType.rightMouth,
    ];
    final pts = <math.Point<double>>[];
    for (final t in types) {
      final lm = face.landmarks[t];
      if (lm == null) return null;
      pts.add(math.Point<double>(lm.position.x.toDouble(), lm.position.y.toDouble()));
    }
    return pts;
  }

  /// 轻量外观摘要（设计稿 §4.2 appearance_summary）：角度 + 表情，纯规则不走模型。
  String _appearanceSummary(List<Face> faces) {
    final parts = <String>[];
    final f = faces.first;
    final yaw = f.headEulerAngleY ?? 0;
    parts.add(yaw.abs() < 15
        ? 'angle=front'
        : (yaw.abs() < 40 ? 'angle=three-quarter' : 'angle=side-profile'));
    final smile = f.smilingProbability;
    if (smile != null) parts.add(smile > 0.5 ? 'expression=smiling' : 'expression=neutral');
    return parts.join(' / ');
  }

  /// 释放原生资源（页面 dispose 时调用；未初始化则无需）。
  void dispose() {
    _detector?.close();
    try {
      _interpreter?.close();
    } on Object catch (_) {}
  }
}

/// 检测 + embedding 管线结果（供 analyze 比对 / 导入身份库 / 校准共用）。
class _FaceEmbedResult {
  const _FaceEmbedResult(this.embeddings, this.summary);
  final List<List<double>> embeddings;
  final String summary;
}
