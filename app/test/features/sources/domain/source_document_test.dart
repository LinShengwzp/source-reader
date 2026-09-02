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
}
