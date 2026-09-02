import 'dart:convert';

import 'package:source_reader/features/sources/domain/source_document.dart';
import 'package:source_reader/features/sources/domain/source_search_book_document.dart';

/// `searchBook` 编辑会话的纯 Dart 草稿。
///
/// 草稿保留创建时的领域对象，用于区分“原字段缺失”与“用户主动清空”。
/// 只有 [applyTo] 时才生成新的 [SourceDocument]，编辑过程不会修改 raw JSON。
final class SourceSearchBookDraft {
  SourceSearchBookDraft._({
    required this._original,
    required this._originalMoreKeysText,
    required this.requestInfo,
    required this.list,
    required this.bookName,
    required this.author,
    required this.cover,
    required this.desc,
    required this.cat,
    required this.status,
    required this.wordCount,
    required this.lastChapterTitle,
    required this.detailUrl,
    required this.requestParamsEncode,
    required this.responseEncode,
    required this.responseFormatType,
    required this.success,
    required this.jsParser,
    required this.moreKeysText,
  });

  factory SourceSearchBookDraft.fromDocument(
    SourceSearchBookDocument? document,
  ) {
    final action = document?.action;
    final moreKeysText = _projectMoreKeys(action?.moreKeysRaw);

    return SourceSearchBookDraft._(
      _original: document,
      _originalMoreKeysText: moreKeysText,
      requestInfo: action?.requestInfo ?? '',
      list: document?.list ?? '',
      bookName: document?.bookName ?? '',
      author: document?.author ?? '',
      cover: document?.cover ?? '',
      desc: document?.desc ?? '',
      cat: document?.cat ?? '',
      status: document?.status ?? '',
      wordCount: document?.wordCount ?? '',
      lastChapterTitle: document?.lastChapterTitle ?? '',
      detailUrl: document?.detailUrl ?? '',
      requestParamsEncode: action?.requestParamsEncode,
      responseEncode: action?.responseEncode,
      responseFormatType: action?.responseFormatType,
      success: document?.success ?? '',
      jsParser: action?.jsParser ?? '',
      moreKeysText: moreKeysText,
    );
  }

  final SourceSearchBookDocument? _original;
  final String _originalMoreKeysText;

  final String requestInfo;
  final String list;
  final String bookName;
  final String author;
  final String cover;
  final String desc;
  final String cat;
  final String status;
  final String wordCount;
  final String lastChapterTitle;
  final String detailUrl;
  final String? requestParamsEncode;
  final String? responseEncode;
  final String? responseFormatType;
  final String success;
  final String jsParser;
  final String moreKeysText;

  SourceSearchBookDraft copyWith({
    String? requestInfo,
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
    String? requestParamsEncode,
    String? responseEncode,
    String? responseFormatType,
    String? success,
    String? jsParser,
    String? moreKeysText,
  }) {
    return SourceSearchBookDraft._(
      _original: _original,
      _originalMoreKeysText: _originalMoreKeysText,
      requestInfo: requestInfo ?? this.requestInfo,
      list: list ?? this.list,
      bookName: bookName ?? this.bookName,
      author: author ?? this.author,
      cover: cover ?? this.cover,
      desc: desc ?? this.desc,
      cat: cat ?? this.cat,
      status: status ?? this.status,
      wordCount: wordCount ?? this.wordCount,
      lastChapterTitle: lastChapterTitle ?? this.lastChapterTitle,
      detailUrl: detailUrl ?? this.detailUrl,
      requestParamsEncode: requestParamsEncode ?? this.requestParamsEncode,
      responseEncode: responseEncode ?? this.responseEncode,
      responseFormatType: responseFormatType ?? this.responseFormatType,
      success: success ?? this.success,
      jsParser: jsParser ?? this.jsParser,
      moreKeysText: moreKeysText ?? this.moreKeysText,
    );
  }

  /// 结构化 `moreKeys` 被编辑后必须仍是 JSON 对象或数组。
  ///
  /// 历史 String 表达以及原字段缺失时继续按 String 兼容，不做 JSON 语义校验。
  String? get moreKeysValidationError {
    if (!_isStructuredOriginalMoreKeys || !_moreKeysChanged) return null;

    try {
      final Object? decoded = jsonDecode(moreKeysText);
      if (_isStructuredJsonValue(decoded)) return null;
    } on FormatException {
      // 统一在下方返回面向表单的稳定错误文本。
    }

    return 'moreKeys 必须是有效 JSON 对象或数组';
  }

  /// 原本没有 `searchBook` 时，只有真实填写内容才需要创建对象。
  bool get hasEditableContent {
    return requestInfo.isNotEmpty ||
        list.isNotEmpty ||
        bookName.isNotEmpty ||
        author.isNotEmpty ||
        cover.isNotEmpty ||
        desc.isNotEmpty ||
        cat.isNotEmpty ||
        status.isNotEmpty ||
        wordCount.isNotEmpty ||
        lastChapterTitle.isNotEmpty ||
        detailUrl.isNotEmpty ||
        requestParamsEncode != null ||
        responseEncode != null ||
        responseFormatType != null ||
        success.isNotEmpty ||
        jsParser.isNotEmpty ||
        moreKeysText.isNotEmpty;
  }

  /// 将当前草稿以 copy-on-write 方式合并回完整书源文档。
  SourceDocument applyTo(SourceDocument original) {
    final validationError = moreKeysValidationError;
    if (validationError != null) {
      throw FormatException(validationError);
    }

    final originalSearchBook = _original;
    if (originalSearchBook == null) {
      if (!hasEditableContent) return original;

      final created = SourceSearchBookDocument.createDefault().copyWithKnownFields(
        requestInfo: _nonEmptyOrNull(requestInfo),
        requestParamsEncode: requestParamsEncode,
        responseEncode: responseEncode,
        responseFormatType: responseFormatType,
        jsParser: _nonEmptyOrNull(jsParser),
        moreKeys: moreKeysText.isEmpty ? null : moreKeysText,
        list: _nonEmptyOrNull(list),
        bookName: _nonEmptyOrNull(bookName),
        author: _nonEmptyOrNull(author),
        cover: _nonEmptyOrNull(cover),
        desc: _nonEmptyOrNull(desc),
        cat: _nonEmptyOrNull(cat),
        status: _nonEmptyOrNull(status),
        wordCount: _nonEmptyOrNull(wordCount),
        lastChapterTitle: _nonEmptyOrNull(lastChapterTitle),
        detailUrl: _nonEmptyOrNull(detailUrl),
        success: _nonEmptyOrNull(success),
      );
      return original.copyWithSearchBook(created);
    }

    final originalAction = originalSearchBook.action;
    final updated = originalSearchBook.copyWithKnownFields(
      requestInfo: _dirtyString(requestInfo, originalAction.requestInfo),
      requestParamsEncode: _dirtyNullableString(
        requestParamsEncode,
        originalAction.requestParamsEncode,
      ),
      responseEncode: _dirtyNullableString(
        responseEncode,
        originalAction.responseEncode,
      ),
      responseFormatType: _dirtyNullableString(
        responseFormatType,
        originalAction.responseFormatType,
      ),
      jsParser: _dirtyString(jsParser, originalAction.jsParser),
      moreKeys: _moreKeysValueForWrite(),
      list: _dirtyString(list, originalSearchBook.list),
      bookName: _dirtyString(bookName, originalSearchBook.bookName),
      author: _dirtyString(author, originalSearchBook.author),
      cover: _dirtyString(cover, originalSearchBook.cover),
      desc: _dirtyString(desc, originalSearchBook.desc),
      cat: _dirtyString(cat, originalSearchBook.cat),
      status: _dirtyString(status, originalSearchBook.status),
      wordCount: _dirtyString(wordCount, originalSearchBook.wordCount),
      lastChapterTitle: _dirtyString(
        lastChapterTitle,
        originalSearchBook.lastChapterTitle,
      ),
      detailUrl: _dirtyString(detailUrl, originalSearchBook.detailUrl),
      success: _dirtyString(success, originalSearchBook.success),
    );

    return original.copyWithSearchBook(updated);
  }

  bool get _moreKeysChanged => moreKeysText != _originalMoreKeysText;

  bool get _isStructuredOriginalMoreKeys {
    final raw = _original?.action.moreKeysRaw;
    return _isStructuredJsonValue(raw);
  }

  Object? _moreKeysValueForWrite() {
    if (!_moreKeysChanged) return null;
    if (!_isStructuredOriginalMoreKeys) return moreKeysText;

    final Object? decoded = jsonDecode(moreKeysText);
    if (_isStructuredJsonValue(decoded)) return decoded;

    throw const FormatException('moreKeys 必须是有效 JSON 对象或数组');
  }

  static String _projectMoreKeys(Object? raw) {
    if (raw == null) return '';
    if (raw is String) return raw;
    return jsonEncode(raw);
  }

  static bool _isStructuredJsonValue(Object? value) {
    return value is Map<Object?, Object?> || value is List<Object?>;
  }

  static String? _dirtyString(String current, String? original) {
    return current == (original ?? '') ? null : current;
  }

  static String? _dirtyNullableString(String? current, String? original) {
    return current == original ? null : current;
  }

  static String? _nonEmptyOrNull(String value) {
    return value.isEmpty ? null : value;
  }
}
