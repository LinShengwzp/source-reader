import 'package:source_reader/features/sources/domain/source_document.dart';

/// 已持久化书源。
///
/// 数据库身份与 platform 属于本地持久化元数据，不写回书源 raw JSON。
final class StoredSource {
  const StoredSource({
    required this.id,
    required this.platform,
    required this.document,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String platform;
  final SourceDocument document;
  final DateTime createdAt;
  final DateTime updatedAt;
}

/// 书源持久化的最小显式接口。
///
/// 新增查询能力时应增加语义明确的方法，不引入通用 SQL/query builder。
abstract interface class SourceRepository {
  Future<List<StoredSource>> listSources();

  Future<StoredSource?> getSource(int id);

  Future<int> insertSource({
    required String platform,
    required SourceDocument document,
  });

  /// 以存储实现能够保证的原子语义批量写入书源。
  ///
  /// 返回值顺序必须与 [documents] 输入顺序一致。
  Future<List<int>> insertSources({
    required String platform,
    required List<SourceDocument> documents,
  });

  Future<void> updateSource(int id, SourceDocument document);

  Future<void> deleteSource(int id);
}
