import 'package:source_reader/features/sources/domain/source_action_document.dart';

/// `searchBook` 规则的领域边界。
///
/// 只为当前已知的搜索规则提供类型化访问；未知字段与历史字段继续保留在 raw JSON 中。
final class SourceSearchBookDocument {
  SourceSearchBookDocument._(this._raw);

  factory SourceSearchBookDocument.fromRaw(Map<String, Object?> raw) {
    return SourceSearchBookDocument._(Map<String, Object?>.from(raw));
  }

  factory SourceSearchBookDocument.createDefault() {
    return SourceSearchBookDocument.fromRaw(<String, Object?>{
      'actionID': 'searchBook',
      'parserID': 'DOM',
    });
  }

  final Map<String, Object?> _raw;

  SourceActionDocument get action => SourceActionDocument.fromRaw(_raw);

  String? get list => _stringValue('list');

  String? get bookName => _stringValue('bookName');

  String? get author => _stringValue('author');

  String? get cover => _stringValue('cover');

  String? get desc => _stringValue('desc');

  String? get cat => _stringValue('cat');

  String? get status => _stringValue('status');

  String? get wordCount => _stringValue('wordCount');

  String? get lastChapterTitle => _stringValue('lastChapterTitle');

  String? get detailUrl => _stringValue('detailUrl');

  String? get success => _stringValue('success');

  Map<String, Object?> toRaw() => Map<String, Object?>.from(_raw);

  SourceSearchBookDocument copyWithKnownFields({
    String? requestInfo,
    String? requestParamsEncode,
    String? responseEncode,
    String? responseFormatType,
    String? jsParser,
    Object? moreKeys,
    String? list,
    String? bookName,
    String? author,
    String? cover,
    String? desc,
    String? cat,
    String? status,
    String? wordCount,
    String? lastChapterTitle,
    String? detailUrl,
    String? success,
  }) {
    final common = action.copyWithKnownFields(
      requestInfo: requestInfo,
      requestParamsEncode: requestParamsEncode,
      responseEncode: responseEncode,
      responseFormatType: responseFormatType,
      jsParser: jsParser,
      moreKeys: moreKeys,
    );
    final raw = common.toRaw();

    if (list != null) raw['list'] = list;
    if (bookName != null) raw['bookName'] = bookName;
    if (author != null) raw['author'] = author;
    if (cover != null) raw['cover'] = cover;
    if (desc != null) raw['desc'] = desc;
    if (cat != null) raw['cat'] = cat;
    if (status != null) raw['status'] = status;
    if (wordCount != null) raw['wordCount'] = wordCount;
    if (lastChapterTitle != null) raw['lastChapterTitle'] = lastChapterTitle;
    if (detailUrl != null) raw['detailUrl'] = detailUrl;
    if (success != null) raw['success'] = success;

    return SourceSearchBookDocument.fromRaw(raw);
  }

  String? _stringValue(String key) {
    final value = _raw[key];
    return value is String ? value : null;
  }
}
