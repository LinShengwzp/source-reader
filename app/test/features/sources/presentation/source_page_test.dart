import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
}

Future<void> _pumpPage(
  WidgetTester tester,
  SourceRepository repository, {
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
      ],
      child: const MaterialApp(home: SourcePage()),
    ),
  );
}

final class TestSourceRepository implements SourceRepository {
  TestSourceRepository(this.onList);

  final Future<List<StoredSource>> Function() onList;

  @override
  Future<List<StoredSource>> listSources() => onList();

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
