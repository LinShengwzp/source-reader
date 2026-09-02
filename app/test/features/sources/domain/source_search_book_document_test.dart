import 'package:flutter_test/flutter_test.dart';
import 'package:source_reader/features/sources/domain/source_search_book_document.dart';

void main() {
  test('读取 searchBook 字段并在修改时保留元数据、未知字段和未知枚举', () {
    final search = SourceSearchBookDocument.fromRaw(<String, Object?>{
      'actionID': 'searchBook',
      'parserID': 'DOM',
      'requestInfo': '/search?q=%@keyWord',
      'list': '//div[@class="book"]',
      'bookName': './/h3/text()',
      'author': './/span/text()',
      'responseFormatType': 'future-format',
      'futureSearchField': <String, Object?>{
        'nested': <Object?>[1, 2],
      },
    });

    expect(search.action.actionId, 'searchBook');
    expect(search.action.parserId, 'DOM');
    expect(search.action.requestInfo, '/search?q=%@keyWord');
    expect(search.list, '//div[@class="book"]');
    expect(search.bookName, './/h3/text()');
    expect(search.author, './/span/text()');

    final changed = search.copyWithKnownFields(
      bookName: './/h2/text()',
      responseEncode: 'utf-8',
    );

    expect(changed.bookName, './/h2/text()');
    expect(changed.action.responseEncode, 'utf-8');
    expect(changed.action.responseFormatType, 'future-format');
    expect(changed.toRaw()['actionID'], 'searchBook');
    expect(changed.toRaw()['parserID'], 'DOM');
    expect(
      changed.toRaw()['futureSearchField'],
      search.toRaw()['futureSearchField'],
    );
  });

  test('createDefault 只创建 searchBook 必要结构元数据', () {
    expect(
      SourceSearchBookDocument.createDefault().toRaw(),
      <String, Object?>{
        'actionID': 'searchBook',
        'parserID': 'DOM',
      },
    );
  });

  test('toRaw 不暴露顶层可变引用', () {
    final input = <String, Object?>{
      'bookName': 'A',
      'futureSearchField': 'keep',
    };
    final search = SourceSearchBookDocument.fromRaw(input);

    input['bookName'] = 'B';
    expect(search.bookName, 'A');

    final exported = search.toRaw();
    exported['bookName'] = 'C';
    expect(search.bookName, 'A');
  });
}
