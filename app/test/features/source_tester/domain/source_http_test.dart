import 'package:flutter_test/flutter_test.dart';
import 'package:source_reader/features/source_tester/domain/source_http.dart';

void main() {
  group('SourceHttpRequest', () {
    test('构造时保存 uri/method/headers', () {
      final uri = Uri.parse('https://example.com/search?q=a');
      final req = SourceHttpRequest(
        uri: uri,
        method: SourceHttpMethod.get,
        headers: {'Accept': 'text/html'},
      );
      expect(req.uri, uri);
      expect(req.method, SourceHttpMethod.get);
      expect(req.headers, {'Accept': 'text/html'});
    });

    test('headers 防御性拷贝不可变', () {
      final headers = {'A': '1'};
      final req = SourceHttpRequest(
        uri: Uri.parse('https://example.com'),
        method: SourceHttpMethod.get,
        headers: headers,
      );
      headers['B'] = '2';
      expect(req.headers.containsKey('B'), isFalse);
      expect(() => req.headers['X'] = 'y', throwsUnsupportedError);
    });
  });

  group('SourceHttpResponse', () {
    test('构造时保存所有字段', () {
      final uri = Uri.parse('https://example.com/final');
      final resp = SourceHttpResponse(
        statusCode: 200,
        headers: {'Content-Type': 'text/html'},
        bodyBytes: [1, 2, 3],
        finalUri: uri,
        duration: const Duration(milliseconds: 100),
      );
      expect(resp.statusCode, 200);
      expect(resp.headers, {'Content-Type': 'text/html'});
      expect(resp.bodyBytes, [1, 2, 3]);
      expect(resp.finalUri, uri);
      expect(resp.duration, const Duration(milliseconds: 100));
    });

    test('headers/body 防御性拷贝不可变', () {
      final headers = {'A': '1'};
      final body = [1, 2];
      final resp = SourceHttpResponse(
        statusCode: 200,
        headers: headers,
        bodyBytes: body,
        finalUri: Uri.parse('https://example.com'),
        duration: Duration.zero,
      );
      headers['B'] = '2';
      body.add(3);
      expect(resp.headers.containsKey('B'), isFalse);
      expect(resp.bodyBytes, [1, 2]);
      expect(() => resp.headers['X'] = 'y', throwsUnsupportedError);
      expect(() => resp.bodyBytes.add(9), throwsUnsupportedError);
    });
  });
}
