import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:source_reader/features/sources/codec/xbs_codec.dart';

void main() {
  group('XBS legacy compatibility', () {
    final vectors = <({String text, String cipherHex})>[
      (
        text: '{}',
        cipherHex: '8d10136095c1c5ab',
      ),
      (
        text: '1234',
        cipherHex: '257e16b837b33220',
      ),
      (
        text: '{"sourceName":"A","enable":"1"}',
        cipherHex:
            '4d7fbc323681eff6a5bf2e7ece066c787a0f579dbb6a6617bf56dd024153932630743c89',
      ),
      (
        text: '{"sourceName":"中文书源","enable":"1"}',
        cipherHex:
            'c2bb566e78a95b32005f0477aab40a20299b3dadd426e24c2ec6a034d45d3dab2425001848a3d7513db9a4da8271b26b',
      ),
    ];

    for (final vector in vectors) {
      test('encode 与旧实现逐字节一致: ${vector.text}', () {
        final plainBytes = Uint8List.fromList(utf8.encode(vector.text));

        final encrypted = encodeXbs(plainBytes);

        expect(encrypted, orderedEquals(_hexToBytes(vector.cipherHex)));
      });

      test('decode 可读取旧实现密文: ${vector.text}', () {
        final encrypted = _hexToBytes(vector.cipherHex);
        final expected = Uint8List.fromList(utf8.encode(vector.text));

        final decoded = decodeXbs(encrypted);

        expect(decoded, orderedEquals(expected));
      });
    }
  });

  group('XBS invalid input', () {
    test('拒绝空明文', () {
      expect(() => encodeXbs(Uint8List(0)), throwsArgumentError);
    });

    test('拒绝长度小于 8 的密文', () {
      expect(() => decodeXbs(Uint8List(0)), throwsFormatException);
      expect(() => decodeXbs(Uint8List(7)), throwsFormatException);
    });

    test('拒绝不是 4 字节倍数的密文', () {
      expect(() => decodeXbs(Uint8List(9)), throwsFormatException);
    });
  });
}

Uint8List _hexToBytes(String hex) {
  if (hex.length.isOdd) {
    throw const FormatException('hex 字符串长度必须为偶数');
  }

  final bytes = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < bytes.length; i++) {
    final start = i * 2;
    bytes[i] = int.parse(hex.substring(start, start + 2), radix: 16);
  }
  return bytes;
}
