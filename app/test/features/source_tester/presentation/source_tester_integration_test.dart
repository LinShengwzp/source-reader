import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:source_reader/core/database/app_database.dart';
import 'package:source_reader/features/source_tester/application/search_book_result_parser.dart';
import 'package:source_reader/features/source_tester/application/search_book_test_runner.dart';
import 'package:source_reader/features/source_tester/application/source_request_builder.dart';
import 'package:source_reader/features/source_tester/application/source_response_decoder.dart';
import 'package:source_reader/features/source_tester/application/source_tester_providers.dart';
import 'package:source_reader/features/source_tester/data/html_xpath_rule_parser.dart';
import 'package:source_reader/features/source_tester/data/json_rule_parser.dart';
import 'package:source_reader/features/source_tester/domain/source_http.dart';
import 'package:source_reader/features/sources/application/source_providers.dart';
import 'package:source_reader/features/sources/data/sqlite_source_repository.dart';
import 'package:source_reader/features/sources/domain/source_document.dart';
import 'package:source_reader/features/sources/presentation/source_page.dart';

void main() {
  testWidgets('Tester 只执行真实 SQLite 已保存版本，返回后保留 Workbench 未保存草稿', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = SqliteSourceRepository(database);
    final sourceId = await repository.insertSource(
      platform: 'StandarReader',
      document: _persistedSource(),
    );
    final httpExecutor = _CapturingHttpExecutor(_htmlFixture());

    await tester.pumpWidget(
      ProviderScope(
        retry: (retryCount, error) => null,
        overrides: <Override>[
          sourceRepositoryProvider.overrideWithValue(repository),
          sourceHttpExecutorProvider.overrideWithValue(httpExecutor),
        ],
        child: const MaterialApp(home: SourcePage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(Key('source-list-tile-$sourceId')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('source-editor-name')),
      '未保存草稿名称',
    );
    final requestInfoKey = find.byKey(const Key('search-book-request-info'));
    await tester.ensureVisible(requestInfoKey);
    await tester.pumpAndSettle();
    await tester.enterText(
      _textFieldFinderForKey(const Key('search-book-request-info')),
      'https://draft.example/search?q=%@keyWord',
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('source-test-action')));
    await tester.pumpAndSettle();

    expect(find.text('已保存书源'), findsOneWidget);
    expect(find.text('未保存草稿名称'), findsNothing);
    expect(find.text('测试使用已保存版本'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('source-tester-input-keyword')),
      'needle',
    );
    await tester.tap(find.byKey(const Key('source-tester-input-run')));
    await tester.pumpAndSettle();

    expect(httpExecutor.requests, hasLength(1));
    expect(
      httpExecutor.requests.single.uri,
      Uri.parse('https://saved.example/search?q=needle'),
    );
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('source-editor-name')))
          .controller
          ?.text,
      '未保存草稿名称',
    );
    expect(
      tester
          .widget<TextFormField>(
            find.descendant(
              of: find.byKey(const Key('search-book-request-info')),
              matching: find.byType(TextFormField),
            ),
          )
          .initialValue,
      'https://draft.example/search?q=%@keyWord',
    );

    final persisted = await repository.getSource(sourceId);
    expect(persisted?.document.sourceName, '已保存书源');
    expect(
      persisted?.document.searchBook?.action.requestInfo,
      'https://saved.example/search?q=%@keyWord',
    );
  });

  test('真实 SQLite Repository 到 Runner 使用已持久化规则并解析 fixture', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = SqliteSourceRepository(database);
    final sourceId = await repository.insertSource(
      platform: 'StandarReader',
      document: _persistedSource(),
    );
    final httpExecutor = _CapturingHttpExecutor(_htmlFixture());
    final runner = SearchBookTestRunner(
      repository: repository,
      requestBuilder: SourceRequestBuilder(),
      httpExecutor: httpExecutor,
      responseDecoder: SourceResponseDecoder(),
      htmlParser: HtmlXPathRuleParser(),
      jsonParser: JsonRuleParser(),
      resultParser: SearchBookResultParser(),
    );

    final report = await runner.run(
      sourceId: sourceId,
      input: const SearchBookTestInput(keyWord: 'integration'),
    );

    expect(httpExecutor.requests, hasLength(1));
    expect(
      httpExecutor.requests.single.uri,
      Uri.parse('https://saved.example/search?q=integration'),
    );
    expect(report.sourceId, sourceId);
    expect(report.sourceName, '已保存书源');
    expect(report.items.map((item) => item.bookName), <String?>['Alpha', 'Beta']);
    expect(report.items.map((item) => item.author), <String?>['作者甲', '作者乙']);
  });
}

SourceDocument _persistedSource() {
  return SourceDocument.fromRaw(<String, Object?>{
    'sourceName': '已保存书源',
    'sourceUrl': 'https://saved.example/base/',
    'enable': '1',
    'weight': '1',
    'searchBook': <String, Object?>{
      'actionID': 'searchBook',
      'parserID': 'DOM',
      'requestInfo': 'https://saved.example/search?q=%@keyWord',
      'responseEncode': 'utf-8',
      'responseFormatType': 'html',
      'list': "//table[@class='grid']//tr",
      'bookName': '//td[1]/a',
      'author': '//td[2]/a',
      'desc': '//td[3]',
      'detailUrl': '//td[1]/a/@href',
    },
  });
}

Finder _textFieldFinderForKey(Key key) {
  return find.descendant(of: find.byKey(key), matching: find.byType(TextField));
}

String _htmlFixture() => File(
      'test/features/source_tester/fixtures/search_fixture.html',
    ).readAsStringSync();

final class _CapturingHttpExecutor implements SourceHttpExecutor {
  _CapturingHttpExecutor(this.body);

  final String body;
  final List<SourceHttpRequest> requests = <SourceHttpRequest>[];

  @override
  Future<SourceHttpResponse> execute(SourceHttpRequest request) async {
    requests.add(request);
    return SourceHttpResponse(
      statusCode: 200,
      headers: const <String, String>{
        'content-type': 'text/html; charset=utf-8',
      },
      bodyBytes: utf8.encode(body),
      finalUri: request.uri,
      duration: const Duration(milliseconds: 5),
    );
  }
}
