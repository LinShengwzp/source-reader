import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:source_reader/features/source_tester/application/source_rule_parser.dart';
import 'package:source_reader/features/source_tester/data/html_xpath_rule_parser.dart';
import 'package:source_reader/features/source_tester/domain/source_rule_value.dart';

void main() {
  group('HtmlXPathRuleParser', () {
    final parser = HtmlXPathRuleParser();

    test('根节点 list XPath 返回两个 row context', () {
      final root = parser.createRoot(_fixture());
      final list = parser.evaluate(
        context: root,
        expression: "//table[@class='grid']//tr",
      );

      expect(list.parserKind, SourceRuleParserKind.htmlXPath);
      expect(list.contexts, hasLength(2));
    });

    test('属性与 text() 提取符合香色常见 XPath', () {
      final root = parser.createRoot(_fixture());

      expect(
        _values(
          parser
              .evaluate(context: root, expression: '//td[1]/a/@href')
              .value,
        ),
        <Object?>['/book/alpha', '/book/beta'],
      );
      expect(
        _values(
          parser
              .evaluate(context: root, expression: '//td[2]/a/text()')
              .value,
        ),
        <Object?>['作者甲', '作者乙'],
      );
      expect(
        _values(parser.evaluate(context: root, expression: '//td[3]').value),
        <Object?>['简介甲', '简介乙'],
      );
    });

    test('row context 上的 // 保持香色相对语义，不回到 document root', () {
      final root = parser.createRoot(_fixture());
      final list = parser.evaluate(
        context: root,
        expression: "//table[@class='grid']//tr",
      );

      expect(_scalar(parser, list.contexts[0], '//td[1]/a'), 'Alpha');
      expect(_scalar(parser, list.contexts[1], '//td[1]/a'), 'Beta');
      expect(_scalar(parser, list.contexts[0], '//td[1]/a/@href'), '/book/alpha');
      expect(_scalar(parser, list.contexts[1], '//td[1]/a/@href'), '/book/beta');
      expect(_scalar(parser, list.contexts[0], '//td[2]/a/text()'), '作者甲');
      expect(_scalar(parser, list.contexts[1], '//td[2]/a/text()'), '作者乙');
    });

    test('无匹配返回空结果', () {
      final root = parser.createRoot(_fixture());
      final result = parser.evaluate(
        context: root,
        expression: '//section[@id="missing"]',
      );

      expect(_values(result.value), isEmpty);
      expect(result.contexts, isEmpty);
    });

    test('非法 XPath 转换成 SourceRuleEvaluationException', () {
      final root = parser.createRoot(_fixture());

      expect(
        () => parser.evaluate(context: root, expression: '//td['),
        throwsA(isA<SourceRuleEvaluationException>()),
      );
    });
  });
}

String _fixture() => File(
  'test/features/source_tester/fixtures/search_fixture.html',
).readAsStringSync();

Object? _scalar(
  HtmlXPathRuleParser parser,
  SourceRuleContext context,
  String expression,
) {
  final values = _values(
    parser.evaluate(context: context, expression: expression).value,
  );
  return values.single;
}

List<Object?> _values(SourceRuleValue value) {
  return switch (value) {
    SourceRuleScalar(:final value) => <Object?>[value],
    SourceRuleList(:final values) => values.expand(_values).toList(),
  };
}
