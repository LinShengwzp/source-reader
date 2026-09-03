import 'dart:convert';

import 'package:source_reader/features/sources/domain/source_search_book_document.dart';
import 'package:source_reader/features/source_tester/application/source_rule_parser.dart';
import 'package:source_reader/features/source_tester/application/source_rule_pipeline.dart';
import 'package:source_reader/features/source_tester/domain/source_rule_value.dart';
import 'package:source_reader/features/source_tester/domain/source_test_error.dart';
import 'package:source_reader/features/source_tester/domain/source_test_report.dart';

final class SearchBookResultParser {
  SearchBookParseResult parse({
    required SourceSearchBookDocument searchBook,
    required SourceRuleParser parser,
    required String responseText,
    required Uri finalResponseUri,
    required String? sourceUrl,
  }) {
    final listRule = searchBook.list?.trim();
    if (listRule == null || listRule.isEmpty) {
      throw const SourceTestException(
        SourceTestFailureReason.listRuleFailure,
        message: 'searchBook.list 缺失',
      );
    }

    final root = parser.createRoot(responseText);
    final listOutcome = _evaluatePipeline(
      parser: parser,
      initialContext: root,
      rule: listRule,
    );
    if (!listOutcome.executedDeclarative || listOutcome.errors.isNotEmpty) {
      throw SourceTestException(
        SourceTestFailureReason.listRuleFailure,
        message: 'searchBook.list 无法执行',
        cause: listOutcome.errors.isEmpty ? null : listOutcome.errors.join('\n'),
      );
    }

    final warnings = <String>[];
    if (listOutcome.partial) {
      warnings.addAll(listOutcome.warnings.map((warning) => 'list: $warning'));
    }

    final moreKeys = _readMoreKeys(searchBook.action.moreKeysRaw, warnings);
    final skipCount = _readSkipCount(moreKeys, warnings);
    _appendUnsupportedMoreKeysWarnings(moreKeys, warnings);

    var itemContexts = listOutcome.contexts;
    if (skipCount > 0) {
      itemContexts = skipCount >= itemContexts.length
          ? const <SourceRuleContext>[]
          : itemContexts.sublist(skipCount);
    }
    if (itemContexts.length > 500) {
      itemContexts = itemContexts.take(500).toList(growable: false);
      warnings.add('搜索结果超过 500 项，已截断为前 500 项');
    }

    final jsParser = searchBook.action.jsParser?.trim();
    if (jsParser != null && jsParser.isNotEmpty) {
      warnings.add('searchBook.JSParser 当前版本未执行');
    }

    final fieldRules = <_FieldRule>[
      _FieldRule('bookName', searchBook.bookName),
      _FieldRule('author', searchBook.author),
      _FieldRule('cover', searchBook.cover, normalizeUrl: true),
      _FieldRule('desc', searchBook.desc),
      _FieldRule('cat', searchBook.cat),
      _FieldRule('status', searchBook.status),
      _FieldRule('wordCount', searchBook.wordCount),
      _FieldRule('lastChapterTitle', searchBook.lastChapterTitle),
      _FieldRule('detailUrl', searchBook.detailUrl, normalizeUrl: true),
    ];
    final accumulators = <String, _TraceAccumulator>{
      for (final field in fieldRules)
        if (field.hasRule) field.name: _TraceAccumulator(field.name, field.rule!),
    };

    final items = <SearchBookTestItem>[];
    for (var index = 0; index < itemContexts.length; index++) {
      final context = itemContexts[index];
      final values = <String, String?>{};
      for (final field in fieldRules) {
        if (!field.hasRule) {
          values[field.name] = null;
          continue;
        }

        final outcome = _evaluatePipeline(
          parser: parser,
          initialContext: context,
          rule: field.rule!,
        );
        accumulators[field.name]!.add(outcome, itemIndex: index);

        var value = outcome.errors.isEmpty ? _firstText(outcome.value) : null;
        if (field.normalizeUrl && value != null && value.isNotEmpty) {
          value = _normalizeUrl(
            value,
            finalResponseUri: finalResponseUri,
            sourceUrl: sourceUrl,
          );
        }
        values[field.name] = value;
      }

      items.add(
        SearchBookTestItem(
          bookName: values['bookName'],
          author: values['author'],
          cover: values['cover'],
          desc: values['desc'],
          cat: values['cat'],
          status: values['status'],
          wordCount: values['wordCount'],
          lastChapterTitle: values['lastChapterTitle'],
          detailUrl: values['detailUrl'],
        ),
      );
    }

    final traces = <SourceRuleTrace>[
      SourceRuleTrace(
        field: 'list',
        rule: listRule,
        stages: listOutcome.stages,
        outputSummary: '${itemContexts.length} 个列表上下文',
        warnings: listOutcome.warnings,
        errors: listOutcome.errors,
        partial: listOutcome.partial,
      ),
      for (final field in fieldRules)
        if (accumulators[field.name] case final accumulator?)
          accumulator.toTrace(),
    ];

    return SearchBookParseResult(
      items: items,
      traces: traces,
      warnings: warnings,
    );
  }
}

final class _FieldRule {
  const _FieldRule(this.name, this.rule, {this.normalizeUrl = false});

  final String name;
  final String? rule;
  final bool normalizeUrl;

  bool get hasRule => rule != null && rule!.trim().isNotEmpty;
}

final class _PipelineOutcome {
  _PipelineOutcome({
    required this.value,
    required List<SourceRuleContext> contexts,
    required List<String> stages,
    required List<String> warnings,
    required List<String> errors,
    required this.partial,
    required this.executedDeclarative,
  })  : contexts = List<SourceRuleContext>.unmodifiable(contexts),
        stages = List<String>.unmodifiable(stages),
        warnings = List<String>.unmodifiable(warnings),
        errors = List<String>.unmodifiable(errors);

  final SourceRuleValue value;
  final List<SourceRuleContext> contexts;
  final List<String> stages;
  final List<String> warnings;
  final List<String> errors;
  final bool partial;
  final bool executedDeclarative;
}

_PipelineOutcome _evaluatePipeline({
  required SourceRuleParser parser,
  required SourceRuleContext initialContext,
  required String rule,
}) {
  List<SourceRulePipelineStage> pipeline;
  try {
    pipeline = tokenizeSourceRulePipeline(rule);
  } on SourceRulePipelineFormatException catch (error) {
    return _PipelineOutcome(
      value: SourceRuleList(const <SourceRuleValue>[]),
      contexts: const <SourceRuleContext>[],
      stages: const <String>[],
      warnings: const <String>[],
      errors: <String>[error.message],
      partial: false,
      executedDeclarative: false,
    );
  }

  var contexts = <SourceRuleContext>[initialContext];
  SourceRuleValue value = SourceRuleList(const <SourceRuleValue>[]);
  final warnings = <String>[];
  final errors = <String>[];
  var partial = false;
  var executedDeclarative = false;

  for (final stage in pipeline) {
    if (stage.isJavaScript) {
      partial = true;
      warnings.add('JS 阶段未执行: ${stage.expression}');
      break;
    }

    executedDeclarative = true;
    if (contexts.isEmpty) {
      value = SourceRuleList(const <SourceRuleValue>[]);
      break;
    }

    final nextContexts = <SourceRuleContext>[];
    final nextValues = <Object?>[];
    for (final context in contexts) {
      try {
        final evaluation = parser.evaluate(
          context: context,
          expression: stage.expression,
        );
        nextContexts.addAll(evaluation.contexts);
        nextValues.addAll(_flattenValue(evaluation.value));
      } on SourceRuleEvaluationException catch (error) {
        errors.add(error.message);
      } catch (error) {
        errors.add('规则执行失败: $error');
      }
    }

    contexts = nextContexts;
    value = _valueFromObjects(nextValues);
  }

  return _PipelineOutcome(
    value: value,
    contexts: contexts,
    stages: pipeline.map((stage) => stage.expression).toList(growable: false),
    warnings: warnings,
    errors: errors,
    partial: partial,
    executedDeclarative: executedDeclarative,
  );
}

final class _TraceAccumulator {
  _TraceAccumulator(this.field, this.rule);

  final String field;
  final String rule;
  final List<String> _stages = <String>[];
  final List<String> _outputs = <String>[];
  final List<String> _warnings = <String>[];
  final List<String> _errors = <String>[];
  var _partial = false;

  void add(_PipelineOutcome outcome, {required int itemIndex}) {
    if (_stages.isEmpty) {
      _stages.addAll(outcome.stages);
    }
    final output = _firstText(outcome.value);
    if (output != null && output.isNotEmpty && outcome.errors.isEmpty) {
      _outputs.add(output);
    }
    for (final warning in outcome.warnings) {
      _warnings.add('第 ${itemIndex + 1} 项: $warning');
    }
    for (final error in outcome.errors) {
      _errors.add('第 ${itemIndex + 1} 项: $error');
    }
    _partial = _partial || outcome.partial;
  }

  SourceRuleTrace toTrace() {
    final outputSummary = switch (_outputs.length) {
      0 => '',
      1 => _outputs.single,
      _ => '${_outputs.length} 项: ${_outputs.take(3).join(' | ')}'
          '${_outputs.length > 3 ? ' …' : ''}',
    };
    return SourceRuleTrace(
      field: field,
      rule: rule,
      stages: _stages,
      outputSummary: outputSummary,
      warnings: _warnings,
      errors: _errors,
      partial: _partial,
    );
  }
}

Map<String, Object?>? _readMoreKeys(Object? raw, List<String> warnings) {
  if (raw == null) {
    return null;
  }
  Object? decoded = raw;
  if (raw is String) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    try {
      decoded = jsonDecode(trimmed);
    } catch (_) {
      warnings.add('moreKeys 不是合法 JSON，当前版本忽略');
      return null;
    }
  }
  if (decoded is! Map) {
    warnings.add('moreKeys 不是对象，当前版本忽略');
    return null;
  }

  final result = <String, Object?>{};
  for (final entry in decoded.entries) {
    if (entry.key is String) {
      result[entry.key as String] = entry.value;
    } else {
      warnings.add('moreKeys 包含非字符串 key，已忽略');
    }
  }
  return result;
}

int _readSkipCount(Map<String, Object?>? moreKeys, List<String> warnings) {
  final raw = moreKeys?['skipCount'];
  if (raw == null) {
    return 0;
  }

  final value = _parseInteger(raw);
  if (value == null || value < 0) {
    warnings.add('moreKeys.skipCount 无效，已按 0 处理');
    return 0;
  }
  return value;
}

int? _parseInteger(Object raw) {
  if (raw is int) {
    return raw;
  }
  if (raw is num && raw.isFinite && raw == raw.roundToDouble()) {
    return raw.toInt();
  }
  if (raw is String) {
    return int.tryParse(raw.trim());
  }
  return null;
}

void _appendUnsupportedMoreKeysWarnings(
  Map<String, Object?>? moreKeys,
  List<String> warnings,
) {
  if (moreKeys == null) {
    return;
  }
  const unsupported = <String>[
    'pageSize',
    'maxPage',
    'removeHtmlKeys',
    'requestFilters',
  ];
  for (final key in unsupported) {
    if (moreKeys.containsKey(key) && moreKeys[key] != null) {
      warnings.add('moreKeys.$key 当前版本尚未应用');
    }
  }
}

String? _normalizeUrl(
  String value, {
  required Uri finalResponseUri,
  required String? sourceUrl,
}) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return trimmed;
  }
  final parsed = Uri.tryParse(trimmed);
  if (parsed != null && parsed.hasScheme) {
    return trimmed;
  }

  final finalBase = finalResponseUri.hasScheme ? finalResponseUri : null;
  final sourceBase = sourceUrl == null ? null : Uri.tryParse(sourceUrl.trim());
  final base = finalBase ?? (sourceBase?.hasScheme == true ? sourceBase : null);
  if (base == null) {
    return trimmed;
  }
  try {
    return base.resolve(trimmed).toString();
  } catch (_) {
    return trimmed;
  }
}

String? _firstText(SourceRuleValue value) {
  for (final raw in _flattenValue(value)) {
    if (raw == null) {
      continue;
    }
    if (raw is String) {
      return raw.trim();
    }
    if (raw is num || raw is bool) {
      return raw.toString();
    }
    try {
      return jsonEncode(raw);
    } catch (_) {
      return raw.toString();
    }
  }
  return null;
}

List<Object?> _flattenValue(SourceRuleValue value) {
  return switch (value) {
    SourceRuleScalar(:final value) => <Object?>[value],
    SourceRuleList(:final values) => values.expand(_flattenValue).toList(growable: false),
  };
}

SourceRuleValue _valueFromObjects(List<Object?> values) {
  return switch (values.length) {
    0 => SourceRuleList(const <SourceRuleValue>[]),
    1 => SourceRuleScalar(values.single),
    _ => SourceRuleList(
        values.map<SourceRuleValue>(SourceRuleScalar.new).toList(growable: false),
      ),
  };
}
