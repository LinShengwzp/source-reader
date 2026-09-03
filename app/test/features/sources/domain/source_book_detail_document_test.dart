import 'package:flutter_test/flutter_test.dart';
import 'package:source_reader/features/sources/domain/source_book_detail_document.dart';

void main() {
  test('bookDetail 暴露已知字段并保留未知 raw 字段', () {
    final detail = SourceBookDetailDocument.fromRaw(<String, Object?>{
      'actionID': 'bookDetail',
      'parserID': 'DOM',
      'requestInfo': '/book/%@result',
      'cover': '//img/@src',
      'desc': '//div[@id="desc"]/text()',
      'cat': '//span[@class="cat"]/text()',
      'status': '//span[@class="status"]/text()',
      'wordCount': '//span[@class="words"]/text()',
      'lastChapterTitle': '//a[@class="latest"]/text()',
      'futureField': <String, Object?>{'keep': true},
    });

    expect(detail.action.actionId, 'bookDetail');
    expect(detail.action.requestInfo, '/book/%@result');
    expect(detail.cover, '//img/@src');
    expect(detail.desc, '//div[@id="desc"]/text()');
    expect(detail.cat, '//span[@class="cat"]/text()');
    expect(detail.status, '//span[@class="status"]/text()');
    expect(detail.wordCount, '//span[@class="words"]/text()');
    expect(detail.lastChapterTitle, '//a[@class="latest"]/text()');
    expect(detail.toRaw()['futureField'], <String, Object?>{'keep': true});
  });

  test('toRaw 不暴露顶层 Map 的可变引用', () {
    final input = <String, Object?>{
      'cover': '//img/@src',
      'futureField': 'keep',
    };
    final detail = SourceBookDetailDocument.fromRaw(input);

    input['cover'] = 'changed-before-read';
    expect(detail.cover, '//img/@src');

    final exported = detail.toRaw();
    exported['cover'] = 'changed-after-read';
    expect(detail.cover, '//img/@src');
  });
}
