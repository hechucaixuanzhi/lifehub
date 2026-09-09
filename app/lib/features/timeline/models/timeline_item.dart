/// 时间线条目（GET /timeline 单条）。
///
/// `at` 为实体本地墙上时间（无时区后缀），`DateTime.parse` 直接按本地时间解析。
/// `ref_id` 是资源/运动/习惯的原始 id，由页面用本地类型表映射成中文名。
/// `count` > 1 表示后端把 60 秒内连续的同类型记录合并了（如连点喝水 ×11）。
class TimelineItem {
  const TimelineItem({
    required this.type,
    required this.at,
    this.refId,
    this.value,
    this.durationSeconds,
    this.distanceMeters,
    this.kind,
    this.content,
    this.note,
    this.count = 1,
  });

  final String type; // study_session | exercise_session | pet_log | life_habit_event | pet
  final DateTime at;
  final String? refId; // resource_id / type_id / habit_id
  final double? value; // 习惯打卡值（计时习惯=分钟，计数习惯=次）
  final int? durationSeconds;
  final double? distanceMeters;
  final String? kind; // pet_log：text | photo
  final String? content;
  final String? note;
  final int count;

  factory TimelineItem.fromJson(Map<String, dynamic> json) => TimelineItem(
        type: json['type'] as String? ?? '',
        at: DateTime.parse(json['at'] as String),
        refId: json['ref_id'] as String?,
        value: (json['value'] as num?)?.toDouble(),
        durationSeconds: json['duration_seconds'] as int?,
        distanceMeters: (json['distance_meters'] as num?)?.toDouble(),
        kind: json['kind'] as String?,
        content: json['content'] as String?,
        note: json['note'] as String?,
        count: (json['count'] as int?) ?? 1,
      );
}
