import 'package:source_reader/features/source_tester/application/search_book_result_parser.dart';
import 'package:source_reader/features/source_tester/application/source_request_builder.dart';
import 'package:source_reader/features/source_tester/application/source_response_decoder.dart';
import 'package:source_reader/features/source_tester/application/source_rule_parser.dart';
import 'package:source_reader/features/source_tester/domain/source_http.dart';
import 'package:source_reader/features/source_tester/domain/source_test_error.dart';
import 'package:source_reader/features/source_tester/domain/source_test_report.dart';
import 'package:source_reader/features/sources/data/source_repository.dart';

/// 串联一次基于已持久化书源的 `searchBook` 测试。
final class SearchBookTestRunner {
  const SearchBookTestRunner({
    required SourceRepository repository,
    required SourceRequestBuilder requestBuilder,
    required SourceHttpExecutor httpExecutor,
    required SourceResponseDecoder responseDecoder,
    required SourceRuleParser htmlParser,
    required SourceRuleParser jsonParser,
    required SearchBookResultParser resultParser,
  })  : _repository = repository,
        _requestBuilder = requestBuilder,
        _httpExecutor = httpExecutor,
        _responseDecoder = responseDecoder,
        _htmlParser = htmlParser,
        _jsonParser = jsonParser,
        _resultParser = resultParser;

  final SourceRepository _repository;
  final SourceRequestBuilder _requestBuilder;
  final SourceHttpExecutor _httpExecutor;
  final SourceResponseDecoder _responseDecoder;
  final SourceRuleParser _htmlParser;
  final SourceRuleParser _jsonParser;
  final SearchBookResultParser _resultParser;

  Future<SearchBookTestReport> run({
    required int sourceId,
    required SearchBookTestInput input,
  }) async {
    final source = await _repository.getSource(sourceId);
    if (source == null) {
      throw const SourceTestException(SourceTestFailureReason.sourceNotFound);
    }
    if (source.platform != 'StandarReader') {
      throw SourceTestException(
        SourceTestFailureReason.unsupportedPlatform,
        message: source.platform,
      );
    }

    final searchBook = source.document.searchBook;
    if (searchBook == null) {
      throw const SourceTestException(SourceTestFailureReason.searchBookMissing);
    }

    final builtRequest = _requestBuilder.build(source: source, input: input);
    final response = await _httpExecutor.execute(builtRequest.request);
    final decoded = _responseDecoder.decode(
      response: response,
      configuredEncoding: searchBook.action.responseEncode,
    );
    final parser = switch (searchBook.action.responseFormatType?.trim()) {
      'html' => _htmlParser,
      'json' => _jsonParser,
      final unsupported => throw SourceTestException(
          SourceTestFailureReason.unsupportedResponseFormat,
          message: unsupported,
        ),
    };

    final parsed = _resultParser.parse(
      searchBook: searchBook,
      parser: parser,
      responseText: decoded.text,
      finalResponseUri: response.finalUri,
      sourceUrl: source.document.sourceUrl,
    );

    final warnings = <String>[
      ...builtRequest.warnings,
      ...decoded.warnings,
      ...parsed.warnings,
    ];
    if (response.statusCode < 200 || response.statusCode >= 300) {
      warnings.add('HTTP 状态码 ${response.statusCode}');
    }

    final hasTraceDiagnostics = parsed.traces.any(
      (trace) => trace.partial || trace.warnings.isNotEmpty || trace.errors.isNotEmpty,
    );
    final outcome = warnings.isEmpty && !hasTraceDiagnostics
        ? SearchBookTestOutcome.success
        : SearchBookTestOutcome.completedWithWarnings;

    return SearchBookTestReport(
      sourceId: source.id,
      sourceName: source.document.sourceName,
      platform: source.platform,
      input: SearchBookTestInputSnapshot(
        keyWord: input.keyWord,
        pageIndex: input.pageIndex,
        offset: input.offset,
        filter: input.filter,
      ),
      request: SourceTestRequestSnapshot(
        originalRequestInfo: builtRequest.originalRequestInfo,
        uri: builtRequest.request.uri,
        method: builtRequest.request.method,
        headers: builtRequest.request.headers,
      ),
      response: SourceTestResponseSnapshot(
        statusCode: response.statusCode,
        finalUri: response.finalUri,
        headers: response.headers,
        duration: response.duration,
        byteCount: response.bodyBytes.length,
        encoding: decoded.encoding.name,
        decodedBody: decoded.text,
      ),
      items: parsed.items,
      traces: parsed.traces,
      warnings: warnings,
      outcome: outcome,
    );
  }
}
