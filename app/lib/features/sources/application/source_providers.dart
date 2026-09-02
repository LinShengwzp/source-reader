import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:source_reader/core/database/app_database.dart';
import 'package:source_reader/features/sources/application/source_import.dart';
import 'package:source_reader/features/sources/data/source_repository.dart';
import 'package:source_reader/features/sources/data/sqlite_source_repository.dart';

/// 应用级数据库实例，由 Riverpod 负责生命周期。
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(() {
    unawaited(database.close());
  });
  return database;
});

/// 书源持久化边界。UI 与 Controller 只依赖接口，不直接依赖 Drift。
final sourceRepositoryProvider = Provider<SourceRepository>((ref) {
  return SqliteSourceRepository(ref.watch(appDatabaseProvider));
});

/// 书源导入用例服务。解析逻辑依赖 Repository 接口，不感知具体数据库实现。
final sourceImportServiceProvider = Provider<SourceImportService>((ref) {
  return SourceImportService(ref.watch(sourceRepositoryProvider));
});
