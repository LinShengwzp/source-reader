import 'package:flutter_test/flutter_test.dart';
import 'package:source_reader/features/source_tester/application/source_request_builder.dart';
import 'package:source_reader/features/source_tester/domain/source_test_error.dart';
import 'package:source_reader/features/sources/data/source_repository.dart';
import 'package:source_reader/features/sources/domain/source_document.dart';

void main() {
  group('SourceRequestBuilder', () {
    test('替换 UTF-8 搜索参数并解析相对 URL', () {
      final source = _source(
        sourceUrl: 'https://example.com/base/',
        searchBook: <String, Object?>{
          'requestInfo':
              '/search?q=%@keyWord&p=%@pageIndex&o=%@offset&f=%@filter',
          'requestParamsEncode': 'utf-8',
        },
      );

      final result = SourceRequestBuilder().build(
        source: source,
        input: const SearchBookTestInput(
          keyWord: '三体',
          filter: '科幻 小说',
        ),
      );

      expect(
        result.request.uri.toString(),
        'https://example.com/search?q=%E4%B8%89%E4%BD%93&p=1&o=0&f=%E7%A7%91%E5%B9%BB%20%E5%B0%8F%E8%AF%B4',
      );
      expect(result.originalRequestInfo, contains('%@keyWord'));
      expect(result.warnings, isEmpty);
    });

    test('使用 GBK 字节编码 keyWord 和 filter', () {
      final source = _source(
        searchBook: <String, Object?>{
          'requestInfo': 'https://example.com/search?q=%@keyWord&f=%@filter',
          'requestParamsEncode': '2147485234',
        },
      );

      final result = SourceRequestBuilder().build(
        source: source,
        input: const SearchBookTestInput(keyWord: '三体', filter: '三体'),
      );

      // 独立 fixture：三体的 GBK bytes = C8 FD CC E5。
      expect(
        result.request.uri.toString(),
        'https://example.com/search?q=%C8%FD%CC%E5&f=%C8%FD%CC%E5',
      );
    });

    test('空 requestInfo 返回 requestInfoMissing', () {
      expect(
        () => SourceRequestBuilder().build(
          source: _source(searchBook: <String, Object?>{'requestInfo': '  '}),
          input: const SearchBookTestInput(keyWord: 'x'),
        ),
        throwsA(_reason(SourceTestFailureReason.requestInfoMissing)),
      );
    });

    test('脚本 requestInfo 返回 unsupportedScriptRequest', () {
      expect(
        () => SourceRequestBuilder().build(
          source: _source(
            searchBook: <String, Object?>{'requestInfo': '  @js: return "x";'},
          ),
          input: const SearchBookTestInput(keyWord: 'x'),
        ),
        throwsA(_reason(SourceTestFailureReason.unsupportedScriptRequest)),
      );
    });

    test('未知占位符返回 unknownPlaceholder', () {
      expect(
        () => SourceRequestBuilder().build(
          source: _source(
            searchBook: <String, Object?>{
              'requestInfo': 'https://example.com/?x=%@unknown',
            },
          ),
          input: const SearchBookTestInput(keyWord: 'x'),
        ),
        throwsA(_reason(SourceTestFailureReason.unknownPlaceholder)),
      );
    });

    test('相对 requestInfo 缺少有效绝对 sourceUrl 时返回 invalidBaseUrl', () {
      expect(
        () => SourceRequestBuilder().build(
          source: _source(
            sourceUrl: 'not-a-url',
            searchBook: <String, Object?>{'requestInfo': '/search?q=%@keyWord'},
          ),
          input: const SearchBookTestInput(keyWord: 'x'),
        ),
        throwsA(_reason(SourceTestFailureReason.invalidBaseUrl)),
      );
    });

    test('未知 requestParamsEncode 返回 unsupportedRequestEncoding', () {
      expect(
        () => SourceRequestBuilder().build(
          source: _source(
            searchBook: <String, Object?>{
              'requestInfo': 'https://example.com/?q=%@keyWord',
              'requestParamsEncode': 'shift-jis',
            },
          ),
          input: const SearchBookTestInput(keyWord: 'x'),
        ),
        throwsA(_reason(SourceTestFailureReason.unsupportedRequestEncoding)),
      );
    });

    test('合并全局与 searchBook headers，子级按大小写覆盖且坏 entry 仅 warning', () {
      final source = _source(
        topLevel: <String, Object?>{
          'httpHeaders': <String, Object?>{
            'Accept': 'text/html',
            'X-Top': 7,
            'X-Bad': <String>['not', 'scalar'],
          },
        },
        searchBook: <String, Object?>{
          'requestInfo': 'https://example.com/?q=%@keyWord',
          'httpHeaders': '{"accept":"application/json","X-Search":true}',
        },
      );

      final result = SourceRequestBuilder().build(
        source: source,
        input: const SearchBookTestInput(keyWord: 'x'),
      );

      expect(result.request.headers.length, 3);
      expect(
        result.request.headers.entries
            .singleWhere((entry) => entry.key.toLowerCase() == 'accept')
            .value,
        'application/json',
      );
      expect(result.request.headers['X-Top'], '7');
      expect(result.request.headers['X-Search'], 'true');
      expect(
        result.request.headers.keys.any((key) => key.toLowerCase() == 'user-agent'),
        isFalse,
      );
      expect(result.warnings, isNotEmpty);
    });

    test('非法 header JSON 返回 invalidHeaders', () {
      expect(
        () => SourceRequestBuilder().build(
          source: _source(
            topLevel: <String, Object?>{'httpHeaders': '{bad'},
            searchBook: <String, Object?>{
              'requestInfo': 'https://example.com/?q=%@keyWord',
            },
          ),
          input: const SearchBookTestInput(keyWord: 'x'),
        ),
        throwsA(_reason(SourceTestFailureReason.invalidHeaders)),
      );
    });

    test('非对象 header JSON 返回 invalidHeaders', () {
      expect(
        () => SourceRequestBuilder().build(
          source: _source(
            topLevel: <String, Object?>{'httpHeaders': '["x"]'},
            searchBook: <String, Object?>{
              'requestInfo': 'https://example.com/?q=%@keyWord',
            },
          ),
          input: const SearchBookTestInput(keyWord: 'x'),
        ),
        throwsA(_reason(SourceTestFailureReason.invalidHeaders)),
      );
    });
  });
}

Matcher _reason(SourceTestFailureReason reason) {
  return isA<SourceTestException>().having(
    (error) => error.reason,
    'reason',
    reason,
  );
}

StoredSource _source({
  String sourceUrl = 'https://example.com/',
  Map<String, Object?> topLevel = const <String, Object?>{},
  required Map<String, Object?> searchBook,
}) {
  final raw = <String, Object?>{
    'sourceName': '测试书源',
    'sourceUrl': sourceUrl,
    ...topLevel,
    'searchBook': <String, Object?>{
      'actionID': 'searchBook',
      'parserID': 'DOM',
      ...searchBook,
    },
  };
  return StoredSource(
    id: 1,
    platform: 'StandarReader',
    document: SourceDocument.fromRaw(raw),
    createdAt: DateTime.utc(2026, 9, 3),
    updatedAt: DateTime.utc(2026, 9, 3),
  );
}
