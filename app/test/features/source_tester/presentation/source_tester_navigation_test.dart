import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:source_reader/features/source_tester/presentation/source_tester_page.dart';
import 'package:source_reader/features/sources/application/source_providers.dart';
import 'package:source_reader/features/sources/data/source_repository.dart';
import 'package:source_reader/features/sources/domain/source_document.dart';
import 'package:source_reader/features/sources/presentation/source_page.dart';

void main() {
  testWidgets('测试按钮未选择时禁用，选择 id=2 后只按 sourceId 导航到 Tester', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final repository = _NavigationRepository(<StoredSource>[
      _source(id: 1, name: '书源 A'),
      _source(id: 2, name: '书源 B'),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        retry: (retryCount, error) => null,
        overrides: [
          sourceRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: SourcePage()),
      ),
    );
    await tester.pumpAndSettle();

    final actionFinder = find.byKey(const Key('source-test-action'));
    expect(actionFinder, findsOneWidget);
    expect(tester.widget<IconButton>(actionFinder).onPressed, isNull);

    await tester.tap(find.byKey(const Key('source-list-tile-2')));
    await tester.pumpAndSettle();

    expect(tester.widget<IconButton>(actionFinder).onPressed, isNotNull);
    await tester.tap(actionFinder);
    await tester.pumpAndSettle();

    final testerPageFinder = find.byType(SourceTesterPage);
    expect(testerPageFinder, findsOneWidget);
    expect(tester.widget<SourceTesterPage>(testerPageFinder).sourceId, 2);
    expect(find.text('书源 B'), findsOneWidget);
    expect(find.text('测试使用已保存版本'), findsOneWidget);
  });
}

StoredSource _source({required int id, required String name}) {
  final now = DateTime.utc(2026, 9, 3);
  return StoredSource(
    id: id,
    platform: 'StandarReader',
    document: SourceDocument.fromRaw(<String, Object?>{
      'sourceName': name,
      'sourceUrl': 'https://example.com/',
      'searchBook': <String, Object?>{
        'actionID': 'searchBook',
        'parserID': 'DOM',
        'requestInfo': '/search?q=%@keyWord',
        'responseFormatType': 'html',
        'list': '//div',
      },
    }),
    createdAt: now,
    updatedAt: now,
  );
}

final class _NavigationRepository implements SourceRepository {
  _NavigationRepository(this.items);

  final List<StoredSource> items;

  @override
  Future<List<StoredSource>> listSources() async => List<StoredSource>.of(items);

  @override
  Future<StoredSource?> getSource(int id) async {
    for (final item in items) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  @override
  Future<int> insertSource({required String platform, required SourceDocument document}) =>
      throw UnimplementedError();

  @override
  Future<List<int>> insertSources({
    required String platform,
    required List<SourceDocument> documents,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> updateSource(int id, SourceDocument document) => throw UnimplementedError();

  @override
  Future<void> deleteSource(int id) => throw UnimplementedError();
}
