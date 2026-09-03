import 'dart:convert';

import 'package:enough_convert/enough_convert.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:source_reader/features/source_tester/application/source_response_decoder.dart';
import 'package:source_reader/features/source_tester/domain/source_http.dart';
import 'package:source_reader/features/source_tester/domain/source_test_error.dart';

void main() {
  group('SourceResponseDecoder', () {
    final decoder = SourceResponseDecoder();

    test('显式 utf-8 解码优先于响应 charset', () {
      final result = decoder.decode(
        response: _response(
          utf8.encode('三体'),
          headers: {'content-type': 'text/plain; charset=gbk'},
        ),
        configuredEncoding: 'utf-8',
      );

      expect(result.text, '三体');
      expect(result.encoding, SourceResponseEncoding.utf8);
      expect(result.warnings, isEmpty);
    });

    test('显式 GB2312 历史值使用 GBK 兼容解码', () {
      final result = decoder.decode(
        response: _response(gbk.encode('中文')),
        configuredEncoding: '2147485232',
      );

      expect(result.text, '中文');
      expect(result.encoding, SourceResponseEncoding.gbk);
    });

    test('显式 GBK 历史值使用 GBK 解码', () {
      final result = decoder.decode(
        response: _response(gbk.encode('三体')),
        configuredEncoding: '2147485234',
      );

      expect(result.text, '三体');
      expect(result.encoding, SourceResponseEncoding.gbk);
    });

    test('未知显式编码返回 unsupportedResponseEncoding', () {
      expect(
        () => decoder.decode(
          response: _response(utf8.encode('x')),
          configuredEncoding: 'big5',
        ),
        throwsA(
          isA<SourceTestException>().having(
            (error) => error.reason,
            'reason',
            SourceTestFailureReason.unsupportedResponseEncoding,
          ),
        ),
      );
    });

    test('无显式配置时从 Content-Type 识别 UTF-8', () {
      final result = decoder.decode(
        response: _response(
          utf8.encode('中文'),
          headers: {'Content-Type': 'text/html; Charset="UTF-8"'},
        ),
        configuredEncoding: null,
      );

      expect(result.text, '中文');
      expect(result.encoding, SourceResponseEncoding.utf8);
    });

    test('无显式配置时从 Content-Type 识别 GBK', () {
      final result = decoder.decode(
        response: _response(
          gbk.encode('中文'),
          headers: {'CONTENT-TYPE': 'text/html; charset=gbk'},
        ),
        configuredEncoding: null,
      );

      expect(result.text, '中文');
      expect(result.encoding, SourceResponseEncoding.gbk);
    });

    test('GB2312 charset 走 GBK 兼容解码', () {
      final result = decoder.decode(
        response: _response(
          gbk.encode('中文'),
          headers: {'content-type': 'text/html; charset=GB2312'},
        ),
        configuredEncoding: null,
      );

      expect(result.text, '中文');
      expect(result.encoding, SourceResponseEncoding.gbk);
    });

    test('未知或缺失 charset 默认 UTF-8', () {
      for (final headers in <Map<String, String>>[
        const {},
        const {'content-type': 'text/plain'},
        const {'content-type': 'text/plain; charset=big5'},
      ]) {
        final result = decoder.decode(
          response: _response(utf8.encode('ok'), headers: headers),
          configuredEncoding: null,
        );
        expect(result.text, 'ok');
        expect(result.encoding, SourceResponseEncoding.utf8);
      }
    });

    test('坏 UTF-8 使用 replacement character 并记录 warning', () {
      final result = decoder.decode(
        response: _response(<int>[0x61, 0xFF, 0x62]),
        configuredEncoding: 'utf-8',
      );

      expect(result.text, 'a\uFFFDb');
      expect(result.warnings, isNotEmpty);
    });

    test('结果 warnings 为不可修改副本', () {
      final result = decoder.decode(
        response: _response(<int>[0xFF]),
        configuredEncoding: 'utf-8',
      );
      expect(() => result.warnings.add('x'), throwsUnsupportedError);
    });
  });
}

SourceHttpResponse _response(
  List<int> bodyBytes, {
  Map<String, String> headers = const {},
}) {
  return SourceHttpResponse(
    statusCode: 200,
    headers: headers,
    bodyBytes: bodyBytes,
    finalUri: Uri.parse('https://example.com/search'),
    duration: const Duration(milliseconds: 10),
  );
}
