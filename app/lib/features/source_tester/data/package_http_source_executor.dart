import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:source_reader/features/source_tester/domain/source_http.dart';
import 'package:source_reader/features/source_tester/domain/source_test_error.dart';

final class PackageHttpSourceExecutor implements SourceHttpExecutor {
  PackageHttpSourceExecutor({
    http.Client? client,
    this.timeout = const Duration(seconds: 20),
    this.maxRedirects = 5,
    this.maxBodyBytes = 5 * 1024 * 1024,
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;
  final Duration timeout;
  final int maxRedirects;
  final int maxBodyBytes;

  @override
  Future<SourceHttpResponse> execute(SourceHttpRequest request) async {
    try {
      return await _execute(request).timeout(timeout);
    } on TimeoutException catch (error) {
      throw SourceTestException(
        SourceTestFailureReason.timeout,
        message: '请求超时',
        cause: error,
      );
    } on SourceTestException {
      rethrow;
    } catch (error) {
      throw SourceTestException(
        SourceTestFailureReason.transportFailure,
        message: 'HTTP 请求失败',
        cause: error,
      );
    }
  }

  Future<SourceHttpResponse> _execute(SourceHttpRequest sourceRequest) async {
    final stopwatch = Stopwatch()..start();
    final request = switch (sourceRequest.method) {
      SourceHttpMethod.get => http.Request('GET', sourceRequest.uri),
    }
      ..headers.addAll(sourceRequest.headers)
      ..followRedirects = true
      ..maxRedirects = maxRedirects;

    final response = await _client.send(request);
    final contentLength = response.contentLength;
    if (contentLength != null && contentLength > maxBodyBytes) {
      throw SourceTestException(
        SourceTestFailureReason.responseTooLarge,
        message: '响应体超过 $maxBodyBytes 字节上限',
      );
    }

    final bodyBytes = <int>[];
    await for (final chunk in response.stream) {
      if (bodyBytes.length + chunk.length > maxBodyBytes) {
        throw SourceTestException(
          SourceTestFailureReason.responseTooLarge,
          message: '响应体超过 $maxBodyBytes 字节上限',
        );
      }
      bodyBytes.addAll(chunk);
    }
    stopwatch.stop();

    final finalUri = switch (response) {
      http.BaseResponseWithUrl(:final url) => url,
      _ => sourceRequest.uri,
    };

    return SourceHttpResponse(
      statusCode: response.statusCode,
      headers: response.headers,
      bodyBytes: bodyBytes,
      finalUri: finalUri,
      duration: stopwatch.elapsed,
    );
  }

  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }
}
