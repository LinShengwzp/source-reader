import 'dart:convert';

import 'package:enough_convert/enough_convert.dart';
import 'package:source_reader/features/source_tester/domain/source_http.dart';
import 'package:source_reader/features/source_tester/domain/source_test_error.dart';

enum SourceResponseEncoding { utf8, gbk }

/// 已解码的响应文本及其诊断信息。
final class DecodedSourceResponse {
  DecodedSourceResponse({
    required this.text,
    required this.encoding,
    required List<String> warnings,
  }) : warnings = List<String>.unmodifiable(warnings);

  final String text;
  final SourceResponseEncoding encoding;
  final List<String> warnings;
}

/// 根据书源显式配置或响应 charset 解码原始响应字节。
final class SourceResponseDecoder {
  DecodedSourceResponse decode({
    required SourceHttpResponse response,
    required String? configuredEncoding,
  }) {
    final encoding = _selectEncoding(
      configuredEncoding: configuredEncoding,
      headers: response.headers,
    );
    final warnings = <String>[];

    final text = switch (encoding) {
      SourceResponseEncoding.utf8 => _decodeUtf8(
          response.bodyBytes,
          warnings,
        ),
      SourceResponseEncoding.gbk => gbk.decode(response.bodyBytes),
    };

    return DecodedSourceResponse(
      text: text,
      encoding: encoding,
      warnings: warnings,
    );
  }
}

SourceResponseEncoding _selectEncoding({
  required String? configuredEncoding,
  required Map<String, String> headers,
}) {
  final configured = configuredEncoding?.trim().toLowerCase();
  if (configured != null && configured.isNotEmpty) {
    return switch (configured) {
      'utf-8' || 'utf8' => SourceResponseEncoding.utf8,
      '2147485232' || '2147485234' => SourceResponseEncoding.gbk,
      _ => throw SourceTestException(
          SourceTestFailureReason.unsupportedResponseEncoding,
          message: configuredEncoding,
        ),
    };
  }

  final contentType = _headerValue(headers, 'content-type');
  final charset = contentType == null ? null : _extractCharset(contentType);
  return switch (charset?.toLowerCase()) {
    'utf-8' || 'utf8' => SourceResponseEncoding.utf8,
    'gbk' || 'gb2312' || 'gb18030' => SourceResponseEncoding.gbk,
    _ => SourceResponseEncoding.utf8,
  };
}

String _decodeUtf8(List<int> bytes, List<String> warnings) {
  try {
    return utf8.decode(bytes);
  } on FormatException {
    warnings.add('响应包含无效 UTF-8 字节，已使用替换字符解码');
    return utf8.decode(bytes, allowMalformed: true);
  }
}

String? _headerValue(Map<String, String> headers, String name) {
  final target = name.toLowerCase();
  for (final entry in headers.entries) {
    if (entry.key.toLowerCase() == target) {
      return entry.value;
    }
  }
  return null;
}

String? _extractCharset(String contentType) {
  final match = RegExp(
    r'''charset\s*=\s*["']?([^;\s"']+)''',
    caseSensitive: false,
  ).firstMatch(contentType);
  return match?.group(1);
}
