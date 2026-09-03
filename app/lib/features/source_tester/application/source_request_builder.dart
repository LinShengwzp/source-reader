import 'dart:convert';

import 'package:enough_convert/enough_convert.dart';
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

/// 已完成模板替换、URL 解析和 header 合并的 GET 请求。
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

/// 将持久化书源中的 `searchBook` 请求配置转换为 A1 可执行 GET 请求。
final class SourceRequestBuilder {
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

    final unknownPlaceholder = RegExp(
      r'%@[A-Za-z_][A-Za-z0-9_]*',
    ).firstMatch(resolvedRequestInfo);
    if (unknownPlaceholder != null) {
      throw SourceTestException(
        SourceTestFailureReason.unknownPlaceholder,
        message: unknownPlaceholder.group(0),
      );
    }

    final uri = _resolveRequestUri(
      resolvedRequestInfo,
      source.document.sourceUrl,
    );

    final warnings = <String>[];
    final globalHeaders = _parseHeaders(
      source.document.toRaw()['httpHeaders'],
      warnings: warnings,
      scope: 'global',
    );
    final actionHeaders = _parseHeaders(
      searchBook.toRaw()['httpHeaders'],
      warnings: warnings,
      scope: 'searchBook',
    );
    final headers = _mergeHeaders(globalHeaders, actionHeaders);

    return BuiltSearchBookRequest(
      originalRequestInfo: originalRequestInfo,
      request: SourceHttpRequest(
        uri: uri,
        method: SourceHttpMethod.get,
        headers: headers,
      ),
      warnings: warnings,
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

Uri _resolveRequestUri(String requestInfo, String? sourceUrl) {
  final requestUri = Uri.tryParse(requestInfo);
  if (requestUri == null) {
    throw const SourceTestException(SourceTestFailureReason.invalidBaseUrl);
  }

  if (requestUri.hasScheme) {
    if (_isHttpUri(requestUri)) {
      return requestUri;
    }
    throw SourceTestException(
      SourceTestFailureReason.invalidBaseUrl,
      message: requestInfo,
    );
  }

  final baseUri = sourceUrl == null ? null : Uri.tryParse(sourceUrl.trim());
  if (baseUri == null || !_isHttpUri(baseUri)) {
    throw SourceTestException(
      SourceTestFailureReason.invalidBaseUrl,
      message: sourceUrl,
    );
  }

  return baseUri.resolveUri(requestUri);
}

bool _isHttpUri(Uri uri) {
  final scheme = uri.scheme.toLowerCase();
  return (scheme == 'http' || scheme == 'https') && uri.host.isNotEmpty;
}

Map<String, String> _parseHeaders(
  Object? raw, {
  required List<String> warnings,
  required String scope,
}) {
  if (raw == null) {
    return const <String, String>{};
  }

  Object? decoded = raw;
  if (raw is String) {
    if (raw.trim().isEmpty) {
      return const <String, String>{};
    }
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (error) {
      throw SourceTestException(
        SourceTestFailureReason.invalidHeaders,
        message: '$scope httpHeaders is not valid JSON',
        cause: error,
      );
    }
  }

  if (decoded is! Map) {
    throw SourceTestException(
      SourceTestFailureReason.invalidHeaders,
      message: '$scope httpHeaders must be an object',
    );
  }

  final result = <String, String>{};
  for (final entry in decoded.entries) {
    final key = entry.key;
    final value = entry.value;
    if (key is! String || key.trim().isEmpty) {
      warnings.add('Skipped invalid $scope httpHeaders key');
      continue;
    }
    if (value is String || value is num || value is bool) {
      result[key] = value.toString();
      continue;
    }
    warnings.add('Skipped invalid $scope httpHeaders entry: $key');
  }
  return result;
}

Map<String, String> _mergeHeaders(
  Map<String, String> global,
  Map<String, String> action,
) {
  final merged = <String, String>{};
  final actualKeyByLower = <String, String>{};

  void addAll(Map<String, String> source) {
    for (final entry in source.entries) {
      final lower = entry.key.toLowerCase();
      final previousKey = actualKeyByLower[lower];
      if (previousKey != null) {
        merged.remove(previousKey);
      }
      merged[entry.key] = entry.value;
      actualKeyByLower[lower] = entry.key;
    }
  }

  addAll(global);
  addAll(action);
  return merged;
}
