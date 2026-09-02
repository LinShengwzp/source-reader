import 'dart:convert';

import 'package:source_reader/features/sources/domain/source_document.dart';

/// 将单个书源对象或书源对象数组解码为统一的文档列表。
List<SourceDocument> decodeSourceJson(String text) {
  final Object? decoded = jsonDecode(text);

  if (decoded is Map<String, Object?>) {
    return <SourceDocument>[SourceDocument.fromRaw(decoded)];
  }

  if (decoded is List<Object?>) {
    final sources = <SourceDocument>[];
    for (final item in decoded) {
      if (item is! Map<String, Object?>) {
        throw const FormatException('JSON 数组中的每一项都必须是对象');
      }
      sources.add(SourceDocument.fromRaw(item));
    }
    return sources;
  }

  throw const FormatException('书源 JSON 顶层必须是对象或对象数组');
}

/// 统一以 JSON 数组形式导出，便于单个与批量书源共用同一条导出链路。
String encodeSourceJson(Iterable<SourceDocument> sources) {
  final rawSources = sources
      .map((source) => source.toRaw())
      .toList(growable: false);
  return jsonEncode(rawSources);
}
