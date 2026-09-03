import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:source_reader/features/source_tester/application/search_book_request_builder.dart';
import 'package:source_reader/features/source_tester/application/search_book_result_parser.dart';
import 'package:source_reader/features/source_tester/application/search_book_test_runner.dart';
import 'package:source_reader/features/source_tester/application/source_action_request_builder.dart';
import 'package:source_reader/features/source_tester/application/source_response_decoder.dart';
import 'package:source_reader/features/source_tester/application/source_rule_parser.dart';
import 'package:source_reader/features/source_tester/data/html_xpath_rule_parser.dart';
import 'package:source_reader/features/source_tester/data/json_rule_parser.dart';
import 'package:source_reader/features/source_tester/data/package_http_source_executor.dart';
import 'package:source_reader/features/source_tester/domain/source_http.dart';
import 'package:source_reader/features/sources/application/source_providers.dart';

/// Source Tester 的 HTTP 执行边界。默认实现由 provider 管理其内部客户端生命周期。
final sourceHttpExecutorProvider = Provider<SourceHttpExecutor>((ref) {
  final executor = PackageHttpSourceExecutor();
  ref.onDispose(executor.close);
  return executor;
});

final sourceActionRequestBuilderProvider = Provider<SourceActionRequestBuilder>((ref) {
  return const SourceActionRequestBuilder();
});

final searchBookRequestBuilderProvider = Provider<SearchBookRequestBuilder>((ref) {
  return SearchBookRequestBuilder(
    actionBuilder: ref.watch(sourceActionRequestBuilderProvider),
  );
});

final sourceResponseDecoderProvider = Provider<SourceResponseDecoder>((ref) {
  return SourceResponseDecoder();
});

final sourceHtmlParserProvider = Provider<SourceRuleParser>((ref) {
  return HtmlXPathRuleParser();
});

final sourceJsonParserProvider = Provider<SourceRuleParser>((ref) {
  return JsonRuleParser();
});

final searchBookResultParserProvider = Provider<SearchBookResultParser>((ref) {
  return SearchBookResultParser();
});

/// 每次运行仍由 Runner 通过现有 Repository 重新读取已持久化书源。
final searchBookTestRunnerProvider = Provider<SearchBookTestRunner>((ref) {
  return SearchBookTestRunner(
    repository: ref.watch(sourceRepositoryProvider),
    requestBuilder: ref.watch(searchBookRequestBuilderProvider),
    httpExecutor: ref.watch(sourceHttpExecutorProvider),
    responseDecoder: ref.watch(sourceResponseDecoderProvider),
    htmlParser: ref.watch(sourceHtmlParserProvider),
    jsonParser: ref.watch(sourceJsonParserProvider),
    resultParser: ref.watch(searchBookResultParserProvider),
  );
});
