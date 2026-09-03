import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:source_reader/features/source_tester/application/search_book_result_parser.dart';
import 'package:source_reader/features/source_tester/application/search_book_test_runner.dart';
import 'package:source_reader/features/source_tester/application/source_request_builder.dart';
import 'package:source_reader/features/source_tester/application/source_response_decoder.dart';
import 'package:source_reader/features/source_tester/application/source_tester_providers.dart';
import 'package:source_reader/features/source_tester/data/html_xpath_rule_parser.dart';
import 'package:source_reader/features/source_tester/data/json_rule_parser.dart';
import 'package:source_reader/features/source_tester/domain/source_http.dart';
import 'package:source_reader/features/source_tester/presentation/source_tester_page.dart';
import 'package:source_reader/features/sources/application/source_providers.dart';
import 'package:source_reader/features/sources/data/source_repository.dart';
import 'package:source_reader/features/sources/domain/source_document.dart';

void main() {
  testWidgets('页面显示 persisted 书源标题与已保存版本提示', (tester) async {
    final repository = _FakeRepository(_storedSource());
    await tester.pumpWidget(_app(repository: repository));
    await tester.pumpAndSettle();

    expect(find.text('已保存书源'), findsOneWidget);
    expect(find.text('测试使用已保存版本'), findsOneWidget);
  });

  testWidgets('运行期间禁用按钮，完成后安装 report', (tester) async {
    final repository = _FakeRepository(_storedSource());
    final completer = Completer<SourceHttpResponse>();
    final executor = _FakeExecutor((_) => completer.future);

    await tester.pumpWidget(_app(repository: repository, executor: executor));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('source-tester-input-keyword')),
      ' 测试 ',
    );
    await tester.tap(find.byKey(const Key('source-tester-input-run')));
    await tester.pump();

    expect(find.byKey(const Key('source-tester-progress')), findsOneWidget);
    final runningButton = tester.widget<ButtonStyleButton>(
      find.byKey(const Key('source-tester-input-run')),
    );
    expect(runningButton.enabled, isFalse);

    completer.complete(_response());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('source-tester-progress')), findsNothing);
    expect(find.byKey(const Key('source-tester-report')), findsOneWidget);
    expect(find.text('测试书籍'), findsOneWidget);
    expect(executor.lastRequest?.uri.toString(), 'https://example.com/search?q=%E6%B5%8B%E8%AF%95&page=1');
  });

  testWidgets('结构化 SourceTestException 映射为中文错误', (tester) async {
    final repository = _FakeRepository(_storedSource(platform: 'OtherReader'));
    await tester.pumpWidget(_app(repository: repository));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('source-tester-input-keyword')),
      '测试',
    );
    await tester.tap(find.byKey(const Key('source-tester-input-run')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('source-tester-error')), findsOneWidget);
    expect(find.textContaining('当前书源平台暂不支持测试'), findsOneWidget);
  });

  testWidgets('脚本 requestInfo 显示明确的不支持诊断', (tester) async {
    final repository = _FakeRepository(
      _storedSource(requestInfo: '@js: return config.host;'),
    );
    await tester.pumpWidget(_app(repository: repository));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('source-tester-input-keyword')),
      '测试',
    );
    await tester.tap(find.byKey(const Key('source-tester-input-run')));
    await tester.pumpAndSettle();

    expect(find.textContaining('当前版本不支持脚本请求'), findsOneWidget);
  });

  testWidgets('成功报告中的 JS partial 诊断在解析日志 Tab 可见', (tester) async {
    final repository = _FakeRepository(_storedSource());
    await tester.pumpWidget(_app(repository: repository));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('source-tester-input-keyword')),
      '测试',
    );
    await tester.tap(find.byKey(const Key('source-tester-input-run')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('source-tester-tab-traces')));
    await tester.pumpAndSettle();

    expect(find.textContaining('JS 阶段未执行'), findsOneWidget);
    expect(find.textContaining('部分执行'), findsOneWidget);
  });
}

Widget _app({
  required _FakeRepository repository,
  SourceHttpExecutor? executor,
}) {
  final effectiveExecutor = executor ?? _FakeExecutor((_) async => _response());
  return ProviderScope(
    overrides: [
      sourceRepositoryProvider.overrideWithValue(repository),
      searchBookTestRunnerProvider.overrideWithValue(
        _runner(repository, effectiveExecutor),
      ),
    ],
    child: const MaterialApp(home: SourceTesterPage(sourceId: 7)),
  );
}

SearchBookTestRunner _runner(
  SourceRepository repository,
  SourceHttpExecutor executor,
) {
  return SearchBookTestRunner(
    repository: repository,
    requestBuilder: SourceRequestBuilder(),
    httpExecutor: executor,
    responseDecoder: SourceResponseDecoder(),
    htmlParser: HtmlXPathRuleParser(),
    jsonParser: JsonRuleParser(),
    resultParser: SearchBookResultParser(),
  );
}

StoredSource _storedSource({
  String platform = 'StandarReader',
  String requestInfo = '/search?q=%@keyWord&page=%@pageIndex',
}) {
  final now = DateTime.utc(2026, 9, 3);
  return StoredSource(
    id: 7,
    platform: platform,
    document: SourceDocument.fromRaw(<String, Object?>{
      'sourceName': '已保存书源',
      'sourceUrl': 'https://example.com/',
      'searchBook': <String, Object?>{
        'actionID': 'searchBook',
        'parserID': 'DOM',
        'requestInfo': requestInfo,
        'responseFormatType': 'html',
        'list': "//div[@class='book']",
        'bookName': '//a/text()',
        'author': "//span[@class='author']/text()",
        'detailUrl': '//a/@href || @js: result',
      },
    }),
    createdAt: now,
    updatedAt: now,
  );
}

SourceHttpResponse _response() {
  const body = '<html><body><div class="book"><a href="/book/1">测试书籍</a><span class="author">作者甲</span></div></body></html>';
  return SourceHttpResponse(
    statusCode: 200,
    headers: const <String, String>{'content-type': 'text/html; charset=utf-8'},
    bodyBytes: body.codeUnits,
    finalUri: Uri.parse('https://example.com/search?q=test&page=1'),
    duration: const Duration(milliseconds: 40),
  );
}

final class _FakeExecutor implements SourceHttpExecutor {
  _FakeExecutor(this._execute);

  final Future<SourceHttpResponse> Function(SourceHttpRequest request) _execute;
  SourceHttpRequest? lastRequest;

  @override
  Future<SourceHttpResponse> execute(SourceHttpRequest request) {
    lastRequest = request;
    return _execute(request);
  }
}

final class _FakeRepository implements SourceRepository {
  _FakeRepository(this.source);

  final StoredSource? source;

  @override
  Future<StoredSource?> getSource(int id) async => source?.id == id ? source : null;

  @override
  Future<List<StoredSource>> listSources() async => source == null ? const [] : [source!];

  @override
  Future<int> insertSource({required String platform, required SourceDocument document}) {
    throw UnimplementedError();
  }

  @override
  Future<List<int>> insertSources({
    required String platform,
    required List<SourceDocument> documents,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> updateSource(int id, SourceDocument document) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteSource(int id) {
    throw UnimplementedError();
  }
}
