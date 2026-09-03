import 'package:source_reader/features/sources/domain/source_action_document.dart';

/// `bookDetail` 规则的领域边界。
///
/// raw JSON 仍是唯一事实来源。这里只为当前已知的详情字段提供类型化访问，
/// 未知历史字段或扩展字段继续原样保留。
final class SourceBookDetailDocument {
  SourceBookDetailDocument._(this._raw);

  factory SourceBookDetailDocument.fromRaw(Map<String, Object?> raw) {
    return SourceBookDetailDocument._(Map<String, Object?>.from(raw));
  }

  final Map<String, Object?> _raw;

  SourceActionDocument get action => SourceActionDocument.fromRaw(_raw);

  String? get cover => _stringValue('cover');

  String? get desc => _stringValue('desc');

  String? get cat => _stringValue('cat');

  String? get status => _stringValue('status');

  String? get wordCount => _stringValue('wordCount');

  String? get lastChapterTitle => _stringValue('lastChapterTitle');

  /// 返回顶层 Map 的副本，避免调用方直接修改内部状态。
  Map<String, Object?> toRaw() => Map<String, Object?>.from(_raw);

  String? _stringValue(String key) {
    final value = _raw[key];
    return value is String ? value : null;
  }
}
