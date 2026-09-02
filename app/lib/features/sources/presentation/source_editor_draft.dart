import 'package:source_reader/features/sources/domain/source_document.dart';

/// SourceEditor 的临时表单草稿。
///
/// 草稿只保存当前四个基础字段；写回时必须基于原始 SourceDocument，
/// 由 copyWithKnownFields 保留未知 raw JSON 字段与历史字段表达类型。
final class SourceEditorDraft {
  const SourceEditorDraft({
    required this.sourceName,
    required this.sourceUrl,
    required this.enabled,
    required this.weight,
  });

  factory SourceEditorDraft.fromDocument(SourceDocument document) {
    return SourceEditorDraft(
      sourceName: document.sourceName ?? '',
      sourceUrl: document.sourceUrl ?? '',
      enabled: document.enabled,
      weight: document.weight.toString(),
    );
  }

  final String sourceName;
  final String sourceUrl;
  final bool enabled;
  final String weight;

  SourceDocument applyTo(SourceDocument original) {
    return original.copyWithKnownFields(
      sourceName: sourceName.trim(),
      sourceUrl: sourceUrl.trim(),
      enabled: enabled,
      weight: int.parse(weight.trim()),
    );
  }
}
