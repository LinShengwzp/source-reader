import 'package:flutter_test/flutter_test.dart';
import 'package:source_reader/features/source_tester/application/source_rule_pipeline.dart';

void main() {
  group('tokenizeSourceRulePipeline', () {
    test('按顶层 || 拆分 XPath 与 JS 阶段', () {
      final stages = tokenizeSourceRulePipeline(
        '//a/@href || @js: return result;',
      );

      expect(stages, hasLength(2));
      expect(stages[0].expression, '//a/@href');
      expect(stages[0].isJavaScript, isFalse);
      expect(stages[1].expression, '@js: return result;');
      expect(stages[1].isJavaScript, isTrue);
    });

    test('JSONPath 字符串中的 || 不拆分', () {
      final stages = tokenizeSourceRulePipeline(
        r'$.items[?(@.a == "x||y")].name || @js: return result;',
      );

      expect(stages, hasLength(2));
      expect(stages.first.expression, r'$.items[?(@.a == "x||y")].name');
    });

    test('括号、方括号、花括号内部的 || 不拆分', () {
      const rule = r'''fn((a || b), [c || d], {"x":"m||n"}) || tail''';
      final stages = tokenizeSourceRulePipeline(rule);

      expect(stages.map((stage) => stage.expression), <String>[
        r'''fn((a || b), [c || d], {"x":"m||n"})''',
        'tail',
      ]);
    });

    test('支持单引号、双引号及转义引号', () {
      const rule = r'''a["x\\\"||y"] || b['z\\\'||q'] || c''';
      final stages = tokenizeSourceRulePipeline(rule);

      expect(stages, hasLength(3));
      expect(stages.last.expression, 'c');
    });

    test('%@js 阶段标记为 JavaScript', () {
      final stages = tokenizeSourceRulePipeline(
        '//a/@href || %@js return result;',
      );

      expect(stages[1].isJavaScript, isTrue);
    });

    test('空白阶段被视为格式错误', () {
      expect(
        () => tokenizeSourceRulePipeline('//a ||   || //b'),
        throwsA(isA<SourceRulePipelineFormatException>()),
      );
    });

    test('未闭合引号是确定性格式错误', () {
      expect(
        () => tokenizeSourceRulePipeline(r'''$.a["unterminated || x'''),
        throwsA(isA<SourceRulePipelineFormatException>()),
      );
    });

    test('未闭合或错配括号是确定性格式错误', () {
      for (final rule in <String>[
        r'$.a[?(@.x == 1)',
        r'fn(a || b]',
        r'{a:[b})',
      ]) {
        expect(
          () => tokenizeSourceRulePipeline(rule),
          throwsA(isA<SourceRulePipelineFormatException>()),
          reason: rule,
        );
      }
    });

    test('空规则返回空阶段列表', () {
      expect(tokenizeSourceRulePipeline('   '), isEmpty);
    });
  });
}
