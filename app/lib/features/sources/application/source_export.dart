import 'dart:convert';
import 'dart:typed_data';

import 'package:source_reader/features/sources/codec/source_json_codec.dart';
import 'package:source_reader/features/sources/codec/xbs_codec.dart';
import 'package:source_reader/features/sources/data/source_repository.dart';

const String _standarReaderPlatform = 'StandarReader';

enum SourceExportFormat { json, xbs }

enum SourceExportScope { current, all }

enum SourceExportFailureReason {
  notFound,
  unsupportedPlatform,
  empty,
  encodingFailed,
}

final class SourceExportException implements Exception {
  const SourceExportException(this.reason, {this.cause});

  final SourceExportFailureReason reason;
  final Object? cause;

  @override
  String toString() => cause == null
      ? 'SourceExportException($reason)'
      : 'SourceExportException($reason, cause: $cause)';
}

final class SourceExportPayload {
  const SourceExportPayload({
    required this.fileName,
    required this.bytes,
    required this.mimeType,
    required this.exportedCount,
  });

  final String fileName;
  final Uint8List bytes;
  final String mimeType;
  final int exportedCount;
}

/// 将书源名转换为适合作为跨平台默认文件名的基础名称。
String sanitizeSourceFileBaseName(String input) {
  final invalidFileNameChars = RegExp(r'[\\/:*?"<>|]');
  final replaced = input.replaceAll(invalidFileNameChars, '_');
  final withoutControlChars = String.fromCharCodes(
    replaced.codeUnits.map(
      (codeUnit) => codeUnit <= 0x1f || codeUnit == 0x7f ? 0x5f : codeUnit,
    ),
  );
  final withoutTrailing = withoutControlChars.replaceFirst(
    RegExp(r'[ .]+$'),
    '',
  );
  return withoutTrailing.isEmpty ? 'source' : withoutTrailing;
}

/// 根据 Repository 中已经成功持久化的书源构建导出文件内容。
final class SourceExportService {
  SourceExportService(this._repository);

  final SourceRepository _repository;

  Future<SourceExportPayload> buildCurrent({
    required int id,
    required SourceExportFormat format,
  }) async {
    final source = await _repository.getSource(id);
    if (source == null) {
      throw const SourceExportException(SourceExportFailureReason.notFound);
    }
    if (source.platform != _standarReaderPlatform) {
      throw const SourceExportException(
        SourceExportFailureReason.unsupportedPlatform,
      );
    }

    return _buildPayload(
      sources: <StoredSource>[source],
      format: format,
      baseName: sanitizeSourceFileBaseName(source.document.sourceName ?? ''),
    );
  }

  Future<SourceExportPayload> buildAll({
    required SourceExportFormat format,
  }) async {
    final sources = (await _repository.listSources())
        .where((source) => source.platform == _standarReaderPlatform)
        .toList(growable: false);
    if (sources.isEmpty) {
      throw const SourceExportException(SourceExportFailureReason.empty);
    }

    return _buildPayload(
      sources: sources,
      format: format,
      baseName: 'source-reader-export',
    );
  }

  SourceExportPayload _buildPayload({
    required List<StoredSource> sources,
    required SourceExportFormat format,
    required String baseName,
  }) {
    try {
      final jsonText = encodeSourceJson(
        sources.map((source) => source.document),
      );
      final jsonBytes = Uint8List.fromList(utf8.encode(jsonText));

      return switch (format) {
        SourceExportFormat.json => SourceExportPayload(
            fileName: '$baseName.json',
            bytes: jsonBytes,
            mimeType: 'application/json',
            exportedCount: sources.length,
          ),
        SourceExportFormat.xbs => SourceExportPayload(
            fileName: '$baseName.xbs',
            bytes: encodeXbs(jsonBytes),
            mimeType: 'application/octet-stream',
            exportedCount: sources.length,
          ),
      };
    } catch (error) {
      throw SourceExportException(
        SourceExportFailureReason.encodingFailed,
        cause: error,
      );
    }
  }
}
