import 'package:drift/drift.dart';

/// AI 聊天历史本地缓存（v5，需求2：聊天秒开 + 完整显示）。
/// 服务端确认消息使用 UUIDv7；发送中的用户消息使用 local-* 临时 id 立即落盘，
/// 服务端确认后再删除临时行，保证快速退出/重进时气泡不消失。
@DataClassName('ChatMessageRow')
@TableIndex(name: 'chat_messages_conv_idx', columns: {#conversationId})
class ChatMessages extends Table {
  TextColumn get conversationId => text()();
  TextColumn get id => text()();
  TextColumn get role =>
      text().withDefault(const Constant('user'))(); // user | assistant
  TextColumn get kind => text()
      .withDefault(const Constant('text'))(); // text|image|file|sticker|audio
  TextColumn get content => text().nullable()();
  TextColumn get mediaAssetId => text().nullable()();
  // 语音时长（秒，kind=audio，v7）：对齐后端 message.audio_duration
  IntColumn get audioDuration => integer().nullable()();
  TextColumn get stickerId => text().nullable()();
  TextColumn get caption => text().nullable()();
  TextColumn get fileName => text().nullable()();
  IntColumn get fileSize => integer().nullable()();
  TextColumn get quoteMessageId => text().nullable()();
  TextColumn get quoteRole => text().nullable()();
  TextColumn get quoteContent => text().nullable()();
  // 群聊（032）：发言人 character_id；NULL=用户消息。群消息据此渲染逐人头像。
  TextColumn get senderCharacterId => text().nullable()();
  // 红包/转账金额（033，kind=redpacket|transfer）：假钱社交信号。
  RealColumn get amount => real().nullable()();
  // R4 红包领取（034）：claimed 是否已被领取；claimers 领取人 JSON
  // （[{"character_id","name","claimed_at"}]，character_id 空=用户）。
  BoolColumn get claimed => boolean().withDefault(const Constant(false))();
  TextColumn get claimers => text().nullable()();
  // 转账收/拒（验收批2，kind=transfer）：null=待回应 / true=收下 / false=婉拒
  BoolColumn get transferAccepted => boolean().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {conversationId, id};
}

/// 生活模块：习惯定义（图标/专属色/每日目标/模式/行为）。
@DataClassName('LifeHabitRow')
class LifeHabits extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get iconName => text()();
  IntColumn get colorArgb =>
      integer().withDefault(const Constant(0xFF4CAF50))();
  IntColumn get dailyTarget => integer().withDefault(const Constant(1))();
  TextColumn get unit => text().withDefault(const Constant('次'))();
  // HabitMode：counter（计数）| timer（计时）
  TextColumn get type => text().withDefault(const Constant('counter'))();
  // 计时行为：normal（当日）| overnight（跨午夜，如睡眠，按结束日归属）
  TextColumn get behavior => text().withDefault(const Constant('normal'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// 生活模块：每次「记一笔」的事件（计数器 +1 / 计时时长秒数）。
@DataClassName('LifeHabitEventRow')
class LifeHabitEvents extends Table {
  TextColumn get id => text()();
  TextColumn get habitId => text()();
  DateTimeColumn get occurredAt => dateTime().withDefault(currentDateAndTime)();
  RealColumn get value => real().withDefault(const Constant(1.0))();
  TextColumn get note => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 进行中的计时会话（持久化 habitId + startedAt；杀 App / 重启可恢复「继续/结束」）。
@DataClassName('ActiveSessionRow')
class ActiveSessions extends Table {
  TextColumn get habitId => text()();
  DateTimeColumn get startedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {habitId};
}

/// 随手记收件箱（通用捕获入口，FAB「记一笔」落点）。
@DataClassName('InboxItemRow')
class InboxItems extends Table {
  TextColumn get id => text()();
  TextColumn get content => text()();
  TextColumn get kind =>
      text().withDefault(const Constant('note'))(); // note | link | media
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get synced => integer().withDefault(const Constant(0))(); // 0/1

  @override
  Set<Column> get primaryKey => {id};
}

/// 本地同步队列：每条本地写操作追加一条，待 POST /sync/push 上传。
/// 字段对齐后端 SyncEvent（entity_type/entity_id/operation/payload/synced）。
@DataClassName('SyncEventRow')
class SyncEventsLocal extends Table {
  TextColumn get id => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get operation => text()(); // create | update | delete
  TextColumn get payload => text()(); // JSON 字符串
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get synced => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// 私人朋友圈预留（PRD R12 / Phase 2 后半段顺手加）：仅表结构，无 UI。
/// 媒体复用 MediaAsset 多态（owner_type='moment', owner_id=moment.id），不建关联表。
@DataClassName('MomentRow')
class Moments extends Table {
  TextColumn get id => text()();
  TextColumn get authorType =>
      text().withDefault(const Constant('user'))(); // user | companion
  TextColumn get content => text()();
  TextColumn get visibility =>
      text().withDefault(const Constant('private'))(); // 仅自己可见
  TextColumn get source =>
      text().withDefault(const Constant('manual'))(); // manual | ai_generated
  TextColumn get deviceId => text()(); // 同步作用域
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// 学习模块：学习资源（小说/论文/数学课程/英语/日语…）。目标量用于进度%。
@DataClassName('StudyResourceRow')
class StudyResources extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get category =>
      text().withDefault(const Constant('其他'))(); // 小说/论文/数学/英语/日语…
  TextColumn get iconName => text().withDefault(const Constant('book'))();
  IntColumn get colorArgb =>
      integer().withDefault(const Constant(0xFF2196F3))();
  // 目标量（进度分母）：页/章/小时/词…；0 表示不量化进度。
  RealColumn get goalAmount => real().withDefault(const Constant(0))();
  TextColumn get goalUnit => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// 学习模块：一次学习记录（计时时长 + 完成量）。
@DataClassName('StudySessionRow')
class StudySessions extends Table {
  TextColumn get id => text()();
  TextColumn get resourceId => text()();
  DateTimeColumn get startedAt => dateTime().withDefault(currentDateAndTime)();
  RealColumn get durationSeconds => real().withDefault(const Constant(0))();
  RealColumn get amount => real().withDefault(const Constant(0))(); // 页/词/…
  TextColumn get note => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 运动模块：运动类型（跑步/散步/俯卧撑/深蹲/平板/卷腹…）。
/// metrics：逗号分隔的能力集合（count|time|distance），决定详情页可填字段。
@DataClassName('ExerciseTypeRow')
class ExerciseTypes extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get iconName =>
      text().withDefault(const Constant('directions_run'))();
  TextColumn get metrics => text().withDefault(const Constant('count'))();
  TextColumn get countUnit => text().withDefault(const Constant('次'))();
  TextColumn get distanceUnit => text().withDefault(const Constant('m'))();
  IntColumn get colorArgb =>
      integer().withDefault(const Constant(0xFFFF5722))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// 运动模块：一次运动记录（次数/时长秒/距离米，按需）。
@DataClassName('ExerciseSessionRow')
class ExerciseSessions extends Table {
  TextColumn get id => text()();
  TextColumn get typeId => text()();
  DateTimeColumn get occurredAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get count => integer().withDefault(const Constant(0))();
  RealColumn get durationSeconds => real().withDefault(const Constant(0))();
  RealColumn get distanceMeters => real().withDefault(const Constant(0))();
  IntColumn get sets => integer().nullable()(); // 健身：组数（v0.4-3）
  RealColumn get weightKg => real().nullable()(); // 健身：重量 kg（v0.4-3）
  TextColumn get note => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 宠物模块：宠物档案（猫优先）。
@DataClassName('PetRow')
class Pets extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get species => text().withDefault(const Constant('cat'))();
  TextColumn get avatarPath => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// 宠物模块：一次宠物记录（文字/体重/健康/照片）。
/// kind：text（文字）| weight（称重，value=kg）| health（健康笔记）| photo（照片，mediaAssetId 关联）。
@DataClassName('PetLogRow')
class PetLogs extends Table {
  TextColumn get id => text()();
  TextColumn get petId => text()();
  TextColumn get kind => text().withDefault(const Constant('text'))();
  TextColumn get content => text().withDefault(const Constant(''))();
  RealColumn get value => real().nullable()();
  TextColumn get mediaAssetId => text().nullable()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get occurredAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// 媒体字节磁盘缓存（v6，优化1：冷启动秒开头像/聊天背景/聊天图片）。
/// media_asset 内容不可变（上传后不改），缓存无需过期；
/// 读优先命中本地，未命中才走隧道下载并回写。
@DataClassName('MediaCacheRow')
class MediaCache extends Table {
  TextColumn get mediaId => text()();
  BlobColumn get bytes => blob()();
  RealColumn get aspect => real().nullable()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {mediaId};
}

/// 通用 KV 缓存（v6，优化1）：角色列表 JSON 等，带写入时间戳供新鲜度判断。
@DataClassName('KvCacheRow')
class KvCache extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {key};
}
