import 'package:flutter_test/flutter_test.dart';
import 'package:source_reader/features/sources/domain/source_document.dart';

void main() {
  test('修改已知字段时保留未知字段', () {
    final source = SourceDocument.fromRaw(<String, Object?>{
      'sourceName': '旧名称',
      'sourceUrl': 'https://example.com',
      'enable': 1,
      'weight': 5,
      'futureExtension': <String, Object?>{'mode': 'x'},
    });

    final changed = source.copyWithKnownFields(sourceName: '新名称');
    final raw = changed.toRaw();

    expect(raw['sourceName'], '新名称');
    expect(raw['futureExtension'], <String, Object?>{'mode': 'x'});
  });

  test('兼容历史 enable 与 weight 表达', () {
    expect(SourceDocument.fromRaw(<String, Object?>{'enable': 1}).enabled, isTrue);
    expect(SourceDocument.fromRaw(<String, Object?>{'enable': 0}).enabled, isFalse);
    expect(SourceDocument.fromRaw(<String, Object?>{'enable': true}).enabled, isTrue);
    expect(SourceDocument.fromRaw(<String, Object?>{'enable': '0'}).enabled, isFalse);
    expect(SourceDocument.fromRaw(<String, Object?>{'enable': '1'}).enabled, isTrue);
    expect(SourceDocument.fromRaw(<String, Object?>{'weight': '12'}).weight, 12);
    expect(SourceDocument.fromRaw(<String, Object?>{'weight': 7}).weight, 7);
    expect(SourceDocument.fromRaw(<String, Object?>{'weight': null}).weight, 0);
  });

  test('不暴露顶层 raw Map 的可变引用', () {
    final input = <String, Object?>{'sourceName': 'A'};
    final source = SourceDocument.fromRaw(input);

    input['sourceName'] = 'B';
    expect(source.sourceName, 'A');

    final exported = source.toRaw();
    exported['sourceName'] = 'C';
    expect(source.sourceName, 'A');
  });

  test('sourceType 只读取字符串字段', () {
    expect(
      SourceDocument.fromRaw(<String, Object?>{'sourceType': 'text'}).sourceType,
      'text',
    );
    expect(
      SourceDocument.fromRaw(<String, Object?>{'sourceType': 1}).sourceType,
      isNull,
    );
    expect(SourceDocument.fromRaw(<String, Object?>{}).sourceType, isNull);
  });

  test('searchBook 使用 typed facade 且替换时保留其他顶层 raw 字段', () {
    final source = SourceDocument.fromRaw(<String, Object?>{
      'sourceName': 'A',
      'futureTop': <String, Object?>{'keep': true},
      'searchBook': <String, Object?>{
        'actionID': 'searchBook',
        'parserID': 'DOM',
        'bookName': './/h3/text()',
        'futureSearchField': 'keep-nested',
      },
    });

    expect(source.searchBook?.bookName, './/h3/text()');

    final changedSearch = source.searchBook!.copyWithKnownFields(
      bookName: './/h2/text()',
    );
    final replaced = source.copyWithSearchBook(changedSearch);

    expect(replaced.searchBook?.bookName, './/h2/text()');
    expect(replaced.toRaw()['futureTop'], <String, Object?>{'keep': true});
    expect(
      replaced.searchBook?.toRaw()['futureSearchField'],
      'keep-nested',
    );
  });

  test('searchBook 非 Map 或包含非字符串 key 时 getter 返回 null 且 raw 原值保留', () {
    final malformed = SourceDocument.fromRaw(<String, Object?>{
      'searchBook': 'legacy-invalid-value',
    });
    expect(malformed.searchBook, isNull);
    expect(malformed.toRaw()['searchBook'], 'legacy-invalid-value');

    final nonStringKey = SourceDocument.fromRaw(<String, Object?>{
      'searchBook': <Object?, Object?>{
        'actionID': 'searchBook',
        1: 'invalid-key',
      },
    });
    expect(nonStringKey.searchBook, isNull);
    expect(nonStringKey.toRaw()['searchBook'], isA<Map<Object?, Object?>>());
  });

  test('bookDetail 使用 typed facade 且非法 raw 原值保持不变', () {
    final valid = SourceDocument.fromRaw(<String, Object?>{
      'bookDetail': <String, Object?>{
        'actionID': 'bookDetail',
        'cover': '//img/@src',
        'futureDetailField': 'keep',
      },
    });
    expect(valid.bookDetail?.cover, '//img/@src');
    expect(valid.bookDetail?.toRaw()['futureDetailField'], 'keep');

    final malformed = SourceDocument.fromRaw(<String, Object?>{
      'bookDetail': 'legacy-invalid-value',
    });
    expect(malformed.bookDetail, isNull);
    expect(malformed.toRaw()['bookDetail'], 'legacy-invalid-value');

    final nonStringKey = SourceDocument.fromRaw(<String, Object?>{
      'bookDetail': <Object?, Object?>{
        'actionID': 'bookDetail',
        1: 'invalid-key',
      },
    });
    expect(nonStringKey.bookDetail, isNull);
    expect(nonStringKey.toRaw()['bookDetail'], isA<Map<Object?, Object?>>());
  });
}
