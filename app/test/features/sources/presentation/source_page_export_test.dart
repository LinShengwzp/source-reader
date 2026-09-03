import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:source_reader/features/sources/application/source_export.dart';
import 'package:source_reader/features/sources/application/source_file_picker.dart';
import 'package:source_reader/features/sources/application/source_file_saver.dart';
import 'package:source_reader/features/sources/application/source_import.dart';
import 'package:source_reader/features/sources/application/source_providers.dart';
import 'package:source_reader/features/sources/data/source_repository.dart';
import 'package:source_reader/features/sources/domain/source_document.dart';
import 'package:source_reader/features/sources/presentation/source_page.dart';

void main() {
  testWidgets('AppBar 显示导出菜单且未选择时 current 禁用、all 启用', (tester) async {
    final repository = _TestSourceRepository.items(<StoredSource>[
      _storedSource(id: 1, name: '书源 A'),
    ]);

    await _pumpPage(tester, repository);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('source-export-menu')), findsOneWidget);

    await tester.tap(find.byKey(const Key('source-export-menu')));
    await tester.pumpAndSettle();

    final currentItem = tester.widget<PopupMenuItem<SourceExportScope>>(
      find.byKey(const Key('source-export-current')),
    );
    final allItem = tester.widget<PopupMenuItem<SourceExportScope>>(
      find.byKey(const Key('source-export-all')),
    );

    expect(currentItem.enabled, isFalse);
    expect(allItem.enabled, isTrue);
  });

  testWidgets('选择 id=2 后 current JSON 重新读取 Repository 并保存', (tester) async {
    final repository = _TestSourceRepository.items(<StoredSource>[
      _storedSource(id: 1, name: '书源 A'),
      _storedSource(id: 2, name: '书源 B'),
    ]);
    final saver = _FakeSourceFileSaver();

    await _pumpPage(tester, repository, saver: saver);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('source-list-tile-2')));
    await tester.pumpAndSettle();
    await _chooseExport(
      tester,
      scopeKey: const Key('source-export-current'),
      formatKey: const Key('source-export-format-json'),
    );

    expect(repository.getCalls, <int>[2]);
    expect(saver.payloads, hasLength(1));
    expect(saver.payloads.single.fileName, '书源 B.json');
    expect(saver.payloads.single.exportedCount, 1);
    expect(find.text('已导出 1 个书源'), findsOneWidget);
  });

  testWidgets('all XBS 只统计 StandarReader 并传给 saver', (tester) async {
    final repository = _TestSourceRepository.items(<StoredSource>[
      _storedSource(id: 1, name: 'A'),
      _storedSource(id: 2, name: 'B', platform: 'OtherReader'),
      _storedSource(id: 3, name: 'C'),
    ]);
    final saver = _FakeSourceFileSaver();

    await _pumpPage(tester, repository, saver: saver);
    await tester.pumpAndSettle();

    await _chooseExport(
      tester,
      scopeKey: const Key('source-export-all'),
      formatKey: const Key('source-export-format-xbs'),
    );

    expect(saver.payloads, hasLength(1));
    expect(saver.payloads.single.fileName, 'source-reader-export.xbs');
    expect(saver.payloads.single.mimeType, 'application/octet-stream');
    expect(saver.payloads.single.exportedCount, 2);
    expect(find.text('已导出 2 个书源'), findsOneWidget);
  });

  testWidgets('系统保存取消时保持静默', (tester) async {
    final repository = _TestSourceRepository.items(<StoredSource>[
      _storedSource(id: 1, name: 'A'),
    ]);
    final saver = _FakeSourceFileSaver(result: false);

    await _pumpPage(tester, repository, saver: saver);
    await tester.pumpAndSettle();

    await _chooseExport(
      tester,
      scopeKey: const Key('source-export-all'),
      formatKey: const Key('source-export-format-json'),
    );

    expect(saver.payloads, hasLength(1));
    expect(find.textContaining('已导出'), findsNothing);
    expect(find.textContaining('导出失败'), findsNothing);
  });

  testWidgets('没有 StandarReader 时提示没有可导出的书源', (tester) async {
    final repository = _TestSourceRepository.items(<StoredSource>[
      _storedSource(id: 1, name: '其他', platform: 'OtherReader'),
    ]);

    await _pumpPage(tester, repository);
    await tester.pumpAndSettle();

    await _chooseExport(
      tester,
      scopeKey: const Key('source-export-all'),
      formatKey: const Key('source-export-format-json'),
    );

    expect(find.text('没有可导出的书源'), findsOneWidget);
  });

  testWidgets('列表仍有选择但 getSource 返回 null 时提示当前书源已不存在', (tester) async {
    final repository = _TestSourceRepository.items(
      <StoredSource>[_storedSource(id: 1, name: 'A')],
      onGetSource: (_) async => null,
    );

    await _pumpPage(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('source-list-tile-1')));
    await tester.pumpAndSettle();
    await _chooseExport(
      tester,
      scopeKey: const Key('source-export-current'),
      formatKey: const Key('source-export-format-json'),
    );

    expect(repository.getCalls, <int>[1]);
    expect(find.text('当前书源已不存在'), findsOneWidget);
  });

  testWidgets('当前选择为 OtherReader 时提示平台暂不支持导出', (tester) async {
    final repository = _TestSourceRepository.items(<StoredSource>[
      _storedSource(id: 1, name: '其他', platform: 'OtherReader'),
    ]);

    await _pumpPage(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('source-list-tile-1')));
    await tester.pumpAndSettle();
    await _chooseExport(
      tester,
      scopeKey: const Key('source-export-current'),
      formatKey: const Key('source-export-format-json'),
    );

    expect(find.text('当前书源平台暂不支持导出'), findsOneWidget);
  });

  testWidgets('当前书源 raw 无法 JSON 编码时提示导出编码失败', (tester) async {
    final repository = _TestSourceRepository.items(<StoredSource>[
      _storedSource(
        id: 1,
        name: '无法编码',
        extraRaw: <String, Object?>{
          'futureValue': DateTime.utc(2026, 9, 3),
        },
      ),
    ]);

    await _pumpPage(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('source-list-tile-1')));
    await tester.pumpAndSettle();
    await _chooseExport(
      tester,
      scopeKey: const Key('source-export-current'),
      formatKey: const Key('source-export-format-json'),
    );

    expect(find.text('导出编码失败'), findsOneWidget);
  });

  testWidgets('saver 抛出任意异常时显示通用导出失败', (tester) async {
    final repository = _TestSourceRepository.items(<StoredSource>[
      _storedSource(id: 1, name: 'A'),
    ]);
    final saver = _FakeSourceFileSaver(error: StateError('disk failed'));

    await _pumpPage(tester, repository, saver: saver);
    await tester.pumpAndSettle();

    await _chooseExport(
      tester,
      scopeKey: const Key('source-export-all'),
      formatKey: const Key('source-export-format-json'),
    );

    expect(
      find.textContaining('导出失败：Bad state: disk failed'),
      findsOneWidget,
    );
  });
}

Future<void> _chooseExport(
  WidgetTester tester, {
  required Key scopeKey,
  required Key formatKey,
}) async {
  await tester.tap(find.byKey(const Key('source-export-menu')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(scopeKey));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(formatKey));
  await tester.pumpAndSettle();
}

Future<void> _pumpPage(
  WidgetTester tester,
  SourceRepository repository, {
  SourceFileSaver? saver,
  Size size = const Size(1200, 800),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    ProviderScope(
      retry: (retryCount, error) => null,
      overrides: [
        sourceRepositoryProvider.overrideWithValue(repository),
        sourceFilePickerProvider.overrideWithValue(_FakeSourceFilePicker()),
        sourceFileSaverProvider.overrideWithValue(
          saver ?? _FakeSourceFileSaver(),
        ),
      ],
      child: const MaterialApp(home: SourcePage()),
    ),
  );
}

final class _FakeSourceFilePicker implements SourceFilePicker {
  @override
  Future<SourceImportPayload?> pickSourceFile() async => null;
}

final class _FakeSourceFileSaver implements SourceFileSaver {
  _FakeSourceFileSaver({this.result = true, this.error});

  final bool result;
  final Object? error;
  final List<SourceExportPayload> payloads = <SourceExportPayload>[];

  @override
  Future<bool> save(SourceExportPayload payload) async {
    final currentError = error;
    if (currentError != null) {
      throw currentError;
    }
    payloads.add(payload);
    return result;
  }
}

final class _TestSourceRepository implements SourceRepository {
  _TestSourceRepository.items(
    List<StoredSource> initialItems, {
    this.onGetSource,
  }) : items = List<StoredSource>.of(initialItems);

  final Future<StoredSource?> Function(int id)? onGetSource;
  List<StoredSource> items;
  final List<int> getCalls = <int>[];
  int listCalls = 0;

  @override
  Future<List<StoredSource>> listSources() async {
    listCalls += 1;
    return List<StoredSource>.of(items);
  }

  @override
  Future<StoredSource?> getSource(int id) async {
    getCalls.add(id);
    final handler = onGetSource;
    if (handler != null) {
      return handler(id);
    }
    for (final item in items) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

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

StoredSource _storedSource({
  required int id,
  required String name,
  String platform = 'StandarReader',
  Map<String, Object?> extraRaw = const <String, Object?>{},
}) {
  final timestamp = DateTime.utc(2026, 9, 3, 8);
  return StoredSource(
    id: id,
    platform: platform,
    document: SourceDocument.fromRaw(<String, Object?>{
      'sourceName': name,
      'enable': '1',
      'weight': '0',
      ...extraRaw,
    }),
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}
