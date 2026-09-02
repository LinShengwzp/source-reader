import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:source_reader/features/sources/application/source_controller.dart';
import 'package:source_reader/features/sources/application/source_import.dart';
import 'package:source_reader/features/sources/application/source_providers.dart';
import 'package:source_reader/features/sources/data/source_repository.dart';
import 'package:source_reader/features/sources/domain/source_document.dart';

void main() {
  test('build 从 SourceRepository 加载书源列表', () async {
    final fake = FakeSourceRepository(<StoredSource>[
      _storedSource(id: 1, name: '书源 A'),
    ]);
    final container = ProviderContainer(
      overrides: [
        sourceRepositoryProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(container.dispose);

    final value = await container.read(sourceControllerProvider.future);

    expect(value, hasLength(1));
    expect(value.single.id, 1);
    expect(value.single.document.sourceName, '书源 A');
    expect(fake.listCalls, 1);
  });

  test('reload 重新读取 Repository 并替换当前列表', () async {
    final fake = FakeSourceRepository(<StoredSource>[
      _storedSource(id: 1, name: '旧书源'),
    ]);
    final container = ProviderContainer(
      overrides: [
        sourceRepositoryProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(container.dispose);

    await container.read(sourceControllerProvider.future);
    fake.items = <StoredSource>[
      _storedSource(id: 2, name: '新书源'),
    ];

    await container.read(sourceControllerProvider.notifier).reload();

    final state = container.read(sourceControllerProvider);
    expect(state.hasValue, isTrue);
    expect(state.requireValue.single.id, 2);
    expect(state.requireValue.single.document.sourceName, '新书源');
    expect(fake.listCalls, 2);
  });

  test('importPayload 成功后刷新列表并返回导入数量', () async {
    final fake = FakeSourceRepository(<StoredSource>[
      _storedSource(id: 1, name: '已有书源'),
    ]);
    final container = ProviderContainer(
      overrides: [
        sourceRepositoryProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(container.dispose);

    await container.read(sourceControllerProvider.future);

    final result = await container
        .read(sourceControllerProvider.notifier)
        .importPayload(
          SourceImportPayload(
            name: 'new.json',
            bytes: Uint8List.fromList(
              utf8.encode('{"sourceName":"导入书源"}'),
            ),
          ),
        );

    final state = container.read(sourceControllerProvider);
    expect(result.importedCount, 1);
    expect(fake.insertCalls, 1);
    expect(fake.listCalls, 2);
    expect(state.hasValue, isTrue);
    expect(
      state.requireValue.map((item) => item.document.sourceName),
      <String?>['已有书源', '导入书源'],
    );
  });

  test('importPayload 失败时保留当前列表并继续抛出原异常', () async {
    final error = StateError('insert failed');
    final fake = FakeSourceRepository(
      <StoredSource>[_storedSource(id: 1, name: '保留书源')],
      insertError: error,
    );
    final container = ProviderContainer(
      overrides: [
        sourceRepositoryProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(container.dispose);

    await container.read(sourceControllerProvider.future);

    await expectLater(
      container.read(sourceControllerProvider.notifier).importPayload(
            SourceImportPayload(
              name: 'bad.json',
              bytes: Uint8List.fromList(
                utf8.encode('{"sourceName":"失败书源"}'),
              ),
            ),
          ),
      throwsA(same(error)),
    );

    final state = container.read(sourceControllerProvider);
    expect(fake.insertCalls, 1);
    expect(fake.listCalls, 1);
    expect(state.hasValue, isTrue);
    expect(state.requireValue.single.document.sourceName, '保留书源');
  });
}

final class FakeSourceRepository implements SourceRepository {
  FakeSourceRepository(this.items, {this.insertError});

  List<StoredSource> items;
  final Object? insertError;
  int listCalls = 0;
  int insertCalls = 0;

  @override
  Future<List<StoredSource>> listSources() async {
    listCalls += 1;
    return List<StoredSource>.of(items);
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
  }) async {
    insertCalls += 1;
    final error = insertError;
    if (error != null) {
      throw error;
    }

    var nextId = 1;
    for (final item in items) {
      if (item.id >= nextId) {
        nextId = item.id + 1;
      }
    }

    final ids = <int>[];
    for (final document in documents) {
      final id = nextId;
      nextId += 1;
      ids.add(id);
      final timestamp = DateTime.utc(2026, 9, 2, 8);
      items.add(
        StoredSource(
          id: id,
          platform: platform,
          document: document,
          createdAt: timestamp,
          updatedAt: timestamp,
        ),
      );
    }
    return ids;
  }

  @override
  Future<void> updateSource(int id, SourceDocument document) =>
      throw UnimplementedError();

  @override
  Future<void> deleteSource(int id) => throw UnimplementedError();
}

StoredSource _storedSource({required int id, required String name}) {
  final timestamp = DateTime.utc(2026, 9, 2, 8);
  return StoredSource(
    id: id,
    platform: 'StandarReader',
    document: SourceDocument.fromRaw(<String, Object?>{
      'sourceName': name,
      'enable': '1',
      'weight': '0',
    }),
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}
