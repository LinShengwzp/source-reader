import 'package:source_reader/features/sources/domain/source_search_book_document.dart';

/// 书源文档的领域边界。
///
/// raw JSON 是唯一事实来源。这里只为当前已知字段提供类型化访问，
/// 未知字段会在复制和导出时保留，避免新版编辑器破坏未来或扩展字段。
final class SourceDocument {
  SourceDocument._(this._raw);

  factory SourceDocument.fromRaw(Map<String, Object?> raw) {
    return SourceDocument._(Map<String, Object?>.from(raw));
  }

  final Map<String, Object?> _raw;

  String? get sourceName => _stringValue('sourceName');

  String? get sourceUrl => _stringValue('sourceUrl');

  String? get sourceType => _stringValue('sourceType');

  SourceSearchBookDocument? get searchBook {
    final value = _raw['searchBook'];
    if (value is! Map) {
      return null;
    }

    final converted = <String, Object?>{};
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is! String) {
        return null;
      }
      converted[key] = entry.value;
    }
    return SourceSearchBookDocument.fromRaw(converted);
  }

  bool get enabled {
    final value = _raw['enable'];
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == '1' || normalized == 'true';
    }
    return false;
  }

  int get weight {
    final value = _raw['weight'];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value.trim()) ?? 0;
    }
    return 0;
  }

  /// 返回顶层 Map 的副本，避免调用方直接改写文档内部状态。
  Map<String, Object?> toRaw() => Map<String, Object?>.from(_raw);

  /// 只更新明确提供的已知字段，其余 raw 字段原样保留。
  SourceDocument copyWithKnownFields({
    String? sourceName,
    String? sourceUrl,
    bool? enabled,
    int? weight,
  }) {
    final raw = toRaw();

    if (sourceName != null) {
      raw['sourceName'] = sourceName;
    }
    if (sourceUrl != null) {
      raw['sourceUrl'] = sourceUrl;
    }
    if (enabled != null) {
      raw['enable'] = _encodeEnabled(enabled, raw['enable']);
    }
    if (weight != null) {
      raw['weight'] = _encodeWeight(weight, raw['weight']);
    }

    return SourceDocument.fromRaw(raw);
  }

  /// 只替换 `searchBook` 子对象，不修改其他顶层 raw 字段。
  SourceDocument copyWithSearchBook(SourceSearchBookDocument searchBook) {
    final raw = toRaw();
    raw['searchBook'] = searchBook.toRaw();
    return SourceDocument.fromRaw(raw);
  }

  String? _stringValue(String key) {
    final value = _raw[key];
    return value is String ? value : null;
  }

  static Object _encodeEnabled(bool value, Object? currentValue) {
    if (currentValue is String) {
      return value ? '1' : '0';
    }
    if (currentValue is bool) {
      return value;
    }
    return value ? 1 : 0;
  }

  static Object _encodeWeight(int value, Object? currentValue) {
    return currentValue is String ? value.toString() : value;
  }
}
