import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:source_reader/features/source_tester/application/search_book_request_builder.dart';
import 'package:source_reader/features/source_tester/application/search_book_result_parser.dart';
import 'package:source_reader/features/source_tester/application/source_action_request_builder.dart';
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
  test('runner provider 使用现有 Repository 与拆分后的请求边界', () {
    final repository = _ProviderRepository();
    final executor = _ProviderExecutor();
    final actionBuilder = const SourceActionRequestBuilder();
    final searchBuilder = SearchBookRequestBuilder(actionBuilder: actionBuilder);
    final decoder = SourceResponseDecoder();
    final htmlParser = HtmlXPathRuleParser();
    final jsonParser = JsonRuleParser();
    final resultParser = SearchBookResultParser();

    final container = ProviderContainer(
      overrides: [
        sourceRepositoryProvider.overrideWithValue(repository),
        sourceHttpExecutorProvider.overrideWithValue(executor),
        sourceActionRequestBuilderProvider.overrideWithValue(actionBuilder),
        searchBookRequestBuilderProvider.overrideWithValue(searchBuilder),
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
    expect(runner.requestBuilder, same(searchBuilder));
    expect(runner.responseDecoder, same(decoder));
    expect(runner.htmlParser, same(htmlParser));
    expect(runner.jsonParser, same(jsonParser));
    expect(runner.resultParser, same(resultParser));
  });

  test('默认 provider 暴露 action 与 Search 两层请求边界', () {
    final container = ProviderContainer(
      overrides: [
        sourceRepositoryProvider.overrideWithValue(_ProviderRepository()),
        sourceHttpExecutorProvider.overrideWithValue(_ProviderExecutor()),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(sourceActionRequestBuilderProvider),
      isA<SourceActionRequestBuilder>(),
    );
    expect(
      container.read(searchBookRequestBuilderProvider),
      isA<SearchBookRequestBuilder>(),
    );
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
