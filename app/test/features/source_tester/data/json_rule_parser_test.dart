import 'package:flutter_test/flutter_test.dart';
import 'package:source_reader/features/source_tester/application/source_rule_parser.dart';
import 'package:source_reader/features/source_tester/data/json_rule_parser.dart';
import 'package:source_reader/features/source_tester/domain/source_rule_value.dart';
import 'package:source_reader/features/source_tester/domain/source_test_error.dart';

void main() {
  group('JsonRuleParser', () {
    final parser = JsonRuleParser();
    const response = '''
{
  "items": [
    {"name":"A", "meta":{"author":"甲"}},
    {"name":"B", "meta":{"author":"乙"}}
  ]
}
''';

    test('legacy path 使用 1-based 与负数数组下标', () {
      final root = parser.createRoot(response);

      expect(_scalar(parser, root, 'items[1]/name'), 'A');
      expect(_scalar(parser, root, 'items[2]/name'), 'B');
      expect(_scalar(parser, root, 'items[-1]/name'), 'B');
      expect(_scalar(parser, root, 'items[-2]/name'), 'A');
      expect(_values(parser.evaluate(context: root, expression: 'items[0]/name').value), isEmpty);
      expect(_values(parser.evaluate(context: root, expression: 'items[3]/name').value), isEmpty);
    });

    test('legacy list 结果产生逐 item context，后续规则不会回到根', () {
      final root = parser.createRoot(response);
      final list = parser.evaluate(context: root, expression: 'items');

      expect(list.contexts, hasLength(2));
      expect(list.parserKind, SourceRuleParserKind.jsonLegacyPath);
      expect(_scalar(parser, list.contexts[0], 'name'), 'A');
      expect(_scalar(parser, list.contexts[1], 'name'), 'B');
      expect(_scalar(parser, list.contexts[0], r'$.name'), 'A');
      expect(_scalar(parser, list.contexts[1], r'$.name'), 'B');
    });

    test('标准 JSONPath 返回所有匹配且不泄漏第三方 match 类型', () {
      final root = parser.createRoot(response);
      final result = parser.evaluate(
        context: root,
        expression: r'$.items[*].name',
      );

      expect(result.parserKind, SourceRuleParserKind.jsonPath);
      expect(_values(result.value), <Object?>['A', 'B']);
      expect(result.contexts, hasLength(2));
      expect(result.contexts.first.summarize(), isA<SourceRuleScalar>());
    });

    test('invalid JSON root 返回 responseParseFailure', () {
      expect(
        () => parser.createRoot('{bad'),
        throwsA(
          isA<SourceTestException>().having(
            (error) => error.reason,
            'reason',
            SourceTestFailureReason.responseParseFailure,
          ),
        ),
      );
    });

    test('malformed JSONPath 变成 SourceRuleEvaluationException', () {
      final root = parser.createRoot(response);
      expect(
        () => parser.evaluate(context: root, expression: r'$.items[?('),
        throwsA(isA<SourceRuleEvaluationException>()),
      );
    });

    test('非法 legacy segment 变成 SourceRuleEvaluationException', () {
      final root = parser.createRoot(response);
      expect(
        () => parser.evaluate(context: root, expression: 'items[abc]/name'),
        throwsA(isA<SourceRuleEvaluationException>()),
      );
    });

    test('空表达式保留当前 context', () {
      final root = parser.createRoot(response);
      final result = parser.evaluate(context: root, expression: '');
      expect(result.contexts, hasLength(1));
      expect(result.parserKind, SourceRuleParserKind.jsonLegacyPath);
    });
  });
}

Object? _scalar(
  JsonRuleParser parser,
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
