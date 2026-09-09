// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $LifeHabitsTable extends LifeHabits
    with TableInfo<$LifeHabitsTable, LifeHabitRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LifeHabitsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _iconNameMeta =
      const VerificationMeta('iconName');
  @override
  late final GeneratedColumn<String> iconName = GeneratedColumn<String>(
      'icon_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _colorArgbMeta =
      const VerificationMeta('colorArgb');
  @override
  late final GeneratedColumn<int> colorArgb = GeneratedColumn<int>(
      'color_argb', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0xFF4CAF50));
  static const VerificationMeta _dailyTargetMeta =
      const VerificationMeta('dailyTarget');
  @override
  late final GeneratedColumn<int> dailyTarget = GeneratedColumn<int>(
      'daily_target', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
      'unit', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('次'));
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('counter'));
  static const VerificationMeta _behaviorMeta =
      const VerificationMeta('behavior');
  @override
  late final GeneratedColumn<String> behavior = GeneratedColumn<String>(
      'behavior', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('normal'));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        iconName,
        colorArgb,
        dailyTarget,
        unit,
        type,
        behavior,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'life_habits';
  @override
  VerificationContext validateIntegrity(Insertable<LifeHabitRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('icon_name')) {
      context.handle(_iconNameMeta,
          iconName.isAcceptableOrUnknown(data['icon_name']!, _iconNameMeta));
    } else if (isInserting) {
      context.missing(_iconNameMeta);
    }
    if (data.containsKey('color_argb')) {
      context.handle(_colorArgbMeta,
          colorArgb.isAcceptableOrUnknown(data['color_argb']!, _colorArgbMeta));
    }
    if (data.containsKey('daily_target')) {
      context.handle(
          _dailyTargetMeta,
          dailyTarget.isAcceptableOrUnknown(
              data['daily_target']!, _dailyTargetMeta));
    }
    if (data.containsKey('unit')) {
      context.handle(
          _unitMeta, unit.isAcceptableOrUnknown(data['unit']!, _unitMeta));
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    }
    if (data.containsKey('behavior')) {
      context.handle(_behaviorMeta,
          behavior.isAcceptableOrUnknown(data['behavior']!, _behaviorMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LifeHabitRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LifeHabitRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      iconName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}icon_name'])!,
      colorArgb: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}color_argb'])!,
      dailyTarget: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}daily_target'])!,
      unit: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}unit'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      behavior: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}behavior'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $LifeHabitsTable createAlias(String alias) {
    return $LifeHabitsTable(attachedDatabase, alias);
  }
}

class LifeHabitRow extends DataClass implements Insertable<LifeHabitRow> {
  final String id;
  final String name;
  final String iconName;
  final int colorArgb;
  final int dailyTarget;
  final String unit;
  final String type;
  final String behavior;
  final DateTime createdAt;
  const LifeHabitRow(
      {required this.id,
      required this.name,
      required this.iconName,
      required this.colorArgb,
      required this.dailyTarget,
      required this.unit,
      required this.type,
      required this.behavior,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['icon_name'] = Variable<String>(iconName);
    map['color_argb'] = Variable<int>(colorArgb);
    map['daily_target'] = Variable<int>(dailyTarget);
    map['unit'] = Variable<String>(unit);
    map['type'] = Variable<String>(type);
    map['behavior'] = Variable<String>(behavior);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  LifeHabitsCompanion toCompanion(bool nullToAbsent) {
    return LifeHabitsCompanion(
      id: Value(id),
      name: Value(name),
      iconName: Value(iconName),
      colorArgb: Value(colorArgb),
      dailyTarget: Value(dailyTarget),
      unit: Value(unit),
      type: Value(type),
      behavior: Value(behavior),
      createdAt: Value(createdAt),
    );
  }

  factory LifeHabitRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LifeHabitRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      iconName: serializer.fromJson<String>(json['iconName']),
      colorArgb: serializer.fromJson<int>(json['colorArgb']),
      dailyTarget: serializer.fromJson<int>(json['dailyTarget']),
      unit: serializer.fromJson<String>(json['unit']),
      type: serializer.fromJson<String>(json['type']),
      behavior: serializer.fromJson<String>(json['behavior']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'iconName': serializer.toJson<String>(iconName),
      'colorArgb': serializer.toJson<int>(colorArgb),
      'dailyTarget': serializer.toJson<int>(dailyTarget),
      'unit': serializer.toJson<String>(unit),
      'type': serializer.toJson<String>(type),
      'behavior': serializer.toJson<String>(behavior),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  LifeHabitRow copyWith(
          {String? id,
          String? name,
          String? iconName,
          int? colorArgb,
          int? dailyTarget,
          String? unit,
          String? type,
          String? behavior,
          DateTime? createdAt}) =>
      LifeHabitRow(
        id: id ?? this.id,
        name: name ?? this.name,
        iconName: iconName ?? this.iconName,
        colorArgb: colorArgb ?? this.colorArgb,
        dailyTarget: dailyTarget ?? this.dailyTarget,
        unit: unit ?? this.unit,
        type: type ?? this.type,
        behavior: behavior ?? this.behavior,
        createdAt: createdAt ?? this.createdAt,
      );
  LifeHabitRow copyWithCompanion(LifeHabitsCompanion data) {
    return LifeHabitRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      iconName: data.iconName.present ? data.iconName.value : this.iconName,
      colorArgb: data.colorArgb.present ? data.colorArgb.value : this.colorArgb,
      dailyTarget:
          data.dailyTarget.present ? data.dailyTarget.value : this.dailyTarget,
      unit: data.unit.present ? data.unit.value : this.unit,
      type: data.type.present ? data.type.value : this.type,
      behavior: data.behavior.present ? data.behavior.value : this.behavior,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LifeHabitRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('iconName: $iconName, ')
          ..write('colorArgb: $colorArgb, ')
          ..write('dailyTarget: $dailyTarget, ')
          ..write('unit: $unit, ')
          ..write('type: $type, ')
          ..write('behavior: $behavior, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, iconName, colorArgb, dailyTarget,
      unit, type, behavior, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LifeHabitRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.iconName == this.iconName &&
          other.colorArgb == this.colorArgb &&
          other.dailyTarget == this.dailyTarget &&
          other.unit == this.unit &&
          other.type == this.type &&
          other.behavior == this.behavior &&
          other.createdAt == this.createdAt);
}

class LifeHabitsCompanion extends UpdateCompanion<LifeHabitRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> iconName;
  final Value<int> colorArgb;
  final Value<int> dailyTarget;
  final Value<String> unit;
  final Value<String> type;
  final Value<String> behavior;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const LifeHabitsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.iconName = const Value.absent(),
    this.colorArgb = const Value.absent(),
    this.dailyTarget = const Value.absent(),
    this.unit = const Value.absent(),
    this.type = const Value.absent(),
    this.behavior = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LifeHabitsCompanion.insert({
    required String id,
    required String name,
    required String iconName,
    this.colorArgb = const Value.absent(),
    this.dailyTarget = const Value.absent(),
    this.unit = const Value.absent(),
    this.type = const Value.absent(),
    this.behavior = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        iconName = Value(iconName);
  static Insertable<LifeHabitRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? iconName,
    Expression<int>? colorArgb,
    Expression<int>? dailyTarget,
    Expression<String>? unit,
    Expression<String>? type,
    Expression<String>? behavior,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (iconName != null) 'icon_name': iconName,
      if (colorArgb != null) 'color_argb': colorArgb,
      if (dailyTarget != null) 'daily_target': dailyTarget,
      if (unit != null) 'unit': unit,
      if (type != null) 'type': type,
      if (behavior != null) 'behavior': behavior,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LifeHabitsCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String>? iconName,
      Value<int>? colorArgb,
      Value<int>? dailyTarget,
      Value<String>? unit,
      Value<String>? type,
      Value<String>? behavior,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return LifeHabitsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      iconName: iconName ?? this.iconName,
      colorArgb: colorArgb ?? this.colorArgb,
      dailyTarget: dailyTarget ?? this.dailyTarget,
      unit: unit ?? this.unit,
      type: type ?? this.type,
      behavior: behavior ?? this.behavior,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (iconName.present) {
      map['icon_name'] = Variable<String>(iconName.value);
    }
    if (colorArgb.present) {
      map['color_argb'] = Variable<int>(colorArgb.value);
    }
    if (dailyTarget.present) {
      map['daily_target'] = Variable<int>(dailyTarget.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (behavior.present) {
      map['behavior'] = Variable<String>(behavior.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LifeHabitsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('iconName: $iconName, ')
          ..write('colorArgb: $colorArgb, ')
          ..write('dailyTarget: $dailyTarget, ')
          ..write('unit: $unit, ')
          ..write('type: $type, ')
          ..write('behavior: $behavior, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LifeHabitEventsTable extends LifeHabitEvents
    with TableInfo<$LifeHabitEventsTable, LifeHabitEventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LifeHabitEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _habitIdMeta =
      const VerificationMeta('habitId');
  @override
  late final GeneratedColumn<String> habitId = GeneratedColumn<String>(
      'habit_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _occurredAtMeta =
      const VerificationMeta('occurredAt');
  @override
  late final GeneratedColumn<DateTime> occurredAt = GeneratedColumn<DateTime>(
      'occurred_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<double> value = GeneratedColumn<double>(
      'value', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(1.0));
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
      'note', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [id, habitId, occurredAt, value, note];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'life_habit_events';
  @override
  VerificationContext validateIntegrity(Insertable<LifeHabitEventRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('habit_id')) {
      context.handle(_habitIdMeta,
          habitId.isAcceptableOrUnknown(data['habit_id']!, _habitIdMeta));
    } else if (isInserting) {
      context.missing(_habitIdMeta);
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
          _occurredAtMeta,
          occurredAt.isAcceptableOrUnknown(
              data['occurred_at']!, _occurredAtMeta));
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    }
    if (data.containsKey('note')) {
      context.handle(
          _noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LifeHabitEventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LifeHabitEventRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      habitId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}habit_id'])!,
      occurredAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}occurred_at'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}value'])!,
      note: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note']),
    );
  }

  @override
  $LifeHabitEventsTable createAlias(String alias) {
    return $LifeHabitEventsTable(attachedDatabase, alias);
  }
}

class LifeHabitEventRow extends DataClass
    implements Insertable<LifeHabitEventRow> {
  final String id;
  final String habitId;
  final DateTime occurredAt;
  final double value;
  final String? note;
  const LifeHabitEventRow(
      {required this.id,
      required this.habitId,
      required this.occurredAt,
      required this.value,
      this.note});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['habit_id'] = Variable<String>(habitId);
    map['occurred_at'] = Variable<DateTime>(occurredAt);
    map['value'] = Variable<double>(value);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    return map;
  }

  LifeHabitEventsCompanion toCompanion(bool nullToAbsent) {
    return LifeHabitEventsCompanion(
      id: Value(id),
      habitId: Value(habitId),
      occurredAt: Value(occurredAt),
      value: Value(value),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
    );
  }

  factory LifeHabitEventRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LifeHabitEventRow(
      id: serializer.fromJson<String>(json['id']),
      habitId: serializer.fromJson<String>(json['habitId']),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
      value: serializer.fromJson<double>(json['value']),
      note: serializer.fromJson<String?>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'habitId': serializer.toJson<String>(habitId),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
      'value': serializer.toJson<double>(value),
      'note': serializer.toJson<String?>(note),
    };
  }

  LifeHabitEventRow copyWith(
          {String? id,
          String? habitId,
          DateTime? occurredAt,
          double? value,
          Value<String?> note = const Value.absent()}) =>
      LifeHabitEventRow(
        id: id ?? this.id,
        habitId: habitId ?? this.habitId,
        occurredAt: occurredAt ?? this.occurredAt,
        value: value ?? this.value,
        note: note.present ? note.value : this.note,
      );
  LifeHabitEventRow copyWithCompanion(LifeHabitEventsCompanion data) {
    return LifeHabitEventRow(
      id: data.id.present ? data.id.value : this.id,
      habitId: data.habitId.present ? data.habitId.value : this.habitId,
      occurredAt:
          data.occurredAt.present ? data.occurredAt.value : this.occurredAt,
      value: data.value.present ? data.value.value : this.value,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LifeHabitEventRow(')
          ..write('id: $id, ')
          ..write('habitId: $habitId, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('value: $value, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, habitId, occurredAt, value, note);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LifeHabitEventRow &&
          other.id == this.id &&
          other.habitId == this.habitId &&
          other.occurredAt == this.occurredAt &&
          other.value == this.value &&
          other.note == this.note);
}

class LifeHabitEventsCompanion extends UpdateCompanion<LifeHabitEventRow> {
  final Value<String> id;
  final Value<String> habitId;
  final Value<DateTime> occurredAt;
  final Value<double> value;
  final Value<String?> note;
  final Value<int> rowid;
  const LifeHabitEventsCompanion({
    this.id = const Value.absent(),
    this.habitId = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.value = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LifeHabitEventsCompanion.insert({
    required String id,
    required String habitId,
    this.occurredAt = const Value.absent(),
    this.value = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        habitId = Value(habitId);
  static Insertable<LifeHabitEventRow> custom({
    Expression<String>? id,
    Expression<String>? habitId,
    Expression<DateTime>? occurredAt,
    Expression<double>? value,
    Expression<String>? note,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (habitId != null) 'habit_id': habitId,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (value != null) 'value': value,
      if (note != null) 'note': note,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LifeHabitEventsCompanion copyWith(
      {Value<String>? id,
      Value<String>? habitId,
      Value<DateTime>? occurredAt,
      Value<double>? value,
      Value<String?>? note,
      Value<int>? rowid}) {
    return LifeHabitEventsCompanion(
      id: id ?? this.id,
      habitId: habitId ?? this.habitId,
      occurredAt: occurredAt ?? this.occurredAt,
      value: value ?? this.value,
      note: note ?? this.note,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (habitId.present) {
      map['habit_id'] = Variable<String>(habitId.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(occurredAt.value);
    }
    if (value.present) {
      map['value'] = Variable<double>(value.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LifeHabitEventsCompanion(')
          ..write('id: $id, ')
          ..write('habitId: $habitId, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('value: $value, ')
          ..write('note: $note, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ActiveSessionsTable extends ActiveSessions
    with TableInfo<$ActiveSessionsTable, ActiveSessionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ActiveSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _habitIdMeta =
      const VerificationMeta('habitId');
  @override
  late final GeneratedColumn<String> habitId = GeneratedColumn<String>(
      'habit_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _startedAtMeta =
      const VerificationMeta('startedAt');
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
      'started_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [habitId, startedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'active_sessions';
  @override
  VerificationContext validateIntegrity(Insertable<ActiveSessionRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('habit_id')) {
      context.handle(_habitIdMeta,
          habitId.isAcceptableOrUnknown(data['habit_id']!, _habitIdMeta));
    } else if (isInserting) {
      context.missing(_habitIdMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(_startedAtMeta,
          startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {habitId};
  @override
  ActiveSessionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ActiveSessionRow(
      habitId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}habit_id'])!,
      startedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}started_at'])!,
    );
  }

  @override
  $ActiveSessionsTable createAlias(String alias) {
    return $ActiveSessionsTable(attachedDatabase, alias);
  }
}

class ActiveSessionRow extends DataClass
    implements Insertable<ActiveSessionRow> {
  final String habitId;
  final DateTime startedAt;
  const ActiveSessionRow({required this.habitId, required this.startedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['habit_id'] = Variable<String>(habitId);
    map['started_at'] = Variable<DateTime>(startedAt);
    return map;
  }

  ActiveSessionsCompanion toCompanion(bool nullToAbsent) {
    return ActiveSessionsCompanion(
      habitId: Value(habitId),
      startedAt: Value(startedAt),
    );
  }

  factory ActiveSessionRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ActiveSessionRow(
      habitId: serializer.fromJson<String>(json['habitId']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'habitId': serializer.toJson<String>(habitId),
      'startedAt': serializer.toJson<DateTime>(startedAt),
    };
  }

  ActiveSessionRow copyWith({String? habitId, DateTime? startedAt}) =>
      ActiveSessionRow(
        habitId: habitId ?? this.habitId,
        startedAt: startedAt ?? this.startedAt,
      );
  ActiveSessionRow copyWithCompanion(ActiveSessionsCompanion data) {
    return ActiveSessionRow(
      habitId: data.habitId.present ? data.habitId.value : this.habitId,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ActiveSessionRow(')
          ..write('habitId: $habitId, ')
          ..write('startedAt: $startedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(habitId, startedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ActiveSessionRow &&
          other.habitId == this.habitId &&
          other.startedAt == this.startedAt);
}

class ActiveSessionsCompanion extends UpdateCompanion<ActiveSessionRow> {
  final Value<String> habitId;
  final Value<DateTime> startedAt;
  final Value<int> rowid;
  const ActiveSessionsCompanion({
    this.habitId = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ActiveSessionsCompanion.insert({
    required String habitId,
    this.startedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : habitId = Value(habitId);
  static Insertable<ActiveSessionRow> custom({
    Expression<String>? habitId,
    Expression<DateTime>? startedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (habitId != null) 'habit_id': habitId,
      if (startedAt != null) 'started_at': startedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ActiveSessionsCompanion copyWith(
      {Value<String>? habitId, Value<DateTime>? startedAt, Value<int>? rowid}) {
    return ActiveSessionsCompanion(
      habitId: habitId ?? this.habitId,
      startedAt: startedAt ?? this.startedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (habitId.present) {
      map['habit_id'] = Variable<String>(habitId.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ActiveSessionsCompanion(')
          ..write('habitId: $habitId, ')
          ..write('startedAt: $startedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $InboxItemsTable extends InboxItems
    with TableInfo<$InboxItemsTable, InboxItemRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InboxItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _contentMeta =
      const VerificationMeta('content');
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
      'content', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
      'kind', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('note'));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _syncedMeta = const VerificationMeta('synced');
  @override
  late final GeneratedColumn<int> synced = GeneratedColumn<int>(
      'synced', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns => [id, content, kind, createdAt, synced];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'inbox_items';
  @override
  VerificationContext validateIntegrity(Insertable<InboxItemRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('content')) {
      context.handle(_contentMeta,
          content.isAcceptableOrUnknown(data['content']!, _contentMeta));
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
          _kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('synced')) {
      context.handle(_syncedMeta,
          synced.isAcceptableOrUnknown(data['synced']!, _syncedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  InboxItemRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InboxItemRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      content: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content'])!,
      kind: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      synced: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}synced'])!,
    );
  }

  @override
  $InboxItemsTable createAlias(String alias) {
    return $InboxItemsTable(attachedDatabase, alias);
  }
}

class InboxItemRow extends DataClass implements Insertable<InboxItemRow> {
  final String id;
  final String content;
  final String kind;
  final DateTime createdAt;
  final int synced;
  const InboxItemRow(
      {required this.id,
      required this.content,
      required this.kind,
      required this.createdAt,
      required this.synced});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['content'] = Variable<String>(content);
    map['kind'] = Variable<String>(kind);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['synced'] = Variable<int>(synced);
    return map;
  }

  InboxItemsCompanion toCompanion(bool nullToAbsent) {
    return InboxItemsCompanion(
      id: Value(id),
      content: Value(content),
      kind: Value(kind),
      createdAt: Value(createdAt),
      synced: Value(synced),
    );
  }

  factory InboxItemRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InboxItemRow(
      id: serializer.fromJson<String>(json['id']),
      content: serializer.fromJson<String>(json['content']),
      kind: serializer.fromJson<String>(json['kind']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      synced: serializer.fromJson<int>(json['synced']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'content': serializer.toJson<String>(content),
      'kind': serializer.toJson<String>(kind),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'synced': serializer.toJson<int>(synced),
    };
  }

  InboxItemRow copyWith(
          {String? id,
          String? content,
          String? kind,
          DateTime? createdAt,
          int? synced}) =>
      InboxItemRow(
        id: id ?? this.id,
        content: content ?? this.content,
        kind: kind ?? this.kind,
        createdAt: createdAt ?? this.createdAt,
        synced: synced ?? this.synced,
      );
  InboxItemRow copyWithCompanion(InboxItemsCompanion data) {
    return InboxItemRow(
      id: data.id.present ? data.id.value : this.id,
      content: data.content.present ? data.content.value : this.content,
      kind: data.kind.present ? data.kind.value : this.kind,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      synced: data.synced.present ? data.synced.value : this.synced,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InboxItemRow(')
          ..write('id: $id, ')
          ..write('content: $content, ')
          ..write('kind: $kind, ')
          ..write('createdAt: $createdAt, ')
          ..write('synced: $synced')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, content, kind, createdAt, synced);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InboxItemRow &&
          other.id == this.id &&
          other.content == this.content &&
          other.kind == this.kind &&
          other.createdAt == this.createdAt &&
          other.synced == this.synced);
}

class InboxItemsCompanion extends UpdateCompanion<InboxItemRow> {
  final Value<String> id;
  final Value<String> content;
  final Value<String> kind;
  final Value<DateTime> createdAt;
  final Value<int> synced;
  final Value<int> rowid;
  const InboxItemsCompanion({
    this.id = const Value.absent(),
    this.content = const Value.absent(),
    this.kind = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.synced = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  InboxItemsCompanion.insert({
    required String id,
    required String content,
    this.kind = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.synced = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        content = Value(content);
  static Insertable<InboxItemRow> custom({
    Expression<String>? id,
    Expression<String>? content,
    Expression<String>? kind,
    Expression<DateTime>? createdAt,
    Expression<int>? synced,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (content != null) 'content': content,
      if (kind != null) 'kind': kind,
      if (createdAt != null) 'created_at': createdAt,
      if (synced != null) 'synced': synced,
      if (rowid != null) 'rowid': rowid,
    });
  }

  InboxItemsCompanion copyWith(
      {Value<String>? id,
      Value<String>? content,
      Value<String>? kind,
      Value<DateTime>? createdAt,
      Value<int>? synced,
      Value<int>? rowid}) {
    return InboxItemsCompanion(
      id: id ?? this.id,
      content: content ?? this.content,
      kind: kind ?? this.kind,
      createdAt: createdAt ?? this.createdAt,
      synced: synced ?? this.synced,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (synced.present) {
      map['synced'] = Variable<int>(synced.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InboxItemsCompanion(')
          ..write('id: $id, ')
          ..write('content: $content, ')
          ..write('kind: $kind, ')
          ..write('createdAt: $createdAt, ')
          ..write('synced: $synced, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncEventsLocalTable extends SyncEventsLocal
    with TableInfo<$SyncEventsLocalTable, SyncEventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncEventsLocalTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _entityTypeMeta =
      const VerificationMeta('entityType');
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
      'entity_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _entityIdMeta =
      const VerificationMeta('entityId');
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
      'entity_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _operationMeta =
      const VerificationMeta('operation');
  @override
  late final GeneratedColumn<String> operation = GeneratedColumn<String>(
      'operation', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _payloadMeta =
      const VerificationMeta('payload');
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
      'payload', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _syncedMeta = const VerificationMeta('synced');
  @override
  late final GeneratedColumn<int> synced = GeneratedColumn<int>(
      'synced', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns =>
      [id, entityType, entityId, operation, payload, createdAt, synced];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_events_local';
  @override
  VerificationContext validateIntegrity(Insertable<SyncEventRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('entity_type')) {
      context.handle(
          _entityTypeMeta,
          entityType.isAcceptableOrUnknown(
              data['entity_type']!, _entityTypeMeta));
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(_entityIdMeta,
          entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta));
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('operation')) {
      context.handle(_operationMeta,
          operation.isAcceptableOrUnknown(data['operation']!, _operationMeta));
    } else if (isInserting) {
      context.missing(_operationMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(_payloadMeta,
          payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta));
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('synced')) {
      context.handle(_syncedMeta,
          synced.isAcceptableOrUnknown(data['synced']!, _syncedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncEventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncEventRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      entityType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}entity_type'])!,
      entityId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}entity_id'])!,
      operation: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}operation'])!,
      payload: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      synced: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}synced'])!,
    );
  }

  @override
  $SyncEventsLocalTable createAlias(String alias) {
    return $SyncEventsLocalTable(attachedDatabase, alias);
  }
}

class SyncEventRow extends DataClass implements Insertable<SyncEventRow> {
  final String id;
  final String entityType;
  final String entityId;
  final String operation;
  final String payload;
  final DateTime createdAt;
  final int synced;
  const SyncEventRow(
      {required this.id,
      required this.entityType,
      required this.entityId,
      required this.operation,
      required this.payload,
      required this.createdAt,
      required this.synced});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['entity_type'] = Variable<String>(entityType);
    map['entity_id'] = Variable<String>(entityId);
    map['operation'] = Variable<String>(operation);
    map['payload'] = Variable<String>(payload);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['synced'] = Variable<int>(synced);
    return map;
  }

  SyncEventsLocalCompanion toCompanion(bool nullToAbsent) {
    return SyncEventsLocalCompanion(
      id: Value(id),
      entityType: Value(entityType),
      entityId: Value(entityId),
      operation: Value(operation),
      payload: Value(payload),
      createdAt: Value(createdAt),
      synced: Value(synced),
    );
  }

  factory SyncEventRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncEventRow(
      id: serializer.fromJson<String>(json['id']),
      entityType: serializer.fromJson<String>(json['entityType']),
      entityId: serializer.fromJson<String>(json['entityId']),
      operation: serializer.fromJson<String>(json['operation']),
      payload: serializer.fromJson<String>(json['payload']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      synced: serializer.fromJson<int>(json['synced']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'entityType': serializer.toJson<String>(entityType),
      'entityId': serializer.toJson<String>(entityId),
      'operation': serializer.toJson<String>(operation),
      'payload': serializer.toJson<String>(payload),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'synced': serializer.toJson<int>(synced),
    };
  }

  SyncEventRow copyWith(
          {String? id,
          String? entityType,
          String? entityId,
          String? operation,
          String? payload,
          DateTime? createdAt,
          int? synced}) =>
      SyncEventRow(
        id: id ?? this.id,
        entityType: entityType ?? this.entityType,
        entityId: entityId ?? this.entityId,
        operation: operation ?? this.operation,
        payload: payload ?? this.payload,
        createdAt: createdAt ?? this.createdAt,
        synced: synced ?? this.synced,
      );
  SyncEventRow copyWithCompanion(SyncEventsLocalCompanion data) {
    return SyncEventRow(
      id: data.id.present ? data.id.value : this.id,
      entityType:
          data.entityType.present ? data.entityType.value : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      operation: data.operation.present ? data.operation.value : this.operation,
      payload: data.payload.present ? data.payload.value : this.payload,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      synced: data.synced.present ? data.synced.value : this.synced,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncEventRow(')
          ..write('id: $id, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('operation: $operation, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('synced: $synced')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, entityType, entityId, operation, payload, createdAt, synced);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncEventRow &&
          other.id == this.id &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.operation == this.operation &&
          other.payload == this.payload &&
          other.createdAt == this.createdAt &&
          other.synced == this.synced);
}

class SyncEventsLocalCompanion extends UpdateCompanion<SyncEventRow> {
  final Value<String> id;
  final Value<String> entityType;
  final Value<String> entityId;
  final Value<String> operation;
  final Value<String> payload;
  final Value<DateTime> createdAt;
  final Value<int> synced;
  final Value<int> rowid;
  const SyncEventsLocalCompanion({
    this.id = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.operation = const Value.absent(),
    this.payload = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.synced = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncEventsLocalCompanion.insert({
    required String id,
    required String entityType,
    required String entityId,
    required String operation,
    required String payload,
    this.createdAt = const Value.absent(),
    this.synced = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        entityType = Value(entityType),
        entityId = Value(entityId),
        operation = Value(operation),
        payload = Value(payload);
  static Insertable<SyncEventRow> custom({
    Expression<String>? id,
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<String>? operation,
    Expression<String>? payload,
    Expression<DateTime>? createdAt,
    Expression<int>? synced,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (operation != null) 'operation': operation,
      if (payload != null) 'payload': payload,
      if (createdAt != null) 'created_at': createdAt,
      if (synced != null) 'synced': synced,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncEventsLocalCompanion copyWith(
      {Value<String>? id,
      Value<String>? entityType,
      Value<String>? entityId,
      Value<String>? operation,
      Value<String>? payload,
      Value<DateTime>? createdAt,
      Value<int>? synced,
      Value<int>? rowid}) {
    return SyncEventsLocalCompanion(
      id: id ?? this.id,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      operation: operation ?? this.operation,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      synced: synced ?? this.synced,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (operation.present) {
      map['operation'] = Variable<String>(operation.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (synced.present) {
      map['synced'] = Variable<int>(synced.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncEventsLocalCompanion(')
          ..write('id: $id, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('operation: $operation, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('synced: $synced, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MomentsTable extends Moments with TableInfo<$MomentsTable, MomentRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MomentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _authorTypeMeta =
      const VerificationMeta('authorType');
  @override
  late final GeneratedColumn<String> authorType = GeneratedColumn<String>(
      'author_type', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('user'));
  static const VerificationMeta _contentMeta =
      const VerificationMeta('content');
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
      'content', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _visibilityMeta =
      const VerificationMeta('visibility');
  @override
  late final GeneratedColumn<String> visibility = GeneratedColumn<String>(
      'visibility', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('private'));
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
      'source', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('manual'));
  static const VerificationMeta _deviceIdMeta =
      const VerificationMeta('deviceId');
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
      'device_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [id, authorType, content, visibility, source, deviceId, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'moments';
  @override
  VerificationContext validateIntegrity(Insertable<MomentRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('author_type')) {
      context.handle(
          _authorTypeMeta,
          authorType.isAcceptableOrUnknown(
              data['author_type']!, _authorTypeMeta));
    }
    if (data.containsKey('content')) {
      context.handle(_contentMeta,
          content.isAcceptableOrUnknown(data['content']!, _contentMeta));
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('visibility')) {
      context.handle(
          _visibilityMeta,
          visibility.isAcceptableOrUnknown(
              data['visibility']!, _visibilityMeta));
    }
    if (data.containsKey('source')) {
      context.handle(_sourceMeta,
          source.isAcceptableOrUnknown(data['source']!, _sourceMeta));
    }
    if (data.containsKey('device_id')) {
      context.handle(_deviceIdMeta,
          deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta));
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MomentRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MomentRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      authorType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}author_type'])!,
      content: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content'])!,
      visibility: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}visibility'])!,
      source: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source'])!,
      deviceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}device_id'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $MomentsTable createAlias(String alias) {
    return $MomentsTable(attachedDatabase, alias);
  }
}

class MomentRow extends DataClass implements Insertable<MomentRow> {
  final String id;
  final String authorType;
  final String content;
  final String visibility;
  final String source;
  final String deviceId;
  final DateTime createdAt;
  const MomentRow(
      {required this.id,
      required this.authorType,
      required this.content,
      required this.visibility,
      required this.source,
      required this.deviceId,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['author_type'] = Variable<String>(authorType);
    map['content'] = Variable<String>(content);
    map['visibility'] = Variable<String>(visibility);
    map['source'] = Variable<String>(source);
    map['device_id'] = Variable<String>(deviceId);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  MomentsCompanion toCompanion(bool nullToAbsent) {
    return MomentsCompanion(
      id: Value(id),
      authorType: Value(authorType),
      content: Value(content),
      visibility: Value(visibility),
      source: Value(source),
      deviceId: Value(deviceId),
      createdAt: Value(createdAt),
    );
  }

  factory MomentRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MomentRow(
      id: serializer.fromJson<String>(json['id']),
      authorType: serializer.fromJson<String>(json['authorType']),
      content: serializer.fromJson<String>(json['content']),
      visibility: serializer.fromJson<String>(json['visibility']),
      source: serializer.fromJson<String>(json['source']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'authorType': serializer.toJson<String>(authorType),
      'content': serializer.toJson<String>(content),
      'visibility': serializer.toJson<String>(visibility),
      'source': serializer.toJson<String>(source),
      'deviceId': serializer.toJson<String>(deviceId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  MomentRow copyWith(
          {String? id,
          String? authorType,
          String? content,
          String? visibility,
          String? source,
          String? deviceId,
          DateTime? createdAt}) =>
      MomentRow(
        id: id ?? this.id,
        authorType: authorType ?? this.authorType,
        content: content ?? this.content,
        visibility: visibility ?? this.visibility,
        source: source ?? this.source,
        deviceId: deviceId ?? this.deviceId,
        createdAt: createdAt ?? this.createdAt,
      );
  MomentRow copyWithCompanion(MomentsCompanion data) {
    return MomentRow(
      id: data.id.present ? data.id.value : this.id,
      authorType:
          data.authorType.present ? data.authorType.value : this.authorType,
      content: data.content.present ? data.content.value : this.content,
      visibility:
          data.visibility.present ? data.visibility.value : this.visibility,
      source: data.source.present ? data.source.value : this.source,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MomentRow(')
          ..write('id: $id, ')
          ..write('authorType: $authorType, ')
          ..write('content: $content, ')
          ..write('visibility: $visibility, ')
          ..write('source: $source, ')
          ..write('deviceId: $deviceId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, authorType, content, visibility, source, deviceId, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MomentRow &&
          other.id == this.id &&
          other.authorType == this.authorType &&
          other.content == this.content &&
          other.visibility == this.visibility &&
          other.source == this.source &&
          other.deviceId == this.deviceId &&
          other.createdAt == this.createdAt);
}

class MomentsCompanion extends UpdateCompanion<MomentRow> {
  final Value<String> id;
  final Value<String> authorType;
  final Value<String> content;
  final Value<String> visibility;
  final Value<String> source;
  final Value<String> deviceId;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const MomentsCompanion({
    this.id = const Value.absent(),
    this.authorType = const Value.absent(),
    this.content = const Value.absent(),
    this.visibility = const Value.absent(),
    this.source = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MomentsCompanion.insert({
    required String id,
    this.authorType = const Value.absent(),
    required String content,
    this.visibility = const Value.absent(),
    this.source = const Value.absent(),
    required String deviceId,
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        content = Value(content),
        deviceId = Value(deviceId);
  static Insertable<MomentRow> custom({
    Expression<String>? id,
    Expression<String>? authorType,
    Expression<String>? content,
    Expression<String>? visibility,
    Expression<String>? source,
    Expression<String>? deviceId,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (authorType != null) 'author_type': authorType,
      if (content != null) 'content': content,
      if (visibility != null) 'visibility': visibility,
      if (source != null) 'source': source,
      if (deviceId != null) 'device_id': deviceId,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MomentsCompanion copyWith(
      {Value<String>? id,
      Value<String>? authorType,
      Value<String>? content,
      Value<String>? visibility,
      Value<String>? source,
      Value<String>? deviceId,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return MomentsCompanion(
      id: id ?? this.id,
      authorType: authorType ?? this.authorType,
      content: content ?? this.content,
      visibility: visibility ?? this.visibility,
      source: source ?? this.source,
      deviceId: deviceId ?? this.deviceId,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (authorType.present) {
      map['author_type'] = Variable<String>(authorType.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (visibility.present) {
      map['visibility'] = Variable<String>(visibility.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MomentsCompanion(')
          ..write('id: $id, ')
          ..write('authorType: $authorType, ')
          ..write('content: $content, ')
          ..write('visibility: $visibility, ')
          ..write('source: $source, ')
          ..write('deviceId: $deviceId, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StudyResourcesTable extends StudyResources
    with TableInfo<$StudyResourcesTable, StudyResourceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StudyResourcesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _categoryMeta =
      const VerificationMeta('category');
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
      'category', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('其他'));
  static const VerificationMeta _iconNameMeta =
      const VerificationMeta('iconName');
  @override
  late final GeneratedColumn<String> iconName = GeneratedColumn<String>(
      'icon_name', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('book'));
  static const VerificationMeta _colorArgbMeta =
      const VerificationMeta('colorArgb');
  @override
  late final GeneratedColumn<int> colorArgb = GeneratedColumn<int>(
      'color_argb', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0xFF2196F3));
  static const VerificationMeta _goalAmountMeta =
      const VerificationMeta('goalAmount');
  @override
  late final GeneratedColumn<double> goalAmount = GeneratedColumn<double>(
      'goal_amount', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _goalUnitMeta =
      const VerificationMeta('goalUnit');
  @override
  late final GeneratedColumn<String> goalUnit = GeneratedColumn<String>(
      'goal_unit', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        category,
        iconName,
        colorArgb,
        goalAmount,
        goalUnit,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'study_resources';
  @override
  VerificationContext validateIntegrity(Insertable<StudyResourceRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('category')) {
      context.handle(_categoryMeta,
          category.isAcceptableOrUnknown(data['category']!, _categoryMeta));
    }
    if (data.containsKey('icon_name')) {
      context.handle(_iconNameMeta,
          iconName.isAcceptableOrUnknown(data['icon_name']!, _iconNameMeta));
    }
    if (data.containsKey('color_argb')) {
      context.handle(_colorArgbMeta,
          colorArgb.isAcceptableOrUnknown(data['color_argb']!, _colorArgbMeta));
    }
    if (data.containsKey('goal_amount')) {
      context.handle(
          _goalAmountMeta,
          goalAmount.isAcceptableOrUnknown(
              data['goal_amount']!, _goalAmountMeta));
    }
    if (data.containsKey('goal_unit')) {
      context.handle(_goalUnitMeta,
          goalUnit.isAcceptableOrUnknown(data['goal_unit']!, _goalUnitMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StudyResourceRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StudyResourceRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      category: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category'])!,
      iconName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}icon_name'])!,
      colorArgb: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}color_argb'])!,
      goalAmount: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}goal_amount'])!,
      goalUnit: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}goal_unit'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $StudyResourcesTable createAlias(String alias) {
    return $StudyResourcesTable(attachedDatabase, alias);
  }
}

class StudyResourceRow extends DataClass
    implements Insertable<StudyResourceRow> {
  final String id;
  final String name;
  final String category;
  final String iconName;
  final int colorArgb;
  final double goalAmount;
  final String goalUnit;
  final DateTime createdAt;
  const StudyResourceRow(
      {required this.id,
      required this.name,
      required this.category,
      required this.iconName,
      required this.colorArgb,
      required this.goalAmount,
      required this.goalUnit,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['category'] = Variable<String>(category);
    map['icon_name'] = Variable<String>(iconName);
    map['color_argb'] = Variable<int>(colorArgb);
    map['goal_amount'] = Variable<double>(goalAmount);
    map['goal_unit'] = Variable<String>(goalUnit);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  StudyResourcesCompanion toCompanion(bool nullToAbsent) {
    return StudyResourcesCompanion(
      id: Value(id),
      name: Value(name),
      category: Value(category),
      iconName: Value(iconName),
      colorArgb: Value(colorArgb),
      goalAmount: Value(goalAmount),
      goalUnit: Value(goalUnit),
      createdAt: Value(createdAt),
    );
  }

  factory StudyResourceRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StudyResourceRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      category: serializer.fromJson<String>(json['category']),
      iconName: serializer.fromJson<String>(json['iconName']),
      colorArgb: serializer.fromJson<int>(json['colorArgb']),
      goalAmount: serializer.fromJson<double>(json['goalAmount']),
      goalUnit: serializer.fromJson<String>(json['goalUnit']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'category': serializer.toJson<String>(category),
      'iconName': serializer.toJson<String>(iconName),
      'colorArgb': serializer.toJson<int>(colorArgb),
      'goalAmount': serializer.toJson<double>(goalAmount),
      'goalUnit': serializer.toJson<String>(goalUnit),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  StudyResourceRow copyWith(
          {String? id,
          String? name,
          String? category,
          String? iconName,
          int? colorArgb,
          double? goalAmount,
          String? goalUnit,
          DateTime? createdAt}) =>
      StudyResourceRow(
        id: id ?? this.id,
        name: name ?? this.name,
        category: category ?? this.category,
        iconName: iconName ?? this.iconName,
        colorArgb: colorArgb ?? this.colorArgb,
        goalAmount: goalAmount ?? this.goalAmount,
        goalUnit: goalUnit ?? this.goalUnit,
        createdAt: createdAt ?? this.createdAt,
      );
  StudyResourceRow copyWithCompanion(StudyResourcesCompanion data) {
    return StudyResourceRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      category: data.category.present ? data.category.value : this.category,
      iconName: data.iconName.present ? data.iconName.value : this.iconName,
      colorArgb: data.colorArgb.present ? data.colorArgb.value : this.colorArgb,
      goalAmount:
          data.goalAmount.present ? data.goalAmount.value : this.goalAmount,
      goalUnit: data.goalUnit.present ? data.goalUnit.value : this.goalUnit,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StudyResourceRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('category: $category, ')
          ..write('iconName: $iconName, ')
          ..write('colorArgb: $colorArgb, ')
          ..write('goalAmount: $goalAmount, ')
          ..write('goalUnit: $goalUnit, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, name, category, iconName, colorArgb, goalAmount, goalUnit, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StudyResourceRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.category == this.category &&
          other.iconName == this.iconName &&
          other.colorArgb == this.colorArgb &&
          other.goalAmount == this.goalAmount &&
          other.goalUnit == this.goalUnit &&
          other.createdAt == this.createdAt);
}

class StudyResourcesCompanion extends UpdateCompanion<StudyResourceRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> category;
  final Value<String> iconName;
  final Value<int> colorArgb;
  final Value<double> goalAmount;
  final Value<String> goalUnit;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const StudyResourcesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.category = const Value.absent(),
    this.iconName = const Value.absent(),
    this.colorArgb = const Value.absent(),
    this.goalAmount = const Value.absent(),
    this.goalUnit = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StudyResourcesCompanion.insert({
    required String id,
    required String name,
    this.category = const Value.absent(),
    this.iconName = const Value.absent(),
    this.colorArgb = const Value.absent(),
    this.goalAmount = const Value.absent(),
    this.goalUnit = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name);
  static Insertable<StudyResourceRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? category,
    Expression<String>? iconName,
    Expression<int>? colorArgb,
    Expression<double>? goalAmount,
    Expression<String>? goalUnit,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (category != null) 'category': category,
      if (iconName != null) 'icon_name': iconName,
      if (colorArgb != null) 'color_argb': colorArgb,
      if (goalAmount != null) 'goal_amount': goalAmount,
      if (goalUnit != null) 'goal_unit': goalUnit,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StudyResourcesCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String>? category,
      Value<String>? iconName,
      Value<int>? colorArgb,
      Value<double>? goalAmount,
      Value<String>? goalUnit,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return StudyResourcesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      iconName: iconName ?? this.iconName,
      colorArgb: colorArgb ?? this.colorArgb,
      goalAmount: goalAmount ?? this.goalAmount,
      goalUnit: goalUnit ?? this.goalUnit,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (iconName.present) {
      map['icon_name'] = Variable<String>(iconName.value);
    }
    if (colorArgb.present) {
      map['color_argb'] = Variable<int>(colorArgb.value);
    }
    if (goalAmount.present) {
      map['goal_amount'] = Variable<double>(goalAmount.value);
    }
    if (goalUnit.present) {
      map['goal_unit'] = Variable<String>(goalUnit.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StudyResourcesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('category: $category, ')
          ..write('iconName: $iconName, ')
          ..write('colorArgb: $colorArgb, ')
          ..write('goalAmount: $goalAmount, ')
          ..write('goalUnit: $goalUnit, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StudySessionsTable extends StudySessions
    with TableInfo<$StudySessionsTable, StudySessionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StudySessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _resourceIdMeta =
      const VerificationMeta('resourceId');
  @override
  late final GeneratedColumn<String> resourceId = GeneratedColumn<String>(
      'resource_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _startedAtMeta =
      const VerificationMeta('startedAt');
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
      'started_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _durationSecondsMeta =
      const VerificationMeta('durationSeconds');
  @override
  late final GeneratedColumn<double> durationSeconds = GeneratedColumn<double>(
      'duration_seconds', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<double> amount = GeneratedColumn<double>(
      'amount', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
      'note', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, resourceId, startedAt, durationSeconds, amount, note];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'study_sessions';
  @override
  VerificationContext validateIntegrity(Insertable<StudySessionRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('resource_id')) {
      context.handle(
          _resourceIdMeta,
          resourceId.isAcceptableOrUnknown(
              data['resource_id']!, _resourceIdMeta));
    } else if (isInserting) {
      context.missing(_resourceIdMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(_startedAtMeta,
          startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta));
    }
    if (data.containsKey('duration_seconds')) {
      context.handle(
          _durationSecondsMeta,
          durationSeconds.isAcceptableOrUnknown(
              data['duration_seconds']!, _durationSecondsMeta));
    }
    if (data.containsKey('amount')) {
      context.handle(_amountMeta,
          amount.isAcceptableOrUnknown(data['amount']!, _amountMeta));
    }
    if (data.containsKey('note')) {
      context.handle(
          _noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StudySessionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StudySessionRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      resourceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}resource_id'])!,
      startedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}started_at'])!,
      durationSeconds: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}duration_seconds'])!,
      amount: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}amount'])!,
      note: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note']),
    );
  }

  @override
  $StudySessionsTable createAlias(String alias) {
    return $StudySessionsTable(attachedDatabase, alias);
  }
}

class StudySessionRow extends DataClass implements Insertable<StudySessionRow> {
  final String id;
  final String resourceId;
  final DateTime startedAt;
  final double durationSeconds;
  final double amount;
  final String? note;
  const StudySessionRow(
      {required this.id,
      required this.resourceId,
      required this.startedAt,
      required this.durationSeconds,
      required this.amount,
      this.note});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['resource_id'] = Variable<String>(resourceId);
    map['started_at'] = Variable<DateTime>(startedAt);
    map['duration_seconds'] = Variable<double>(durationSeconds);
    map['amount'] = Variable<double>(amount);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    return map;
  }

  StudySessionsCompanion toCompanion(bool nullToAbsent) {
    return StudySessionsCompanion(
      id: Value(id),
      resourceId: Value(resourceId),
      startedAt: Value(startedAt),
      durationSeconds: Value(durationSeconds),
      amount: Value(amount),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
    );
  }

  factory StudySessionRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StudySessionRow(
      id: serializer.fromJson<String>(json['id']),
      resourceId: serializer.fromJson<String>(json['resourceId']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      durationSeconds: serializer.fromJson<double>(json['durationSeconds']),
      amount: serializer.fromJson<double>(json['amount']),
      note: serializer.fromJson<String?>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'resourceId': serializer.toJson<String>(resourceId),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'durationSeconds': serializer.toJson<double>(durationSeconds),
      'amount': serializer.toJson<double>(amount),
      'note': serializer.toJson<String?>(note),
    };
  }

  StudySessionRow copyWith(
          {String? id,
          String? resourceId,
          DateTime? startedAt,
          double? durationSeconds,
          double? amount,
          Value<String?> note = const Value.absent()}) =>
      StudySessionRow(
        id: id ?? this.id,
        resourceId: resourceId ?? this.resourceId,
        startedAt: startedAt ?? this.startedAt,
        durationSeconds: durationSeconds ?? this.durationSeconds,
        amount: amount ?? this.amount,
        note: note.present ? note.value : this.note,
      );
  StudySessionRow copyWithCompanion(StudySessionsCompanion data) {
    return StudySessionRow(
      id: data.id.present ? data.id.value : this.id,
      resourceId:
          data.resourceId.present ? data.resourceId.value : this.resourceId,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      durationSeconds: data.durationSeconds.present
          ? data.durationSeconds.value
          : this.durationSeconds,
      amount: data.amount.present ? data.amount.value : this.amount,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StudySessionRow(')
          ..write('id: $id, ')
          ..write('resourceId: $resourceId, ')
          ..write('startedAt: $startedAt, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('amount: $amount, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, resourceId, startedAt, durationSeconds, amount, note);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StudySessionRow &&
          other.id == this.id &&
          other.resourceId == this.resourceId &&
          other.startedAt == this.startedAt &&
          other.durationSeconds == this.durationSeconds &&
          other.amount == this.amount &&
          other.note == this.note);
}

class StudySessionsCompanion extends UpdateCompanion<StudySessionRow> {
  final Value<String> id;
  final Value<String> resourceId;
  final Value<DateTime> startedAt;
  final Value<double> durationSeconds;
  final Value<double> amount;
  final Value<String?> note;
  final Value<int> rowid;
  const StudySessionsCompanion({
    this.id = const Value.absent(),
    this.resourceId = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.amount = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StudySessionsCompanion.insert({
    required String id,
    required String resourceId,
    this.startedAt = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.amount = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        resourceId = Value(resourceId);
  static Insertable<StudySessionRow> custom({
    Expression<String>? id,
    Expression<String>? resourceId,
    Expression<DateTime>? startedAt,
    Expression<double>? durationSeconds,
    Expression<double>? amount,
    Expression<String>? note,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (resourceId != null) 'resource_id': resourceId,
      if (startedAt != null) 'started_at': startedAt,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (amount != null) 'amount': amount,
      if (note != null) 'note': note,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StudySessionsCompanion copyWith(
      {Value<String>? id,
      Value<String>? resourceId,
      Value<DateTime>? startedAt,
      Value<double>? durationSeconds,
      Value<double>? amount,
      Value<String?>? note,
      Value<int>? rowid}) {
    return StudySessionsCompanion(
      id: id ?? this.id,
      resourceId: resourceId ?? this.resourceId,
      startedAt: startedAt ?? this.startedAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      amount: amount ?? this.amount,
      note: note ?? this.note,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (resourceId.present) {
      map['resource_id'] = Variable<String>(resourceId.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (durationSeconds.present) {
      map['duration_seconds'] = Variable<double>(durationSeconds.value);
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StudySessionsCompanion(')
          ..write('id: $id, ')
          ..write('resourceId: $resourceId, ')
          ..write('startedAt: $startedAt, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('amount: $amount, ')
          ..write('note: $note, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ExerciseTypesTable extends ExerciseTypes
    with TableInfo<$ExerciseTypesTable, ExerciseTypeRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExerciseTypesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _iconNameMeta =
      const VerificationMeta('iconName');
  @override
  late final GeneratedColumn<String> iconName = GeneratedColumn<String>(
      'icon_name', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('directions_run'));
  static const VerificationMeta _metricsMeta =
      const VerificationMeta('metrics');
  @override
  late final GeneratedColumn<String> metrics = GeneratedColumn<String>(
      'metrics', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('count'));
  static const VerificationMeta _countUnitMeta =
      const VerificationMeta('countUnit');
  @override
  late final GeneratedColumn<String> countUnit = GeneratedColumn<String>(
      'count_unit', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('次'));
  static const VerificationMeta _distanceUnitMeta =
      const VerificationMeta('distanceUnit');
  @override
  late final GeneratedColumn<String> distanceUnit = GeneratedColumn<String>(
      'distance_unit', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('m'));
  static const VerificationMeta _colorArgbMeta =
      const VerificationMeta('colorArgb');
  @override
  late final GeneratedColumn<int> colorArgb = GeneratedColumn<int>(
      'color_argb', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0xFFFF5722));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        iconName,
        metrics,
        countUnit,
        distanceUnit,
        colorArgb,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'exercise_types';
  @override
  VerificationContext validateIntegrity(Insertable<ExerciseTypeRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('icon_name')) {
      context.handle(_iconNameMeta,
          iconName.isAcceptableOrUnknown(data['icon_name']!, _iconNameMeta));
    }
    if (data.containsKey('metrics')) {
      context.handle(_metricsMeta,
          metrics.isAcceptableOrUnknown(data['metrics']!, _metricsMeta));
    }
    if (data.containsKey('count_unit')) {
      context.handle(_countUnitMeta,
          countUnit.isAcceptableOrUnknown(data['count_unit']!, _countUnitMeta));
    }
    if (data.containsKey('distance_unit')) {
      context.handle(
          _distanceUnitMeta,
          distanceUnit.isAcceptableOrUnknown(
              data['distance_unit']!, _distanceUnitMeta));
    }
    if (data.containsKey('color_argb')) {
      context.handle(_colorArgbMeta,
          colorArgb.isAcceptableOrUnknown(data['color_argb']!, _colorArgbMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ExerciseTypeRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExerciseTypeRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      iconName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}icon_name'])!,
      metrics: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}metrics'])!,
      countUnit: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}count_unit'])!,
      distanceUnit: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}distance_unit'])!,
      colorArgb: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}color_argb'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $ExerciseTypesTable createAlias(String alias) {
    return $ExerciseTypesTable(attachedDatabase, alias);
  }
}

class ExerciseTypeRow extends DataClass implements Insertable<ExerciseTypeRow> {
  final String id;
  final String name;
  final String iconName;
  final String metrics;
  final String countUnit;
  final String distanceUnit;
  final int colorArgb;
  final DateTime createdAt;
  const ExerciseTypeRow(
      {required this.id,
      required this.name,
      required this.iconName,
      required this.metrics,
      required this.countUnit,
      required this.distanceUnit,
      required this.colorArgb,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['icon_name'] = Variable<String>(iconName);
    map['metrics'] = Variable<String>(metrics);
    map['count_unit'] = Variable<String>(countUnit);
    map['distance_unit'] = Variable<String>(distanceUnit);
    map['color_argb'] = Variable<int>(colorArgb);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ExerciseTypesCompanion toCompanion(bool nullToAbsent) {
    return ExerciseTypesCompanion(
      id: Value(id),
      name: Value(name),
      iconName: Value(iconName),
      metrics: Value(metrics),
      countUnit: Value(countUnit),
      distanceUnit: Value(distanceUnit),
      colorArgb: Value(colorArgb),
      createdAt: Value(createdAt),
    );
  }

  factory ExerciseTypeRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExerciseTypeRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      iconName: serializer.fromJson<String>(json['iconName']),
      metrics: serializer.fromJson<String>(json['metrics']),
      countUnit: serializer.fromJson<String>(json['countUnit']),
      distanceUnit: serializer.fromJson<String>(json['distanceUnit']),
      colorArgb: serializer.fromJson<int>(json['colorArgb']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'iconName': serializer.toJson<String>(iconName),
      'metrics': serializer.toJson<String>(metrics),
      'countUnit': serializer.toJson<String>(countUnit),
      'distanceUnit': serializer.toJson<String>(distanceUnit),
      'colorArgb': serializer.toJson<int>(colorArgb),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ExerciseTypeRow copyWith(
          {String? id,
          String? name,
          String? iconName,
          String? metrics,
          String? countUnit,
          String? distanceUnit,
          int? colorArgb,
          DateTime? createdAt}) =>
      ExerciseTypeRow(
        id: id ?? this.id,
        name: name ?? this.name,
        iconName: iconName ?? this.iconName,
        metrics: metrics ?? this.metrics,
        countUnit: countUnit ?? this.countUnit,
        distanceUnit: distanceUnit ?? this.distanceUnit,
        colorArgb: colorArgb ?? this.colorArgb,
        createdAt: createdAt ?? this.createdAt,
      );
  ExerciseTypeRow copyWithCompanion(ExerciseTypesCompanion data) {
    return ExerciseTypeRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      iconName: data.iconName.present ? data.iconName.value : this.iconName,
      metrics: data.metrics.present ? data.metrics.value : this.metrics,
      countUnit: data.countUnit.present ? data.countUnit.value : this.countUnit,
      distanceUnit: data.distanceUnit.present
          ? data.distanceUnit.value
          : this.distanceUnit,
      colorArgb: data.colorArgb.present ? data.colorArgb.value : this.colorArgb,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExerciseTypeRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('iconName: $iconName, ')
          ..write('metrics: $metrics, ')
          ..write('countUnit: $countUnit, ')
          ..write('distanceUnit: $distanceUnit, ')
          ..write('colorArgb: $colorArgb, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, iconName, metrics, countUnit,
      distanceUnit, colorArgb, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExerciseTypeRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.iconName == this.iconName &&
          other.metrics == this.metrics &&
          other.countUnit == this.countUnit &&
          other.distanceUnit == this.distanceUnit &&
          other.colorArgb == this.colorArgb &&
          other.createdAt == this.createdAt);
}

class ExerciseTypesCompanion extends UpdateCompanion<ExerciseTypeRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> iconName;
  final Value<String> metrics;
  final Value<String> countUnit;
  final Value<String> distanceUnit;
  final Value<int> colorArgb;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ExerciseTypesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.iconName = const Value.absent(),
    this.metrics = const Value.absent(),
    this.countUnit = const Value.absent(),
    this.distanceUnit = const Value.absent(),
    this.colorArgb = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ExerciseTypesCompanion.insert({
    required String id,
    required String name,
    this.iconName = const Value.absent(),
    this.metrics = const Value.absent(),
    this.countUnit = const Value.absent(),
    this.distanceUnit = const Value.absent(),
    this.colorArgb = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name);
  static Insertable<ExerciseTypeRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? iconName,
    Expression<String>? metrics,
    Expression<String>? countUnit,
    Expression<String>? distanceUnit,
    Expression<int>? colorArgb,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (iconName != null) 'icon_name': iconName,
      if (metrics != null) 'metrics': metrics,
      if (countUnit != null) 'count_unit': countUnit,
      if (distanceUnit != null) 'distance_unit': distanceUnit,
      if (colorArgb != null) 'color_argb': colorArgb,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ExerciseTypesCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String>? iconName,
      Value<String>? metrics,
      Value<String>? countUnit,
      Value<String>? distanceUnit,
      Value<int>? colorArgb,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return ExerciseTypesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      iconName: iconName ?? this.iconName,
      metrics: metrics ?? this.metrics,
      countUnit: countUnit ?? this.countUnit,
      distanceUnit: distanceUnit ?? this.distanceUnit,
      colorArgb: colorArgb ?? this.colorArgb,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (iconName.present) {
      map['icon_name'] = Variable<String>(iconName.value);
    }
    if (metrics.present) {
      map['metrics'] = Variable<String>(metrics.value);
    }
    if (countUnit.present) {
      map['count_unit'] = Variable<String>(countUnit.value);
    }
    if (distanceUnit.present) {
      map['distance_unit'] = Variable<String>(distanceUnit.value);
    }
    if (colorArgb.present) {
      map['color_argb'] = Variable<int>(colorArgb.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExerciseTypesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('iconName: $iconName, ')
          ..write('metrics: $metrics, ')
          ..write('countUnit: $countUnit, ')
          ..write('distanceUnit: $distanceUnit, ')
          ..write('colorArgb: $colorArgb, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ExerciseSessionsTable extends ExerciseSessions
    with TableInfo<$ExerciseSessionsTable, ExerciseSessionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExerciseSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _typeIdMeta = const VerificationMeta('typeId');
  @override
  late final GeneratedColumn<String> typeId = GeneratedColumn<String>(
      'type_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _occurredAtMeta =
      const VerificationMeta('occurredAt');
  @override
  late final GeneratedColumn<DateTime> occurredAt = GeneratedColumn<DateTime>(
      'occurred_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _countMeta = const VerificationMeta('count');
  @override
  late final GeneratedColumn<int> count = GeneratedColumn<int>(
      'count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _durationSecondsMeta =
      const VerificationMeta('durationSeconds');
  @override
  late final GeneratedColumn<double> durationSeconds = GeneratedColumn<double>(
      'duration_seconds', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _distanceMetersMeta =
      const VerificationMeta('distanceMeters');
  @override
  late final GeneratedColumn<double> distanceMeters = GeneratedColumn<double>(
      'distance_meters', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _setsMeta = const VerificationMeta('sets');
  @override
  late final GeneratedColumn<int> sets = GeneratedColumn<int>(
      'sets', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _weightKgMeta =
      const VerificationMeta('weightKg');
  @override
  late final GeneratedColumn<double> weightKg = GeneratedColumn<double>(
      'weight_kg', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
      'note', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        typeId,
        occurredAt,
        count,
        durationSeconds,
        distanceMeters,
        sets,
        weightKg,
        note
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'exercise_sessions';
  @override
  VerificationContext validateIntegrity(Insertable<ExerciseSessionRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('type_id')) {
      context.handle(_typeIdMeta,
          typeId.isAcceptableOrUnknown(data['type_id']!, _typeIdMeta));
    } else if (isInserting) {
      context.missing(_typeIdMeta);
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
          _occurredAtMeta,
          occurredAt.isAcceptableOrUnknown(
              data['occurred_at']!, _occurredAtMeta));
    }
    if (data.containsKey('count')) {
      context.handle(
          _countMeta, count.isAcceptableOrUnknown(data['count']!, _countMeta));
    }
    if (data.containsKey('duration_seconds')) {
      context.handle(
          _durationSecondsMeta,
          durationSeconds.isAcceptableOrUnknown(
              data['duration_seconds']!, _durationSecondsMeta));
    }
    if (data.containsKey('distance_meters')) {
      context.handle(
          _distanceMetersMeta,
          distanceMeters.isAcceptableOrUnknown(
              data['distance_meters']!, _distanceMetersMeta));
    }
    if (data.containsKey('sets')) {
      context.handle(
          _setsMeta, sets.isAcceptableOrUnknown(data['sets']!, _setsMeta));
    }
    if (data.containsKey('weight_kg')) {
      context.handle(_weightKgMeta,
          weightKg.isAcceptableOrUnknown(data['weight_kg']!, _weightKgMeta));
    }
    if (data.containsKey('note')) {
      context.handle(
          _noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ExerciseSessionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExerciseSessionRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      typeId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type_id'])!,
      occurredAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}occurred_at'])!,
      count: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}count'])!,
      durationSeconds: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}duration_seconds'])!,
      distanceMeters: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}distance_meters'])!,
      sets: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sets']),
      weightKg: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}weight_kg']),
      note: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note']),
    );
  }

  @override
  $ExerciseSessionsTable createAlias(String alias) {
    return $ExerciseSessionsTable(attachedDatabase, alias);
  }
}

class ExerciseSessionRow extends DataClass
    implements Insertable<ExerciseSessionRow> {
  final String id;
  final String typeId;
  final DateTime occurredAt;
  final int count;
  final double durationSeconds;
  final double distanceMeters;
  final int? sets;
  final double? weightKg;
  final String? note;
  const ExerciseSessionRow(
      {required this.id,
      required this.typeId,
      required this.occurredAt,
      required this.count,
      required this.durationSeconds,
      required this.distanceMeters,
      this.sets,
      this.weightKg,
      this.note});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['type_id'] = Variable<String>(typeId);
    map['occurred_at'] = Variable<DateTime>(occurredAt);
    map['count'] = Variable<int>(count);
    map['duration_seconds'] = Variable<double>(durationSeconds);
    map['distance_meters'] = Variable<double>(distanceMeters);
    if (!nullToAbsent || sets != null) {
      map['sets'] = Variable<int>(sets);
    }
    if (!nullToAbsent || weightKg != null) {
      map['weight_kg'] = Variable<double>(weightKg);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    return map;
  }

  ExerciseSessionsCompanion toCompanion(bool nullToAbsent) {
    return ExerciseSessionsCompanion(
      id: Value(id),
      typeId: Value(typeId),
      occurredAt: Value(occurredAt),
      count: Value(count),
      durationSeconds: Value(durationSeconds),
      distanceMeters: Value(distanceMeters),
      sets: sets == null && nullToAbsent ? const Value.absent() : Value(sets),
      weightKg: weightKg == null && nullToAbsent
          ? const Value.absent()
          : Value(weightKg),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
    );
  }

  factory ExerciseSessionRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExerciseSessionRow(
      id: serializer.fromJson<String>(json['id']),
      typeId: serializer.fromJson<String>(json['typeId']),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
      count: serializer.fromJson<int>(json['count']),
      durationSeconds: serializer.fromJson<double>(json['durationSeconds']),
      distanceMeters: serializer.fromJson<double>(json['distanceMeters']),
      sets: serializer.fromJson<int?>(json['sets']),
      weightKg: serializer.fromJson<double?>(json['weightKg']),
      note: serializer.fromJson<String?>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'typeId': serializer.toJson<String>(typeId),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
      'count': serializer.toJson<int>(count),
      'durationSeconds': serializer.toJson<double>(durationSeconds),
      'distanceMeters': serializer.toJson<double>(distanceMeters),
      'sets': serializer.toJson<int?>(sets),
      'weightKg': serializer.toJson<double?>(weightKg),
      'note': serializer.toJson<String?>(note),
    };
  }

  ExerciseSessionRow copyWith(
          {String? id,
          String? typeId,
          DateTime? occurredAt,
          int? count,
          double? durationSeconds,
          double? distanceMeters,
          Value<int?> sets = const Value.absent(),
          Value<double?> weightKg = const Value.absent(),
          Value<String?> note = const Value.absent()}) =>
      ExerciseSessionRow(
        id: id ?? this.id,
        typeId: typeId ?? this.typeId,
        occurredAt: occurredAt ?? this.occurredAt,
        count: count ?? this.count,
        durationSeconds: durationSeconds ?? this.durationSeconds,
        distanceMeters: distanceMeters ?? this.distanceMeters,
        sets: sets.present ? sets.value : this.sets,
        weightKg: weightKg.present ? weightKg.value : this.weightKg,
        note: note.present ? note.value : this.note,
      );
  ExerciseSessionRow copyWithCompanion(ExerciseSessionsCompanion data) {
    return ExerciseSessionRow(
      id: data.id.present ? data.id.value : this.id,
      typeId: data.typeId.present ? data.typeId.value : this.typeId,
      occurredAt:
          data.occurredAt.present ? data.occurredAt.value : this.occurredAt,
      count: data.count.present ? data.count.value : this.count,
      durationSeconds: data.durationSeconds.present
          ? data.durationSeconds.value
          : this.durationSeconds,
      distanceMeters: data.distanceMeters.present
          ? data.distanceMeters.value
          : this.distanceMeters,
      sets: data.sets.present ? data.sets.value : this.sets,
      weightKg: data.weightKg.present ? data.weightKg.value : this.weightKg,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExerciseSessionRow(')
          ..write('id: $id, ')
          ..write('typeId: $typeId, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('count: $count, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('distanceMeters: $distanceMeters, ')
          ..write('sets: $sets, ')
          ..write('weightKg: $weightKg, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, typeId, occurredAt, count,
      durationSeconds, distanceMeters, sets, weightKg, note);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExerciseSessionRow &&
          other.id == this.id &&
          other.typeId == this.typeId &&
          other.occurredAt == this.occurredAt &&
          other.count == this.count &&
          other.durationSeconds == this.durationSeconds &&
          other.distanceMeters == this.distanceMeters &&
          other.sets == this.sets &&
          other.weightKg == this.weightKg &&
          other.note == this.note);
}

class ExerciseSessionsCompanion extends UpdateCompanion<ExerciseSessionRow> {
  final Value<String> id;
  final Value<String> typeId;
  final Value<DateTime> occurredAt;
  final Value<int> count;
  final Value<double> durationSeconds;
  final Value<double> distanceMeters;
  final Value<int?> sets;
  final Value<double?> weightKg;
  final Value<String?> note;
  final Value<int> rowid;
  const ExerciseSessionsCompanion({
    this.id = const Value.absent(),
    this.typeId = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.count = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.distanceMeters = const Value.absent(),
    this.sets = const Value.absent(),
    this.weightKg = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ExerciseSessionsCompanion.insert({
    required String id,
    required String typeId,
    this.occurredAt = const Value.absent(),
    this.count = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.distanceMeters = const Value.absent(),
    this.sets = const Value.absent(),
    this.weightKg = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        typeId = Value(typeId);
  static Insertable<ExerciseSessionRow> custom({
    Expression<String>? id,
    Expression<String>? typeId,
    Expression<DateTime>? occurredAt,
    Expression<int>? count,
    Expression<double>? durationSeconds,
    Expression<double>? distanceMeters,
    Expression<int>? sets,
    Expression<double>? weightKg,
    Expression<String>? note,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (typeId != null) 'type_id': typeId,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (count != null) 'count': count,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (distanceMeters != null) 'distance_meters': distanceMeters,
      if (sets != null) 'sets': sets,
      if (weightKg != null) 'weight_kg': weightKg,
      if (note != null) 'note': note,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ExerciseSessionsCompanion copyWith(
      {Value<String>? id,
      Value<String>? typeId,
      Value<DateTime>? occurredAt,
      Value<int>? count,
      Value<double>? durationSeconds,
      Value<double>? distanceMeters,
      Value<int?>? sets,
      Value<double?>? weightKg,
      Value<String?>? note,
      Value<int>? rowid}) {
    return ExerciseSessionsCompanion(
      id: id ?? this.id,
      typeId: typeId ?? this.typeId,
      occurredAt: occurredAt ?? this.occurredAt,
      count: count ?? this.count,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      sets: sets ?? this.sets,
      weightKg: weightKg ?? this.weightKg,
      note: note ?? this.note,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (typeId.present) {
      map['type_id'] = Variable<String>(typeId.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(occurredAt.value);
    }
    if (count.present) {
      map['count'] = Variable<int>(count.value);
    }
    if (durationSeconds.present) {
      map['duration_seconds'] = Variable<double>(durationSeconds.value);
    }
    if (distanceMeters.present) {
      map['distance_meters'] = Variable<double>(distanceMeters.value);
    }
    if (sets.present) {
      map['sets'] = Variable<int>(sets.value);
    }
    if (weightKg.present) {
      map['weight_kg'] = Variable<double>(weightKg.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExerciseSessionsCompanion(')
          ..write('id: $id, ')
          ..write('typeId: $typeId, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('count: $count, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('distanceMeters: $distanceMeters, ')
          ..write('sets: $sets, ')
          ..write('weightKg: $weightKg, ')
          ..write('note: $note, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PetsTable extends Pets with TableInfo<$PetsTable, PetRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _speciesMeta =
      const VerificationMeta('species');
  @override
  late final GeneratedColumn<String> species = GeneratedColumn<String>(
      'species', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('cat'));
  static const VerificationMeta _avatarPathMeta =
      const VerificationMeta('avatarPath');
  @override
  late final GeneratedColumn<String> avatarPath = GeneratedColumn<String>(
      'avatar_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [id, name, species, avatarPath, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pets';
  @override
  VerificationContext validateIntegrity(Insertable<PetRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('species')) {
      context.handle(_speciesMeta,
          species.isAcceptableOrUnknown(data['species']!, _speciesMeta));
    }
    if (data.containsKey('avatar_path')) {
      context.handle(
          _avatarPathMeta,
          avatarPath.isAcceptableOrUnknown(
              data['avatar_path']!, _avatarPathMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PetRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PetRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      species: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}species'])!,
      avatarPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}avatar_path']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $PetsTable createAlias(String alias) {
    return $PetsTable(attachedDatabase, alias);
  }
}

class PetRow extends DataClass implements Insertable<PetRow> {
  final String id;
  final String name;
  final String species;
  final String? avatarPath;
  final DateTime createdAt;
  const PetRow(
      {required this.id,
      required this.name,
      required this.species,
      this.avatarPath,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['species'] = Variable<String>(species);
    if (!nullToAbsent || avatarPath != null) {
      map['avatar_path'] = Variable<String>(avatarPath);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  PetsCompanion toCompanion(bool nullToAbsent) {
    return PetsCompanion(
      id: Value(id),
      name: Value(name),
      species: Value(species),
      avatarPath: avatarPath == null && nullToAbsent
          ? const Value.absent()
          : Value(avatarPath),
      createdAt: Value(createdAt),
    );
  }

  factory PetRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PetRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      species: serializer.fromJson<String>(json['species']),
      avatarPath: serializer.fromJson<String?>(json['avatarPath']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'species': serializer.toJson<String>(species),
      'avatarPath': serializer.toJson<String?>(avatarPath),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  PetRow copyWith(
          {String? id,
          String? name,
          String? species,
          Value<String?> avatarPath = const Value.absent(),
          DateTime? createdAt}) =>
      PetRow(
        id: id ?? this.id,
        name: name ?? this.name,
        species: species ?? this.species,
        avatarPath: avatarPath.present ? avatarPath.value : this.avatarPath,
        createdAt: createdAt ?? this.createdAt,
      );
  PetRow copyWithCompanion(PetsCompanion data) {
    return PetRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      species: data.species.present ? data.species.value : this.species,
      avatarPath:
          data.avatarPath.present ? data.avatarPath.value : this.avatarPath,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PetRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('species: $species, ')
          ..write('avatarPath: $avatarPath, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, species, avatarPath, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PetRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.species == this.species &&
          other.avatarPath == this.avatarPath &&
          other.createdAt == this.createdAt);
}

class PetsCompanion extends UpdateCompanion<PetRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> species;
  final Value<String?> avatarPath;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const PetsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.species = const Value.absent(),
    this.avatarPath = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PetsCompanion.insert({
    required String id,
    required String name,
    this.species = const Value.absent(),
    this.avatarPath = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name);
  static Insertable<PetRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? species,
    Expression<String>? avatarPath,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (species != null) 'species': species,
      if (avatarPath != null) 'avatar_path': avatarPath,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PetsCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String>? species,
      Value<String?>? avatarPath,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return PetsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      species: species ?? this.species,
      avatarPath: avatarPath ?? this.avatarPath,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (species.present) {
      map['species'] = Variable<String>(species.value);
    }
    if (avatarPath.present) {
      map['avatar_path'] = Variable<String>(avatarPath.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PetsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('species: $species, ')
          ..write('avatarPath: $avatarPath, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PetLogsTable extends PetLogs with TableInfo<$PetLogsTable, PetLogRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PetLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _petIdMeta = const VerificationMeta('petId');
  @override
  late final GeneratedColumn<String> petId = GeneratedColumn<String>(
      'pet_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
      'kind', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('text'));
  static const VerificationMeta _contentMeta =
      const VerificationMeta('content');
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
      'content', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<double> value = GeneratedColumn<double>(
      'value', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _mediaAssetIdMeta =
      const VerificationMeta('mediaAssetId');
  @override
  late final GeneratedColumn<String> mediaAssetId = GeneratedColumn<String>(
      'media_asset_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
      'note', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _occurredAtMeta =
      const VerificationMeta('occurredAt');
  @override
  late final GeneratedColumn<DateTime> occurredAt = GeneratedColumn<DateTime>(
      'occurred_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [id, petId, kind, content, value, mediaAssetId, note, occurredAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pet_logs';
  @override
  VerificationContext validateIntegrity(Insertable<PetLogRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('pet_id')) {
      context.handle(
          _petIdMeta, petId.isAcceptableOrUnknown(data['pet_id']!, _petIdMeta));
    } else if (isInserting) {
      context.missing(_petIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
          _kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    }
    if (data.containsKey('content')) {
      context.handle(_contentMeta,
          content.isAcceptableOrUnknown(data['content']!, _contentMeta));
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    }
    if (data.containsKey('media_asset_id')) {
      context.handle(
          _mediaAssetIdMeta,
          mediaAssetId.isAcceptableOrUnknown(
              data['media_asset_id']!, _mediaAssetIdMeta));
    }
    if (data.containsKey('note')) {
      context.handle(
          _noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
          _occurredAtMeta,
          occurredAt.isAcceptableOrUnknown(
              data['occurred_at']!, _occurredAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PetLogRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PetLogRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      petId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}pet_id'])!,
      kind: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      content: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}value']),
      mediaAssetId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}media_asset_id']),
      note: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note']),
      occurredAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}occurred_at'])!,
    );
  }

  @override
  $PetLogsTable createAlias(String alias) {
    return $PetLogsTable(attachedDatabase, alias);
  }
}

class PetLogRow extends DataClass implements Insertable<PetLogRow> {
  final String id;
  final String petId;
  final String kind;
  final String content;
  final double? value;
  final String? mediaAssetId;
  final String? note;
  final DateTime occurredAt;
  const PetLogRow(
      {required this.id,
      required this.petId,
      required this.kind,
      required this.content,
      this.value,
      this.mediaAssetId,
      this.note,
      required this.occurredAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['pet_id'] = Variable<String>(petId);
    map['kind'] = Variable<String>(kind);
    map['content'] = Variable<String>(content);
    if (!nullToAbsent || value != null) {
      map['value'] = Variable<double>(value);
    }
    if (!nullToAbsent || mediaAssetId != null) {
      map['media_asset_id'] = Variable<String>(mediaAssetId);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['occurred_at'] = Variable<DateTime>(occurredAt);
    return map;
  }

  PetLogsCompanion toCompanion(bool nullToAbsent) {
    return PetLogsCompanion(
      id: Value(id),
      petId: Value(petId),
      kind: Value(kind),
      content: Value(content),
      value:
          value == null && nullToAbsent ? const Value.absent() : Value(value),
      mediaAssetId: mediaAssetId == null && nullToAbsent
          ? const Value.absent()
          : Value(mediaAssetId),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      occurredAt: Value(occurredAt),
    );
  }

  factory PetLogRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PetLogRow(
      id: serializer.fromJson<String>(json['id']),
      petId: serializer.fromJson<String>(json['petId']),
      kind: serializer.fromJson<String>(json['kind']),
      content: serializer.fromJson<String>(json['content']),
      value: serializer.fromJson<double?>(json['value']),
      mediaAssetId: serializer.fromJson<String?>(json['mediaAssetId']),
      note: serializer.fromJson<String?>(json['note']),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'petId': serializer.toJson<String>(petId),
      'kind': serializer.toJson<String>(kind),
      'content': serializer.toJson<String>(content),
      'value': serializer.toJson<double?>(value),
      'mediaAssetId': serializer.toJson<String?>(mediaAssetId),
      'note': serializer.toJson<String?>(note),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
    };
  }

  PetLogRow copyWith(
          {String? id,
          String? petId,
          String? kind,
          String? content,
          Value<double?> value = const Value.absent(),
          Value<String?> mediaAssetId = const Value.absent(),
          Value<String?> note = const Value.absent(),
          DateTime? occurredAt}) =>
      PetLogRow(
        id: id ?? this.id,
        petId: petId ?? this.petId,
        kind: kind ?? this.kind,
        content: content ?? this.content,
        value: value.present ? value.value : this.value,
        mediaAssetId:
            mediaAssetId.present ? mediaAssetId.value : this.mediaAssetId,
        note: note.present ? note.value : this.note,
        occurredAt: occurredAt ?? this.occurredAt,
      );
  PetLogRow copyWithCompanion(PetLogsCompanion data) {
    return PetLogRow(
      id: data.id.present ? data.id.value : this.id,
      petId: data.petId.present ? data.petId.value : this.petId,
      kind: data.kind.present ? data.kind.value : this.kind,
      content: data.content.present ? data.content.value : this.content,
      value: data.value.present ? data.value.value : this.value,
      mediaAssetId: data.mediaAssetId.present
          ? data.mediaAssetId.value
          : this.mediaAssetId,
      note: data.note.present ? data.note.value : this.note,
      occurredAt:
          data.occurredAt.present ? data.occurredAt.value : this.occurredAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PetLogRow(')
          ..write('id: $id, ')
          ..write('petId: $petId, ')
          ..write('kind: $kind, ')
          ..write('content: $content, ')
          ..write('value: $value, ')
          ..write('mediaAssetId: $mediaAssetId, ')
          ..write('note: $note, ')
          ..write('occurredAt: $occurredAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, petId, kind, content, value, mediaAssetId, note, occurredAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PetLogRow &&
          other.id == this.id &&
          other.petId == this.petId &&
          other.kind == this.kind &&
          other.content == this.content &&
          other.value == this.value &&
          other.mediaAssetId == this.mediaAssetId &&
          other.note == this.note &&
          other.occurredAt == this.occurredAt);
}

class PetLogsCompanion extends UpdateCompanion<PetLogRow> {
  final Value<String> id;
  final Value<String> petId;
  final Value<String> kind;
  final Value<String> content;
  final Value<double?> value;
  final Value<String?> mediaAssetId;
  final Value<String?> note;
  final Value<DateTime> occurredAt;
  final Value<int> rowid;
  const PetLogsCompanion({
    this.id = const Value.absent(),
    this.petId = const Value.absent(),
    this.kind = const Value.absent(),
    this.content = const Value.absent(),
    this.value = const Value.absent(),
    this.mediaAssetId = const Value.absent(),
    this.note = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PetLogsCompanion.insert({
    required String id,
    required String petId,
    this.kind = const Value.absent(),
    this.content = const Value.absent(),
    this.value = const Value.absent(),
    this.mediaAssetId = const Value.absent(),
    this.note = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        petId = Value(petId);
  static Insertable<PetLogRow> custom({
    Expression<String>? id,
    Expression<String>? petId,
    Expression<String>? kind,
    Expression<String>? content,
    Expression<double>? value,
    Expression<String>? mediaAssetId,
    Expression<String>? note,
    Expression<DateTime>? occurredAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (petId != null) 'pet_id': petId,
      if (kind != null) 'kind': kind,
      if (content != null) 'content': content,
      if (value != null) 'value': value,
      if (mediaAssetId != null) 'media_asset_id': mediaAssetId,
      if (note != null) 'note': note,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PetLogsCompanion copyWith(
      {Value<String>? id,
      Value<String>? petId,
      Value<String>? kind,
      Value<String>? content,
      Value<double?>? value,
      Value<String?>? mediaAssetId,
      Value<String?>? note,
      Value<DateTime>? occurredAt,
      Value<int>? rowid}) {
    return PetLogsCompanion(
      id: id ?? this.id,
      petId: petId ?? this.petId,
      kind: kind ?? this.kind,
      content: content ?? this.content,
      value: value ?? this.value,
      mediaAssetId: mediaAssetId ?? this.mediaAssetId,
      note: note ?? this.note,
      occurredAt: occurredAt ?? this.occurredAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (petId.present) {
      map['pet_id'] = Variable<String>(petId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (value.present) {
      map['value'] = Variable<double>(value.value);
    }
    if (mediaAssetId.present) {
      map['media_asset_id'] = Variable<String>(mediaAssetId.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(occurredAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PetLogsCompanion(')
          ..write('id: $id, ')
          ..write('petId: $petId, ')
          ..write('kind: $kind, ')
          ..write('content: $content, ')
          ..write('value: $value, ')
          ..write('mediaAssetId: $mediaAssetId, ')
          ..write('note: $note, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChatMessagesTable extends ChatMessages
    with TableInfo<$ChatMessagesTable, ChatMessageRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChatMessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _conversationIdMeta =
      const VerificationMeta('conversationId');
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
      'conversation_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
      'role', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('user'));
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
      'kind', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('text'));
  static const VerificationMeta _contentMeta =
      const VerificationMeta('content');
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
      'content', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _mediaAssetIdMeta =
      const VerificationMeta('mediaAssetId');
  @override
  late final GeneratedColumn<String> mediaAssetId = GeneratedColumn<String>(
      'media_asset_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _audioDurationMeta =
      const VerificationMeta('audioDuration');
  @override
  late final GeneratedColumn<int> audioDuration = GeneratedColumn<int>(
      'audio_duration', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _stickerIdMeta =
      const VerificationMeta('stickerId');
  @override
  late final GeneratedColumn<String> stickerId = GeneratedColumn<String>(
      'sticker_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _captionMeta =
      const VerificationMeta('caption');
  @override
  late final GeneratedColumn<String> caption = GeneratedColumn<String>(
      'caption', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _fileNameMeta =
      const VerificationMeta('fileName');
  @override
  late final GeneratedColumn<String> fileName = GeneratedColumn<String>(
      'file_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _fileSizeMeta =
      const VerificationMeta('fileSize');
  @override
  late final GeneratedColumn<int> fileSize = GeneratedColumn<int>(
      'file_size', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _quoteMessageIdMeta =
      const VerificationMeta('quoteMessageId');
  @override
  late final GeneratedColumn<String> quoteMessageId = GeneratedColumn<String>(
      'quote_message_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _quoteRoleMeta =
      const VerificationMeta('quoteRole');
  @override
  late final GeneratedColumn<String> quoteRole = GeneratedColumn<String>(
      'quote_role', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _quoteContentMeta =
      const VerificationMeta('quoteContent');
  @override
  late final GeneratedColumn<String> quoteContent = GeneratedColumn<String>(
      'quote_content', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _senderCharacterIdMeta =
      const VerificationMeta('senderCharacterId');
  @override
  late final GeneratedColumn<String> senderCharacterId =
      GeneratedColumn<String>('sender_character_id', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<double> amount = GeneratedColumn<double>(
      'amount', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _claimedMeta =
      const VerificationMeta('claimed');
  @override
  late final GeneratedColumn<bool> claimed = GeneratedColumn<bool>(
      'claimed', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("claimed" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _claimersMeta =
      const VerificationMeta('claimers');
  @override
  late final GeneratedColumn<String> claimers = GeneratedColumn<String>(
      'claimers', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _transferAcceptedMeta =
      const VerificationMeta('transferAccepted');
  @override
  late final GeneratedColumn<bool> transferAccepted = GeneratedColumn<bool>(
      'transfer_accepted', aliasedName, true,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("transfer_accepted" IN (0, 1))'));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        conversationId,
        id,
        role,
        kind,
        content,
        mediaAssetId,
        audioDuration,
        stickerId,
        caption,
        fileName,
        fileSize,
        quoteMessageId,
        quoteRole,
        quoteContent,
        senderCharacterId,
        amount,
        claimed,
        claimers,
        transferAccepted,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chat_messages';
  @override
  VerificationContext validateIntegrity(Insertable<ChatMessageRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('conversation_id')) {
      context.handle(
          _conversationIdMeta,
          conversationId.isAcceptableOrUnknown(
              data['conversation_id']!, _conversationIdMeta));
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
          _roleMeta, role.isAcceptableOrUnknown(data['role']!, _roleMeta));
    }
    if (data.containsKey('kind')) {
      context.handle(
          _kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    }
    if (data.containsKey('content')) {
      context.handle(_contentMeta,
          content.isAcceptableOrUnknown(data['content']!, _contentMeta));
    }
    if (data.containsKey('media_asset_id')) {
      context.handle(
          _mediaAssetIdMeta,
          mediaAssetId.isAcceptableOrUnknown(
              data['media_asset_id']!, _mediaAssetIdMeta));
    }
    if (data.containsKey('audio_duration')) {
      context.handle(
          _audioDurationMeta,
          audioDuration.isAcceptableOrUnknown(
              data['audio_duration']!, _audioDurationMeta));
    }
    if (data.containsKey('sticker_id')) {
      context.handle(_stickerIdMeta,
          stickerId.isAcceptableOrUnknown(data['sticker_id']!, _stickerIdMeta));
    }
    if (data.containsKey('caption')) {
      context.handle(_captionMeta,
          caption.isAcceptableOrUnknown(data['caption']!, _captionMeta));
    }
    if (data.containsKey('file_name')) {
      context.handle(_fileNameMeta,
          fileName.isAcceptableOrUnknown(data['file_name']!, _fileNameMeta));
    }
    if (data.containsKey('file_size')) {
      context.handle(_fileSizeMeta,
          fileSize.isAcceptableOrUnknown(data['file_size']!, _fileSizeMeta));
    }
    if (data.containsKey('quote_message_id')) {
      context.handle(
          _quoteMessageIdMeta,
          quoteMessageId.isAcceptableOrUnknown(
              data['quote_message_id']!, _quoteMessageIdMeta));
    }
    if (data.containsKey('quote_role')) {
      context.handle(_quoteRoleMeta,
          quoteRole.isAcceptableOrUnknown(data['quote_role']!, _quoteRoleMeta));
    }
    if (data.containsKey('quote_content')) {
      context.handle(
          _quoteContentMeta,
          quoteContent.isAcceptableOrUnknown(
              data['quote_content']!, _quoteContentMeta));
    }
    if (data.containsKey('sender_character_id')) {
      context.handle(
          _senderCharacterIdMeta,
          senderCharacterId.isAcceptableOrUnknown(
              data['sender_character_id']!, _senderCharacterIdMeta));
    }
    if (data.containsKey('amount')) {
      context.handle(_amountMeta,
          amount.isAcceptableOrUnknown(data['amount']!, _amountMeta));
    }
    if (data.containsKey('claimed')) {
      context.handle(_claimedMeta,
          claimed.isAcceptableOrUnknown(data['claimed']!, _claimedMeta));
    }
    if (data.containsKey('claimers')) {
      context.handle(_claimersMeta,
          claimers.isAcceptableOrUnknown(data['claimers']!, _claimersMeta));
    }
    if (data.containsKey('transfer_accepted')) {
      context.handle(
          _transferAcceptedMeta,
          transferAccepted.isAcceptableOrUnknown(
              data['transfer_accepted']!, _transferAcceptedMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {conversationId, id};
  @override
  ChatMessageRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChatMessageRow(
      conversationId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}conversation_id'])!,
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      role: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}role'])!,
      kind: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      content: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content']),
      mediaAssetId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}media_asset_id']),
      audioDuration: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}audio_duration']),
      stickerId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sticker_id']),
      caption: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}caption']),
      fileName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}file_name']),
      fileSize: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}file_size']),
      quoteMessageId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}quote_message_id']),
      quoteRole: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}quote_role']),
      quoteContent: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}quote_content']),
      senderCharacterId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}sender_character_id']),
      amount: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}amount']),
      claimed: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}claimed'])!,
      claimers: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}claimers']),
      transferAccepted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}transfer_accepted']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $ChatMessagesTable createAlias(String alias) {
    return $ChatMessagesTable(attachedDatabase, alias);
  }
}

class ChatMessageRow extends DataClass implements Insertable<ChatMessageRow> {
  final String conversationId;
  final String id;
  final String role;
  final String kind;
  final String? content;
  final String? mediaAssetId;
  final int? audioDuration;
  final String? stickerId;
  final String? caption;
  final String? fileName;
  final int? fileSize;
  final String? quoteMessageId;
  final String? quoteRole;
  final String? quoteContent;
  final String? senderCharacterId;
  final double? amount;
  final bool claimed;
  final String? claimers;
  final bool? transferAccepted;
  final DateTime createdAt;
  const ChatMessageRow(
      {required this.conversationId,
      required this.id,
      required this.role,
      required this.kind,
      this.content,
      this.mediaAssetId,
      this.audioDuration,
      this.stickerId,
      this.caption,
      this.fileName,
      this.fileSize,
      this.quoteMessageId,
      this.quoteRole,
      this.quoteContent,
      this.senderCharacterId,
      this.amount,
      required this.claimed,
      this.claimers,
      this.transferAccepted,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['conversation_id'] = Variable<String>(conversationId);
    map['id'] = Variable<String>(id);
    map['role'] = Variable<String>(role);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || content != null) {
      map['content'] = Variable<String>(content);
    }
    if (!nullToAbsent || mediaAssetId != null) {
      map['media_asset_id'] = Variable<String>(mediaAssetId);
    }
    if (!nullToAbsent || audioDuration != null) {
      map['audio_duration'] = Variable<int>(audioDuration);
    }
    if (!nullToAbsent || stickerId != null) {
      map['sticker_id'] = Variable<String>(stickerId);
    }
    if (!nullToAbsent || caption != null) {
      map['caption'] = Variable<String>(caption);
    }
    if (!nullToAbsent || fileName != null) {
      map['file_name'] = Variable<String>(fileName);
    }
    if (!nullToAbsent || fileSize != null) {
      map['file_size'] = Variable<int>(fileSize);
    }
    if (!nullToAbsent || quoteMessageId != null) {
      map['quote_message_id'] = Variable<String>(quoteMessageId);
    }
    if (!nullToAbsent || quoteRole != null) {
      map['quote_role'] = Variable<String>(quoteRole);
    }
    if (!nullToAbsent || quoteContent != null) {
      map['quote_content'] = Variable<String>(quoteContent);
    }
    if (!nullToAbsent || senderCharacterId != null) {
      map['sender_character_id'] = Variable<String>(senderCharacterId);
    }
    if (!nullToAbsent || amount != null) {
      map['amount'] = Variable<double>(amount);
    }
    map['claimed'] = Variable<bool>(claimed);
    if (!nullToAbsent || claimers != null) {
      map['claimers'] = Variable<String>(claimers);
    }
    if (!nullToAbsent || transferAccepted != null) {
      map['transfer_accepted'] = Variable<bool>(transferAccepted);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ChatMessagesCompanion toCompanion(bool nullToAbsent) {
    return ChatMessagesCompanion(
      conversationId: Value(conversationId),
      id: Value(id),
      role: Value(role),
      kind: Value(kind),
      content: content == null && nullToAbsent
          ? const Value.absent()
          : Value(content),
      mediaAssetId: mediaAssetId == null && nullToAbsent
          ? const Value.absent()
          : Value(mediaAssetId),
      audioDuration: audioDuration == null && nullToAbsent
          ? const Value.absent()
          : Value(audioDuration),
      stickerId: stickerId == null && nullToAbsent
          ? const Value.absent()
          : Value(stickerId),
      caption: caption == null && nullToAbsent
          ? const Value.absent()
          : Value(caption),
      fileName: fileName == null && nullToAbsent
          ? const Value.absent()
          : Value(fileName),
      fileSize: fileSize == null && nullToAbsent
          ? const Value.absent()
          : Value(fileSize),
      quoteMessageId: quoteMessageId == null && nullToAbsent
          ? const Value.absent()
          : Value(quoteMessageId),
      quoteRole: quoteRole == null && nullToAbsent
          ? const Value.absent()
          : Value(quoteRole),
      quoteContent: quoteContent == null && nullToAbsent
          ? const Value.absent()
          : Value(quoteContent),
      senderCharacterId: senderCharacterId == null && nullToAbsent
          ? const Value.absent()
          : Value(senderCharacterId),
      amount:
          amount == null && nullToAbsent ? const Value.absent() : Value(amount),
      claimed: Value(claimed),
      claimers: claimers == null && nullToAbsent
          ? const Value.absent()
          : Value(claimers),
      transferAccepted: transferAccepted == null && nullToAbsent
          ? const Value.absent()
          : Value(transferAccepted),
      createdAt: Value(createdAt),
    );
  }

  factory ChatMessageRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChatMessageRow(
      conversationId: serializer.fromJson<String>(json['conversationId']),
      id: serializer.fromJson<String>(json['id']),
      role: serializer.fromJson<String>(json['role']),
      kind: serializer.fromJson<String>(json['kind']),
      content: serializer.fromJson<String?>(json['content']),
      mediaAssetId: serializer.fromJson<String?>(json['mediaAssetId']),
      audioDuration: serializer.fromJson<int?>(json['audioDuration']),
      stickerId: serializer.fromJson<String?>(json['stickerId']),
      caption: serializer.fromJson<String?>(json['caption']),
      fileName: serializer.fromJson<String?>(json['fileName']),
      fileSize: serializer.fromJson<int?>(json['fileSize']),
      quoteMessageId: serializer.fromJson<String?>(json['quoteMessageId']),
      quoteRole: serializer.fromJson<String?>(json['quoteRole']),
      quoteContent: serializer.fromJson<String?>(json['quoteContent']),
      senderCharacterId:
          serializer.fromJson<String?>(json['senderCharacterId']),
      amount: serializer.fromJson<double?>(json['amount']),
      claimed: serializer.fromJson<bool>(json['claimed']),
      claimers: serializer.fromJson<String?>(json['claimers']),
      transferAccepted: serializer.fromJson<bool?>(json['transferAccepted']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'conversationId': serializer.toJson<String>(conversationId),
      'id': serializer.toJson<String>(id),
      'role': serializer.toJson<String>(role),
      'kind': serializer.toJson<String>(kind),
      'content': serializer.toJson<String?>(content),
      'mediaAssetId': serializer.toJson<String?>(mediaAssetId),
      'audioDuration': serializer.toJson<int?>(audioDuration),
      'stickerId': serializer.toJson<String?>(stickerId),
      'caption': serializer.toJson<String?>(caption),
      'fileName': serializer.toJson<String?>(fileName),
      'fileSize': serializer.toJson<int?>(fileSize),
      'quoteMessageId': serializer.toJson<String?>(quoteMessageId),
      'quoteRole': serializer.toJson<String?>(quoteRole),
      'quoteContent': serializer.toJson<String?>(quoteContent),
      'senderCharacterId': serializer.toJson<String?>(senderCharacterId),
      'amount': serializer.toJson<double?>(amount),
      'claimed': serializer.toJson<bool>(claimed),
      'claimers': serializer.toJson<String?>(claimers),
      'transferAccepted': serializer.toJson<bool?>(transferAccepted),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ChatMessageRow copyWith(
          {String? conversationId,
          String? id,
          String? role,
          String? kind,
          Value<String?> content = const Value.absent(),
          Value<String?> mediaAssetId = const Value.absent(),
          Value<int?> audioDuration = const Value.absent(),
          Value<String?> stickerId = const Value.absent(),
          Value<String?> caption = const Value.absent(),
          Value<String?> fileName = const Value.absent(),
          Value<int?> fileSize = const Value.absent(),
          Value<String?> quoteMessageId = const Value.absent(),
          Value<String?> quoteRole = const Value.absent(),
          Value<String?> quoteContent = const Value.absent(),
          Value<String?> senderCharacterId = const Value.absent(),
          Value<double?> amount = const Value.absent(),
          bool? claimed,
          Value<String?> claimers = const Value.absent(),
          Value<bool?> transferAccepted = const Value.absent(),
          DateTime? createdAt}) =>
      ChatMessageRow(
        conversationId: conversationId ?? this.conversationId,
        id: id ?? this.id,
        role: role ?? this.role,
        kind: kind ?? this.kind,
        content: content.present ? content.value : this.content,
        mediaAssetId:
            mediaAssetId.present ? mediaAssetId.value : this.mediaAssetId,
        audioDuration:
            audioDuration.present ? audioDuration.value : this.audioDuration,
        stickerId: stickerId.present ? stickerId.value : this.stickerId,
        caption: caption.present ? caption.value : this.caption,
        fileName: fileName.present ? fileName.value : this.fileName,
        fileSize: fileSize.present ? fileSize.value : this.fileSize,
        quoteMessageId:
            quoteMessageId.present ? quoteMessageId.value : this.quoteMessageId,
        quoteRole: quoteRole.present ? quoteRole.value : this.quoteRole,
        quoteContent:
            quoteContent.present ? quoteContent.value : this.quoteContent,
        senderCharacterId: senderCharacterId.present
            ? senderCharacterId.value
            : this.senderCharacterId,
        amount: amount.present ? amount.value : this.amount,
        claimed: claimed ?? this.claimed,
        claimers: claimers.present ? claimers.value : this.claimers,
        transferAccepted: transferAccepted.present
            ? transferAccepted.value
            : this.transferAccepted,
        createdAt: createdAt ?? this.createdAt,
      );
  ChatMessageRow copyWithCompanion(ChatMessagesCompanion data) {
    return ChatMessageRow(
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      id: data.id.present ? data.id.value : this.id,
      role: data.role.present ? data.role.value : this.role,
      kind: data.kind.present ? data.kind.value : this.kind,
      content: data.content.present ? data.content.value : this.content,
      mediaAssetId: data.mediaAssetId.present
          ? data.mediaAssetId.value
          : this.mediaAssetId,
      audioDuration: data.audioDuration.present
          ? data.audioDuration.value
          : this.audioDuration,
      stickerId: data.stickerId.present ? data.stickerId.value : this.stickerId,
      caption: data.caption.present ? data.caption.value : this.caption,
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
      fileSize: data.fileSize.present ? data.fileSize.value : this.fileSize,
      quoteMessageId: data.quoteMessageId.present
          ? data.quoteMessageId.value
          : this.quoteMessageId,
      quoteRole: data.quoteRole.present ? data.quoteRole.value : this.quoteRole,
      quoteContent: data.quoteContent.present
          ? data.quoteContent.value
          : this.quoteContent,
      senderCharacterId: data.senderCharacterId.present
          ? data.senderCharacterId.value
          : this.senderCharacterId,
      amount: data.amount.present ? data.amount.value : this.amount,
      claimed: data.claimed.present ? data.claimed.value : this.claimed,
      claimers: data.claimers.present ? data.claimers.value : this.claimers,
      transferAccepted: data.transferAccepted.present
          ? data.transferAccepted.value
          : this.transferAccepted,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChatMessageRow(')
          ..write('conversationId: $conversationId, ')
          ..write('id: $id, ')
          ..write('role: $role, ')
          ..write('kind: $kind, ')
          ..write('content: $content, ')
          ..write('mediaAssetId: $mediaAssetId, ')
          ..write('audioDuration: $audioDuration, ')
          ..write('stickerId: $stickerId, ')
          ..write('caption: $caption, ')
          ..write('fileName: $fileName, ')
          ..write('fileSize: $fileSize, ')
          ..write('quoteMessageId: $quoteMessageId, ')
          ..write('quoteRole: $quoteRole, ')
          ..write('quoteContent: $quoteContent, ')
          ..write('senderCharacterId: $senderCharacterId, ')
          ..write('amount: $amount, ')
          ..write('claimed: $claimed, ')
          ..write('claimers: $claimers, ')
          ..write('transferAccepted: $transferAccepted, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      conversationId,
      id,
      role,
      kind,
      content,
      mediaAssetId,
      audioDuration,
      stickerId,
      caption,
      fileName,
      fileSize,
      quoteMessageId,
      quoteRole,
      quoteContent,
      senderCharacterId,
      amount,
      claimed,
      claimers,
      transferAccepted,
      createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChatMessageRow &&
          other.conversationId == this.conversationId &&
          other.id == this.id &&
          other.role == this.role &&
          other.kind == this.kind &&
          other.content == this.content &&
          other.mediaAssetId == this.mediaAssetId &&
          other.audioDuration == this.audioDuration &&
          other.stickerId == this.stickerId &&
          other.caption == this.caption &&
          other.fileName == this.fileName &&
          other.fileSize == this.fileSize &&
          other.quoteMessageId == this.quoteMessageId &&
          other.quoteRole == this.quoteRole &&
          other.quoteContent == this.quoteContent &&
          other.senderCharacterId == this.senderCharacterId &&
          other.amount == this.amount &&
          other.claimed == this.claimed &&
          other.claimers == this.claimers &&
          other.transferAccepted == this.transferAccepted &&
          other.createdAt == this.createdAt);
}

class ChatMessagesCompanion extends UpdateCompanion<ChatMessageRow> {
  final Value<String> conversationId;
  final Value<String> id;
  final Value<String> role;
  final Value<String> kind;
  final Value<String?> content;
  final Value<String?> mediaAssetId;
  final Value<int?> audioDuration;
  final Value<String?> stickerId;
  final Value<String?> caption;
  final Value<String?> fileName;
  final Value<int?> fileSize;
  final Value<String?> quoteMessageId;
  final Value<String?> quoteRole;
  final Value<String?> quoteContent;
  final Value<String?> senderCharacterId;
  final Value<double?> amount;
  final Value<bool> claimed;
  final Value<String?> claimers;
  final Value<bool?> transferAccepted;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ChatMessagesCompanion({
    this.conversationId = const Value.absent(),
    this.id = const Value.absent(),
    this.role = const Value.absent(),
    this.kind = const Value.absent(),
    this.content = const Value.absent(),
    this.mediaAssetId = const Value.absent(),
    this.audioDuration = const Value.absent(),
    this.stickerId = const Value.absent(),
    this.caption = const Value.absent(),
    this.fileName = const Value.absent(),
    this.fileSize = const Value.absent(),
    this.quoteMessageId = const Value.absent(),
    this.quoteRole = const Value.absent(),
    this.quoteContent = const Value.absent(),
    this.senderCharacterId = const Value.absent(),
    this.amount = const Value.absent(),
    this.claimed = const Value.absent(),
    this.claimers = const Value.absent(),
    this.transferAccepted = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChatMessagesCompanion.insert({
    required String conversationId,
    required String id,
    this.role = const Value.absent(),
    this.kind = const Value.absent(),
    this.content = const Value.absent(),
    this.mediaAssetId = const Value.absent(),
    this.audioDuration = const Value.absent(),
    this.stickerId = const Value.absent(),
    this.caption = const Value.absent(),
    this.fileName = const Value.absent(),
    this.fileSize = const Value.absent(),
    this.quoteMessageId = const Value.absent(),
    this.quoteRole = const Value.absent(),
    this.quoteContent = const Value.absent(),
    this.senderCharacterId = const Value.absent(),
    this.amount = const Value.absent(),
    this.claimed = const Value.absent(),
    this.claimers = const Value.absent(),
    this.transferAccepted = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : conversationId = Value(conversationId),
        id = Value(id);
  static Insertable<ChatMessageRow> custom({
    Expression<String>? conversationId,
    Expression<String>? id,
    Expression<String>? role,
    Expression<String>? kind,
    Expression<String>? content,
    Expression<String>? mediaAssetId,
    Expression<int>? audioDuration,
    Expression<String>? stickerId,
    Expression<String>? caption,
    Expression<String>? fileName,
    Expression<int>? fileSize,
    Expression<String>? quoteMessageId,
    Expression<String>? quoteRole,
    Expression<String>? quoteContent,
    Expression<String>? senderCharacterId,
    Expression<double>? amount,
    Expression<bool>? claimed,
    Expression<String>? claimers,
    Expression<bool>? transferAccepted,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (conversationId != null) 'conversation_id': conversationId,
      if (id != null) 'id': id,
      if (role != null) 'role': role,
      if (kind != null) 'kind': kind,
      if (content != null) 'content': content,
      if (mediaAssetId != null) 'media_asset_id': mediaAssetId,
      if (audioDuration != null) 'audio_duration': audioDuration,
      if (stickerId != null) 'sticker_id': stickerId,
      if (caption != null) 'caption': caption,
      if (fileName != null) 'file_name': fileName,
      if (fileSize != null) 'file_size': fileSize,
      if (quoteMessageId != null) 'quote_message_id': quoteMessageId,
      if (quoteRole != null) 'quote_role': quoteRole,
      if (quoteContent != null) 'quote_content': quoteContent,
      if (senderCharacterId != null) 'sender_character_id': senderCharacterId,
      if (amount != null) 'amount': amount,
      if (claimed != null) 'claimed': claimed,
      if (claimers != null) 'claimers': claimers,
      if (transferAccepted != null) 'transfer_accepted': transferAccepted,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChatMessagesCompanion copyWith(
      {Value<String>? conversationId,
      Value<String>? id,
      Value<String>? role,
      Value<String>? kind,
      Value<String?>? content,
      Value<String?>? mediaAssetId,
      Value<int?>? audioDuration,
      Value<String?>? stickerId,
      Value<String?>? caption,
      Value<String?>? fileName,
      Value<int?>? fileSize,
      Value<String?>? quoteMessageId,
      Value<String?>? quoteRole,
      Value<String?>? quoteContent,
      Value<String?>? senderCharacterId,
      Value<double?>? amount,
      Value<bool>? claimed,
      Value<String?>? claimers,
      Value<bool?>? transferAccepted,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return ChatMessagesCompanion(
      conversationId: conversationId ?? this.conversationId,
      id: id ?? this.id,
      role: role ?? this.role,
      kind: kind ?? this.kind,
      content: content ?? this.content,
      mediaAssetId: mediaAssetId ?? this.mediaAssetId,
      audioDuration: audioDuration ?? this.audioDuration,
      stickerId: stickerId ?? this.stickerId,
      caption: caption ?? this.caption,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      quoteMessageId: quoteMessageId ?? this.quoteMessageId,
      quoteRole: quoteRole ?? this.quoteRole,
      quoteContent: quoteContent ?? this.quoteContent,
      senderCharacterId: senderCharacterId ?? this.senderCharacterId,
      amount: amount ?? this.amount,
      claimed: claimed ?? this.claimed,
      claimers: claimers ?? this.claimers,
      transferAccepted: transferAccepted ?? this.transferAccepted,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (mediaAssetId.present) {
      map['media_asset_id'] = Variable<String>(mediaAssetId.value);
    }
    if (audioDuration.present) {
      map['audio_duration'] = Variable<int>(audioDuration.value);
    }
    if (stickerId.present) {
      map['sticker_id'] = Variable<String>(stickerId.value);
    }
    if (caption.present) {
      map['caption'] = Variable<String>(caption.value);
    }
    if (fileName.present) {
      map['file_name'] = Variable<String>(fileName.value);
    }
    if (fileSize.present) {
      map['file_size'] = Variable<int>(fileSize.value);
    }
    if (quoteMessageId.present) {
      map['quote_message_id'] = Variable<String>(quoteMessageId.value);
    }
    if (quoteRole.present) {
      map['quote_role'] = Variable<String>(quoteRole.value);
    }
    if (quoteContent.present) {
      map['quote_content'] = Variable<String>(quoteContent.value);
    }
    if (senderCharacterId.present) {
      map['sender_character_id'] = Variable<String>(senderCharacterId.value);
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (claimed.present) {
      map['claimed'] = Variable<bool>(claimed.value);
    }
    if (claimers.present) {
      map['claimers'] = Variable<String>(claimers.value);
    }
    if (transferAccepted.present) {
      map['transfer_accepted'] = Variable<bool>(transferAccepted.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChatMessagesCompanion(')
          ..write('conversationId: $conversationId, ')
          ..write('id: $id, ')
          ..write('role: $role, ')
          ..write('kind: $kind, ')
          ..write('content: $content, ')
          ..write('mediaAssetId: $mediaAssetId, ')
          ..write('audioDuration: $audioDuration, ')
          ..write('stickerId: $stickerId, ')
          ..write('caption: $caption, ')
          ..write('fileName: $fileName, ')
          ..write('fileSize: $fileSize, ')
          ..write('quoteMessageId: $quoteMessageId, ')
          ..write('quoteRole: $quoteRole, ')
          ..write('quoteContent: $quoteContent, ')
          ..write('senderCharacterId: $senderCharacterId, ')
          ..write('amount: $amount, ')
          ..write('claimed: $claimed, ')
          ..write('claimers: $claimers, ')
          ..write('transferAccepted: $transferAccepted, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MediaCacheTable extends MediaCache
    with TableInfo<$MediaCacheTable, MediaCacheRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MediaCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _mediaIdMeta =
      const VerificationMeta('mediaId');
  @override
  late final GeneratedColumn<String> mediaId = GeneratedColumn<String>(
      'media_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _bytesMeta = const VerificationMeta('bytes');
  @override
  late final GeneratedColumn<Uint8List> bytes = GeneratedColumn<Uint8List>(
      'bytes', aliasedName, false,
      type: DriftSqlType.blob, requiredDuringInsert: true);
  static const VerificationMeta _aspectMeta = const VerificationMeta('aspect');
  @override
  late final GeneratedColumn<double> aspect = GeneratedColumn<double>(
      'aspect', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [mediaId, bytes, aspect, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'media_cache';
  @override
  VerificationContext validateIntegrity(Insertable<MediaCacheRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('media_id')) {
      context.handle(_mediaIdMeta,
          mediaId.isAcceptableOrUnknown(data['media_id']!, _mediaIdMeta));
    } else if (isInserting) {
      context.missing(_mediaIdMeta);
    }
    if (data.containsKey('bytes')) {
      context.handle(
          _bytesMeta, bytes.isAcceptableOrUnknown(data['bytes']!, _bytesMeta));
    } else if (isInserting) {
      context.missing(_bytesMeta);
    }
    if (data.containsKey('aspect')) {
      context.handle(_aspectMeta,
          aspect.isAcceptableOrUnknown(data['aspect']!, _aspectMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {mediaId};
  @override
  MediaCacheRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MediaCacheRow(
      mediaId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}media_id'])!,
      bytes: attachedDatabase.typeMapping
          .read(DriftSqlType.blob, data['${effectivePrefix}bytes'])!,
      aspect: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}aspect']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $MediaCacheTable createAlias(String alias) {
    return $MediaCacheTable(attachedDatabase, alias);
  }
}

class MediaCacheRow extends DataClass implements Insertable<MediaCacheRow> {
  final String mediaId;
  final Uint8List bytes;
  final double? aspect;
  final int updatedAt;
  const MediaCacheRow(
      {required this.mediaId,
      required this.bytes,
      this.aspect,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['media_id'] = Variable<String>(mediaId);
    map['bytes'] = Variable<Uint8List>(bytes);
    if (!nullToAbsent || aspect != null) {
      map['aspect'] = Variable<double>(aspect);
    }
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  MediaCacheCompanion toCompanion(bool nullToAbsent) {
    return MediaCacheCompanion(
      mediaId: Value(mediaId),
      bytes: Value(bytes),
      aspect:
          aspect == null && nullToAbsent ? const Value.absent() : Value(aspect),
      updatedAt: Value(updatedAt),
    );
  }

  factory MediaCacheRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MediaCacheRow(
      mediaId: serializer.fromJson<String>(json['mediaId']),
      bytes: serializer.fromJson<Uint8List>(json['bytes']),
      aspect: serializer.fromJson<double?>(json['aspect']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'mediaId': serializer.toJson<String>(mediaId),
      'bytes': serializer.toJson<Uint8List>(bytes),
      'aspect': serializer.toJson<double?>(aspect),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  MediaCacheRow copyWith(
          {String? mediaId,
          Uint8List? bytes,
          Value<double?> aspect = const Value.absent(),
          int? updatedAt}) =>
      MediaCacheRow(
        mediaId: mediaId ?? this.mediaId,
        bytes: bytes ?? this.bytes,
        aspect: aspect.present ? aspect.value : this.aspect,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  MediaCacheRow copyWithCompanion(MediaCacheCompanion data) {
    return MediaCacheRow(
      mediaId: data.mediaId.present ? data.mediaId.value : this.mediaId,
      bytes: data.bytes.present ? data.bytes.value : this.bytes,
      aspect: data.aspect.present ? data.aspect.value : this.aspect,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MediaCacheRow(')
          ..write('mediaId: $mediaId, ')
          ..write('bytes: $bytes, ')
          ..write('aspect: $aspect, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(mediaId, $driftBlobEquality.hash(bytes), aspect, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MediaCacheRow &&
          other.mediaId == this.mediaId &&
          $driftBlobEquality.equals(other.bytes, this.bytes) &&
          other.aspect == this.aspect &&
          other.updatedAt == this.updatedAt);
}

class MediaCacheCompanion extends UpdateCompanion<MediaCacheRow> {
  final Value<String> mediaId;
  final Value<Uint8List> bytes;
  final Value<double?> aspect;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const MediaCacheCompanion({
    this.mediaId = const Value.absent(),
    this.bytes = const Value.absent(),
    this.aspect = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MediaCacheCompanion.insert({
    required String mediaId,
    required Uint8List bytes,
    this.aspect = const Value.absent(),
    required int updatedAt,
    this.rowid = const Value.absent(),
  })  : mediaId = Value(mediaId),
        bytes = Value(bytes),
        updatedAt = Value(updatedAt);
  static Insertable<MediaCacheRow> custom({
    Expression<String>? mediaId,
    Expression<Uint8List>? bytes,
    Expression<double>? aspect,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (mediaId != null) 'media_id': mediaId,
      if (bytes != null) 'bytes': bytes,
      if (aspect != null) 'aspect': aspect,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MediaCacheCompanion copyWith(
      {Value<String>? mediaId,
      Value<Uint8List>? bytes,
      Value<double?>? aspect,
      Value<int>? updatedAt,
      Value<int>? rowid}) {
    return MediaCacheCompanion(
      mediaId: mediaId ?? this.mediaId,
      bytes: bytes ?? this.bytes,
      aspect: aspect ?? this.aspect,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (mediaId.present) {
      map['media_id'] = Variable<String>(mediaId.value);
    }
    if (bytes.present) {
      map['bytes'] = Variable<Uint8List>(bytes.value);
    }
    if (aspect.present) {
      map['aspect'] = Variable<double>(aspect.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MediaCacheCompanion(')
          ..write('mediaId: $mediaId, ')
          ..write('bytes: $bytes, ')
          ..write('aspect: $aspect, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $KvCacheTable extends KvCache with TableInfo<$KvCacheTable, KvCacheRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $KvCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
      'value', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [key, value, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'kv_cache';
  @override
  VerificationContext validateIntegrity(Insertable<KvCacheRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  KvCacheRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return KvCacheRow(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}value'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $KvCacheTable createAlias(String alias) {
    return $KvCacheTable(attachedDatabase, alias);
  }
}

class KvCacheRow extends DataClass implements Insertable<KvCacheRow> {
  final String key;
  final String value;
  final int updatedAt;
  const KvCacheRow(
      {required this.key, required this.value, required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  KvCacheCompanion toCompanion(bool nullToAbsent) {
    return KvCacheCompanion(
      key: Value(key),
      value: Value(value),
      updatedAt: Value(updatedAt),
    );
  }

  factory KvCacheRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return KvCacheRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  KvCacheRow copyWith({String? key, String? value, int? updatedAt}) =>
      KvCacheRow(
        key: key ?? this.key,
        value: value ?? this.value,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  KvCacheRow copyWithCompanion(KvCacheCompanion data) {
    return KvCacheRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('KvCacheRow(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is KvCacheRow &&
          other.key == this.key &&
          other.value == this.value &&
          other.updatedAt == this.updatedAt);
}

class KvCacheCompanion extends UpdateCompanion<KvCacheRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const KvCacheCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  KvCacheCompanion.insert({
    required String key,
    required String value,
    required int updatedAt,
    this.rowid = const Value.absent(),
  })  : key = Value(key),
        value = Value(value),
        updatedAt = Value(updatedAt);
  static Insertable<KvCacheRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  KvCacheCompanion copyWith(
      {Value<String>? key,
      Value<String>? value,
      Value<int>? updatedAt,
      Value<int>? rowid}) {
    return KvCacheCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('KvCacheCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $LifeHabitsTable lifeHabits = $LifeHabitsTable(this);
  late final $LifeHabitEventsTable lifeHabitEvents =
      $LifeHabitEventsTable(this);
  late final $ActiveSessionsTable activeSessions = $ActiveSessionsTable(this);
  late final $InboxItemsTable inboxItems = $InboxItemsTable(this);
  late final $SyncEventsLocalTable syncEventsLocal =
      $SyncEventsLocalTable(this);
  late final $MomentsTable moments = $MomentsTable(this);
  late final $StudyResourcesTable studyResources = $StudyResourcesTable(this);
  late final $StudySessionsTable studySessions = $StudySessionsTable(this);
  late final $ExerciseTypesTable exerciseTypes = $ExerciseTypesTable(this);
  late final $ExerciseSessionsTable exerciseSessions =
      $ExerciseSessionsTable(this);
  late final $PetsTable pets = $PetsTable(this);
  late final $PetLogsTable petLogs = $PetLogsTable(this);
  late final $ChatMessagesTable chatMessages = $ChatMessagesTable(this);
  late final $MediaCacheTable mediaCache = $MediaCacheTable(this);
  late final $KvCacheTable kvCache = $KvCacheTable(this);
  late final Index chatMessagesConvIdx = Index('chat_messages_conv_idx',
      'CREATE INDEX chat_messages_conv_idx ON chat_messages (conversation_id)');
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        lifeHabits,
        lifeHabitEvents,
        activeSessions,
        inboxItems,
        syncEventsLocal,
        moments,
        studyResources,
        studySessions,
        exerciseTypes,
        exerciseSessions,
        pets,
        petLogs,
        chatMessages,
        mediaCache,
        kvCache,
        chatMessagesConvIdx
      ];
}

typedef $$LifeHabitsTableCreateCompanionBuilder = LifeHabitsCompanion Function({
  required String id,
  required String name,
  required String iconName,
  Value<int> colorArgb,
  Value<int> dailyTarget,
  Value<String> unit,
  Value<String> type,
  Value<String> behavior,
  Value<DateTime> createdAt,
  Value<int> rowid,
});
typedef $$LifeHabitsTableUpdateCompanionBuilder = LifeHabitsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> iconName,
  Value<int> colorArgb,
  Value<int> dailyTarget,
  Value<String> unit,
  Value<String> type,
  Value<String> behavior,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$LifeHabitsTableFilterComposer
    extends Composer<_$AppDatabase, $LifeHabitsTable> {
  $$LifeHabitsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get iconName => $composableBuilder(
      column: $table.iconName, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get colorArgb => $composableBuilder(
      column: $table.colorArgb, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get dailyTarget => $composableBuilder(
      column: $table.dailyTarget, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get unit => $composableBuilder(
      column: $table.unit, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get behavior => $composableBuilder(
      column: $table.behavior, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$LifeHabitsTableOrderingComposer
    extends Composer<_$AppDatabase, $LifeHabitsTable> {
  $$LifeHabitsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get iconName => $composableBuilder(
      column: $table.iconName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get colorArgb => $composableBuilder(
      column: $table.colorArgb, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get dailyTarget => $composableBuilder(
      column: $table.dailyTarget, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get unit => $composableBuilder(
      column: $table.unit, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get behavior => $composableBuilder(
      column: $table.behavior, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$LifeHabitsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LifeHabitsTable> {
  $$LifeHabitsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get iconName =>
      $composableBuilder(column: $table.iconName, builder: (column) => column);

  GeneratedColumn<int> get colorArgb =>
      $composableBuilder(column: $table.colorArgb, builder: (column) => column);

  GeneratedColumn<int> get dailyTarget => $composableBuilder(
      column: $table.dailyTarget, builder: (column) => column);

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get behavior =>
      $composableBuilder(column: $table.behavior, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$LifeHabitsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $LifeHabitsTable,
    LifeHabitRow,
    $$LifeHabitsTableFilterComposer,
    $$LifeHabitsTableOrderingComposer,
    $$LifeHabitsTableAnnotationComposer,
    $$LifeHabitsTableCreateCompanionBuilder,
    $$LifeHabitsTableUpdateCompanionBuilder,
    (
      LifeHabitRow,
      BaseReferences<_$AppDatabase, $LifeHabitsTable, LifeHabitRow>
    ),
    LifeHabitRow,
    PrefetchHooks Function()> {
  $$LifeHabitsTableTableManager(_$AppDatabase db, $LifeHabitsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LifeHabitsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LifeHabitsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LifeHabitsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> iconName = const Value.absent(),
            Value<int> colorArgb = const Value.absent(),
            Value<int> dailyTarget = const Value.absent(),
            Value<String> unit = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<String> behavior = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LifeHabitsCompanion(
            id: id,
            name: name,
            iconName: iconName,
            colorArgb: colorArgb,
            dailyTarget: dailyTarget,
            unit: unit,
            type: type,
            behavior: behavior,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            required String iconName,
            Value<int> colorArgb = const Value.absent(),
            Value<int> dailyTarget = const Value.absent(),
            Value<String> unit = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<String> behavior = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LifeHabitsCompanion.insert(
            id: id,
            name: name,
            iconName: iconName,
            colorArgb: colorArgb,
            dailyTarget: dailyTarget,
            unit: unit,
            type: type,
            behavior: behavior,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LifeHabitsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $LifeHabitsTable,
    LifeHabitRow,
    $$LifeHabitsTableFilterComposer,
    $$LifeHabitsTableOrderingComposer,
    $$LifeHabitsTableAnnotationComposer,
    $$LifeHabitsTableCreateCompanionBuilder,
    $$LifeHabitsTableUpdateCompanionBuilder,
    (
      LifeHabitRow,
      BaseReferences<_$AppDatabase, $LifeHabitsTable, LifeHabitRow>
    ),
    LifeHabitRow,
    PrefetchHooks Function()>;
typedef $$LifeHabitEventsTableCreateCompanionBuilder = LifeHabitEventsCompanion
    Function({
  required String id,
  required String habitId,
  Value<DateTime> occurredAt,
  Value<double> value,
  Value<String?> note,
  Value<int> rowid,
});
typedef $$LifeHabitEventsTableUpdateCompanionBuilder = LifeHabitEventsCompanion
    Function({
  Value<String> id,
  Value<String> habitId,
  Value<DateTime> occurredAt,
  Value<double> value,
  Value<String?> note,
  Value<int> rowid,
});

class $$LifeHabitEventsTableFilterComposer
    extends Composer<_$AppDatabase, $LifeHabitEventsTable> {
  $$LifeHabitEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get habitId => $composableBuilder(
      column: $table.habitId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get occurredAt => $composableBuilder(
      column: $table.occurredAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnFilters(column));
}

class $$LifeHabitEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $LifeHabitEventsTable> {
  $$LifeHabitEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get habitId => $composableBuilder(
      column: $table.habitId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get occurredAt => $composableBuilder(
      column: $table.occurredAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnOrderings(column));
}

class $$LifeHabitEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LifeHabitEventsTable> {
  $$LifeHabitEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get habitId =>
      $composableBuilder(column: $table.habitId, builder: (column) => column);

  GeneratedColumn<DateTime> get occurredAt => $composableBuilder(
      column: $table.occurredAt, builder: (column) => column);

  GeneratedColumn<double> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);
}

class $$LifeHabitEventsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $LifeHabitEventsTable,
    LifeHabitEventRow,
    $$LifeHabitEventsTableFilterComposer,
    $$LifeHabitEventsTableOrderingComposer,
    $$LifeHabitEventsTableAnnotationComposer,
    $$LifeHabitEventsTableCreateCompanionBuilder,
    $$LifeHabitEventsTableUpdateCompanionBuilder,
    (
      LifeHabitEventRow,
      BaseReferences<_$AppDatabase, $LifeHabitEventsTable, LifeHabitEventRow>
    ),
    LifeHabitEventRow,
    PrefetchHooks Function()> {
  $$LifeHabitEventsTableTableManager(
      _$AppDatabase db, $LifeHabitEventsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LifeHabitEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LifeHabitEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LifeHabitEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> habitId = const Value.absent(),
            Value<DateTime> occurredAt = const Value.absent(),
            Value<double> value = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LifeHabitEventsCompanion(
            id: id,
            habitId: habitId,
            occurredAt: occurredAt,
            value: value,
            note: note,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String habitId,
            Value<DateTime> occurredAt = const Value.absent(),
            Value<double> value = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LifeHabitEventsCompanion.insert(
            id: id,
            habitId: habitId,
            occurredAt: occurredAt,
            value: value,
            note: note,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LifeHabitEventsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $LifeHabitEventsTable,
    LifeHabitEventRow,
    $$LifeHabitEventsTableFilterComposer,
    $$LifeHabitEventsTableOrderingComposer,
    $$LifeHabitEventsTableAnnotationComposer,
    $$LifeHabitEventsTableCreateCompanionBuilder,
    $$LifeHabitEventsTableUpdateCompanionBuilder,
    (
      LifeHabitEventRow,
      BaseReferences<_$AppDatabase, $LifeHabitEventsTable, LifeHabitEventRow>
    ),
    LifeHabitEventRow,
    PrefetchHooks Function()>;
typedef $$ActiveSessionsTableCreateCompanionBuilder = ActiveSessionsCompanion
    Function({
  required String habitId,
  Value<DateTime> startedAt,
  Value<int> rowid,
});
typedef $$ActiveSessionsTableUpdateCompanionBuilder = ActiveSessionsCompanion
    Function({
  Value<String> habitId,
  Value<DateTime> startedAt,
  Value<int> rowid,
});

class $$ActiveSessionsTableFilterComposer
    extends Composer<_$AppDatabase, $ActiveSessionsTable> {
  $$ActiveSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get habitId => $composableBuilder(
      column: $table.habitId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
      column: $table.startedAt, builder: (column) => ColumnFilters(column));
}

class $$ActiveSessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $ActiveSessionsTable> {
  $$ActiveSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get habitId => $composableBuilder(
      column: $table.habitId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
      column: $table.startedAt, builder: (column) => ColumnOrderings(column));
}

class $$ActiveSessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ActiveSessionsTable> {
  $$ActiveSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get habitId =>
      $composableBuilder(column: $table.habitId, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);
}

class $$ActiveSessionsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ActiveSessionsTable,
    ActiveSessionRow,
    $$ActiveSessionsTableFilterComposer,
    $$ActiveSessionsTableOrderingComposer,
    $$ActiveSessionsTableAnnotationComposer,
    $$ActiveSessionsTableCreateCompanionBuilder,
    $$ActiveSessionsTableUpdateCompanionBuilder,
    (
      ActiveSessionRow,
      BaseReferences<_$AppDatabase, $ActiveSessionsTable, ActiveSessionRow>
    ),
    ActiveSessionRow,
    PrefetchHooks Function()> {
  $$ActiveSessionsTableTableManager(
      _$AppDatabase db, $ActiveSessionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ActiveSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ActiveSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ActiveSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> habitId = const Value.absent(),
            Value<DateTime> startedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ActiveSessionsCompanion(
            habitId: habitId,
            startedAt: startedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String habitId,
            Value<DateTime> startedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ActiveSessionsCompanion.insert(
            habitId: habitId,
            startedAt: startedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ActiveSessionsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ActiveSessionsTable,
    ActiveSessionRow,
    $$ActiveSessionsTableFilterComposer,
    $$ActiveSessionsTableOrderingComposer,
    $$ActiveSessionsTableAnnotationComposer,
    $$ActiveSessionsTableCreateCompanionBuilder,
    $$ActiveSessionsTableUpdateCompanionBuilder,
    (
      ActiveSessionRow,
      BaseReferences<_$AppDatabase, $ActiveSessionsTable, ActiveSessionRow>
    ),
    ActiveSessionRow,
    PrefetchHooks Function()>;
typedef $$InboxItemsTableCreateCompanionBuilder = InboxItemsCompanion Function({
  required String id,
  required String content,
  Value<String> kind,
  Value<DateTime> createdAt,
  Value<int> synced,
  Value<int> rowid,
});
typedef $$InboxItemsTableUpdateCompanionBuilder = InboxItemsCompanion Function({
  Value<String> id,
  Value<String> content,
  Value<String> kind,
  Value<DateTime> createdAt,
  Value<int> synced,
  Value<int> rowid,
});

class $$InboxItemsTableFilterComposer
    extends Composer<_$AppDatabase, $InboxItemsTable> {
  $$InboxItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get synced => $composableBuilder(
      column: $table.synced, builder: (column) => ColumnFilters(column));
}

class $$InboxItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $InboxItemsTable> {
  $$InboxItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get synced => $composableBuilder(
      column: $table.synced, builder: (column) => ColumnOrderings(column));
}

class $$InboxItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $InboxItemsTable> {
  $$InboxItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get synced =>
      $composableBuilder(column: $table.synced, builder: (column) => column);
}

class $$InboxItemsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $InboxItemsTable,
    InboxItemRow,
    $$InboxItemsTableFilterComposer,
    $$InboxItemsTableOrderingComposer,
    $$InboxItemsTableAnnotationComposer,
    $$InboxItemsTableCreateCompanionBuilder,
    $$InboxItemsTableUpdateCompanionBuilder,
    (
      InboxItemRow,
      BaseReferences<_$AppDatabase, $InboxItemsTable, InboxItemRow>
    ),
    InboxItemRow,
    PrefetchHooks Function()> {
  $$InboxItemsTableTableManager(_$AppDatabase db, $InboxItemsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InboxItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$InboxItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$InboxItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> content = const Value.absent(),
            Value<String> kind = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> synced = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              InboxItemsCompanion(
            id: id,
            content: content,
            kind: kind,
            createdAt: createdAt,
            synced: synced,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String content,
            Value<String> kind = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> synced = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              InboxItemsCompanion.insert(
            id: id,
            content: content,
            kind: kind,
            createdAt: createdAt,
            synced: synced,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$InboxItemsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $InboxItemsTable,
    InboxItemRow,
    $$InboxItemsTableFilterComposer,
    $$InboxItemsTableOrderingComposer,
    $$InboxItemsTableAnnotationComposer,
    $$InboxItemsTableCreateCompanionBuilder,
    $$InboxItemsTableUpdateCompanionBuilder,
    (
      InboxItemRow,
      BaseReferences<_$AppDatabase, $InboxItemsTable, InboxItemRow>
    ),
    InboxItemRow,
    PrefetchHooks Function()>;
typedef $$SyncEventsLocalTableCreateCompanionBuilder = SyncEventsLocalCompanion
    Function({
  required String id,
  required String entityType,
  required String entityId,
  required String operation,
  required String payload,
  Value<DateTime> createdAt,
  Value<int> synced,
  Value<int> rowid,
});
typedef $$SyncEventsLocalTableUpdateCompanionBuilder = SyncEventsLocalCompanion
    Function({
  Value<String> id,
  Value<String> entityType,
  Value<String> entityId,
  Value<String> operation,
  Value<String> payload,
  Value<DateTime> createdAt,
  Value<int> synced,
  Value<int> rowid,
});

class $$SyncEventsLocalTableFilterComposer
    extends Composer<_$AppDatabase, $SyncEventsLocalTable> {
  $$SyncEventsLocalTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get entityType => $composableBuilder(
      column: $table.entityType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get entityId => $composableBuilder(
      column: $table.entityId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get operation => $composableBuilder(
      column: $table.operation, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get synced => $composableBuilder(
      column: $table.synced, builder: (column) => ColumnFilters(column));
}

class $$SyncEventsLocalTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncEventsLocalTable> {
  $$SyncEventsLocalTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get entityType => $composableBuilder(
      column: $table.entityType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get entityId => $composableBuilder(
      column: $table.entityId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get operation => $composableBuilder(
      column: $table.operation, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get synced => $composableBuilder(
      column: $table.synced, builder: (column) => ColumnOrderings(column));
}

class $$SyncEventsLocalTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncEventsLocalTable> {
  $$SyncEventsLocalTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get entityType => $composableBuilder(
      column: $table.entityType, builder: (column) => column);

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get operation =>
      $composableBuilder(column: $table.operation, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get synced =>
      $composableBuilder(column: $table.synced, builder: (column) => column);
}

class $$SyncEventsLocalTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SyncEventsLocalTable,
    SyncEventRow,
    $$SyncEventsLocalTableFilterComposer,
    $$SyncEventsLocalTableOrderingComposer,
    $$SyncEventsLocalTableAnnotationComposer,
    $$SyncEventsLocalTableCreateCompanionBuilder,
    $$SyncEventsLocalTableUpdateCompanionBuilder,
    (
      SyncEventRow,
      BaseReferences<_$AppDatabase, $SyncEventsLocalTable, SyncEventRow>
    ),
    SyncEventRow,
    PrefetchHooks Function()> {
  $$SyncEventsLocalTableTableManager(
      _$AppDatabase db, $SyncEventsLocalTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncEventsLocalTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncEventsLocalTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncEventsLocalTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> entityType = const Value.absent(),
            Value<String> entityId = const Value.absent(),
            Value<String> operation = const Value.absent(),
            Value<String> payload = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> synced = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SyncEventsLocalCompanion(
            id: id,
            entityType: entityType,
            entityId: entityId,
            operation: operation,
            payload: payload,
            createdAt: createdAt,
            synced: synced,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String entityType,
            required String entityId,
            required String operation,
            required String payload,
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> synced = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SyncEventsLocalCompanion.insert(
            id: id,
            entityType: entityType,
            entityId: entityId,
            operation: operation,
            payload: payload,
            createdAt: createdAt,
            synced: synced,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SyncEventsLocalTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SyncEventsLocalTable,
    SyncEventRow,
    $$SyncEventsLocalTableFilterComposer,
    $$SyncEventsLocalTableOrderingComposer,
    $$SyncEventsLocalTableAnnotationComposer,
    $$SyncEventsLocalTableCreateCompanionBuilder,
    $$SyncEventsLocalTableUpdateCompanionBuilder,
    (
      SyncEventRow,
      BaseReferences<_$AppDatabase, $SyncEventsLocalTable, SyncEventRow>
    ),
    SyncEventRow,
    PrefetchHooks Function()>;
typedef $$MomentsTableCreateCompanionBuilder = MomentsCompanion Function({
  required String id,
  Value<String> authorType,
  required String content,
  Value<String> visibility,
  Value<String> source,
  required String deviceId,
  Value<DateTime> createdAt,
  Value<int> rowid,
});
typedef $$MomentsTableUpdateCompanionBuilder = MomentsCompanion Function({
  Value<String> id,
  Value<String> authorType,
  Value<String> content,
  Value<String> visibility,
  Value<String> source,
  Value<String> deviceId,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$MomentsTableFilterComposer
    extends Composer<_$AppDatabase, $MomentsTable> {
  $$MomentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get authorType => $composableBuilder(
      column: $table.authorType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get visibility => $composableBuilder(
      column: $table.visibility, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deviceId => $composableBuilder(
      column: $table.deviceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$MomentsTableOrderingComposer
    extends Composer<_$AppDatabase, $MomentsTable> {
  $$MomentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get authorType => $composableBuilder(
      column: $table.authorType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get visibility => $composableBuilder(
      column: $table.visibility, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deviceId => $composableBuilder(
      column: $table.deviceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$MomentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MomentsTable> {
  $$MomentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get authorType => $composableBuilder(
      column: $table.authorType, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get visibility => $composableBuilder(
      column: $table.visibility, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$MomentsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $MomentsTable,
    MomentRow,
    $$MomentsTableFilterComposer,
    $$MomentsTableOrderingComposer,
    $$MomentsTableAnnotationComposer,
    $$MomentsTableCreateCompanionBuilder,
    $$MomentsTableUpdateCompanionBuilder,
    (MomentRow, BaseReferences<_$AppDatabase, $MomentsTable, MomentRow>),
    MomentRow,
    PrefetchHooks Function()> {
  $$MomentsTableTableManager(_$AppDatabase db, $MomentsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MomentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MomentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MomentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> authorType = const Value.absent(),
            Value<String> content = const Value.absent(),
            Value<String> visibility = const Value.absent(),
            Value<String> source = const Value.absent(),
            Value<String> deviceId = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MomentsCompanion(
            id: id,
            authorType: authorType,
            content: content,
            visibility: visibility,
            source: source,
            deviceId: deviceId,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            Value<String> authorType = const Value.absent(),
            required String content,
            Value<String> visibility = const Value.absent(),
            Value<String> source = const Value.absent(),
            required String deviceId,
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MomentsCompanion.insert(
            id: id,
            authorType: authorType,
            content: content,
            visibility: visibility,
            source: source,
            deviceId: deviceId,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$MomentsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $MomentsTable,
    MomentRow,
    $$MomentsTableFilterComposer,
    $$MomentsTableOrderingComposer,
    $$MomentsTableAnnotationComposer,
    $$MomentsTableCreateCompanionBuilder,
    $$MomentsTableUpdateCompanionBuilder,
    (MomentRow, BaseReferences<_$AppDatabase, $MomentsTable, MomentRow>),
    MomentRow,
    PrefetchHooks Function()>;
typedef $$StudyResourcesTableCreateCompanionBuilder = StudyResourcesCompanion
    Function({
  required String id,
  required String name,
  Value<String> category,
  Value<String> iconName,
  Value<int> colorArgb,
  Value<double> goalAmount,
  Value<String> goalUnit,
  Value<DateTime> createdAt,
  Value<int> rowid,
});
typedef $$StudyResourcesTableUpdateCompanionBuilder = StudyResourcesCompanion
    Function({
  Value<String> id,
  Value<String> name,
  Value<String> category,
  Value<String> iconName,
  Value<int> colorArgb,
  Value<double> goalAmount,
  Value<String> goalUnit,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$StudyResourcesTableFilterComposer
    extends Composer<_$AppDatabase, $StudyResourcesTable> {
  $$StudyResourcesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get iconName => $composableBuilder(
      column: $table.iconName, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get colorArgb => $composableBuilder(
      column: $table.colorArgb, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get goalAmount => $composableBuilder(
      column: $table.goalAmount, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get goalUnit => $composableBuilder(
      column: $table.goalUnit, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$StudyResourcesTableOrderingComposer
    extends Composer<_$AppDatabase, $StudyResourcesTable> {
  $$StudyResourcesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get iconName => $composableBuilder(
      column: $table.iconName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get colorArgb => $composableBuilder(
      column: $table.colorArgb, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get goalAmount => $composableBuilder(
      column: $table.goalAmount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get goalUnit => $composableBuilder(
      column: $table.goalUnit, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$StudyResourcesTableAnnotationComposer
    extends Composer<_$AppDatabase, $StudyResourcesTable> {
  $$StudyResourcesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get iconName =>
      $composableBuilder(column: $table.iconName, builder: (column) => column);

  GeneratedColumn<int> get colorArgb =>
      $composableBuilder(column: $table.colorArgb, builder: (column) => column);

  GeneratedColumn<double> get goalAmount => $composableBuilder(
      column: $table.goalAmount, builder: (column) => column);

  GeneratedColumn<String> get goalUnit =>
      $composableBuilder(column: $table.goalUnit, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$StudyResourcesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $StudyResourcesTable,
    StudyResourceRow,
    $$StudyResourcesTableFilterComposer,
    $$StudyResourcesTableOrderingComposer,
    $$StudyResourcesTableAnnotationComposer,
    $$StudyResourcesTableCreateCompanionBuilder,
    $$StudyResourcesTableUpdateCompanionBuilder,
    (
      StudyResourceRow,
      BaseReferences<_$AppDatabase, $StudyResourcesTable, StudyResourceRow>
    ),
    StudyResourceRow,
    PrefetchHooks Function()> {
  $$StudyResourcesTableTableManager(
      _$AppDatabase db, $StudyResourcesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StudyResourcesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StudyResourcesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StudyResourcesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> category = const Value.absent(),
            Value<String> iconName = const Value.absent(),
            Value<int> colorArgb = const Value.absent(),
            Value<double> goalAmount = const Value.absent(),
            Value<String> goalUnit = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              StudyResourcesCompanion(
            id: id,
            name: name,
            category: category,
            iconName: iconName,
            colorArgb: colorArgb,
            goalAmount: goalAmount,
            goalUnit: goalUnit,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            Value<String> category = const Value.absent(),
            Value<String> iconName = const Value.absent(),
            Value<int> colorArgb = const Value.absent(),
            Value<double> goalAmount = const Value.absent(),
            Value<String> goalUnit = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              StudyResourcesCompanion.insert(
            id: id,
            name: name,
            category: category,
            iconName: iconName,
            colorArgb: colorArgb,
            goalAmount: goalAmount,
            goalUnit: goalUnit,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$StudyResourcesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $StudyResourcesTable,
    StudyResourceRow,
    $$StudyResourcesTableFilterComposer,
    $$StudyResourcesTableOrderingComposer,
    $$StudyResourcesTableAnnotationComposer,
    $$StudyResourcesTableCreateCompanionBuilder,
    $$StudyResourcesTableUpdateCompanionBuilder,
    (
      StudyResourceRow,
      BaseReferences<_$AppDatabase, $StudyResourcesTable, StudyResourceRow>
    ),
    StudyResourceRow,
    PrefetchHooks Function()>;
typedef $$StudySessionsTableCreateCompanionBuilder = StudySessionsCompanion
    Function({
  required String id,
  required String resourceId,
  Value<DateTime> startedAt,
  Value<double> durationSeconds,
  Value<double> amount,
  Value<String?> note,
  Value<int> rowid,
});
typedef $$StudySessionsTableUpdateCompanionBuilder = StudySessionsCompanion
    Function({
  Value<String> id,
  Value<String> resourceId,
  Value<DateTime> startedAt,
  Value<double> durationSeconds,
  Value<double> amount,
  Value<String?> note,
  Value<int> rowid,
});

class $$StudySessionsTableFilterComposer
    extends Composer<_$AppDatabase, $StudySessionsTable> {
  $$StudySessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get resourceId => $composableBuilder(
      column: $table.resourceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
      column: $table.startedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get durationSeconds => $composableBuilder(
      column: $table.durationSeconds,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get amount => $composableBuilder(
      column: $table.amount, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnFilters(column));
}

class $$StudySessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $StudySessionsTable> {
  $$StudySessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get resourceId => $composableBuilder(
      column: $table.resourceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
      column: $table.startedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get durationSeconds => $composableBuilder(
      column: $table.durationSeconds,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get amount => $composableBuilder(
      column: $table.amount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnOrderings(column));
}

class $$StudySessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $StudySessionsTable> {
  $$StudySessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get resourceId => $composableBuilder(
      column: $table.resourceId, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<double> get durationSeconds => $composableBuilder(
      column: $table.durationSeconds, builder: (column) => column);

  GeneratedColumn<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);
}

class $$StudySessionsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $StudySessionsTable,
    StudySessionRow,
    $$StudySessionsTableFilterComposer,
    $$StudySessionsTableOrderingComposer,
    $$StudySessionsTableAnnotationComposer,
    $$StudySessionsTableCreateCompanionBuilder,
    $$StudySessionsTableUpdateCompanionBuilder,
    (
      StudySessionRow,
      BaseReferences<_$AppDatabase, $StudySessionsTable, StudySessionRow>
    ),
    StudySessionRow,
    PrefetchHooks Function()> {
  $$StudySessionsTableTableManager(_$AppDatabase db, $StudySessionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StudySessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StudySessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StudySessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> resourceId = const Value.absent(),
            Value<DateTime> startedAt = const Value.absent(),
            Value<double> durationSeconds = const Value.absent(),
            Value<double> amount = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              StudySessionsCompanion(
            id: id,
            resourceId: resourceId,
            startedAt: startedAt,
            durationSeconds: durationSeconds,
            amount: amount,
            note: note,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String resourceId,
            Value<DateTime> startedAt = const Value.absent(),
            Value<double> durationSeconds = const Value.absent(),
            Value<double> amount = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              StudySessionsCompanion.insert(
            id: id,
            resourceId: resourceId,
            startedAt: startedAt,
            durationSeconds: durationSeconds,
            amount: amount,
            note: note,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$StudySessionsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $StudySessionsTable,
    StudySessionRow,
    $$StudySessionsTableFilterComposer,
    $$StudySessionsTableOrderingComposer,
    $$StudySessionsTableAnnotationComposer,
    $$StudySessionsTableCreateCompanionBuilder,
    $$StudySessionsTableUpdateCompanionBuilder,
    (
      StudySessionRow,
      BaseReferences<_$AppDatabase, $StudySessionsTable, StudySessionRow>
    ),
    StudySessionRow,
    PrefetchHooks Function()>;
typedef $$ExerciseTypesTableCreateCompanionBuilder = ExerciseTypesCompanion
    Function({
  required String id,
  required String name,
  Value<String> iconName,
  Value<String> metrics,
  Value<String> countUnit,
  Value<String> distanceUnit,
  Value<int> colorArgb,
  Value<DateTime> createdAt,
  Value<int> rowid,
});
typedef $$ExerciseTypesTableUpdateCompanionBuilder = ExerciseTypesCompanion
    Function({
  Value<String> id,
  Value<String> name,
  Value<String> iconName,
  Value<String> metrics,
  Value<String> countUnit,
  Value<String> distanceUnit,
  Value<int> colorArgb,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$ExerciseTypesTableFilterComposer
    extends Composer<_$AppDatabase, $ExerciseTypesTable> {
  $$ExerciseTypesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get iconName => $composableBuilder(
      column: $table.iconName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get metrics => $composableBuilder(
      column: $table.metrics, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get countUnit => $composableBuilder(
      column: $table.countUnit, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get distanceUnit => $composableBuilder(
      column: $table.distanceUnit, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get colorArgb => $composableBuilder(
      column: $table.colorArgb, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$ExerciseTypesTableOrderingComposer
    extends Composer<_$AppDatabase, $ExerciseTypesTable> {
  $$ExerciseTypesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get iconName => $composableBuilder(
      column: $table.iconName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get metrics => $composableBuilder(
      column: $table.metrics, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get countUnit => $composableBuilder(
      column: $table.countUnit, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get distanceUnit => $composableBuilder(
      column: $table.distanceUnit,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get colorArgb => $composableBuilder(
      column: $table.colorArgb, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$ExerciseTypesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ExerciseTypesTable> {
  $$ExerciseTypesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get iconName =>
      $composableBuilder(column: $table.iconName, builder: (column) => column);

  GeneratedColumn<String> get metrics =>
      $composableBuilder(column: $table.metrics, builder: (column) => column);

  GeneratedColumn<String> get countUnit =>
      $composableBuilder(column: $table.countUnit, builder: (column) => column);

  GeneratedColumn<String> get distanceUnit => $composableBuilder(
      column: $table.distanceUnit, builder: (column) => column);

  GeneratedColumn<int> get colorArgb =>
      $composableBuilder(column: $table.colorArgb, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ExerciseTypesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ExerciseTypesTable,
    ExerciseTypeRow,
    $$ExerciseTypesTableFilterComposer,
    $$ExerciseTypesTableOrderingComposer,
    $$ExerciseTypesTableAnnotationComposer,
    $$ExerciseTypesTableCreateCompanionBuilder,
    $$ExerciseTypesTableUpdateCompanionBuilder,
    (
      ExerciseTypeRow,
      BaseReferences<_$AppDatabase, $ExerciseTypesTable, ExerciseTypeRow>
    ),
    ExerciseTypeRow,
    PrefetchHooks Function()> {
  $$ExerciseTypesTableTableManager(_$AppDatabase db, $ExerciseTypesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExerciseTypesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExerciseTypesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExerciseTypesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> iconName = const Value.absent(),
            Value<String> metrics = const Value.absent(),
            Value<String> countUnit = const Value.absent(),
            Value<String> distanceUnit = const Value.absent(),
            Value<int> colorArgb = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ExerciseTypesCompanion(
            id: id,
            name: name,
            iconName: iconName,
            metrics: metrics,
            countUnit: countUnit,
            distanceUnit: distanceUnit,
            colorArgb: colorArgb,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            Value<String> iconName = const Value.absent(),
            Value<String> metrics = const Value.absent(),
            Value<String> countUnit = const Value.absent(),
            Value<String> distanceUnit = const Value.absent(),
            Value<int> colorArgb = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ExerciseTypesCompanion.insert(
            id: id,
            name: name,
            iconName: iconName,
            metrics: metrics,
            countUnit: countUnit,
            distanceUnit: distanceUnit,
            colorArgb: colorArgb,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ExerciseTypesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ExerciseTypesTable,
    ExerciseTypeRow,
    $$ExerciseTypesTableFilterComposer,
    $$ExerciseTypesTableOrderingComposer,
    $$ExerciseTypesTableAnnotationComposer,
    $$ExerciseTypesTableCreateCompanionBuilder,
    $$ExerciseTypesTableUpdateCompanionBuilder,
    (
      ExerciseTypeRow,
      BaseReferences<_$AppDatabase, $ExerciseTypesTable, ExerciseTypeRow>
    ),
    ExerciseTypeRow,
    PrefetchHooks Function()>;
typedef $$ExerciseSessionsTableCreateCompanionBuilder
    = ExerciseSessionsCompanion Function({
  required String id,
  required String typeId,
  Value<DateTime> occurredAt,
  Value<int> count,
  Value<double> durationSeconds,
  Value<double> distanceMeters,
  Value<int?> sets,
  Value<double?> weightKg,
  Value<String?> note,
  Value<int> rowid,
});
typedef $$ExerciseSessionsTableUpdateCompanionBuilder
    = ExerciseSessionsCompanion Function({
  Value<String> id,
  Value<String> typeId,
  Value<DateTime> occurredAt,
  Value<int> count,
  Value<double> durationSeconds,
  Value<double> distanceMeters,
  Value<int?> sets,
  Value<double?> weightKg,
  Value<String?> note,
  Value<int> rowid,
});

class $$ExerciseSessionsTableFilterComposer
    extends Composer<_$AppDatabase, $ExerciseSessionsTable> {
  $$ExerciseSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get typeId => $composableBuilder(
      column: $table.typeId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get occurredAt => $composableBuilder(
      column: $table.occurredAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get count => $composableBuilder(
      column: $table.count, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get durationSeconds => $composableBuilder(
      column: $table.durationSeconds,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get distanceMeters => $composableBuilder(
      column: $table.distanceMeters,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sets => $composableBuilder(
      column: $table.sets, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get weightKg => $composableBuilder(
      column: $table.weightKg, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnFilters(column));
}

class $$ExerciseSessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $ExerciseSessionsTable> {
  $$ExerciseSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get typeId => $composableBuilder(
      column: $table.typeId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get occurredAt => $composableBuilder(
      column: $table.occurredAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get count => $composableBuilder(
      column: $table.count, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get durationSeconds => $composableBuilder(
      column: $table.durationSeconds,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get distanceMeters => $composableBuilder(
      column: $table.distanceMeters,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sets => $composableBuilder(
      column: $table.sets, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get weightKg => $composableBuilder(
      column: $table.weightKg, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnOrderings(column));
}

class $$ExerciseSessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ExerciseSessionsTable> {
  $$ExerciseSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get typeId =>
      $composableBuilder(column: $table.typeId, builder: (column) => column);

  GeneratedColumn<DateTime> get occurredAt => $composableBuilder(
      column: $table.occurredAt, builder: (column) => column);

  GeneratedColumn<int> get count =>
      $composableBuilder(column: $table.count, builder: (column) => column);

  GeneratedColumn<double> get durationSeconds => $composableBuilder(
      column: $table.durationSeconds, builder: (column) => column);

  GeneratedColumn<double> get distanceMeters => $composableBuilder(
      column: $table.distanceMeters, builder: (column) => column);

  GeneratedColumn<int> get sets =>
      $composableBuilder(column: $table.sets, builder: (column) => column);

  GeneratedColumn<double> get weightKg =>
      $composableBuilder(column: $table.weightKg, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);
}

class $$ExerciseSessionsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ExerciseSessionsTable,
    ExerciseSessionRow,
    $$ExerciseSessionsTableFilterComposer,
    $$ExerciseSessionsTableOrderingComposer,
    $$ExerciseSessionsTableAnnotationComposer,
    $$ExerciseSessionsTableCreateCompanionBuilder,
    $$ExerciseSessionsTableUpdateCompanionBuilder,
    (
      ExerciseSessionRow,
      BaseReferences<_$AppDatabase, $ExerciseSessionsTable, ExerciseSessionRow>
    ),
    ExerciseSessionRow,
    PrefetchHooks Function()> {
  $$ExerciseSessionsTableTableManager(
      _$AppDatabase db, $ExerciseSessionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExerciseSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExerciseSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExerciseSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> typeId = const Value.absent(),
            Value<DateTime> occurredAt = const Value.absent(),
            Value<int> count = const Value.absent(),
            Value<double> durationSeconds = const Value.absent(),
            Value<double> distanceMeters = const Value.absent(),
            Value<int?> sets = const Value.absent(),
            Value<double?> weightKg = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ExerciseSessionsCompanion(
            id: id,
            typeId: typeId,
            occurredAt: occurredAt,
            count: count,
            durationSeconds: durationSeconds,
            distanceMeters: distanceMeters,
            sets: sets,
            weightKg: weightKg,
            note: note,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String typeId,
            Value<DateTime> occurredAt = const Value.absent(),
            Value<int> count = const Value.absent(),
            Value<double> durationSeconds = const Value.absent(),
            Value<double> distanceMeters = const Value.absent(),
            Value<int?> sets = const Value.absent(),
            Value<double?> weightKg = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ExerciseSessionsCompanion.insert(
            id: id,
            typeId: typeId,
            occurredAt: occurredAt,
            count: count,
            durationSeconds: durationSeconds,
            distanceMeters: distanceMeters,
            sets: sets,
            weightKg: weightKg,
            note: note,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ExerciseSessionsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ExerciseSessionsTable,
    ExerciseSessionRow,
    $$ExerciseSessionsTableFilterComposer,
    $$ExerciseSessionsTableOrderingComposer,
    $$ExerciseSessionsTableAnnotationComposer,
    $$ExerciseSessionsTableCreateCompanionBuilder,
    $$ExerciseSessionsTableUpdateCompanionBuilder,
    (
      ExerciseSessionRow,
      BaseReferences<_$AppDatabase, $ExerciseSessionsTable, ExerciseSessionRow>
    ),
    ExerciseSessionRow,
    PrefetchHooks Function()>;
typedef $$PetsTableCreateCompanionBuilder = PetsCompanion Function({
  required String id,
  required String name,
  Value<String> species,
  Value<String?> avatarPath,
  Value<DateTime> createdAt,
  Value<int> rowid,
});
typedef $$PetsTableUpdateCompanionBuilder = PetsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> species,
  Value<String?> avatarPath,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$PetsTableFilterComposer extends Composer<_$AppDatabase, $PetsTable> {
  $$PetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get species => $composableBuilder(
      column: $table.species, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get avatarPath => $composableBuilder(
      column: $table.avatarPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$PetsTableOrderingComposer extends Composer<_$AppDatabase, $PetsTable> {
  $$PetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get species => $composableBuilder(
      column: $table.species, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get avatarPath => $composableBuilder(
      column: $table.avatarPath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$PetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PetsTable> {
  $$PetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get species =>
      $composableBuilder(column: $table.species, builder: (column) => column);

  GeneratedColumn<String> get avatarPath => $composableBuilder(
      column: $table.avatarPath, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$PetsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PetsTable,
    PetRow,
    $$PetsTableFilterComposer,
    $$PetsTableOrderingComposer,
    $$PetsTableAnnotationComposer,
    $$PetsTableCreateCompanionBuilder,
    $$PetsTableUpdateCompanionBuilder,
    (PetRow, BaseReferences<_$AppDatabase, $PetsTable, PetRow>),
    PetRow,
    PrefetchHooks Function()> {
  $$PetsTableTableManager(_$AppDatabase db, $PetsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> species = const Value.absent(),
            Value<String?> avatarPath = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PetsCompanion(
            id: id,
            name: name,
            species: species,
            avatarPath: avatarPath,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            Value<String> species = const Value.absent(),
            Value<String?> avatarPath = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PetsCompanion.insert(
            id: id,
            name: name,
            species: species,
            avatarPath: avatarPath,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PetsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PetsTable,
    PetRow,
    $$PetsTableFilterComposer,
    $$PetsTableOrderingComposer,
    $$PetsTableAnnotationComposer,
    $$PetsTableCreateCompanionBuilder,
    $$PetsTableUpdateCompanionBuilder,
    (PetRow, BaseReferences<_$AppDatabase, $PetsTable, PetRow>),
    PetRow,
    PrefetchHooks Function()>;
typedef $$PetLogsTableCreateCompanionBuilder = PetLogsCompanion Function({
  required String id,
  required String petId,
  Value<String> kind,
  Value<String> content,
  Value<double?> value,
  Value<String?> mediaAssetId,
  Value<String?> note,
  Value<DateTime> occurredAt,
  Value<int> rowid,
});
typedef $$PetLogsTableUpdateCompanionBuilder = PetLogsCompanion Function({
  Value<String> id,
  Value<String> petId,
  Value<String> kind,
  Value<String> content,
  Value<double?> value,
  Value<String?> mediaAssetId,
  Value<String?> note,
  Value<DateTime> occurredAt,
  Value<int> rowid,
});

class $$PetLogsTableFilterComposer
    extends Composer<_$AppDatabase, $PetLogsTable> {
  $$PetLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get petId => $composableBuilder(
      column: $table.petId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mediaAssetId => $composableBuilder(
      column: $table.mediaAssetId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get occurredAt => $composableBuilder(
      column: $table.occurredAt, builder: (column) => ColumnFilters(column));
}

class $$PetLogsTableOrderingComposer
    extends Composer<_$AppDatabase, $PetLogsTable> {
  $$PetLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get petId => $composableBuilder(
      column: $table.petId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mediaAssetId => $composableBuilder(
      column: $table.mediaAssetId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get occurredAt => $composableBuilder(
      column: $table.occurredAt, builder: (column) => ColumnOrderings(column));
}

class $$PetLogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PetLogsTable> {
  $$PetLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get petId =>
      $composableBuilder(column: $table.petId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<double> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<String> get mediaAssetId => $composableBuilder(
      column: $table.mediaAssetId, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<DateTime> get occurredAt => $composableBuilder(
      column: $table.occurredAt, builder: (column) => column);
}

class $$PetLogsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PetLogsTable,
    PetLogRow,
    $$PetLogsTableFilterComposer,
    $$PetLogsTableOrderingComposer,
    $$PetLogsTableAnnotationComposer,
    $$PetLogsTableCreateCompanionBuilder,
    $$PetLogsTableUpdateCompanionBuilder,
    (PetLogRow, BaseReferences<_$AppDatabase, $PetLogsTable, PetLogRow>),
    PetLogRow,
    PrefetchHooks Function()> {
  $$PetLogsTableTableManager(_$AppDatabase db, $PetLogsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PetLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PetLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PetLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> petId = const Value.absent(),
            Value<String> kind = const Value.absent(),
            Value<String> content = const Value.absent(),
            Value<double?> value = const Value.absent(),
            Value<String?> mediaAssetId = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<DateTime> occurredAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PetLogsCompanion(
            id: id,
            petId: petId,
            kind: kind,
            content: content,
            value: value,
            mediaAssetId: mediaAssetId,
            note: note,
            occurredAt: occurredAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String petId,
            Value<String> kind = const Value.absent(),
            Value<String> content = const Value.absent(),
            Value<double?> value = const Value.absent(),
            Value<String?> mediaAssetId = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<DateTime> occurredAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PetLogsCompanion.insert(
            id: id,
            petId: petId,
            kind: kind,
            content: content,
            value: value,
            mediaAssetId: mediaAssetId,
            note: note,
            occurredAt: occurredAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PetLogsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PetLogsTable,
    PetLogRow,
    $$PetLogsTableFilterComposer,
    $$PetLogsTableOrderingComposer,
    $$PetLogsTableAnnotationComposer,
    $$PetLogsTableCreateCompanionBuilder,
    $$PetLogsTableUpdateCompanionBuilder,
    (PetLogRow, BaseReferences<_$AppDatabase, $PetLogsTable, PetLogRow>),
    PetLogRow,
    PrefetchHooks Function()>;
typedef $$ChatMessagesTableCreateCompanionBuilder = ChatMessagesCompanion
    Function({
  required String conversationId,
  required String id,
  Value<String> role,
  Value<String> kind,
  Value<String?> content,
  Value<String?> mediaAssetId,
  Value<int?> audioDuration,
  Value<String?> stickerId,
  Value<String?> caption,
  Value<String?> fileName,
  Value<int?> fileSize,
  Value<String?> quoteMessageId,
  Value<String?> quoteRole,
  Value<String?> quoteContent,
  Value<String?> senderCharacterId,
  Value<double?> amount,
  Value<bool> claimed,
  Value<String?> claimers,
  Value<bool?> transferAccepted,
  Value<DateTime> createdAt,
  Value<int> rowid,
});
typedef $$ChatMessagesTableUpdateCompanionBuilder = ChatMessagesCompanion
    Function({
  Value<String> conversationId,
  Value<String> id,
  Value<String> role,
  Value<String> kind,
  Value<String?> content,
  Value<String?> mediaAssetId,
  Value<int?> audioDuration,
  Value<String?> stickerId,
  Value<String?> caption,
  Value<String?> fileName,
  Value<int?> fileSize,
  Value<String?> quoteMessageId,
  Value<String?> quoteRole,
  Value<String?> quoteContent,
  Value<String?> senderCharacterId,
  Value<double?> amount,
  Value<bool> claimed,
  Value<String?> claimers,
  Value<bool?> transferAccepted,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$ChatMessagesTableFilterComposer
    extends Composer<_$AppDatabase, $ChatMessagesTable> {
  $$ChatMessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get conversationId => $composableBuilder(
      column: $table.conversationId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get role => $composableBuilder(
      column: $table.role, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mediaAssetId => $composableBuilder(
      column: $table.mediaAssetId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get audioDuration => $composableBuilder(
      column: $table.audioDuration, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get stickerId => $composableBuilder(
      column: $table.stickerId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get caption => $composableBuilder(
      column: $table.caption, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fileName => $composableBuilder(
      column: $table.fileName, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get fileSize => $composableBuilder(
      column: $table.fileSize, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get quoteMessageId => $composableBuilder(
      column: $table.quoteMessageId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get quoteRole => $composableBuilder(
      column: $table.quoteRole, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get quoteContent => $composableBuilder(
      column: $table.quoteContent, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get senderCharacterId => $composableBuilder(
      column: $table.senderCharacterId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get amount => $composableBuilder(
      column: $table.amount, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get claimed => $composableBuilder(
      column: $table.claimed, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get claimers => $composableBuilder(
      column: $table.claimers, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get transferAccepted => $composableBuilder(
      column: $table.transferAccepted,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$ChatMessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $ChatMessagesTable> {
  $$ChatMessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get conversationId => $composableBuilder(
      column: $table.conversationId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get role => $composableBuilder(
      column: $table.role, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mediaAssetId => $composableBuilder(
      column: $table.mediaAssetId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get audioDuration => $composableBuilder(
      column: $table.audioDuration,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get stickerId => $composableBuilder(
      column: $table.stickerId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get caption => $composableBuilder(
      column: $table.caption, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fileName => $composableBuilder(
      column: $table.fileName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get fileSize => $composableBuilder(
      column: $table.fileSize, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get quoteMessageId => $composableBuilder(
      column: $table.quoteMessageId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get quoteRole => $composableBuilder(
      column: $table.quoteRole, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get quoteContent => $composableBuilder(
      column: $table.quoteContent,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get senderCharacterId => $composableBuilder(
      column: $table.senderCharacterId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get amount => $composableBuilder(
      column: $table.amount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get claimed => $composableBuilder(
      column: $table.claimed, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get claimers => $composableBuilder(
      column: $table.claimers, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get transferAccepted => $composableBuilder(
      column: $table.transferAccepted,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$ChatMessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChatMessagesTable> {
  $$ChatMessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get conversationId => $composableBuilder(
      column: $table.conversationId, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get mediaAssetId => $composableBuilder(
      column: $table.mediaAssetId, builder: (column) => column);

  GeneratedColumn<int> get audioDuration => $composableBuilder(
      column: $table.audioDuration, builder: (column) => column);

  GeneratedColumn<String> get stickerId =>
      $composableBuilder(column: $table.stickerId, builder: (column) => column);

  GeneratedColumn<String> get caption =>
      $composableBuilder(column: $table.caption, builder: (column) => column);

  GeneratedColumn<String> get fileName =>
      $composableBuilder(column: $table.fileName, builder: (column) => column);

  GeneratedColumn<int> get fileSize =>
      $composableBuilder(column: $table.fileSize, builder: (column) => column);

  GeneratedColumn<String> get quoteMessageId => $composableBuilder(
      column: $table.quoteMessageId, builder: (column) => column);

  GeneratedColumn<String> get quoteRole =>
      $composableBuilder(column: $table.quoteRole, builder: (column) => column);

  GeneratedColumn<String> get quoteContent => $composableBuilder(
      column: $table.quoteContent, builder: (column) => column);

  GeneratedColumn<String> get senderCharacterId => $composableBuilder(
      column: $table.senderCharacterId, builder: (column) => column);

  GeneratedColumn<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<bool> get claimed =>
      $composableBuilder(column: $table.claimed, builder: (column) => column);

  GeneratedColumn<String> get claimers =>
      $composableBuilder(column: $table.claimers, builder: (column) => column);

  GeneratedColumn<bool> get transferAccepted => $composableBuilder(
      column: $table.transferAccepted, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ChatMessagesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ChatMessagesTable,
    ChatMessageRow,
    $$ChatMessagesTableFilterComposer,
    $$ChatMessagesTableOrderingComposer,
    $$ChatMessagesTableAnnotationComposer,
    $$ChatMessagesTableCreateCompanionBuilder,
    $$ChatMessagesTableUpdateCompanionBuilder,
    (
      ChatMessageRow,
      BaseReferences<_$AppDatabase, $ChatMessagesTable, ChatMessageRow>
    ),
    ChatMessageRow,
    PrefetchHooks Function()> {
  $$ChatMessagesTableTableManager(_$AppDatabase db, $ChatMessagesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChatMessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChatMessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChatMessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> conversationId = const Value.absent(),
            Value<String> id = const Value.absent(),
            Value<String> role = const Value.absent(),
            Value<String> kind = const Value.absent(),
            Value<String?> content = const Value.absent(),
            Value<String?> mediaAssetId = const Value.absent(),
            Value<int?> audioDuration = const Value.absent(),
            Value<String?> stickerId = const Value.absent(),
            Value<String?> caption = const Value.absent(),
            Value<String?> fileName = const Value.absent(),
            Value<int?> fileSize = const Value.absent(),
            Value<String?> quoteMessageId = const Value.absent(),
            Value<String?> quoteRole = const Value.absent(),
            Value<String?> quoteContent = const Value.absent(),
            Value<String?> senderCharacterId = const Value.absent(),
            Value<double?> amount = const Value.absent(),
            Value<bool> claimed = const Value.absent(),
            Value<String?> claimers = const Value.absent(),
            Value<bool?> transferAccepted = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ChatMessagesCompanion(
            conversationId: conversationId,
            id: id,
            role: role,
            kind: kind,
            content: content,
            mediaAssetId: mediaAssetId,
            audioDuration: audioDuration,
            stickerId: stickerId,
            caption: caption,
            fileName: fileName,
            fileSize: fileSize,
            quoteMessageId: quoteMessageId,
            quoteRole: quoteRole,
            quoteContent: quoteContent,
            senderCharacterId: senderCharacterId,
            amount: amount,
            claimed: claimed,
            claimers: claimers,
            transferAccepted: transferAccepted,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String conversationId,
            required String id,
            Value<String> role = const Value.absent(),
            Value<String> kind = const Value.absent(),
            Value<String?> content = const Value.absent(),
            Value<String?> mediaAssetId = const Value.absent(),
            Value<int?> audioDuration = const Value.absent(),
            Value<String?> stickerId = const Value.absent(),
            Value<String?> caption = const Value.absent(),
            Value<String?> fileName = const Value.absent(),
            Value<int?> fileSize = const Value.absent(),
            Value<String?> quoteMessageId = const Value.absent(),
            Value<String?> quoteRole = const Value.absent(),
            Value<String?> quoteContent = const Value.absent(),
            Value<String?> senderCharacterId = const Value.absent(),
            Value<double?> amount = const Value.absent(),
            Value<bool> claimed = const Value.absent(),
            Value<String?> claimers = const Value.absent(),
            Value<bool?> transferAccepted = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ChatMessagesCompanion.insert(
            conversationId: conversationId,
            id: id,
            role: role,
            kind: kind,
            content: content,
            mediaAssetId: mediaAssetId,
            audioDuration: audioDuration,
            stickerId: stickerId,
            caption: caption,
            fileName: fileName,
            fileSize: fileSize,
            quoteMessageId: quoteMessageId,
            quoteRole: quoteRole,
            quoteContent: quoteContent,
            senderCharacterId: senderCharacterId,
            amount: amount,
            claimed: claimed,
            claimers: claimers,
            transferAccepted: transferAccepted,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ChatMessagesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ChatMessagesTable,
    ChatMessageRow,
    $$ChatMessagesTableFilterComposer,
    $$ChatMessagesTableOrderingComposer,
    $$ChatMessagesTableAnnotationComposer,
    $$ChatMessagesTableCreateCompanionBuilder,
    $$ChatMessagesTableUpdateCompanionBuilder,
    (
      ChatMessageRow,
      BaseReferences<_$AppDatabase, $ChatMessagesTable, ChatMessageRow>
    ),
    ChatMessageRow,
    PrefetchHooks Function()>;
typedef $$MediaCacheTableCreateCompanionBuilder = MediaCacheCompanion Function({
  required String mediaId,
  required Uint8List bytes,
  Value<double?> aspect,
  required int updatedAt,
  Value<int> rowid,
});
typedef $$MediaCacheTableUpdateCompanionBuilder = MediaCacheCompanion Function({
  Value<String> mediaId,
  Value<Uint8List> bytes,
  Value<double?> aspect,
  Value<int> updatedAt,
  Value<int> rowid,
});

class $$MediaCacheTableFilterComposer
    extends Composer<_$AppDatabase, $MediaCacheTable> {
  $$MediaCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get mediaId => $composableBuilder(
      column: $table.mediaId, builder: (column) => ColumnFilters(column));

  ColumnFilters<Uint8List> get bytes => $composableBuilder(
      column: $table.bytes, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get aspect => $composableBuilder(
      column: $table.aspect, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$MediaCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $MediaCacheTable> {
  $$MediaCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get mediaId => $composableBuilder(
      column: $table.mediaId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<Uint8List> get bytes => $composableBuilder(
      column: $table.bytes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get aspect => $composableBuilder(
      column: $table.aspect, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$MediaCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $MediaCacheTable> {
  $$MediaCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get mediaId =>
      $composableBuilder(column: $table.mediaId, builder: (column) => column);

  GeneratedColumn<Uint8List> get bytes =>
      $composableBuilder(column: $table.bytes, builder: (column) => column);

  GeneratedColumn<double> get aspect =>
      $composableBuilder(column: $table.aspect, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$MediaCacheTableTableManager extends RootTableManager<
    _$AppDatabase,
    $MediaCacheTable,
    MediaCacheRow,
    $$MediaCacheTableFilterComposer,
    $$MediaCacheTableOrderingComposer,
    $$MediaCacheTableAnnotationComposer,
    $$MediaCacheTableCreateCompanionBuilder,
    $$MediaCacheTableUpdateCompanionBuilder,
    (
      MediaCacheRow,
      BaseReferences<_$AppDatabase, $MediaCacheTable, MediaCacheRow>
    ),
    MediaCacheRow,
    PrefetchHooks Function()> {
  $$MediaCacheTableTableManager(_$AppDatabase db, $MediaCacheTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MediaCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MediaCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MediaCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> mediaId = const Value.absent(),
            Value<Uint8List> bytes = const Value.absent(),
            Value<double?> aspect = const Value.absent(),
            Value<int> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MediaCacheCompanion(
            mediaId: mediaId,
            bytes: bytes,
            aspect: aspect,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String mediaId,
            required Uint8List bytes,
            Value<double?> aspect = const Value.absent(),
            required int updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              MediaCacheCompanion.insert(
            mediaId: mediaId,
            bytes: bytes,
            aspect: aspect,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$MediaCacheTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $MediaCacheTable,
    MediaCacheRow,
    $$MediaCacheTableFilterComposer,
    $$MediaCacheTableOrderingComposer,
    $$MediaCacheTableAnnotationComposer,
    $$MediaCacheTableCreateCompanionBuilder,
    $$MediaCacheTableUpdateCompanionBuilder,
    (
      MediaCacheRow,
      BaseReferences<_$AppDatabase, $MediaCacheTable, MediaCacheRow>
    ),
    MediaCacheRow,
    PrefetchHooks Function()>;
typedef $$KvCacheTableCreateCompanionBuilder = KvCacheCompanion Function({
  required String key,
  required String value,
  required int updatedAt,
  Value<int> rowid,
});
typedef $$KvCacheTableUpdateCompanionBuilder = KvCacheCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> updatedAt,
  Value<int> rowid,
});

class $$KvCacheTableFilterComposer
    extends Composer<_$AppDatabase, $KvCacheTable> {
  $$KvCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$KvCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $KvCacheTable> {
  $$KvCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$KvCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $KvCacheTable> {
  $$KvCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$KvCacheTableTableManager extends RootTableManager<
    _$AppDatabase,
    $KvCacheTable,
    KvCacheRow,
    $$KvCacheTableFilterComposer,
    $$KvCacheTableOrderingComposer,
    $$KvCacheTableAnnotationComposer,
    $$KvCacheTableCreateCompanionBuilder,
    $$KvCacheTableUpdateCompanionBuilder,
    (KvCacheRow, BaseReferences<_$AppDatabase, $KvCacheTable, KvCacheRow>),
    KvCacheRow,
    PrefetchHooks Function()> {
  $$KvCacheTableTableManager(_$AppDatabase db, $KvCacheTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$KvCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$KvCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$KvCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              KvCacheCompanion(
            key: key,
            value: value,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            required String value,
            required int updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              KvCacheCompanion.insert(
            key: key,
            value: value,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$KvCacheTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $KvCacheTable,
    KvCacheRow,
    $$KvCacheTableFilterComposer,
    $$KvCacheTableOrderingComposer,
    $$KvCacheTableAnnotationComposer,
    $$KvCacheTableCreateCompanionBuilder,
    $$KvCacheTableUpdateCompanionBuilder,
    (KvCacheRow, BaseReferences<_$AppDatabase, $KvCacheTable, KvCacheRow>),
    KvCacheRow,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$LifeHabitsTableTableManager get lifeHabits =>
      $$LifeHabitsTableTableManager(_db, _db.lifeHabits);
  $$LifeHabitEventsTableTableManager get lifeHabitEvents =>
      $$LifeHabitEventsTableTableManager(_db, _db.lifeHabitEvents);
  $$ActiveSessionsTableTableManager get activeSessions =>
      $$ActiveSessionsTableTableManager(_db, _db.activeSessions);
  $$InboxItemsTableTableManager get inboxItems =>
      $$InboxItemsTableTableManager(_db, _db.inboxItems);
  $$SyncEventsLocalTableTableManager get syncEventsLocal =>
      $$SyncEventsLocalTableTableManager(_db, _db.syncEventsLocal);
  $$MomentsTableTableManager get moments =>
      $$MomentsTableTableManager(_db, _db.moments);
  $$StudyResourcesTableTableManager get studyResources =>
      $$StudyResourcesTableTableManager(_db, _db.studyResources);
  $$StudySessionsTableTableManager get studySessions =>
      $$StudySessionsTableTableManager(_db, _db.studySessions);
  $$ExerciseTypesTableTableManager get exerciseTypes =>
      $$ExerciseTypesTableTableManager(_db, _db.exerciseTypes);
  $$ExerciseSessionsTableTableManager get exerciseSessions =>
      $$ExerciseSessionsTableTableManager(_db, _db.exerciseSessions);
  $$PetsTableTableManager get pets => $$PetsTableTableManager(_db, _db.pets);
  $$PetLogsTableTableManager get petLogs =>
      $$PetLogsTableTableManager(_db, _db.petLogs);
  $$ChatMessagesTableTableManager get chatMessages =>
      $$ChatMessagesTableTableManager(_db, _db.chatMessages);
  $$MediaCacheTableTableManager get mediaCache =>
      $$MediaCacheTableTableManager(_db, _db.mediaCache);
  $$KvCacheTableTableManager get kvCache =>
      $$KvCacheTableTableManager(_db, _db.kvCache);
}
