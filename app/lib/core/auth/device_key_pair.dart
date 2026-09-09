import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

const _storage = FlutterSecureStorage();
const _kSeed = 'lifehub_device_ed25519_seed';
const _kDeviceId = 'lifehub_device_id';

/// Device Key Pair（类 SSH，冻结，见 API.md §1）。
/// 手机本地生成 Ed25519 密钥对，私钥(seed)存 secure_storage，公钥经 /auth/register 报送。
/// 每次请求用私钥对 `METHOD|PATH|sha256_hex(body)|timestamp_ms` 签名，放 X-Signature 头。
class DeviceKeyPair {
  DeviceKeyPair(this.deviceId, this.keyPair);

  final String deviceId;
  final KeyPair keyPair;

  /// 首次启动生成并持久化 seed；之后用 seed 重建。
  static Future<DeviceKeyPair> loadOrCreate() async {
    final deviceId = await _storage.read(key: _kDeviceId);
    final seedB64 = await _storage.read(key: _kSeed);
    final algorithm = Ed25519();
    if (deviceId != null && seedB64 != null) {
      final kp = await algorithm.newKeyPairFromSeed(base64Decode(seedB64));
      return DeviceKeyPair(deviceId, kp);
    }
    final newId = const Uuid().v4();
    final kp = await algorithm.newKeyPair();
    final seed = await kp.extractPrivateKeyBytes();
    await _storage.write(key: _kDeviceId, value: newId);
    await _storage.write(key: _kSeed, value: base64Encode(seed));
    return DeviceKeyPair(newId, kp);
  }

  Future<String> get publicKeyBase64 async {
    final pk = await keyPair.extractPublicKey();
    return base64Encode((pk as SimplePublicKey).bytes);
  }

  /// 与后端 auth.py `_signing_message` 严格对齐。
  Future<String> sign(
    String method,
    String path,
    List<int> body,
    String timestampMs,
  ) async {
    final bodyHash = sha256.convert(body).toString();
    final msg = utf8.encode('$method|$path|$bodyHash|$timestampMs');
    final sig = await Ed25519().sign(msg, keyPair: keyPair);
    return base64Encode(sig.bytes);
  }
}
