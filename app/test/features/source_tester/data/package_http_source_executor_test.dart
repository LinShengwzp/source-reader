import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:source_reader/features/source_tester/data/package_http_source_executor.dart';
import 'package:source_reader/features/source_tester/domain/source_http.dart';
import 'package:source_reader/features/source_tester/domain/source_test_error.dart';

void main() {
  group('PackageHttpSourceExecutor', () {
    test('映射 GET 请求并保留响应快照与最终 URI', () async {
      http.BaseRequest? capturedRequest;
      final client = _FakeClient((request) async {
        capturedRequest = request;
        return _StreamedResponseWithUrl(
          Stream<List<int>>.value(utf8.encode('ok')),
          200,
          url: Uri.parse('https://example.com/final'),
          request: request,
          headers: const <String, String>{'x-response': 'yes'},
        );
      });
      final executor = PackageHttpSourceExecutor(client: client);

      final response = await executor.execute(
        SourceHttpRequest(
          uri: Uri.parse('https://example.com/start'),
          method: SourceHttpMethod.get,
          headers: const <String, String>{'x-test': '1'},
        ),
      );

      expect(capturedRequest, isA<http.Request>());
      expect(capturedRequest!.method, 'GET');
      expect(capturedRequest!.url, Uri.parse('https://example.com/start'));
      expect(capturedRequest!.headers['x-test'], '1');
      expect(capturedRequest!.followRedirects, isTrue);
      expect(capturedRequest!.maxRedirects, 5);
      expect(response.statusCode, 200);
      expect(response.headers['x-response'], 'yes');
      expect(utf8.decode(response.bodyBytes), 'ok');
      expect(response.finalUri, Uri.parse('https://example.com/final'));
      expect(response.duration.isNegative, isFalse);
      expect(client.closed, isFalse);

      executor.close();
      expect(client.closed, isFalse);
    });

    for (final statusCode in <int>[404, 500]) {
      test('$statusCode 仍返回正常 Tester 响应', () async {
        final client = _FakeClient((request) async {
          return http.StreamedResponse(
            Stream<List<int>>.value(utf8.encode('server body')),
            statusCode,
            request: request,
          );
        });
        final executor = PackageHttpSourceExecutor(client: client);

        final response = await executor.execute(_request());

        expect(response.statusCode, statusCode);
        expect(utf8.decode(response.bodyBytes), 'server body');
        expect(response.finalUri, _request().uri);
      });
    }

    test('超时映射为 timeout', () async {
      final client = _FakeClient((_) => Completer<http.StreamedResponse>().future);
      final executor = PackageHttpSourceExecutor(
        client: client,
        timeout: const Duration(milliseconds: 1),
      );

      await expectLater(
        executor.execute(_request()),
        throwsA(_failure(SourceTestFailureReason.timeout)),
      );
    });

    test('ClientException 映射为 transportFailure 并保留 cause', () async {
      final client = _FakeClient((request) {
        throw http.ClientException('boom', request.url);
      });
      final executor = PackageHttpSourceExecutor(client: client);

      await expectLater(
        executor.execute(_request()),
        throwsA(
          isA<SourceTestException>()
              .having(
                (error) => error.reason,
                'reason',
                SourceTestFailureReason.transportFailure,
              )
              .having(
                (error) => error.cause,
                'cause',
                isA<http.ClientException>(),
              ),
        ),
      );
    });

    test('响应体超过上限时立即终止并返回 responseTooLarge', () async {
      var thirdChunkRequested = false;

      Stream<List<int>> oversizedBody() async* {
        yield <int>[1, 2, 3];
        yield <int>[4, 5, 6];
        thirdChunkRequested = true;
        yield <int>[7];
      }

      final client = _FakeClient((request) async {
        return http.StreamedResponse(
          oversizedBody(),
          200,
          request: request,
        );
      });
      final executor = PackageHttpSourceExecutor(
        client: client,
        maxBodyBytes: 5,
      );

      await expectLater(
        executor.execute(_request()),
        throwsA(_failure(SourceTestFailureReason.responseTooLarge)),
      );
      expect(thirdChunkRequested, isFalse);
    });

    test('自定义 redirect 上限写入 http.Request', () async {
      http.BaseRequest? capturedRequest;
      final client = _FakeClient((request) async {
        capturedRequest = request;
        return http.StreamedResponse(
          const Stream<List<int>>.empty(),
          204,
          request: request,
        );
      });
      final executor = PackageHttpSourceExecutor(
        client: client,
        maxRedirects: 3,
      );

      await executor.execute(_request());

      expect(capturedRequest!.followRedirects, isTrue);
      expect(capturedRequest!.maxRedirects, 3);
    });
  });
}

SourceHttpRequest _request() => SourceHttpRequest(
      uri: Uri.parse('https://example.com/search'),
      method: SourceHttpMethod.get,
      headers: const <String, String>{'accept': 'text/plain'},
    );

Matcher _failure(SourceTestFailureReason reason) => isA<SourceTestException>().having(
      (error) => error.reason,
      'reason',
      reason,
    );

final class _FakeClient extends http.BaseClient {
  _FakeClient(this._handler);

  final Future<http.StreamedResponse> Function(http.BaseRequest request) _handler;
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) => _handler(request);

  @override
  void close() {
    closed = true;
  }
}

final class _StreamedResponseWithUrl extends http.StreamedResponse
    implements http.BaseResponseWithUrl {
  _StreamedResponseWithUrl(
    super.stream,
    super.statusCode, {
    required this.url,
    super.request,
    super.headers,
  });

  @override
  final Uri url;
}
