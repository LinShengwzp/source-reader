import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:source_reader/features/sources/domain/source_document.dart';
import 'package:source_reader/features/sources/presentation/source_search_book_draft.dart';

void main() {
  test('从现有 searchBook 映射全部编辑字段并保留未知枚举值', () {
    final source = SourceDocument.fromRaw(<String, Object?>{
      'searchBook': <String, Object?>{
        'actionID': 'searchBook',
        'parserID': 'DOM',
        'requestInfo': '/search?q=%@keyWord',
        'requestParamsEncode': 'future-request-encode',
        'responseEncode': 'gbk',
        'responseFormatType': 'future-format',
        'list': '//div[@class="book"]',
        'bookName': './/h3/text()',
        'author': './/span/text()',
        'cover': './/img/@src',
        'desc': './/p/text()',
        'cat': './/i/text()',
        'status': './/b/text()',
        'wordCount': './/em/text()',
        'lastChapterTitle': './/a/text()',
        'detailUrl': './/a/@href',
        'success': 'true',
        'JSParser': 'return result;',
        'moreKeys': <String, Object?>{
          'pageSize': 20,
          'removeHtmlKeys': <Object?>['bookName'],
        },
      },
    });

    final draft = SourceSearchBookDraft.fromDocument(source.searchBook);

    expect(draft.requestInfo, '/search?q=%@keyWord');
    expect(draft.requestParamsEncode, 'future-request-encode');
    expect(draft.responseEncode, 'gbk');
    expect(draft.responseFormatType, 'future-format');
    expect(draft.list, '//div[@class="book"]');
    expect(draft.bookName, './/h3/text()');
    expect(draft.author, './/span/text()');
    expect(draft.cover, './/img/@src');
    expect(draft.desc, './/p/text()');
    expect(draft.cat, './/i/text()');
    expect(draft.status, './/b/text()');
    expect(draft.wordCount, './/em/text()');
    expect(draft.lastChapterTitle, './/a/text()');
    expect(draft.detailUrl, './/a/@href');
    expect(draft.success, 'true');
    expect(draft.jsParser, 'return result;');
    expect(
      draft.moreKeysText,
      jsonEncode(<String, Object?>{
        'pageSize': 20,
        'removeHtmlKeys': <Object?>['bookName'],
      }),
    );
  });

  test('缺失 searchBook 的空白 draft 不创建对象', () {
    final source = SourceDocument.fromRaw(<String, Object?>{
      'sourceName': 'A',
      'futureTop': true,
    });

    final draft = SourceSearchBookDraft.fromDocument(source.searchBook);

    expect(draft.requestInfo, '');
    expect(draft.bookName, '');
    expect(draft.requestParamsEncode, isNull);
    expect(draft.responseEncode, isNull);
    expect(draft.responseFormatType, isNull);
    expect(draft.moreKeysText, '');
    expect(draft.hasEditableContent, isFalse);
    expect(draft.applyTo(source).toRaw(), source.toRaw());
  });

  test('缺失 searchBook 只有真正编辑后才创建必要元数据与 dirty 字段', () {
    final source = SourceDocument.fromRaw(<String, Object?>{
      'sourceName': 'A',
      'futureTop': <String, Object?>{'keep': true},
    });
    final draft = SourceSearchBookDraft.fromDocument(source.searchBook).copyWith(
      requestInfo: '/search?q=%@keyWord',
      bookName: './/h3/text()',
    );

    final changed = draft.applyTo(source);
    final raw = changed.searchBook!.toRaw();

    expect(raw['actionID'], 'searchBook');
    expect(raw['parserID'], 'DOM');
    expect(raw['requestInfo'], '/search?q=%@keyWord');
    expect(raw['bookName'], './/h3/text()');
    expect(raw.containsKey('author'), isFalse);
    expect(raw.containsKey('cover'), isFalse);
    expect(raw.containsKey('responseFormatType'), isFalse);
    expect(changed.toRaw()['futureTop'], <String, Object?>{'keep': true});
  });

  test('已有仅元数据 searchBook 在未编辑保存时仍完整保留', () {
    final source = SourceDocument.fromRaw(<String, Object?>{
      'sourceName': 'A',
      'searchBook': <String, Object?>{
        'actionID': 'searchBook',
        'parserID': 'DOM',
      },
    });

    final draft = SourceSearchBookDraft.fromDocument(source.searchBook);

    expect(draft.hasEditableContent, isFalse);
    expect(draft.applyTo(source).toRaw(), source.toRaw());
  });

  test('未修改字段保持缺失，主动清空已有字符串字段只写回该字段', () {
    final source = SourceDocument.fromRaw(<String, Object?>{
      'searchBook': <String, Object?>{
        'actionID': 'searchBook',
        'parserID': 'DOM',
        'bookName': './/h3/text()',
        'futureSearchField': <String, Object?>{'keep': true},
      },
    });
    final draft = SourceSearchBookDraft.fromDocument(source.searchBook);

    expect(draft.applyTo(source).toRaw(), source.toRaw());

    final changed = draft.copyWith(bookName: '').applyTo(source);
    final raw = changed.searchBook!.toRaw();
    expect(raw['bookName'], '');
    expect(raw.containsKey('author'), isFalse);
    expect(raw.containsKey('cover'), isFalse);
    expect(raw.containsKey('requestInfo'), isFalse);
    expect(raw['futureSearchField'], <String, Object?>{'keep': true});
  });

  test('未知 enum 未修改时原样保留，主动选择已知值后才替换', () {
    final source = SourceDocument.fromRaw(<String, Object?>{
      'searchBook': <String, Object?>{
        'actionID': 'searchBook',
        'parserID': 'DOM',
        'responseFormatType': 'future-format',
      },
    });
    final draft = SourceSearchBookDraft.fromDocument(source.searchBook);

    expect(draft.responseFormatType, 'future-format');
    expect(draft.applyTo(source).searchBook!.action.responseFormatType, 'future-format');

    final changed = draft
        .copyWith(responseFormatType: 'str')
        .applyTo(source);
    expect(changed.searchBook!.action.responseFormatType, 'str');
  });

  test('结构化 moreKeys 未修改时保留原 Map 类型和值', () {
    final rawMoreKeys = <String, Object?>{
      'pageSize': 20,
      'removeHtmlKeys': <Object?>['bookName'],
    };
    final source = SourceDocument.fromRaw(<String, Object?>{
      'searchBook': <String, Object?>{
        'actionID': 'searchBook',
        'parserID': 'DOM',
        'moreKeys': rawMoreKeys,
      },
    });
    final draft = SourceSearchBookDraft.fromDocument(source.searchBook);

    final unchanged = draft.applyTo(source);

    expect(unchanged.searchBook!.action.moreKeysRaw, rawMoreKeys);
    expect(
      unchanged.searchBook!.action.moreKeysRaw,
      isA<Map<String, Object?>>(),
    );
  });

  test('结构化 moreKeys 修改后解析回结构值，非法 JSON 拒绝 apply', () {
    final source = SourceDocument.fromRaw(<String, Object?>{
      'searchBook': <String, Object?>{
        'actionID': 'searchBook',
        'parserID': 'DOM',
        'moreKeys': <String, Object?>{'pageSize': 20},
      },
    });
    final draft = SourceSearchBookDraft.fromDocument(source.searchBook);

    final changed = draft.copyWith(
      moreKeysText: '{"pageSize":30,"maxPage":2}',
    );
    expect(changed.moreKeysValidationError, isNull);
    expect(
      changed.applyTo(source).searchBook!.action.moreKeysRaw,
      <String, Object?>{'pageSize': 30, 'maxPage': 2},
    );

    final invalid = draft.copyWith(moreKeysText: '{bad json');
    expect(invalid.moreKeysValidationError, 'moreKeys 必须是有效 JSON 对象或数组');
    expect(() => invalid.applyTo(source), throwsFormatException);
  });

  test('历史字符串 moreKeys 修改后继续按字符串写回且不做 JSON 校验', () {
    final source = SourceDocument.fromRaw(<String, Object?>{
      'searchBook': <String, Object?>{
        'actionID': 'searchBook',
        'parserID': 'DOM',
        'moreKeys': 'legacy text',
      },
    });
    final draft = SourceSearchBookDraft.fromDocument(source.searchBook).copyWith(
      moreKeysText: '{bad json',
    );

    expect(draft.moreKeysValidationError, isNull);
    expect(draft.applyTo(source).searchBook!.action.moreKeysRaw, '{bad json');
  });

  test('原字段不存在时新填写 moreKeys 即使像 JSON 也按 String 写回', () {
    final source = SourceDocument.fromRaw(<String, Object?>{'sourceName': 'A'});
    final draft = SourceSearchBookDraft.fromDocument(source.searchBook).copyWith(
      moreKeysText: '{"pageSize":30}',
    );

    final raw = draft.applyTo(source).searchBook!.action.moreKeysRaw;
    expect(raw, '{"pageSize":30}');
    expect(raw, isA<String>());
  });
}
