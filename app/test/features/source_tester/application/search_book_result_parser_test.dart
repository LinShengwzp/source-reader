import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:source_reader/features/sources/domain/source_search_book_document.dart';
import 'package:source_reader/features/source_tester/application/search_book_result_parser.dart';
import 'package:source_reader/features/source_tester/data/html_xpath_rule_parser.dart';
import 'package:source_reader/features/source_tester/data/json_rule_parser.dart';
import 'package:source_reader/features/source_tester/domain/source_test_error.dart';

void main() {
  group('SearchBookResultParser', () {
    final resultParser = SearchBookResultParser();

    test('list 缺失或不可执行时返回 listRuleFailure', () {
      final htmlParser = HtmlXPathRuleParser();

      expect(
        () => resultParser.parse(
          searchBook: _searchBook(),
          parser: htmlParser,
          responseText: _htmlFixture(),
          finalResponseUri: Uri.parse('https://mirror.example/search'),
          sourceUrl: 'https://source.example/',
        ),
        throwsA(_failure(SourceTestFailureReason.listRuleFailure)),
      );

      expect(
        () => resultParser.parse(
          searchBook: _searchBook(list: '//td['),
          parser: htmlParser,
          responseText: _htmlFixture(),
          finalResponseUri: Uri.parse('https://mirror.example/search'),
          sourceUrl: 'https://source.example/',
        ),
        throwsA(_failure(SourceTestFailureReason.listRuleFailure)),
      );
    });

    test('合法 list 零匹配是成功空结果', () {
      final result = resultParser.parse(
        searchBook: _searchBook(list: '//article[@class="missing"]'),
        parser: HtmlXPathRuleParser(),
        responseText: _htmlFixture(),
        finalResponseUri: Uri.parse('https://mirror.example/search'),
        sourceUrl: 'https://source.example/',
      );

      expect(result.items, isEmpty);
      expect(result.traces.single.field, 'list');
      expect(result.traces.single.errors, isEmpty);
    });

    test('字段失败只记录 trace，不破坏其他字段和其他 item', () {
      final result = resultParser.parse(
        searchBook: _searchBook(
          list: "//table[@class='grid']//tr",
          bookName: '//td[1]/a',
          author: '//td[',
          desc: '//td[3]',
        ),
        parser: HtmlXPathRuleParser(),
        responseText: _htmlFixture(),
        finalResponseUri: Uri.parse('https://mirror.example/search'),
        sourceUrl: 'https://source.example/',
      );

      expect(result.items, hasLength(2));
      expect(result.items[0].bookName, 'Alpha');
      expect(result.items[1].bookName, 'Beta');
      expect(result.items[0].desc, '简介甲');
      expect(result.items[1].desc, '简介乙');
      expect(result.items.every((item) => item.author == null), isTrue);

      final authorTrace = result.traces.singleWhere(
        (trace) => trace.field == 'author',
      );
      expect(authorTrace.errors, isNotEmpty);
    });

    test('JS 后处理保留声明式前缀，JS-first 无值，JSParser 只告警', () {
      final result = resultParser.parse(
        searchBook: _searchBook(
          list: "//table[@class='grid']//tr",
          bookName: '//td[1]/a',
          author: '@js: result.author',
          detailUrl: '//td[1]/a/@href || @js: result.trim()',
          jsParser: 'return result;',
        ),
        parser: HtmlXPathRuleParser(),
        responseText: _htmlFixture(),
        finalResponseUri: Uri.parse('https://mirror.example/search?q=x'),
        sourceUrl: 'https://source.example/',
      );

      expect(result.items[0].bookName, 'Alpha');
      expect(result.items[1].bookName, 'Beta');
      expect(result.items.every((item) => item.author == null), isTrue);
      expect(result.items[0].detailUrl, 'https://mirror.example/book/alpha');
      expect(result.items[1].detailUrl, 'https://mirror.example/book/beta');

      final detailTrace = result.traces.singleWhere(
        (trace) => trace.field == 'detailUrl',
      );
      expect(detailTrace.partial, isTrue);
      expect(detailTrace.warnings.any((warning) => warning.contains('JS')), isTrue);

      final authorTrace = result.traces.singleWhere(
        (trace) => trace.field == 'author',
      );
      expect(authorTrace.partial, isTrue);
      expect(authorTrace.outputSummary, isEmpty);
      expect(result.warnings.any((warning) => warning.contains('JSParser')), isTrue);
    });

    test('cover/detailUrl 绝对 URL 保持不变，相对 URL 优先使用最终响应 URI', () {
      const response = '''
{
  "items": [
    {"name":"A", "cover":"https://cdn.example/a.jpg", "url":"book/a"}
  ]
}
''';
      final result = resultParser.parse(
        searchBook: _searchBook(
          list: 'items',
          bookName: 'name',
          cover: 'cover',
          detailUrl: 'url',
        ),
        parser: JsonRuleParser(),
        responseText: response,
        finalResponseUri: Uri.parse('https://mirror.example/search/list'),
        sourceUrl: 'https://source.example/base/',
      );

      expect(result.items.single.cover, 'https://cdn.example/a.jpg');
      expect(
        result.items.single.detailUrl,
        'https://mirror.example/search/book/a',
      );
    });

    test('最终响应 URI 不是绝对地址时回退 persisted sourceUrl', () {
      const response = '{"items":[{"url":"book/a"}]}';
      final result = resultParser.parse(
        searchBook: _searchBook(list: 'items', detailUrl: 'url'),
        parser: JsonRuleParser(),
        responseText: response,
        finalResponseUri: Uri.parse('relative/search'),
        sourceUrl: 'https://source.example/base/',
      );

      expect(result.items.single.detailUrl, 'https://source.example/base/book/a');
    });

    test('moreKeys skipCount 先跳过，再限制最多 500 项并提示暂未应用的配置', () {
      final items = List<Map<String, Object?>>.generate(
        505,
        (index) => <String, Object?>{'name': 'N$index'},
      );
      final response = jsonEncode(<String, Object?>{'items': items});
      final result = resultParser.parse(
        searchBook: _searchBook(
          list: 'items',
          bookName: 'name',
          moreKeys: <String, Object?>{
            'skipCount': 2,
            'pageSize': 20,
            'maxPage': 10,
            'removeHtmlKeys': <String>['script'],
            'requestFilters': <String>['x'],
          },
        ),
        parser: JsonRuleParser(),
        responseText: response,
        finalResponseUri: Uri.parse('https://mirror.example/search'),
        sourceUrl: 'https://source.example/',
      );

      expect(result.items, hasLength(500));
      expect(result.items.first.bookName, 'N2');
      expect(result.items.last.bookName, 'N501');
      expect(result.warnings.any((warning) => warning.contains('500')), isTrue);
      expect(result.warnings.any((warning) => warning.contains('pageSize')), isTrue);
      expect(result.warnings.any((warning) => warning.contains('maxPage')), isTrue);
      expect(result.warnings.any((warning) => warning.contains('removeHtmlKeys')), isTrue);
      expect(result.warnings.any((warning) => warning.contains('requestFilters')), isTrue);
    });

    test('moreKeys JSON 字符串同样应用 skipCount', () {
      const response = '{"items":[{"name":"A"},{"name":"B"}]}';
      final result = resultParser.parse(
        searchBook: _searchBook(
          list: 'items',
          bookName: 'name',
          moreKeys: '{"skipCount":1}',
        ),
        parser: JsonRuleParser(),
        responseText: response,
        finalResponseUri: Uri.parse('https://mirror.example/search'),
        sourceUrl: 'https://source.example/',
      );

      expect(result.items, hasLength(1));
      expect(result.items.single.bookName, 'B');
    });
  });
}

SourceSearchBookDocument _searchBook({
  String? list,
  String? bookName,
  String? author,
  String? cover,
  String? desc,
  String? detailUrl,
  String? jsParser,
  Object? moreKeys,
}) {
  return SourceSearchBookDocument.fromRaw(<String, Object?>{
    'actionID': 'searchBook',
    'parserID': 'DOM',
    if (list != null) 'list': list,
    if (bookName != null) 'bookName': bookName,
    if (author != null) 'author': author,
    if (cover != null) 'cover': cover,
    if (desc != null) 'desc': desc,
    if (detailUrl != null) 'detailUrl': detailUrl,
    if (jsParser != null) 'JSParser': jsParser,
    if (moreKeys != null) 'moreKeys': moreKeys,
  });
}

Matcher _failure(SourceTestFailureReason reason) => isA<SourceTestException>().having(
      (error) => error.reason,
      'reason',
      reason,
    );

String _htmlFixture() => File(
      'test/features/source_tester/fixtures/search_fixture.html',
    ).readAsStringSync();
