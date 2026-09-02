import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:source_reader/features/sources/application/source_file_picker.dart';
import 'package:source_reader/features/sources/application/source_import.dart';
import 'package:source_reader/features/sources/application/source_providers.dart';
import 'package:source_reader/features/sources/data/source_repository.dart';
import 'package:source_reader/features/sources/domain/source_document.dart';
import 'package:source_reader/features/sources/presentation/source_page.dart';

void main() {
  testWidgets('加载中显示进度指示器', (tester) async {
    final completer = Completer<List<StoredSource>>();
    final repository = TestSourceRepository(() => completer.future);

    await _pumpPage(tester, repository);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete(<StoredSource>[]);
    await tester.pumpAndSettle();
  });

  testWidgets('空列表显示空状态', (tester) async {
    final repository = TestSourceRepository(
      () async => <StoredSource>[],
    );

    await _pumpPage(tester, repository);
    await tester.pumpAndSettle();

    expect(find.text('还没有书源'), findsOneWidget);
  });

  testWidgets('列表显示书源名称、平台和启用状态', (tester) async {
    final repository = TestSourceRepository(
      () async => <StoredSource>[
        _storedSource(id: 1, name: '书源 A', enabled: true),
        _storedSource(id: 2, name: '书源 B', enabled: false),
      ],
    );

    await _pumpPage(tester, repository);
    await tester.pumpAndSettle();

    expect(find.text('书源 A'), findsOneWidget);
    expect(find.text('书源 B'), findsOneWidget);
    expect(find.text('StandarReader'), findsNWidgets(2));
    expect(find.text('启用'), findsOneWidget);
    expect(find.text('停用'), findsOneWidget);
  });

  testWidgets('宽屏点击书源后按数据库 id 显示选中态', (tester) async {
    final repository = TestSourceRepository(
      () async => <StoredSource>[
        _storedSource(id: 1, name: '书源 A'),
        _storedSource(id: 2, name: '书源 B'),
      ],
    );

    await _pumpPage(
      tester,
      repository,
      size: const Size(1200, 800),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('source-list-tile-2')));
    await tester.pump();

    expect(
      tester.widget<ListTile>(
        find.byKey(const Key('source-list-tile-1')),
      ).selected,
      isFalse,
    );
    expect(
      tester.widget<ListTile>(
        find.byKey(const Key('source-list-tile-2')),
      ).selected,
      isTrue,
    );
  });

  testWidgets('宽屏选择书源后左侧保留列表并在右侧显示编辑器', (tester) async {
    final repository = TestSourceRepository.items(
      <StoredSource>[
        _storedSource(id: 1, name: '书源 A'),
        _storedSource(id: 2, name: '书源 B'),
      ],
    );

    await _pumpPage(
      tester,
      repository,
      size: const Size(1200, 800),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('source-list-tile-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('source-master-pane')), findsOneWidget);
    expect(find.byKey(const Key('source-detail-pane')), findsOneWidget);
    expect(find.byKey(const Key('source-editor-name')), findsOneWidget);
  });

  testWidgets('窄屏选择书源后切换为编辑器并可返回列表', (tester) async {
    final repository = TestSourceRepository.items(
      <StoredSource>[
        _storedSource(id: 1, name: '书源 A'),
      ],
    );

    await _pumpPage(
      tester,
      repository,
      size: const Size(600, 800),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('source-list-tile-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('source-master-pane')), findsNothing);
    expect(find.byKey(const Key('source-editor-name')), findsOneWidget);
    expect(find.byKey(const Key('source-editor-back')), findsOneWidget);

    await tester.tap(find.byKey(const Key('source-editor-back')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('source-master-pane')), findsOneWidget);
    expect(find.byKey(const Key('source-editor-name')), findsNothing);
  });

  testWidgets('保存成功后刷新列表并显示成功提示', (tester) async {
    final repository = TestSourceRepository.items(
      <StoredSource>[
        _storedSource(id: 1, name: '旧名称'),
      ],
    );

    await _pumpPage(
      tester,
      repository,
      size: const Size(1200, 800),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('source-list-tile-1')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('source-editor-name')),
      '已保存名称',
    );
    await tester.tap(find.byKey(const Key('source-editor-save')));
    await tester.pumpAndSettle();

    expect(find.text('已保存'), findsOneWidget);
    expect(repository.updateCalls, 1);
    expect(repository.listCalls, 2);
    expect(find.text('已保存名称'), findsWidgets);
  });

  testWidgets('保存失败显示错误提示并保留当前草稿', (tester) async {
    final error = StateError('save failed');
    final repository = TestSourceRepository.items(
      <StoredSource>[
        _storedSource(id: 1, name: '旧名称'),
      ],
      updateError: error,
    );

    await _pumpPage(
      tester,
      repository,
      size: const Size(1200, 800),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('source-list-tile-1')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('source-editor-name')),
      '草稿仍在',
    );
    await tester.tap(find.byKey(const Key('source-editor-save')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('保存失败：Bad state: save failed'),
      findsOneWidget,
    );
    expect(repository.updateCalls, 1);
    expect(repository.listCalls, 1);
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const Key('source-editor-name')),
          )
          .controller
          ?.text,
      '草稿仍在',
    );
  });

  testWidgets('reload 移除已选书源时清理 stale selection', (tester) async {
    final repository = TestSourceRepository.items(
      <StoredSource>[
        _storedSource(id: 1, name: '书源 A'),
        _storedSource(id: 2, name: '书源 B'),
      ],
    );

    await _pumpPage(
      tester,
      repository,
      size: const Size(1200, 800),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('source-list-tile-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('source-editor-name')), findsOneWidget);

    repository.items = <StoredSource>[
      _storedSource(id: 2, name: '书源 B'),
    ];
    await tester.tap(find.byTooltip('重新加载'));
    await tester.pumpAndSettle();

    expect(find.text('选择一个书源开始编辑'), findsOneWidget);
    expect(find.byKey(const Key('source-editor-name')), findsNothing);

    tester.view.physicalSize = const Size(600, 800);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('source-master-pane')), findsOneWidget);
    expect(find.byKey(const Key('source-editor-name')), findsNothing);
  });

  testWidgets('宽屏显示 master-detail 双栏', (tester) async {
    final repository = TestSourceRepository(
      () async => <StoredSource>[_storedSource(id: 1, name: '书源 A')],
    );

    await _pumpPage(
      tester,
      repository,
      size: const Size(1200, 800),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('source-master-pane')), findsOneWidget);
    expect(find.byKey(const Key('source-detail-pane')), findsOneWidget);
    expect(find.text('选择一个书源开始编辑'), findsOneWidget);
  });

  testWidgets('窄屏只显示 master 列表', (tester) async {
    final repository = TestSourceRepository(
      () async => <StoredSource>[_storedSource(id: 1, name: '书源 A')],
    );

    await _pumpPage(
      tester,
      repository,
      size: const Size(600, 800),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('source-master-pane')), findsOneWidget);
    expect(find.byKey(const Key('source-detail-pane')), findsNothing);
  });

  testWidgets('Repository 失败显示错误态和重试入口', (tester) async {
    final repository = TestSourceRepository(
      () async => throw StateError('load failed'),
    );

    await _pumpPage(tester, repository);
    await tester.pumpAndSettle();

    expect(find.text('加载书源失败'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
  });

  testWidgets('导入按钮成功导入并显示成功提示', (tester) async {
    final repository = TestSourceRepository(
      () async => <StoredSource>[],
      onInsertSources: ({
        required String platform,
        required List<SourceDocument> documents,
      }) async {
        return List<int>.generate(documents.length, (index) => index + 1);
      },
    );
    final picker = FakeSourceFilePicker(
      payload: SourceImportPayload(
        name: 'new.json',
        bytes: Uint8List.fromList(utf8.encode('{"sourceName":"导入书源"}')),
      ),
    );

    await _pumpPage(
      tester,
      repository,
      picker: picker,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('导入书源'));
    await tester.pumpAndSettle();

    expect(find.text('已导入 1 个书源'), findsOneWidget);
    expect(picker.pickCalls, 1);
  });

  testWidgets('用户取消文件选择时不显示错误也不刷新', (tester) async {
    final repository = TestSourceRepository(
      () async => <StoredSource>[],
    );
    final picker = FakeSourceFilePicker(payload: null);

    await _pumpPage(
      tester,
      repository,
      picker: picker,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('导入书源'));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsNothing);
    expect(picker.pickCalls, 1);
  });

  testWidgets('导入失败显示错误提示', (tester) async {
    final repository = TestSourceRepository(
      () async => <StoredSource>[],
      onInsertSources: ({
        required String platform,
        required List<SourceDocument> documents,
      }) async {
        throw FormatException('解析失败');
      },
    );
    final picker = FakeSourceFilePicker(
      payload: SourceImportPayload(
        name: 'bad.json',
        bytes: Uint8List.fromList(utf8.encode('invalid json')),
      ),
    );

    await _pumpPage(
      tester,
      repository,
      picker: picker,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('导入书源'));
    await tester.pumpAndSettle();

    expect(find.textContaining('导入失败'), findsOneWidget);
  });
}

Future<void> _pumpPage(
  WidgetTester tester,
  SourceRepository repository, {
  SourceFilePicker? picker,
  Size size = const Size(800, 800),
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
        sourceFilePickerProvider.overrideWithValue(
          picker ?? FakeSourceFilePicker(payload: null),
        ),
      ],
      child: const MaterialApp(home: SourcePage()),
    ),
  );
}

final class FakeSourceFilePicker implements SourceFilePicker {
  FakeSourceFilePicker({required this.payload});

  final SourceImportPayload? payload;
  int pickCalls = 0;

  @override
  Future<SourceImportPayload?> pickSourceFile() async {
    pickCalls += 1;
    return payload;
  }
}

final class TestSourceRepository implements SourceRepository {
  TestSourceRepository(
    this._onList, {
    this.onInsertSources,
    this.updateError,
  });

  TestSourceRepository.items(
    List<StoredSource> initialItems, {
    this.onInsertSources,
    this.updateError,
  })  : _onList = null,
        items = List<StoredSource>.of(initialItems);

  final Future<List<StoredSource>> Function()? _onList;
  final Future<List<int>> Function({
    required String platform,
    required List<SourceDocument> documents,
  })? onInsertSources;
  Object? updateError;
  List<StoredSource>? items;
  int listCalls = 0;
  int updateCalls = 0;

  @override
  Future<List<StoredSource>> listSources() async {
    listCalls += 1;
    final currentItems = items;
    if (currentItems != null) {
      return List<StoredSource>.of(currentItems);
    }
    return _onList!();
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
  }) {
    final handler = onInsertSources;
    if (handler != null) {
      return handler(platform: platform, documents: documents);
    }
    return Future<List<int>>.error(UnimplementedError());
  }

  @override
  Future<void> updateSource(int id, SourceDocument document) async {
    updateCalls += 1;
    final error = updateError;
    if (error != null) {
      throw error;
    }

    final currentItems = items;
    if (currentItems == null) {
      throw StateError('TestSourceRepository 未配置可更新的 items');
    }

    final index = currentItems.indexWhere((item) => item.id == id);
    if (index < 0) {
      throw StateError('source $id not found');
    }

    final previous = currentItems[index];
    currentItems[index] = StoredSource(
      id: previous.id,
      platform: previous.platform,
      document: document,
      createdAt: previous.createdAt,
      updatedAt: DateTime.utc(2026, 9, 2, 12),
    );
  }

  @override
  Future<void> deleteSource(int id) => throw UnimplementedError();
}

StoredSource _storedSource({
  required int id,
  required String name,
  bool enabled = true,
}) {
  final timestamp = DateTime.utc(2026, 9, 2, 8);
  return StoredSource(
    id: id,
    platform: 'StandarReader',
    document: SourceDocument.fromRaw(<String, Object?>{
      'sourceName': name,
      'enable': enabled ? '1' : '0',
      'weight': '0',
    }),
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}
