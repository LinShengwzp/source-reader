import 'dart:convert';
import 'dart:typed_data';

import 'package:source_reader/features/sources/codec/source_json_codec.dart';
import 'package:source_reader/features/sources/codec/xbs_codec.dart';
import 'package:source_reader/features/sources/data/source_repository.dart';
import 'package:source_reader/features/sources/domain/source_document.dart';

/// 文件选择层与书源解析层之间的最小数据载体。
final class SourceImportPayload {
  const SourceImportPayload({
    required this.name,
    required this.bytes,
  });

  final String name;
  final Uint8List bytes;
}

/// 一次书源导入的成功结果。
final class SourceImportResult {
  const SourceImportResult({required this.importedCount});

  final int importedCount;
}

/// 将 JSON/XBS 文件内容转换为书源，并通过 Repository 原子写入。
///
/// 本服务不负责文件选择、UI 状态或数据库细节。第一阶段只接受香色闺阁
/// `StandarReader` 平台，后续新增平台时再在 importer 外层扩展选择策略。
final class SourceImportService {
  SourceImportService(this._repository);

  static const String _platform = 'StandarReader';

  final SourceRepository _repository;

  Future<SourceImportResult> importPayload(SourceImportPayload payload) async {
    final plainBytes = _decodeFileBytes(payload);
    var jsonText = utf8.decode(plainBytes);
    if (jsonText.startsWith('\ufeff')) {
      jsonText = jsonText.substring(1);
    }

    final documents = decodeSourceJson(jsonText);
    if (documents.isEmpty) {
      throw const FormatException('书源文件不能为空');
    }

    _validateDocuments(documents);

    await _repository.insertSources(
      platform: _platform,
      documents: documents,
    );

    return SourceImportResult(importedCount: documents.length);
  }

  Uint8List _decodeFileBytes(SourceImportPayload payload) {
    final name = payload.name.toLowerCase();
    if (name.endsWith('.json')) {
      return payload.bytes;
    }
    if (name.endsWith('.xbs')) {
      return decodeXbs(payload.bytes);
    }
    throw FormatException('不支持的书源文件类型: ${payload.name}');
  }

  void _validateDocuments(List<SourceDocument> documents) {
    for (var index = 0; index < documents.length; index++) {
      final name = documents[index].sourceName;
      if (name == null || name.trim().isEmpty) {
        throw FormatException('第 ${index + 1} 个书源缺少有效 sourceName');
      }
    }
  }
}
