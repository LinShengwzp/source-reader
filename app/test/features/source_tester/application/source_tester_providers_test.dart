import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:source_reader/features/source_tester/application/search_book_result_parser.dart';
import 'package:source_reader/features/source_tester/application/source_request_builder.dart';
import 'package:source_reader/features/source_tester/application/source_response_decoder.dart';
import 'package:source_reader/features/source_tester/application/source_rule_parser.dart';
import 'package:source_reader/features/source_tester/application/source_tester_providers.dart';
import 'package:source_reader/features/source_tester/data/html_xpath_rule_parser.dart';
import 'package:source_reader/features/source_tester/data/json_rule_parser.dart';
import 'package:source_reader/features/source_tester/domain/source_http.dart';
import 'package:source_reader/features/sources/application/source_providers.dart';
import 'package:source_reader/features/sources/data/source_repository.dart';
import 'package:source_reader/features/sources/domain/source_document.dart';

void main() {
  test('runner provider 使用现有 sourceRepositoryProvider 与全部 Tester 依赖 provider', () {
    final repository = _ProviderRepository();
    final executor = _ProviderExecutor();
    final requestBuilder = SourceRequestBuilder();
    final decoder = SourceResponseDecoder();
    final htmlParser = HtmlXPathRuleParser();
    final jsonParser = JsonRuleParser();
    final resultParser = SearchBookResultParser();

    final container = ProviderContainer(
      overrides: <Override>[
        sourceRepositoryProvider.overrideWithValue(repository),
        sourceHttpExecutorProvider.overrideWithValue(executor),
        sourceRequestBuilderProvider.overrideWithValue(requestBuilder),
        sourceResponseDecoderProvider.overrideWithValue(decoder),
        sourceHtmlParserProvider.overrideWithValue(htmlParser),
        sourceJsonParserProvider.overrideWithValue(jsonParser),
        searchBookResultParserProvider.overrideWithValue(resultParser),
      ],
    );
    addTearDown(container.dispose);

    final runner = container.read(searchBookTestRunnerProvider);

    expect(runner.repository, same(repository));
    expect(runner.httpExecutor, same(executor));
    expect(runner.requestBuilder, same(requestBuilder));
    expect(runner.responseDecoder, same(decoder));
    expect(runner.htmlParser, same(htmlParser));
    expect(runner.jsonParser, same(jsonParser));
    expect(runner.resultParser, same(resultParser));
  });

  test('默认 provider 暴露明确的 request/decoder/parser/result 边界', () {
    final container = ProviderContainer(
      overrides: <Override>[
        sourceRepositoryProvider.overrideWithValue(_ProviderRepository()),
        sourceHttpExecutorProvider.overrideWithValue(_ProviderExecutor()),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(sourceRequestBuilderProvider), isA<SourceRequestBuilder>());
    expect(container.read(sourceResponseDecoderProvider), isA<SourceResponseDecoder>());
    expect(container.read(sourceHtmlParserProvider), isA<SourceRuleParser>());
    expect(container.read(sourceJsonParserProvider), isA<SourceRuleParser>());
    expect(container.read(searchBookResultParserProvider), isA<SearchBookResultParser>());
    expect(container.read(searchBookTestRunnerProvider).repository, isA<SourceRepository>());
  });
}

final class _ProviderExecutor implements SourceHttpExecutor {
  @override
  Future<SourceHttpResponse> execute(SourceHttpRequest request) => throw UnimplementedError();
}

final class _ProviderRepository implements SourceRepository {
  @override
  Future<StoredSource?> getSource(int id) => throw UnimplementedError();

  @override
  Future<List<StoredSource>> listSources() => throw UnimplementedError();

  @override
  Future<int> insertSource({required String platform, required SourceDocument document}) =>
      throw UnimplementedError();

  @override
  Future<List<int>> insertSources({
    required String platform,
    required List<SourceDocument> documents,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> updateSource(int id, SourceDocument document) => throw UnimplementedError();

  @override
  Future<void> deleteSource(int id) => throw UnimplementedError();
}
