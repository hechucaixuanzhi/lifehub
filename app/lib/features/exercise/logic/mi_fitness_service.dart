import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';

/// 小米运动健康每日数据。
class MiFitnessDaily {
  const MiFitnessDaily({
    required this.date,
    this.steps = 0,
    this.distanceM = 0,
    this.activeKcal = 0,
  });
  final String date;
  final int steps;
  final double distanceM;
  final double activeKcal;
}

/// 小米自动同步的运动记录。
class MiFitnessWorkout {
  const MiFitnessWorkout({
    required this.id,
    required this.activityType,
    this.startAt,
    this.durationMin = 0,
    this.distanceM,
    this.caloriesKcal,
    this.avgHrBpm,
    this.totalSteps,
  });
  final String id;
  final String activityType;
  final DateTime? startAt;
  final int durationMin;
  final double? distanceM;
  final double? caloriesKcal;
  final int? avgHrBpm;
  final int? totalSteps;
}

class MiFitnessException implements Exception {
  const MiFitnessException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 小米运动 activity_type → (图标键, 中文名)。未知类型回退显示原名 + 跑步图标。
const Map<String, (String, String)> miWorkoutTypeMap = {
  'running': ('directions_run', '跑步'),
  'outdoor_running': ('directions_run', '户外跑步'),
  'indoor_running': ('directions_run', '室内跑步'),
  'treadmill': ('directions_run', '跑步机'),
  'walking': ('walk', '步行'),
  'outdoor_walking': ('walk', '健走'),
  'hiking': ('hiking', '徒步'),
  'mountaineering': ('hiking', '登山'),
  'cycling': ('pedal_bike', '骑行'),
  'outdoor_cycling': ('pedal_bike', '户外骑行'),
  'indoor_cycling': ('pedal_bike', '动感单车'),
  'swimming': ('pool', '游泳'),
  'strength': ('fitness_center', '力量训练'),
  'fitness': ('fitness_center', '健身'),
  'workout': ('fitness_center', '训练'),
};

/// 小米运动健康同步服务：调后端 /mi_fitness/* 签名 endpoint。
class MiFitnessService {
  MiFitnessService(this._api);

  final ApiClient _api;

  /// 手动触发后端同步（近 2 天）。
  Future<Map<String, dynamic>> sync() async {
    final resp = await _api
        .post('/mi_fitness/sync', {}).timeout(const Duration(seconds: 90));
    return _decodeResponse(resp.statusCode, resp.bodyBytes);
  }

  /// 同步配置/状态探针（是否已配置小米账号、数据量）。
  Future<Map<String, dynamic>> status() async {
    final resp = await _api
        .get('/mi_fitness/status')
        .timeout(const Duration(seconds: 20));
    return _decodeResponse(resp.statusCode, resp.bodyBytes);
  }

  /// 拉取日期区间每日步数。start/end 为 YYYY-MM-DD。
  Future<List<MiFitnessDaily>> fetchDaily(String start, String end) async {
    final resp = await _api
        .get('/mi_fitness/daily?start=$start&end=$end')
        .timeout(const Duration(seconds: 20));
    final body = _decodeResponse(resp.statusCode, resp.bodyBytes);
    final days = (body['days'] as List? ?? const []);
    return days
        .map((d) => MiFitnessDaily(
              date: (d['date'] as String?) ?? '',
              steps: (d['steps'] as num?)?.toInt() ?? 0,
              distanceM: (d['distance_m'] as num?)?.toDouble() ?? 0,
              activeKcal: (d['active_kcal'] as num?)?.toDouble() ?? 0,
            ))
        .toList();
  }

  /// 拉取运动记录（倒序，最多 limit 条）。
  Future<List<MiFitnessWorkout>> fetchWorkouts({
    String start = '',
    String end = '',
    int limit = 20,
  }) async {
    final query = ['limit=$limit'];
    if (start.isNotEmpty) query.add('start=$start');
    if (end.isNotEmpty) query.add('end=$end');
    final resp = await _api
        .get('/mi_fitness/workouts?${query.join('&')}')
        .timeout(const Duration(seconds: 20));
    final body = _decodeResponse(resp.statusCode, resp.bodyBytes);
    final workouts = (body['workouts'] as List? ?? const []);
    return workouts
        .map((w) => MiFitnessWorkout(
              id: (w['id'] as String?) ?? '',
              activityType: (w['activity_type'] as String?) ?? 'workout',
              startAt: w['start_at'] != null
                  ? DateTime.tryParse(w['start_at'] as String)?.toLocal()
                  : null,
              durationMin: (w['duration_min'] as num?)?.toInt() ?? 0,
              distanceM: (w['distance_m'] as num?)?.toDouble(),
              caloriesKcal: (w['calories_kcal'] as num?)?.toDouble(),
              avgHrBpm: (w['avg_hr_bpm'] as num?)?.toInt(),
              totalSteps: (w['total_steps'] as num?)?.toInt(),
            ))
        .toList();
  }

  Map<String, dynamic> _decodeResponse(int status, List<int> bytes) {
    Map<String, dynamic>? body;
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is Map) body = Map<String, dynamic>.from(decoded);
    } on Object {
      body = null;
    }
    if (status >= 200 && status < 300 && body != null) return body;

    String? message;
    final detail = body?['detail'];
    if (detail is String) {
      message = detail;
    } else if (detail is Map) {
      final error = detail['error'];
      if (error is Map) message = error['message'] as String?;
      message ??= detail['message'] as String?;
    }
    message ??= body?['message'] as String?;
    throw MiFitnessException(
      message?.trim().isNotEmpty == true ? message! : '服务暂时不可用（$status）',
    );
  }
}

final miFitnessServiceProvider = Provider<MiFitnessService>((ref) {
  return MiFitnessService(ref.watch(apiProvider));
});
