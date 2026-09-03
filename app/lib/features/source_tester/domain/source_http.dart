enum SourceHttpMethod { get }

final class SourceHttpRequest {
  SourceHttpRequest({
    required this.uri,
    required this.method,
    Map<String, String> headers = const {},
  }) : headers = Map.unmodifiable(Map<String, String>.of(headers));

  final Uri uri;
  final SourceHttpMethod method;
  final Map<String, String> headers;
}

final class SourceHttpResponse {
  SourceHttpResponse({
    required this.statusCode,
    required Map<String, String> headers,
    required List<int> bodyBytes,
    required this.finalUri,
    required this.duration,
  })  : headers = Map.unmodifiable(Map<String, String>.of(headers)),
        bodyBytes = List<int>.unmodifiable(List<int>.of(bodyBytes));

  final int statusCode;
  final Map<String, String> headers;
  final List<int> bodyBytes;
  final Uri finalUri;
  final Duration duration;
}

abstract interface class SourceHttpExecutor {
  Future<SourceHttpResponse> execute(SourceHttpRequest request);
}
