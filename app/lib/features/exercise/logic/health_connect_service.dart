import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';

/// Health Connect 同步结果。
class HealthSyncResult {
  const HealthSyncResult({
    this.authorized = false,
    this.steps = 0,
    this.distanceMeters = 0,
    this.error,
  });
  final bool authorized;
  final int steps;
  final double distanceMeters;
  final String? error;
}

/// Health Connect 服务：授权 + 读取今日步数/跑步距离。
/// 封装 health 插件（Android Health Connect）。
class HealthConnectService {
  HealthConnectService() : _health = Health();

  final Health _health;
  bool _configured = false;

  /// HealthValue → num（NumericHealthValue 取 numericValue）。
  double _valueToNum(HealthValue v) {
    if (v is NumericHealthValue) return v.numericValue.toDouble();
    return 0;
  }

  /// 请求 Health Connect 授权（步数 + 走路/跑步距离）。
  /// 返回 (是否授权, 错误信息)。不依赖 SDK 状态预判，直接尝试授权；
  /// 若不可用由插件抛异常，捕获后返回具体原因。
  Future<(bool, String?)> requestAuthorization() async {
    try {
      if (!_configured) {
        await _health.configure();
        _configured = true;
      }
      final status = await _health.getHealthConnectSdkStatus();
      debugPrint('HC SDK status: ${status?.nativeValue} ($status)');
      if (status == HealthConnectSdkStatus.sdkUnavailable) {
        return (false, 'SDK不可用(${status?.nativeValue})');
      }
      // 只请求 STEPS：DISTANCE_WALKING_RUNNING 在部分设备 Health Connect 里不存在
      //（FLUTTER_HEALTH ERROR: Datatype DISTANCE_WALKING_RUNNING not found），会导致授权失败。
      final granted = await _health.requestAuthorization([
        HealthDataType.STEPS,
      ]);
      debugPrint('HC auth granted: $granted');
      return (granted, null);
    } on Object catch (e) {
      debugPrint('HC auth error: $e');
      return (false, '授权失败：$e');
    }
  }

  /// 读取今日步数和走路/跑步距离。
  Future<HealthSyncResult> fetchToday() async {
    try {
      if (!_configured) {
        await _health.configure();
        _configured = true;
      }
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);
      final steps = await _health.getTotalStepsInInterval(start, now);
      // 距离：走路/跑步距离，单位米
      double distMeters = 0;
      try {
        final points = await _health.getHealthDataFromTypes(
          types: [HealthDataType.DISTANCE_WALKING_RUNNING],
          preferredUnits: {
            HealthDataType.DISTANCE_WALKING_RUNNING: HealthDataUnit.METER,
          },
          startTime: start,
          endTime: now,
        );
        for (final p in points) {
          distMeters += _valueToNum(p.value);
        }
      } on Object {
        // 距离读取失败不影响步数
      }
      return HealthSyncResult(
        authorized: true,
        steps: steps ?? 0,
        distanceMeters: distMeters,
      );
    } on Object {
      return const HealthSyncResult(error: 'Health Connect 读取失败');
    }
  }
}

final healthConnectServiceProvider = Provider<HealthConnectService>((ref) {
  return HealthConnectService();
});
