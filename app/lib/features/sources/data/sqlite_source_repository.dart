import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:source_reader/core/database/app_database.dart';
import 'package:source_reader/features/sources/data/source_repository.dart';
import 'package:source_reader/features/sources/domain/source_document.dart';

/// 基于 Drift/SQLite 的书源持久化实现。
///
/// `rawJson` 始终保存完整书源对象；表中的其余业务列只是便于查询的投影。
final class SqliteSourceRepository implements SourceRepository {
  SqliteSourceRepository(
    this._database, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final AppDatabase _database;
  final DateTime Function() _now;

  @override
  Future<List<StoredSource>> listSources() async {
    final query = _database.select(_database.sourceRows)
      ..orderBy(<OrderingTerm Function(SourceRows)>[
        (row) => OrderingTerm.asc(row.id),
      ]);
    final rows = await query.get();
    return rows.map(_toStoredSource).toList(growable: false);
  }

  @override
  Future<StoredSource?> getSource(int id) async {
    final query = _database.select(_database.sourceRows)
      ..where((row) => row.id.equals(id));
    final row = await query.getSingleOrNull();
    return row == null ? null : _toStoredSource(row);
  }

  @override
  Future<int> insertSource({
    required String platform,
    required SourceDocument document,
  }) async {
    final ids = await insertSources(
      platform: platform,
      documents: <SourceDocument>[document],
    );
    return ids.single;
  }

  @override
  Future<List<int>> insertSources({
    required String platform,
    required List<SourceDocument> documents,
  }) async {
    // 先完成整批校验，避免在进入事务后才发现明显的领域错误。
    final names = documents.map(_requireSourceName).toList(growable: false);
    if (documents.isEmpty) {
      return const <int>[];
    }

    final timestamp = _now();
    return _database.transaction(() async {
      final ids = <int>[];
      for (var index = 0; index < documents.length; index++) {
        final document = documents[index];
        final id = await _database.into(_database.sourceRows).insert(
              _toInsertCompanion(
                platform: platform,
                name: names[index],
                document: document,
                timestamp: timestamp,
              ),
            );
        ids.add(id);
      }
      return ids;
    });
  }

  @override
  Future<void> updateSource(int id, SourceDocument document) async {
    final name = _requireSourceName(document);
    final existing = await getSource(id);
    if (existing == null) {
      throw StateError('书源不存在: $id');
    }

    final affected = await (_database.update(_database.sourceRows)
          ..where((row) => row.id.equals(id)))
        .write(
      SourceRowsCompanion(
        sourceName: Value<String>(name),
        sourceType: Value<String?>(document.sourceType),
        sourceUrl: Value<String?>(document.sourceUrl),
        enabled: Value<bool>(document.enabled),
        weight: Value<int>(document.weight),
        rawJson: Value<String>(jsonEncode(document.toRaw())),
        updatedAt: Value<DateTime>(_now()),
      ),
    );

    if (affected != 1) {
      throw StateError('更新书源失败: $id');
    }
  }

  @override
  Future<void> deleteSource(int id) async {
    await (_database.delete(_database.sourceRows)
          ..where((row) => row.id.equals(id)))
        .go();
  }

  SourceRowsCompanion _toInsertCompanion({
    required String platform,
    required String name,
    required SourceDocument document,
    required DateTime timestamp,
  }) {
    return SourceRowsCompanion.insert(
      platform: platform,
      sourceName: name,
      sourceType: Value<String?>(document.sourceType),
      sourceUrl: Value<String?>(document.sourceUrl),
      enabled: document.enabled,
      weight: document.weight,
      rawJson: jsonEncode(document.toRaw()),
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }

  StoredSource _toStoredSource(SourceRow row) {
    final decoded = jsonDecode(row.rawJson);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('数据库中的书源 raw_json 必须是 JSON 对象');
    }

    return StoredSource(
      id: row.id,
      platform: row.platform,
      document: SourceDocument.fromRaw(decoded),
      createdAt: row.createdAt.toUtc(),
      updatedAt: row.updatedAt.toUtc(),
    );
  }

  static String _requireSourceName(SourceDocument document) {
    final name = document.sourceName;
    if (name == null || name.trim().isEmpty) {
      throw ArgumentError.value(name, 'sourceName', '书源名称不能为空');
    }
    return name;
  }
}
