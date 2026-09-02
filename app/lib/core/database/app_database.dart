import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// Source Workbench 第一阶段唯一的持久化表。
///
/// raw_json 保存完整书源内容，其余字段只用于列表、过滤和排序。
class SourceRows extends Table {
  @override
  String get tableName => 'sources';

  IntColumn get id => integer().autoIncrement()();

  TextColumn get platform => text()();

  TextColumn get sourceName => text()();

  TextColumn get sourceType => text().nullable()();

  TextColumn get sourceUrl => text().nullable()();

  BoolColumn get enabled => boolean()();

  IntColumn get weight => integer()();

  TextColumn get rawJson => text()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => <Set<Column<Object>>>[
    <Column<Object>>{platform, sourceName},
  ];
}

@DriftDatabase(tables: <Type>[SourceRows])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'source_reader');
  }
}
