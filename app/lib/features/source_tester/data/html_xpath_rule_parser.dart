import 'package:source_reader/features/source_tester/application/source_rule_parser.dart';
import 'package:source_reader/features/source_tester/domain/source_rule_value.dart';
import 'package:source_reader/features/source_tester/domain/source_test_error.dart';
import 'package:xpath_selector_html_parser/xpath_selector_html_parser.dart';

final class HtmlXPathRuleParser implements SourceRuleParser {
  @override
  SourceRuleContext createRoot(String responseText) {
    try {
      final xpath = HtmlXPath.html(responseText);
      return _HtmlRuleContext(xpath.root as HtmlNodeTree);
    } catch (error) {
      throw SourceTestException(
        SourceTestFailureReason.responseParseFailure,
        message: '响应不是有效 HTML',
        cause: error,
      );
    }
  }

  @override
  SourceRuleEvaluation evaluate({
    required SourceRuleContext context,
    required String expression,
  }) {
    if (context is! _HtmlRuleContext) {
      throw const SourceRuleEvaluationException('XPath parser 收到不兼容的 context');
    }

    final trimmed = expression.trim();
    if (trimmed.isEmpty) {
      throw const SourceRuleEvaluationException('XPath 表达式不能为空');
    }

    try {
      final result = HtmlXPath(context.node).query(trimmed);
      final contexts = result.nodes
          .map<SourceRuleContext>(
            (node) => _HtmlRuleContext(HtmlNodeTree(node.node)),
          )
          .toList(growable: false);

      final rawValues = result.attrs.isNotEmpty
          ? result.attrs.cast<Object?>()
          : result.nodes.map<Object?>((node) => node.text).toList(growable: false);

      return SourceRuleEvaluation(
        value: _sourceValue(rawValues),
        contexts: contexts,
        parserKind: SourceRuleParserKind.htmlXPath,
      );
    } on SourceRuleEvaluationException {
      rethrow;
    } catch (error) {
      throw SourceRuleEvaluationException(
        'XPath 执行失败: $trimmed',
        cause: error,
      );
    }
  }
}

final class _HtmlRuleContext implements SourceRuleContext {
  const _HtmlRuleContext(this.node);

  final HtmlNodeTree node;

  @override
  SourceRuleValue summarize() => SourceRuleScalar(node.text);
}

SourceRuleValue _sourceValue(List<Object?> values) {
  return switch (values.length) {
    0 => SourceRuleList(const <SourceRuleValue>[]),
    1 => SourceRuleScalar(values.single),
    _ => SourceRuleList(
        values.map<SourceRuleValue>(SourceRuleScalar.new).toList(growable: false),
      ),
  };
}
