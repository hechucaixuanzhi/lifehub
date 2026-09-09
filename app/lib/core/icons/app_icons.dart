import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Phosphor 图标统一映射（v0.3 图标系统）。
/// 对齐 docs/design/tokens.md §6：生活/学习图标轮廓差异明显，避免都是文档剪影。
/// 用 PhosphorIconsRegular 常量类（PhosphorFlatIconData extends IconData），
/// 保持 const 映射表。替代旧的 habit_icons / study_icons / exercise_icons。

/// 习惯图标（iconName → Phosphor Regular）。
const Map<String, IconData> habitIcons = {
  'water': PhosphorIconsRegular.drop, // 喝水
  'sleep': PhosphorIconsRegular.moon, // 睡眠
  'sun': PhosphorIconsRegular.sun, // 晒太阳
  'meditate': PhosphorIconsRegular.flowerLotus, // 冥想
  'meal': PhosphorIconsRegular.bowlFood, // 三餐
  'brush': PhosphorIconsRegular.tooth, // 刷牙
  'eye': PhosphorIconsRegular.eye, // 护眼
  'fruit': PhosphorIconsRegular.orange, // 水果
  'coffee': PhosphorIconsRegular.coffee, // 咖啡
};

IconData habitIcon(String name) => habitIcons[name] ?? PhosphorIconsRegular.circle;

/// 习惯图标 Fill 实心版（状态填充覆盖层用：图标内部被颜色填满，贴合轮廓）。
const Map<String, IconData> habitIconsFill = {
  'water': PhosphorIconsFill.drop,
  'sleep': PhosphorIconsFill.moon,
  'sun': PhosphorIconsFill.sun,
  'meditate': PhosphorIconsFill.flowerLotus,
  'meal': PhosphorIconsFill.bowlFood,
  'brush': PhosphorIconsFill.tooth,
  'eye': PhosphorIconsFill.eye,
  'fruit': PhosphorIconsFill.orange,
  'coffee': PhosphorIconsFill.coffee,
};

IconData habitIconFill(String name) =>
    habitIconsFill[name] ?? habitIcon(name);

/// 学习图标（iconName → Phosphor Regular）。
const Map<String, IconData> studyIcons = {
  'book': PhosphorIconsRegular.book,
  'menu_book': PhosphorIconsRegular.bookOpen, // 小说
  'article': PhosphorIconsRegular.article, // 论文
  'calculate': PhosphorIconsRegular.calculator, // 数学
  'translate': PhosphorIconsRegular.translate, // 英语
  'language': PhosphorIconsRegular.globeHemisphereWest, // 日语
  'school': PhosphorIconsRegular.graduationCap,
  'auto_stories': PhosphorIconsRegular.bookOpenText,
  'headphones': PhosphorIconsRegular.headphones,
};

IconData studyIcon(String name) => studyIcons[name] ?? PhosphorIconsRegular.book;

/// 学习图标 Fill 实心版（状态填充覆盖层用）。
const Map<String, IconData> studyIconsFill = {
  'book': PhosphorIconsFill.book,
  'menu_book': PhosphorIconsFill.bookOpen,
  'article': PhosphorIconsFill.article,
  'calculate': PhosphorIconsFill.calculator,
  'translate': PhosphorIconsFill.translate,
  'language': PhosphorIconsFill.globeHemisphereWest,
  'school': PhosphorIconsFill.graduationCap,
  'auto_stories': PhosphorIconsFill.bookOpenText,
  'headphones': PhosphorIconsFill.headphones,
};

IconData studyIconFill(String name) =>
    studyIconsFill[name] ?? studyIcon(name);

/// 运动图标（iconName → Phosphor Regular；标准库缺失的动作用近似）。
const Map<String, IconData> exerciseIcons = {
  'directions_run': PhosphorIconsRegular.personSimpleRun,
  'walk': PhosphorIconsRegular.footprints,
  'fitness_center': PhosphorIconsRegular.barbell, // 俯卧撑/力量
  'squat': PhosphorIconsRegular.personSimpleTaiChi, // 深蹲（近似：半蹲姿态）
  'plank': PhosphorIconsRegular.personSimple, // 平板（近似）
  'crunches': PhosphorIconsRegular.personSimpleRun, // 卷腹（近似：核心发力）
  'pool': PhosphorIconsRegular.personSimpleSwim,
  'pedal_bike': PhosphorIconsRegular.personSimpleBike,
  'hiking': PhosphorIconsRegular.personSimpleHike,
  'sports_gymnastics': PhosphorIconsRegular.personSimpleCircle,
};

IconData exerciseIcon(String name) =>
    exerciseIcons[name] ?? PhosphorIconsRegular.personSimpleRun;

/// 运动图标 Fill 实心版（状态填充覆盖层用；标准库缺失的动作用近似）。
const Map<String, IconData> exerciseIconsFill = {
  'directions_run': PhosphorIconsFill.personSimpleRun,
  'walk': PhosphorIconsFill.footprints,
  'fitness_center': PhosphorIconsFill.barbell,
  'squat': PhosphorIconsFill.personSimpleTaiChi,
  'plank': PhosphorIconsFill.personSimple,
  'crunches': PhosphorIconsFill.personSimpleRun,
  'pool': PhosphorIconsFill.personSimpleSwim,
  'pedal_bike': PhosphorIconsFill.personSimpleBike,
  'hiking': PhosphorIconsFill.personSimpleHike,
  'sports_gymnastics': PhosphorIconsFill.personSimpleCircle,
};

IconData exerciseIconFill(String name) =>
    exerciseIconsFill[name] ?? exerciseIcon(name);

/// 学习分类（添加资源时的分类下拉）。
const List<String> studyCategories = [
  '小说',
  '论文',
  '数学',
  '英语',
  '日语',
  '其他',
];

/// 可选图标名（添加资源时的图标下拉，与上面映射表键一致）。
const List<String> studyIconNames = [
  'book',
  'menu_book',
  'article',
  'calculate',
  'translate',
  'language',
  'school',
  'auto_stories',
  'headphones',
];

/// 可选运动图标名（添加类型时的图标下拉）。
const List<String> exerciseIconNames = [
  'directions_run',
  'walk',
  'fitness_center',
  'squat',
  'plank',
  'crunches',
  'pool',
  'pedal_bike',
  'hiking',
  'sports_gymnastics',
];

/// 导航 / 顶栏 / FAB 图标。
class AppNavIcons {
  static const IconData home = PhosphorIconsRegular.house;
  static const IconData study = PhosphorIconsRegular.bookOpen;
  static const IconData exercise = PhosphorIconsRegular.clock;
  static const IconData ai = PhosphorIconsRegular.sparkle;
  static const IconData me = PhosphorIconsRegular.user;
  static const IconData pet = PhosphorIconsRegular.pawPrint;
  static const IconData plus = PhosphorIconsRegular.plus;
  static const IconData back = PhosphorIconsRegular.caretLeft;
}
