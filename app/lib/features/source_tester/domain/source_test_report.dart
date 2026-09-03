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
