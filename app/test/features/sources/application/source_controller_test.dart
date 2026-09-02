import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:source_reader/features/sources/application/source_controller.dart';
import 'package:source_reader/features/sources/application/source_providers.dart';
import 'package:source_reader/features/sources/data/source_repository.dart';
import 'package:source_reader/features/sources/domain/source_document.dart';

void main() {
  test('build 从 SourceRepository 加载书源列表', () async {
    final fake = FakeSourceRepository(<StoredSource>[
      _storedSource(id: 1, name: '书源 A'),
    ]);
    final container = ProviderContainer(
      overrides: <Override>[
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
      overrides: <Override>[
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
}

final class FakeSourceRepository implements SourceRepository {
  FakeSourceRepository(this.items);

  List<StoredSource> items;
  int listCalls = 0;

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
