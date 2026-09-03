import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:source_reader/core/database/app_database.dart';
import 'package:source_reader/features/sources/application/source_providers.dart';
import 'package:source_reader/features/sources/data/sqlite_source_repository.dart';
import 'package:source_reader/features/sources/domain/source_document.dart';
import 'package:source_reader/features/sources/presentation/source_page.dart';

void main() {
  testWidgets('真实 SQLite 链路保存 searchBook 并在 reload 后保留未知字段', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = SqliteSourceRepository(
      database,
      now: () => DateTime.utc(2026, 9, 2, 13),
    );

    final id = await repository.insertSource(
      platform: 'StandarReader',
      document: SourceDocument.fromRaw(<String, Object?>{
        'sourceName': '集成书源',
        'sourceUrl': 'https://example.com',
        'enable': '1',
        'weight': '1000',
        'futureTop': <String, Object?>{'keep': true},
        'searchBook': <String, Object?>{
          'actionID': 'searchBook',
          'parserID': 'DOM',
          'requestInfo': '/old-search',
          'bookName': './/old-name',
          'futureSearchField': <String, Object?>{'keep': 42},
        },
      }),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sourceRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: SourcePage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(Key('source-list-tile-$id')));
    await tester.pumpAndSettle();

    final requestInfo = _ruleTextFieldFinder(
      const Key('search-book-request-info'),
    );
    final bookName = _ruleTextFieldFinder(
      const Key('search-book-book-name'),
    );

    await tester.ensureVisible(requestInfo);
    await tester.enterText(requestInfo, '/new-search?q=%@keyWord');
    await tester.ensureVisible(bookName);
    await tester.enterText(bookName, './/h2/text()');
    await tester.pump();

    final saveButton = find.byKey(const Key('source-editor-save'));
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    final stored = await repository.getSource(id);
    expect(stored, isNotNull);
    expect(
      stored!.document.searchBook?.action.requestInfo,
      '/new-search?q=%@keyWord',
    );
    expect(stored.document.searchBook?.bookName, './/h2/text()');
    expect(
      stored.document.toRaw()['futureTop'],
      <String, Object?>{'keep': true},
    );
    expect(
      stored.document.searchBook?.toRaw()['futureSearchField'],
      <String, Object?>{'keep': 42},
    );
    expect(find.text('已保存'), findsOneWidget);

    expect(
      _ruleTextFormField(
        tester,
        const Key('search-book-request-info'),
      ).initialValue,
      '/new-search?q=%@keyWord',
    );
    expect(
      _ruleTextFormField(
        tester,
        const Key('search-book-book-name'),
      ).initialValue,
      './/h2/text()',
    );
  });
}

Finder _ruleTextFieldFinder(Key key) {
  return find.descendant(of: find.byKey(key), matching: find.byType(TextField));
}

TextFormField _ruleTextFormField(WidgetTester tester, Key key) {
  return tester.widget<TextFormField>(
    find.descendant(of: find.byKey(key), matching: find.byType(TextFormField)),
  );
}
