/// 四条主规则链共享的 action 领域边界。
///
/// raw JSON 仍是唯一事实来源；这里只为共同已知字段提供类型化访问，
/// copy 时只修改显式提供的字段，其余历史或未来字段原样保留。
final class SourceActionDocument {
  SourceActionDocument._(this._raw);

  factory SourceActionDocument.fromRaw(Map<String, Object?> raw) {
    return SourceActionDocument._(Map<String, Object?>.from(raw));
  }

  final Map<String, Object?> _raw;

  String? get actionId => _stringValue('actionID');

  String? get parserId => _stringValue('parserID');

  String? get requestInfo => _stringValue('requestInfo');

  String? get requestParamsEncode => _stringValue('requestParamsEncode');

  String? get responseEncode => _stringValue('responseEncode');

  String? get responseFormatType => _stringValue('responseFormatType');

  String? get jsParser => _stringValue('JSParser');

  Object? get moreKeysRaw => _raw['moreKeys'];

  /// 返回顶层 Map 副本，避免调用方直接修改内部状态。
  Map<String, Object?> toRaw() => Map<String, Object?>.from(_raw);

  SourceActionDocument copyWithKnownFields({
    String? requestInfo,
    String? requestParamsEncode,
    String? responseEncode,
    String? responseFormatType,
    String? jsParser,
    Object? moreKeys,
  }) {
    final raw = toRaw();

    if (requestInfo != null) {
      raw['requestInfo'] = requestInfo;
    }
    if (requestParamsEncode != null) {
      raw['requestParamsEncode'] = requestParamsEncode;
    }
    if (responseEncode != null) {
      raw['responseEncode'] = responseEncode;
    }
    if (responseFormatType != null) {
      raw['responseFormatType'] = responseFormatType;
    }
    if (jsParser != null) {
      raw['JSParser'] = jsParser;
    }
    if (moreKeys != null) {
      raw['moreKeys'] = moreKeys;
    }

    return SourceActionDocument.fromRaw(raw);
  }

  String? _stringValue(String key) {
    final value = _raw[key];
    return value is String ? value : null;
  }
}
