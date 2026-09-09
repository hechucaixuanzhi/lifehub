import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth/device_key_pair.dart';
import 'api_config.dart';

/// 流式 POST 非 200 响应：携带状态码与错误体，供调用方解析后端错误码。
class ApiStreamError implements Exception {
  ApiStreamError(this.statusCode, this.body);

  final int statusCode;
  final String body;

  @override
  String toString() => 'ApiStreamError($statusCode)';
}

/// 签名 HTTP 客户端。所有需要鉴权的请求都走这里，自动附加 Device Key Pair 签名头。
class ApiClient {
  ApiClient(this.device);

  final DeviceKeyPair device;
  http.Client _client = http.Client();

  /// quick tunnel/移动网络偶尔会留下已被服务端关闭的 keep-alive 连接。
  /// 任一传输异常后丢弃连接池，避免下一条聊天继续复用坏连接。
  void _resetTransport() {
    _client.close();
    _client = http.Client();
  }

  Future<Map<String, String>> _signedHeaders(
    String method,
    String path,
    List<int> body,
  ) async {
    // 签名用 path 不含 query（与后端 auth.py _signing_message 的 request.url.path 对齐）：
    // 统一在此剥离，避免带 query 的 POST/PATCH（如 /ai/memory/refine?character_id=）
    // 签名串带 query 而后端用 request.url.path 验签 → SIGNATURE_INVALID 401。
    path = path.split('?').first;
    final ts = DateTime.now().millisecondsSinceEpoch.toString();
    final sig = await device.sign(method, path, body, ts);
    return {
      'Content-Type': 'application/json',
      'X-Device-Id': device.deviceId,
      'X-Timestamp': ts,
      'X-Signature': sig,
    };
  }

  /// 免签注册（仅首次，见 main.dart）。
  Future<http.Response> register() async {
    final body = jsonEncode({
      'device_id': device.deviceId,
      'pubkey': await device.publicKeyBase64,
      'name': 'LifeHub Phone',
    });
    return _client.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: body,
    );
  }

  Future<http.Response> post(String path, Map<String, dynamic> json) async {
    final body = utf8.encode(jsonEncode(json));
    final headers = await _signedHeaders('POST', path, body);
    try {
      return await _client.post(
        Uri.parse('${ApiConfig.baseUrl}$path'),
        headers: headers,
        body: body,
      );
    } on Object {
      // POST 不自动重试：请求可能已被服务端处理，避免产生重复聊天消息。
      _resetTransport();
      rethrow;
    }
  }

  /// JSON PUT（配置类写入，如全局回复规范）。签名用原始 body 字节，与后端一致。
  Future<http.Response> put(String path, Map<String, dynamic> json) async {
    final body = utf8.encode(jsonEncode(json));
    final headers = await _signedHeaders('PUT', path, body);
    try {
      return await _client.put(
        Uri.parse('${ApiConfig.baseUrl}$path'),
        headers: headers,
        body: body,
      );
    } on Object {
      _resetTransport();
      rethrow;
    }
  }

  /// SSE 流式 POST：返回 UTF-8 文本流（逐行 `event:`/`data:`）。
  /// 非 200（校验错误等）→ 读完 body 抛 [ApiStreamError]，错误码可解析。
  Future<Stream<String>> streamPost(
    String path,
    Map<String, dynamic> json,
  ) async {
    final body = utf8.encode(jsonEncode(json));
    final headers = await _signedHeaders('POST', path, body);
    try {
      final request = http.Request(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}$path'),
      );
      request.headers.addAll(headers);
      request.bodyBytes = body;
      final response = await _client.send(request);
      if (response.statusCode != 200) {
        final errBody = await response.stream.bytesToString();
        throw ApiStreamError(response.statusCode, errBody);
      }
      return response.stream.transform(utf8.decoder);
    } on Object {
      _resetTransport();
      rethrow;
    }
  }

  Future<http.Response> get(String path) async {
    // 签名用 path 不含 query（与后端 auth.py _signing_message 的 request.url.path 对齐）；
    // 实际请求仍带完整 path（含 query）。GET 仅有分页等参数，query 不进签名对私人系统足够。
    final signedPath = path.split('?').first;
    final headers = await _signedHeaders('GET', signedPath, []);
    try {
      return await _client.get(
        Uri.parse('${ApiConfig.baseUrl}$path'),
        headers: headers,
      );
    } on Object {
      _resetTransport();
      rethrow;
    }
  }

  /// PUT 原始字节（媒体上传第二步：POST /media → PUT /media/{id}/content）。
  /// body 即签名用的原始字节（sha256(body)），与后端 `await request.body()` 严格一致。
  Future<http.Response> putBytes(
    String path,
    List<int> bytes, {
    String? contentType,
  }) async {
    Object? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final headers = await _signedHeaders('PUT', path, bytes);
        if (contentType != null) headers['Content-Type'] = contentType;
        final response = await _client
            .put(
              Uri.parse('${ApiConfig.baseUrl}$path'),
              headers: headers,
              body: bytes,
            )
            .timeout(const Duration(seconds: 60));
        if (response.statusCode >= 500 && attempt == 0) {
          _resetTransport();
          continue;
        }
        return response;
      } on Object catch (error) {
        lastError = error;
        _resetTransport();
        if (attempt == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 350));
          continue;
        }
      }
    }
    throw lastError ?? Exception('媒体上传连接失败');
  }

  /// GET 二进制（下载图片/文件缩略图）。
  Future<http.Response> getBytes(String path) async {
    final signedPath = path.split('?').first;
    final headers = await _signedHeaders('GET', signedPath, []);
    try {
      return await _client
          .get(
            Uri.parse('${ApiConfig.baseUrl}$path'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 60));
    } on Object {
      _resetTransport();
      rethrow;
    }
  }

  /// 供 Image.network 直接携带的签名请求头。timestamp 每次现算，勿缓存复用。
  Future<Map<String, String>> signedGetHeaders(String path) async {
    final signedPath = path.split('?').first;
    return _signedHeaders('GET', signedPath, []);
  }

  /// 创建媒体元数据（status=pending）→ {media_id, storage_path}。
  Future<Map<String, dynamic>> createMedia({
    required String fileName,
    required String mimeType,
    required int size,
  }) async {
    final resp = await post('/media', {
      'file_name': fileName,
      'mime_type': mimeType,
      'size': size,
      'owner_type': 'chat',
    });
    if (resp.statusCode != 200) {
      throw Exception('上传初始化失败 (${resp.statusCode}): ${resp.body}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  /// 两步上传组合：create → put content → 返回 media_id。
  Future<String> uploadAsset(
    List<int> bytes,
    String fileName,
    String mimeType,
  ) async {
    final meta = await createMedia(
      fileName: fileName,
      mimeType: mimeType,
      size: bytes.length,
    );
    final mediaId = meta['media_id'] as String;
    final resp = await putBytes(
      '/media/$mediaId/content',
      bytes,
      contentType: mimeType,
    );
    if (resp.statusCode != 200) {
      throw Exception('上传失败 (${resp.statusCode}): ${resp.body}');
    }
    return mediaId;
  }

  Future<http.Response> patch(String path, Map<String, dynamic> json) async {
    final body = utf8.encode(jsonEncode(json));
    final headers = await _signedHeaders('PATCH', path, body);
    try {
      return await _client.patch(
        Uri.parse('${ApiConfig.baseUrl}$path'),
        headers: headers,
        body: body,
      );
    } on Object {
      _resetTransport();
      rethrow;
    }
  }

  /// 角色自定义头像/背景（010）：省略字段=不改；显式 null=恢复默认。
  /// 返回 PATCH 后最新 character dict。
  static const Object _unset = Object();

  Future<Map<String, dynamic>> patchCharacter(
    String characterId, {
    Object? avatarMediaId = _unset,
    Object? backgroundMediaId = _unset,
  }) async {
    final body = <String, dynamic>{};
    if (avatarMediaId != _unset) body['avatar_media_id'] = avatarMediaId;
    if (backgroundMediaId != _unset)
      body['background_media_id'] = backgroundMediaId;
    final resp = await patch('/ai/characters/$characterId', body);
    if (resp.statusCode != 200) {
      throw Exception('更新角色失败 (${resp.statusCode}): ${resp.body}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  Future<http.Response> delete(String path) async {
    // DELETE 无 body：签名空 body（sha256(b"")），与后端 request.body() 一致。
    final headers = await _signedHeaders('DELETE', path, []);
    try {
      return await _client.delete(
        Uri.parse('${ApiConfig.baseUrl}$path'),
        headers: headers,
      );
    } on Object {
      _resetTransport();
      rethrow;
    }
  }

  void close() => _client.close();
}
