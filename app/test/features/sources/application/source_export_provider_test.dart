import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:source_reader/features/sources/application/source_export.dart';
import 'package:source_reader/features/sources/application/source_file_saver.dart';
import 'package:source_reader/features/sources/application/source_providers.dart';
import 'package:source_reader/features/sources/data/source_repository.dart';
import 'package:source_reader/features/sources/domain/source_document.dart';

void main() {
  test('sourceExportServiceProvider 使用 sourceRepositoryProvider', () async {
    final repository = _ProviderTestRepository(
      <StoredSource>[_storedSource(id: 1, name: 'Provider 书源')],
    );
    final container = ProviderContainer(
      overrides: [sourceRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final payload = await container
        .read(sourceExportServiceProvider)
        .buildAll(format: SourceExportFormat.json);

    expect(repository.listCalls, 1);
    expect(payload.exportedCount, 1);
  });

  test('sourceFileSaverProvider 默认提供 SourceFileSaver', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(sourceFileSaverProvider), isA<SourceFileSaver>());
  });
}

StoredSource _storedSource({required int id, required String name}) {
  final now = DateTime.utc(2026, 9, 3);
  return StoredSource(
    id: id,
    platform: 'StandarReader',
    document: SourceDocument.fromRaw(<String, Object?>{'sourceName': name}),
    createdAt: now,
    updatedAt: now,
  );
}

final class _ProviderTestRepository implements SourceRepository {
  _ProviderTestRepository(this.sources);

  final List<StoredSource> sources;
  int listCalls = 0;

  @override
  Future<List<StoredSource>> listSources() async {
    listCalls += 1;
    return List<StoredSource>.of(sources);
  }

  @override
  Future<StoredSource?> getSource(int id) => throw UnimplementedError();

  @override
  Future<int> insertSource({
    required String platform,
    required SourceDocument document,
  }) => throw UnimplementedError();

  @override
  Future<List<int>> insertSources({
    required String platform,
    required List<SourceDocument> documents,
  }) => throw UnimplementedError();

  @override
  Future<void> updateSource(int id, SourceDocument document) =>
      throw UnimplementedError();

  @override
  Future<void> deleteSource(int id) => throw UnimplementedError();
}
