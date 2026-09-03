import 'package:source_reader/features/source_tester/domain/source_http.dart';

final class SearchBookTestItem {
  const SearchBookTestItem({
    this.bookName,
    this.author,
    this.cover,
    this.desc,
    this.cat,
    this.status,
    this.wordCount,
    this.lastChapterTitle,
    this.detailUrl,
  });

  final String? bookName;
  final String? author;
  final String? cover;
  final String? desc;
  final String? cat;
  final String? status;
  final String? wordCount;
  final String? lastChapterTitle;
  final String? detailUrl;
}

final class SourceRuleTrace {
  SourceRuleTrace({
    required this.field,
    required this.rule,
    required List<String> stages,
    required this.outputSummary,
    required List<String> warnings,
    required List<String> errors,
    required this.partial,
  })  : stages = List<String>.unmodifiable(stages),
        warnings = List<String>.unmodifiable(warnings),
        errors = List<String>.unmodifiable(errors);

  final String field;
  final String rule;
  final List<String> stages;
  final String outputSummary;
  final List<String> warnings;
  final List<String> errors;
  final bool partial;
}

final class SearchBookParseResult {
  SearchBookParseResult({
    required List<SearchBookTestItem> items,
    required List<SourceRuleTrace> traces,
    required List<String> warnings,
  })  : items = List<SearchBookTestItem>.unmodifiable(items),
        traces = List<SourceRuleTrace>.unmodifiable(traces),
        warnings = List<String>.unmodifiable(warnings);

  final List<SearchBookTestItem> items;
  final List<SourceRuleTrace> traces;
  final List<String> warnings;
}

enum SearchBookTestOutcome { success, completedWithWarnings }

final class SearchBookTestInputSnapshot {
  const SearchBookTestInputSnapshot({
    required this.keyWord,
    required this.pageIndex,
    required this.offset,
    required this.filter,
  });

  final String keyWord;
  final int pageIndex;
  final int offset;
  final String filter;
}

final class SourceTestRequestSnapshot {
  SourceTestRequestSnapshot({
    required this.originalRequestInfo,
    required this.uri,
    required this.method,
    required Map<String, String> headers,
  }) : headers = Map<String, String>.unmodifiable(headers);

  final String originalRequestInfo;
  final Uri uri;
  final SourceHttpMethod method;
  final Map<String, String> headers;
}

final class SourceTestResponseSnapshot {
  SourceTestResponseSnapshot({
    required this.statusCode,
    required this.finalUri,
    required Map<String, String> headers,
    required this.duration,
    required this.byteCount,
    required this.encoding,
    required this.decodedBody,
  }) : headers = Map<String, String>.unmodifiable(headers);

  final int statusCode;
  final Uri finalUri;
  final Map<String, String> headers;
  final Duration duration;
  final int byteCount;
  final String encoding;
  final String decodedBody;
}

/// 一次 `searchBook` 测试的完整、不可持久化诊断快照。
final class SearchBookTestReport {
  SearchBookTestReport({
    required this.sourceId,
    required this.sourceName,
    required this.platform,
    required this.input,
    required this.request,
    required this.response,
    required List<SearchBookTestItem> items,
    required List<SourceRuleTrace> traces,
    required List<String> warnings,
    required this.outcome,
  })  : items = List<SearchBookTestItem>.unmodifiable(items),
        traces = List<SourceRuleTrace>.unmodifiable(traces),
        warnings = List<String>.unmodifiable(warnings);

  final int sourceId;
  final String? sourceName;
  final String platform;
  final SearchBookTestInputSnapshot input;
  final SourceTestRequestSnapshot request;
  final SourceTestResponseSnapshot response;
  final List<SearchBookTestItem> items;
  final List<SourceRuleTrace> traces;
  final List<String> warnings;
  final SearchBookTestOutcome outcome;
}
