/// 一段由 `||` 分隔的规则执行阶段。
final class SourceRulePipelineStage {
  const SourceRulePipelineStage({
    required this.expression,
    required this.isJavaScript,
  });

  final String expression;
  final bool isJavaScript;
}

final class SourceRulePipelineFormatException implements Exception {
  const SourceRulePipelineFormatException(this.message);

  final String message;

  @override
  String toString() => 'SourceRulePipelineFormatException: $message';
}

/// 只在顶层拆分 `||`，保留字符串和嵌套表达式内部的逻辑或。
List<SourceRulePipelineStage> tokenizeSourceRulePipeline(String rule) {
  if (rule.trim().isEmpty) {
    return const <SourceRulePipelineStage>[];
  }

  final expressions = <String>[];
  final buffer = StringBuffer();
  final brackets = <int>[];
  int? quote;
  var escaped = false;

  for (var index = 0; index < rule.length; index++) {
    final code = rule.codeUnitAt(index);

    if (quote != null) {
      buffer.writeCharCode(code);
      if (escaped) {
        escaped = false;
        continue;
      }
      if (code == 0x5C) {
        escaped = true;
        continue;
      }
      if (code == quote) {
        quote = null;
      }
      continue;
    }

    if (code == 0x22 || code == 0x27) {
      quote = code;
      buffer.writeCharCode(code);
      continue;
    }

    if (_isOpeningBracket(code)) {
      brackets.add(code);
      buffer.writeCharCode(code);
      continue;
    }

    if (_isClosingBracket(code)) {
      if (brackets.isEmpty || !_matches(brackets.last, code)) {
        throw SourceRulePipelineFormatException(
          '括号不匹配，位置 $index',
        );
      }
      brackets.removeLast();
      buffer.writeCharCode(code);
      continue;
    }

    final isSeparator = code == 0x7C &&
        index + 1 < rule.length &&
        rule.codeUnitAt(index + 1) == 0x7C &&
        brackets.isEmpty;
    if (isSeparator) {
      _appendExpression(expressions, buffer.toString());
      buffer.clear();
      index++;
      continue;
    }

    buffer.writeCharCode(code);
  }

  if (quote != null) {
    throw const SourceRulePipelineFormatException('字符串未闭合');
  }
  if (brackets.isNotEmpty) {
    throw const SourceRulePipelineFormatException('括号未闭合');
  }

  _appendExpression(expressions, buffer.toString());
  return List<SourceRulePipelineStage>.unmodifiable(
    expressions.map((expression) {
      final trimmed = expression.trim();
      return SourceRulePipelineStage(
        expression: trimmed,
        isJavaScript:
            trimmed.startsWith('@js:') || trimmed.startsWith('%@js'),
      );
    }),
  );
}

void _appendExpression(List<String> target, String expression) {
  if (expression.trim().isEmpty) {
    throw const SourceRulePipelineFormatException('存在空规则阶段');
  }
  target.add(expression);
}

bool _isOpeningBracket(int code) => code == 0x28 || code == 0x5B || code == 0x7B;

bool _isClosingBracket(int code) => code == 0x29 || code == 0x5D || code == 0x7D;

bool _matches(int opening, int closing) {
  return (opening == 0x28 && closing == 0x29) ||
      (opening == 0x5B && closing == 0x5D) ||
      (opening == 0x7B && closing == 0x7D);
}
