import 'dart:convert';

import 'package:source_reader/features/source_tester/domain/source_http.dart';
import 'package:source_reader/features/source_tester/domain/source_test_error.dart';
import 'package:source_reader/features/sources/data/source_repository.dart';

/// 已完成公共 URL 解析与 Header 合并的 GET 请求。
final class BuiltSourceActionRequest {
  BuiltSourceActionRequest({
    required this.request,
    required List<String> warnings,
  }) : warnings = List<String>.unmodifiable(warnings);

  final SourceHttpRequest request;
  final List<String> warnings;
}

/// 四条主规则链共享的确定性请求构造底座。
///
/// 这里只处理 action 无关的 URL、Header 与残留占位符检查，
/// 不理解搜索关键词、页码或上一级结果等业务语义。
final class SourceActionRequestBuilder {
  const SourceActionRequestBuilder();

  BuiltSourceActionRequest build({
    required StoredSource source,
    required String resolvedRequestInfo,
    required Object? actionHttpHeaders,
    required String actionName,
  }) {
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
      actionHttpHeaders,
      warnings: warnings,
      scope: actionName,
    );

    return BuiltSourceActionRequest(
      request: SourceHttpRequest(
        uri: uri,
        method: SourceHttpMethod.get,
        headers: _mergeHeaders(globalHeaders, actionHeaders),
      ),
      warnings: warnings,
    );
  }
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
