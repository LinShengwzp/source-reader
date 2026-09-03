import 'package:source_reader/features/source_tester/domain/source_rule_value.dart';

enum SourceRuleParserKind { htmlXPath, jsonLegacyPath, jsonPath }

final class SourceRuleEvaluation {
  SourceRuleEvaluation({
    required this.value,
    required List<SourceRuleContext> contexts,
    required this.parserKind,
  }) : contexts = List<SourceRuleContext>.unmodifiable(contexts);

  final SourceRuleValue value;
  final List<SourceRuleContext> contexts;
  final SourceRuleParserKind parserKind;
}

final class SourceRuleEvaluationException implements Exception {
  const SourceRuleEvaluationException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'SourceRuleEvaluationException: $message';
}

/// 第三方解析器不得越过此接口进入 application/presentation。
abstract interface class SourceRuleParser {
  SourceRuleContext createRoot(String responseText);

  SourceRuleEvaluation evaluate({
    required SourceRuleContext context,
    required String expression,
  });
}
