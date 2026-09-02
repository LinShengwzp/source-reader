import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:source_reader/features/sources/codec/source_json_codec.dart';

void main() {
  test('单个 JSON 对象解码为一个书源', () {
    final sources = decodeSourceJson('{"sourceName":"A","unknown":123}');

    expect(sources, hasLength(1));
    expect(sources.single.sourceName, 'A');
    expect(sources.single.toRaw()['unknown'], 123);
  });

  test('JSON 对象数组解码为多个书源', () {
    final sources = decodeSourceJson(
      '[{"sourceName":"A"},{"sourceName":"B"}]',
    );

    expect(sources.map((source) => source.sourceName), ['A', 'B']);
  });

  test('拒绝非法 JSON 和非对象顶层结构', () {
    expect(() => decodeSourceJson('{bad'), throwsFormatException);
    expect(() => decodeSourceJson('"abc"'), throwsFormatException);
    expect(() => decodeSourceJson('[1, 2, 3]'), throwsFormatException);
  });

  test('encode/decode round-trip 保留未知字段', () {
    const input = '[{"sourceName":"A","future":{"flag":true}}]';

    final encoded = encodeSourceJson(decodeSourceJson(input));
    final raw = jsonDecode(encoded) as List<Object?>;
    final first = raw.single as Map<String, Object?>;

    expect(first['future'], <String, Object?>{'flag': true});
  });

  test('即使只有一个书源，encode 也固定输出数组', () {
    final encoded = encodeSourceJson(
      decodeSourceJson('{"sourceName":"A"}'),
    );

    expect(jsonDecode(encoded), isA<List<Object?>>());
  });
}
