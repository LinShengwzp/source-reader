import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:source_reader/features/source_tester/application/search_book_result_parser.dart';
import 'package:source_reader/features/source_tester/application/search_book_test_runner.dart';
import 'package:source_reader/features/source_tester/application/source_request_builder.dart';
import 'package:source_reader/features/source_tester/application/source_response_decoder.dart';
import 'package:source_reader/features/source_tester/data/html_xpath_rule_parser.dart';
import 'package:source_reader/features/source_tester/data/json_rule_parser.dart';
import 'package:source_reader/features/source_tester/domain/source_http.dart';
import 'package:source_reader/features/source_tester/domain/source_test_error.dart';
import 'package:source_reader/features/source_tester/domain/source_test_report.dart';
import 'package:source_reader/features/sources/data/source_repository.dart';
import 'package:source_reader/features/sources/domain/source_document.dart';

void main() {
  group('SearchBookTestRunner persisted semantics', () {
    test('每次 run 只按 sourceId 重新读取 Repository 一次', () async {
      final repository = _FakeRepository(_htmlSource());
      final executor = _FakeExecutor(_htmlResponse());
      final runner = _runner(repository: repository, executor: executor);

      await runner.run(
        sourceId: 7,
        input: const SearchBookTestInput(keyWord: '三体'),
      );

      expect(repository.getSourceCalls, <int>[7]);
    });

    test('书源不存在返回 sourceNotFound，且不会发 HTTP', () async {
      final repository = _FakeRepository(null);
      final executor = _FakeExecutor(_htmlResponse());
      final runner = _runner(repository: repository, executor: executor);

      await expectLater(
        runner.run(
          sourceId: 404,
          input: const SearchBookTestInput(keyWord: 'x'),
        ),
        throwsA(_failure(SourceTestFailureReason.sourceNotFound)),
      );
      expect(repository.getSourceCalls, <int>[404]);
      expect(executor.requests, isEmpty);
    });

    test('非 StandarReader 返回 unsupportedPlatform', () async {
      final repository = _FakeRepository(_htmlSource(platform: 'OtherReader'));
      final executor = _FakeExecutor(_htmlResponse());
      final runner = _runner(repository: repository, executor: executor);

      await expectLater(
        runner.run(
          sourceId: 7,
          input: const SearchBookTestInput(keyWord: 'x'),
        ),
        throwsA(_failure(SourceTestFailureReason.unsupportedPlatform)),
      );
      expect(executor.requests, isEmpty);
    });

    test('缺少 searchBook 返回 searchBookMissing', () async {
      final repository = _FakeRepository(
        _storedSource(
          raw: <String, Object?>{
            'sourceName': 'No Search',
            'sourceUrl': 'https://source.example/',
          },
        ),
      );
      final executor = _FakeExecutor(_htmlResponse());
      final runner = _runner(repository: repository, executor: executor);

      await expectLater(
        runner.run(
          sourceId: 7,
          input: const SearchBookTestInput(keyWord: 'x'),
        ),
        throwsA(_failure(SourceTestFailureReason.searchBookMissing)),
      );
      expect(executor.requests, isEmpty);
    });
  });

  group('SearchBookTestRunner orchestration', () {
    test('HTML 完整链路生成 persisted request/response/result/trace report', () async {
      final repository = _FakeRepository(_htmlSource());
      final executor = _FakeExecutor(_htmlResponse());
      final runner = _runner(repository: repository, executor: executor);

      final report = await runner.run(
        sourceId: 7,
        input: const SearchBookTestInput(
          keyWord: '三体',
          pageIndex: 2,
          offset: 10,
          filter: '科幻',
        ),
      );

      expect(repository.getSourceCalls, <int>[7]);
      expect(executor.requests, hasLength(1));
      expect(
        executor.requests.single.uri,
        Uri.parse(
          'https://source.example/search?q=%E4%B8%89%E4%BD%93&page=2&offset=10&filter=%E7%A7%91%E5%B9%BB',
        ),
      );

      expect(report.sourceId, 7);
      expect(report.sourceName, 'HTML Source');
      expect(report.platform, 'StandarReader');
      expect(report.input.keyWord, '三体');
      expect(report.input.pageIndex, 2);
      expect(report.input.offset, 10);
      expect(report.input.filter, '科幻');

      expect(
        report.request.originalRequestInfo,
        '/search?q=%@keyWord&page=%@pageIndex&offset=%@offset&filter=%@filter',
      );
      expect(report.request.method, SourceHttpMethod.get);
      expect(report.request.uri, executor.requests.single.uri);
      expect(report.request.headers['x-source'], 'yes');

      expect(report.response.statusCode, 200);
      expect(report.response.finalUri, Uri.parse('https://mirror.example/final?q=1'));
      expect(report.response.byteCount, _htmlBytes().length);
      expect(report.response.encoding, 'utf8');
      expect(report.response.decodedBody, _htmlFixture());
      expect(report.response.duration, const Duration(milliseconds: 12));

      expect(report.items, hasLength(2));
      expect(report.items[0].bookName, 'Alpha');
      expect(report.items[1].bookName, 'Beta');
      expect(report.items[0].author, '作者甲');
      expect(report.items[1].author, '作者乙');
      expect(report.items[1].detailUrl, 'https://mirror.example/book/beta');
      expect(report.traces.any((trace) => trace.field == 'list'), isTrue);
      expect(report.outcome, SearchBookTestOutcome.success);
    });

    test('JSON 格式选择 JsonRuleParser 并解析列表', () async {
      final repository = _FakeRepository(_jsonSource());
      final executor = _FakeExecutor(
        SourceHttpResponse(
          statusCode: 200,
          headers: const <String, String>{'content-type': 'application/json; charset=utf-8'},
          bodyBytes: utf8.encode('{"items":[{"name":"A"},{"name":"B"}]}'),
          finalUri: Uri.parse('https://api.example/search?q=x'),
          duration: const Duration(milliseconds: 4),
        ),
      );
      final runner = _runner(repository: repository, executor: executor);

      final report = await runner.run(
        sourceId: 7,
        input: const SearchBookTestInput(keyWord: 'x'),
      );

      expect(report.items.map((item) => item.bookName), <String?>['A', 'B']);
      expect(report.response.encoding, 'utf8');
    });

    for (final format in <String?>[null, 'str', 'xml']) {
      test('responseFormatType=$format 返回 unsupportedResponseFormat', () async {
        final repository = _FakeRepository(_htmlSource(responseFormatType: format));
        final executor = _FakeExecutor(_htmlResponse());
        final runner = _runner(repository: repository, executor: executor);

        await expectLater(
          runner.run(
            sourceId: 7,
            input: const SearchBookTestInput(keyWord: 'x'),
          ),
          throwsA(_failure(SourceTestFailureReason.unsupportedResponseFormat)),
        );

        expect(executor.requests, hasLength(1));
      });
    }

    test('HTTP 500 仍继续解码解析并在 report 中保留状态', () async {
      final repository = _FakeRepository(_htmlSource());
      final executor = _FakeExecutor(_htmlResponse(statusCode: 500));
      final runner = _runner(repository: repository, executor: executor);

      final report = await runner.run(
        sourceId: 7,
        input: const SearchBookTestInput(keyWord: 'x'),
      );

      expect(report.response.statusCode, 500);
      expect(report.items, hasLength(2));
      expect(report.items.first.bookName, 'Alpha');
      expect(report.outcome, SearchBookTestOutcome.completedWithWarnings);
      expect(report.warnings.any((warning) => warning.contains('500')), isTrue);
    });
  });
}

SearchBookTestRunner _runner({
  required SourceRepository repository,
  required SourceHttpExecutor executor,
}) {
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

StoredSource _htmlSource({
  String platform = 'StandarReader',
  String? responseFormatType = 'html',
}) {
  final searchBook = <String, Object?>{
    'actionID': 'searchBook',
    'parserID': 'DOM',
    'requestInfo': '/search?q=%@keyWord&page=%@pageIndex&offset=%@offset&filter=%@filter',
    'list': "//table[@class='grid']//tr",
    'bookName': '//td[1]/a',
    'author': '//td[2]/a',
    'desc': '//td[3]',
    'detailUrl': '//td[1]/a/@href',
  };
  if (responseFormatType != null) {
    searchBook['responseFormatType'] = responseFormatType;
  }
  return _storedSource(
    platform: platform,
    raw: <String, Object?>{
      'sourceName': 'HTML Source',
      'sourceUrl': 'https://source.example/base/',
      'httpHeaders': <String, Object?>{'x-source': 'yes'},
      'searchBook': searchBook,
    },
  );
}

StoredSource _jsonSource() => _storedSource(
      raw: <String, Object?>{
        'sourceName': 'JSON Source',
        'sourceUrl': 'https://api.example/',
        'searchBook': <String, Object?>{
          'actionID': 'searchBook',
          'parserID': 'DOM',
          'requestInfo': '/search?q=%@keyWord',
          'responseFormatType': 'json',
          'list': 'items',
          'bookName': 'name',
        },
      },
    );

StoredSource _storedSource({
  String platform = 'StandarReader',
  required Map<String, Object?> raw,
}) {
  return StoredSource(
    id: 7,
    platform: platform,
    document: SourceDocument.fromRaw(raw),
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 2),
  );
}

SourceHttpResponse _htmlResponse({int statusCode = 200}) => SourceHttpResponse(
      statusCode: statusCode,
      headers: const <String, String>{'content-type': 'text/html; charset=utf-8'},
      bodyBytes: _htmlBytes(),
      finalUri: Uri.parse('https://mirror.example/final?q=1'),
      duration: const Duration(milliseconds: 12),
    );

List<int> _htmlBytes() => utf8.encode(_htmlFixture());

String _htmlFixture() => File(
      'test/features/source_tester/fixtures/search_fixture.html',
    ).readAsStringSync();

Matcher _failure(SourceTestFailureReason reason) => isA<SourceTestException>().having(
      (error) => error.reason,
      'reason',
      reason,
    );

final class _FakeRepository implements SourceRepository {
  _FakeRepository(this.source);

  StoredSource? source;
  final List<int> getSourceCalls = <int>[];

  @override
  Future<StoredSource?> getSource(int id) async {
    getSourceCalls.add(id);
    return source;
  }

  @override
  Future<List<StoredSource>> listSources() => throw UnimplementedError();

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

final class _FakeExecutor implements SourceHttpExecutor {
  _FakeExecutor(this.response);

  final SourceHttpResponse response;
  final List<SourceHttpRequest> requests = <SourceHttpRequest>[];

  @override
  Future<SourceHttpResponse> execute(SourceHttpRequest request) async {
    requests.add(request);
    return response;
  }
}
