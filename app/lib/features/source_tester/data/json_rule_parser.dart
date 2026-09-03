import 'dart:convert';

import 'package:json_path/json_path.dart';
import 'package:source_reader/features/source_tester/application/source_rule_parser.dart';
import 'package:source_reader/features/source_tester/domain/source_rule_value.dart';
import 'package:source_reader/features/source_tester/domain/source_test_error.dart';

final class JsonRuleParser implements SourceRuleParser {
  @override
  SourceRuleContext createRoot(String responseText) {
    try {
      return _JsonRuleContext(jsonDecode(responseText));
    } on FormatException catch (error) {
      throw SourceTestException(
        SourceTestFailureReason.responseParseFailure,
        message: '响应不是有效 JSON',
        cause: error,
      );
    }
  }

  @override
  SourceRuleEvaluation evaluate({
    required SourceRuleContext context,
    required String expression,
  }) {
    if (context is! _JsonRuleContext) {
      throw const SourceRuleEvaluationException('JSON parser 收到不兼容的 context');
    }

    final trimmed = expression.trim();
    if (trimmed.startsWith(r'$')) {
      return _evaluateJsonPath(context, trimmed);
    }
    return _evaluateLegacyPath(context, trimmed);
  }

  SourceRuleEvaluation _evaluateJsonPath(
    _JsonRuleContext context,
    String expression,
  ) {
    try {
      final values = JsonPath(expression)
          .read(context.value)
          .map<Object?>((match) => match.value)
          .toList(growable: false);
      return _evaluationFromRaw(values, SourceRuleParserKind.jsonPath);
    } catch (error) {
      throw SourceRuleEvaluationException(
        'JSONPath 执行失败: $expression',
        cause: error,
      );
    }
  }

  SourceRuleEvaluation _evaluateLegacyPath(
    _JsonRuleContext context,
    String expression,
  ) {
    if (expression.isEmpty) {
      return _evaluationFromRaw(
        <Object?>[context.value],
        SourceRuleParserKind.jsonLegacyPath,
      );
    }

    try {
      var current = <Object?>[context.value];
      for (final segmentText in expression.split('/')) {
        if (segmentText.isEmpty) {
          throw const SourceRuleEvaluationException('legacy JSON path 包含空 segment');
        }
        final segment = _LegacySegment.parse(segmentText);
        final next = <Object?>[];
        for (final value in current) {
          final selected = segment.select(value);
          if (selected.$1) {
            next.add(selected.$2);
          }
        }
        current = next;
        if (current.isEmpty) {
          break;
        }
      }
      return _evaluationFromRaw(
        current,
        SourceRuleParserKind.jsonLegacyPath,
      );
    } on SourceRuleEvaluationException {
      rethrow;
    } catch (error) {
      throw SourceRuleEvaluationException(
        'legacy JSON path 执行失败: $expression',
        cause: error,
      );
    }
  }
}

final class _JsonRuleContext implements SourceRuleContext {
  const _JsonRuleContext(this.value);

  final Object? value;

  @override
  SourceRuleValue summarize() => _sourceValue(value);
}

final class _LegacySegment {
  const _LegacySegment({required this.key, required this.index});

  factory _LegacySegment.parse(String text) {
    final match = RegExp(r'^([^\[\]]+)?(?:\[(-?\d+)\])?$').firstMatch(text);
    if (match == null || (match.group(1) == null && match.group(2) == null)) {
      throw SourceRuleEvaluationException('非法 legacy JSON segment: $text');
    }
    return _LegacySegment(
      key: match.group(1),
      index: match.group(2) == null ? null : int.parse(match.group(2)!),
    );
  }

  final String? key;
  final int? index;

  (bool, Object?) select(Object? input) {
    Object? value = input;
    if (key != null) {
      if (value is! Map || !value.containsKey(key)) {
        return (false, null);
      }
      value = value[key];
    }

    final targetIndex = index;
    if (targetIndex == null) {
      return (true, value);
    }
    if (value is! List || targetIndex == 0) {
      return (false, null);
    }
    final zeroBased = targetIndex > 0
        ? targetIndex - 1
        : value.length + targetIndex;
    if (zeroBased < 0 || zeroBased >= value.length) {
      return (false, null);
    }
    return (true, value[zeroBased]);
  }
}

SourceRuleEvaluation _evaluationFromRaw(
  List<Object?> rawValues,
  SourceRuleParserKind kind,
) {
  final flattened = <Object?>[];
  for (final value in rawValues) {
    if (value is List) {
      flattened.addAll(value);
    } else {
      flattened.add(value);
    }
  }

  final contexts = flattened
      .map<SourceRuleContext>(_JsonRuleContext.new)
      .toList(growable: false);
  final value = switch (flattened.length) {
    0 => SourceRuleList(const <SourceRuleValue>[]),
    1 => _sourceValue(flattened.single),
    _ => SourceRuleList(flattened.map(_sourceValue).toList(growable: false)),
  };

  return SourceRuleEvaluation(
    value: value,
    contexts: contexts,
    parserKind: kind,
  );
}

SourceRuleValue _sourceValue(Object? value) {
  if (value is List) {
    return SourceRuleList(value.map(_sourceValue).toList(growable: false));
  }
  return SourceRuleScalar(value);
}
