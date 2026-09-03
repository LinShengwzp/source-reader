import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:source_reader/core/database/app_database.dart';
import 'package:source_reader/features/sources/application/source_export.dart';
import 'package:source_reader/features/sources/application/source_file_saver.dart';
import 'package:source_reader/features/sources/application/source_providers.dart';
import 'package:source_reader/features/sources/codec/source_json_codec.dart';
import 'package:source_reader/features/sources/data/sqlite_source_repository.dart';
import 'package:source_reader/features/sources/domain/source_document.dart';
import 'package:source_reader/features/sources/presentation/source_page.dart';

void main() {
  test('真实 SQLite 全部导出只包含 StandarReader 且保留未知字段', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = SqliteSourceRepository(
      database,
      now: () => DateTime.utc(2026, 9, 3, 12),
    );

    await repository.insertSource(
      platform: 'StandarReader',
      document: SourceDocument.fromRaw(<String, Object?>{
        'sourceName': 'A',
        'futureTop': <String, Object?>{'keep': true},
      }),
    );
    await repository.insertSource(
      platform: 'OtherReader',
      document: SourceDocument.fromRaw(<String, Object?>{
        'sourceName': 'B',
        'otherOnly': true,
      }),
    );

    final payload = await SourceExportService(repository).buildAll(
      format: SourceExportFormat.json,
    );
    final decoded = decodeSourceJson(utf8.decode(payload.bytes));

    expect(decoded, hasLength(1));
    expect(decoded.single.sourceName, 'A');
    expect(
      decoded.single.toRaw()['futureTop'],
      <String, Object?>{'keep': true},
    );
    expect(payload.exportedCount, 1);
  });

  testWidgets('真实 SourcePage 导出忽略未保存 Draft 且不重置编辑状态', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = SqliteSourceRepository(
      database,
      now: () => DateTime.utc(2026, 9, 3, 12),
    );
    final saver = _CapturingSourceFileSaver();

    final id = await repository.insertSource(
      platform: 'StandarReader',
      document: SourceDocument.fromRaw(<String, Object?>{
        'sourceName': '数据库旧名称',
        'sourceUrl': 'https://example.com',
        'enable': '1',
        'weight': '1000',
        'searchBook': <String, Object?>{
          'actionID': 'searchBook',
          'parserID': 'DOM',
          'requestInfo': '/saved-search',
        },
      }),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sourceRepositoryProvider.overrideWithValue(repository),
          sourceFileSaverProvider.overrideWithValue(saver),
        ],
        child: const MaterialApp(home: SourcePage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(Key('source-list-tile-$id')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('source-editor-name')),
      '未保存新名称',
    );

    final requestInfo = find.descendant(
      of: find.byKey(const Key('search-book-request-info')),
      matching: find.byType(TextField),
    );
    await tester.ensureVisible(requestInfo);
    await tester.enterText(requestInfo, '/unsaved-search');
    await tester.pump();

    await tester.tap(find.byKey(const Key('source-export-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('source-export-current')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('source-export-format-json')));
    await tester.pumpAndSettle();

    expect(saver.payloads, hasLength(1));
    final decoded = decodeSourceJson(
      utf8.decode(saver.payloads.single.bytes),
    );
    expect(decoded, hasLength(1));
    expect(decoded.single.sourceName, '数据库旧名称');
    expect(
      decoded.single.searchBook?.action.requestInfo,
      '/saved-search',
    );

    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('source-editor-name')))
          .controller
          ?.text,
      '未保存新名称',
    );
    expect(
      tester.widget<TextFormField>(requestInfo).controller?.text ??
          tester.widget<TextFormField>(requestInfo).initialValue,
      '/unsaved-search',
    );

    final stored = await repository.getSource(id);
    expect(stored?.document.sourceName, '数据库旧名称');
    expect(
      stored?.document.searchBook?.action.requestInfo,
      '/saved-search',
    );
  });
}

final class _CapturingSourceFileSaver implements SourceFileSaver {
  final List<SourceExportPayload> payloads = <SourceExportPayload>[];

  @override
  Future<bool> save(SourceExportPayload payload) async {
    payloads.add(payload);
    return true;
  }
}
