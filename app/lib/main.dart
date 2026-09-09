import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';

import 'core/auth/device_key_pair.dart';
import 'core/database/app_database.dart';
import 'core/network/api_client.dart';
import 'core/providers.dart';
import 'core/sync/sync_manager.dart';
import 'features/inbox/data/drift_inbox_repository.dart';
import 'features/inbox/logic/inbox_notifier.dart';
import 'features/life/data/drift_life_repository.dart';
import 'features/life/logic/life_notifier.dart';
import 'features/study/data/drift_study_repository.dart';
import 'features/study/logic/study_notifier.dart';
import 'features/exercise/data/drift_exercise_repository.dart';
import 'features/exercise/logic/exercise_notifier.dart';
import 'features/pet/data/drift_pet_repository.dart';
import 'features/pet/logic/pet_notifier.dart';
import 'features/exercise/data/exercise_presets.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) Device Key Pair（首次生成并持久化）
  final device = await DeviceKeyPair.loadOrCreate();

  // 2) 本地主库 + 默认种子（首次启动）
  final db = AppDatabase();
  await _seedDefaultHabits(db);
  await _seedExerciseTypes(db);
  await _seedStudyResources(db);

  // 3) API / Sync 构造（注册与同步放到首帧后后台执行，首帧不再等网络）
  final api = ApiClient(device);
  final sync = SyncManager(db, api);

  runApp(
    ProviderScope(
      overrides: [
        dbProvider.overrideWithValue(db),
        deviceProvider.overrideWithValue(device),
        apiProvider.overrideWithValue(api),
        syncManagerProvider.overrideWithValue(sync),
        lifeRepositoryProvider.overrideWithValue(DriftLifeRepository(db)),
        inboxRepositoryProvider.overrideWithValue(DriftInboxRepository(db)),
        studyRepositoryProvider.overrideWithValue(DriftStudyRepository(db)),
        exerciseRepositoryProvider
            .overrideWithValue(DriftExerciseRepository(db)),
        petRepositoryProvider.overrideWithValue(DriftPetRepository(db)),
      ],
      child: const App(),
    ),
  );

  // 首帧后后台网络初始化：注册设备 → 推本地变更 → 拉增量。
  // 失败静默不影响 UI；本地数据先出、后台刷新（先旧后新）。
  WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrapNetwork(api, sync));
}

/// 后台网络引导：register（推送公钥）→ push（本地待同步变更）→ pull（拉增量）。
/// 先 push 后 pull 是删除不「回退」的关键——否则重启 pull 会把旧数据拉回。
Future<void> _bootstrapNetwork(ApiClient api, SyncManager sync) async {
  try {
    await api.register();
  } on Object {
    // 服务器未启动 / 离线：本地优先，忽略
  }
  try {
    await sync.push();
  } on Object {
    // 离线 / 不可达：本地优先，忽略
  }
  try {
    await sync.pull();
  } on Object {
    // 离线 / 不可达：本地优先，忽略
  }
}

/// 首次启动写入 9 个默认习惯（固定 ID，避免重复 seed）。
/// 生活模块边界：不含「读书」（归学习 StudyLog）、「写日记」（归 Moment/Inbox）。
Future<void> _seedDefaultHabits(AppDatabase db) async {
  if (await db.getAllHabits().then((l) => l.isNotEmpty)) return;
  const defaults = [
    // id, name, icon, color, target, unit, mode, behavior
    ('habit_water', '喝水', 'water', 0xFF2196F3, 8, '杯', 'counter', 'normal'),
    ('habit_sleep', '睡眠', 'sleep', 0xFF9C27B0, 480, 'min', 'timer', 'overnight'),
    ('habit_sun', '晒太阳', 'sun', 0xFFFBC02D, 20, 'min', 'timer', 'normal'),
    ('habit_med', '冥想', 'meditate', 0xFF4CAF50, 10, 'min', 'timer', 'normal'),
    ('habit_meal', '三餐', 'meal', 0xFFFF9800, 3, '次', 'counter', 'normal'),
    ('habit_brush', '刷牙', 'brush', 0xFF00BCD4, 2, '次', 'counter', 'normal'),
    ('habit_eye', '护眼', 'eye', 0xFF3F51B5, 1, '次', 'counter', 'normal'),
    ('habit_fruit', '水果', 'fruit', 0xFFE91E63, 1, '份', 'counter', 'normal'),
    ('habit_coffee', '咖啡', 'coffee', 0xFF795548, 1, '杯', 'counter', 'normal'),
  ];
  for (final d in defaults) {
    await db.upsertHabit(
      LifeHabitsCompanion.insert(
        id: d.$1,
        name: d.$2,
        iconName: d.$3,
        colorArgb: Value(d.$4),
        dailyTarget: Value(d.$5),
        unit: Value(d.$6),
        type: Value(d.$7),
        behavior: Value(d.$8),
      ),
    );
  }
}

/// 首次启动写入 6 个运动预设（固定 ID，避免重复 seed）。
Future<void> _seedExerciseTypes(AppDatabase db) async {
  final existing = await db.select(db.exerciseTypes).get();
  if (existing.isNotEmpty) return;
  for (final p in exercisePresets) {
    await db.into(db.exerciseTypes).insert(
          ExerciseTypesCompanion.insert(
            id: p.id,
            name: p.name,
            iconName: Value(p.iconName),
            metrics: Value(p.metrics),
            countUnit: Value(p.countUnit),
            distanceUnit: Value(p.distanceUnit),
            colorArgb: Value(p.colorArgb),
            createdAt: Value(DateTime.now()),
          ),
        );
  }
}

/// 首次启动写入几个默认学习资源（固定 ID，避免重复 seed）。
/// 对齐 PRD：学习模块默认有「在读」（书/课程）+「语言」（英/日）。
Future<void> _seedStudyResources(AppDatabase db) async {
  final existing = await db.select(db.studyResources).get();
  if (existing.isNotEmpty) return;
  const defaults = [
    // id, name, category, icon, color, goalAmount, goalUnit
    ('sr_book', '阅读一本书', '小说', 'menu_book', 0xFF16A085, 30, '页'),
    ('sr_course', '数学专业课', '数学', 'calculate', 0xFFC0392B, 40, '章'),
    ('sr_paper', '读论文', '论文', 'article', 0xFF2980B9, 20, '页'),
    ('sr_en', '英语', '英语', 'translate', 0xFF27AE60, 20, 'min'),
    ('sr_jp', '日语', '日语', 'language', 0xFFE67E22, 15, 'min'),
  ];
  for (final d in defaults) {
    await db.into(db.studyResources).insert(
          StudyResourcesCompanion.insert(
            id: d.$1,
            name: d.$2,
            category: Value(d.$3),
            iconName: Value(d.$4),
            colorArgb: Value(d.$5),
            goalAmount: Value(d.$6.toDouble()),
            goalUnit: Value(d.$7),
            createdAt: Value(DateTime.now()),
          ),
        );
  }
}
