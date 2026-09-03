import 'dart:convert';

import 'package:enough_convert/enough_convert.dart';
import 'package:source_reader/features/source_tester/application/source_action_request_builder.dart';
import 'package:source_reader/features/source_tester/domain/source_http.dart';
import 'package:source_reader/features/source_tester/domain/source_test_error.dart';
import 'package:source_reader/features/sources/data/source_repository.dart';

/// 搜索测试的运行参数。
final class SearchBookTestInput {
  const SearchBookTestInput({
    required this.keyWord,
    this.pageIndex = 1,
    this.offset = 0,
    this.filter = '',
  });

  final String keyWord;
  final int pageIndex;
  final int offset;
  final String filter;
}

/// 已完成搜索占位符替换与公共请求构造的 GET 请求。
final class BuiltSearchBookRequest {
  BuiltSearchBookRequest({
    required this.originalRequestInfo,
    required this.request,
    required List<String> warnings,
  }) : warnings = List<String>.unmodifiable(warnings);

  final String originalRequestInfo;
  final SourceHttpRequest request;
  final List<String> warnings;
}

/// 将持久化书源中的 `searchBook` 请求配置转换为可执行 GET 请求。
///
/// 搜索专属占位符和参数编码停留在这一层，URL/Header 等公共行为交给
/// [SourceActionRequestBuilder]，从而为后续详情、目录和正文链复用底座。
final class SearchBookRequestBuilder {
  const SearchBookRequestBuilder({required this.actionBuilder});

  final SourceActionRequestBuilder actionBuilder;

  BuiltSearchBookRequest build({
    required StoredSource source,
    required SearchBookTestInput input,
  }) {
    final searchBook = source.document.searchBook;
    if (searchBook == null) {
      throw const SourceTestException(SourceTestFailureReason.searchBookMissing);
    }

    final originalRequestInfo = searchBook.action.requestInfo;
    if (originalRequestInfo == null || originalRequestInfo.trim().isEmpty) {
      throw const SourceTestException(SourceTestFailureReason.requestInfoMissing);
    }

    final template = originalRequestInfo.trim();
    if (template.startsWith('@js:') || template.contains('%@js')) {
      throw const SourceTestException(
        SourceTestFailureReason.unsupportedScriptRequest,
      );
    }

    final encoding = _requestEncoding(searchBook.action.requestParamsEncode);
    final resolvedRequestInfo = template
        .replaceAll('%@keyWord', _encodeParameter(input.keyWord, encoding))
        .replaceAll('%@filter', _encodeParameter(input.filter, encoding))
        .replaceAll('%@pageIndex', input.pageIndex.toString())
        .replaceAll('%@offset', input.offset.toString());

    final built = actionBuilder.build(
      source: source,
      resolvedRequestInfo: resolvedRequestInfo,
      actionHttpHeaders: searchBook.toRaw()['httpHeaders'],
      actionName: 'searchBook',
    );

    return BuiltSearchBookRequest(
      originalRequestInfo: originalRequestInfo,
      request: built.request,
      warnings: built.warnings,
    );
  }
}

enum _RequestEncoding { utf8, gbk }

_RequestEncoding _requestEncoding(String? value) {
  final normalized = value?.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty || normalized == 'utf-8') {
    return _RequestEncoding.utf8;
  }
  if (normalized == '2147485234') {
    return _RequestEncoding.gbk;
  }
  throw SourceTestException(
    SourceTestFailureReason.unsupportedRequestEncoding,
    message: value,
  );
}

String _encodeParameter(String value, _RequestEncoding encoding) {
  final bytes = switch (encoding) {
    _RequestEncoding.utf8 => utf8.encode(value),
    _RequestEncoding.gbk => gbk.encode(value),
  };
  final buffer = StringBuffer();
  for (final byte in bytes) {
    if (_isUnreserved(byte)) {
      buffer.writeCharCode(byte);
    } else {
      buffer
        ..write('%')
        ..write(byte.toRadixString(16).toUpperCase().padLeft(2, '0'));
    }
  }
  return buffer.toString();
}

bool _isUnreserved(int byte) {
  return (byte >= 0x41 && byte <= 0x5A) ||
      (byte >= 0x61 && byte <= 0x7A) ||
      (byte >= 0x30 && byte <= 0x39) ||
      byte == 0x2D ||
      byte == 0x2E ||
      byte == 0x5F ||
      byte == 0x7E;
}
