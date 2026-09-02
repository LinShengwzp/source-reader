import 'dart:typed_data';

const int _uint32Mask = 0xffffffff;
const int _delta = 0x9e3779b9;

const List<int> _xbsKeyBytes = <int>[
  0xe5,
  0x87,
  0xbc,
  0xe8,
  0xa4,
  0x86,
  0xe6,
  0xbb,
  0xbf,
  0xe9,
  0x87,
  0x91,
  0xe6,
  0xba,
  0xa1,
  0xe5,
];

/// 使用旧版香色闺阁 XBS 格式编码原始字节。
///
/// XBS 会先把 payload 用 0 补齐到 4 字节边界，再追加 4 字节小端序
/// 原始长度，最后使用固定 key 执行 XXTEA。
Uint8List encodeXbs(Uint8List sourceBytes) {
  if (sourceBytes.isEmpty) {
    throw ArgumentError.value(sourceBytes, 'sourceBytes', 'XBS 不支持空 payload');
  }

  final paddedLength = ((sourceBytes.length + 3) ~/ 4) * 4;
  final plain = Uint8List(paddedLength + 4);
  plain.setRange(0, sourceBytes.length, sourceBytes);

  final lengthView = ByteData.sublistView(plain);
  lengthView.setUint32(paddedLength, sourceBytes.length, Endian.little);

  return _xxteaEncrypt(plain);
}

/// 解码旧版香色闺阁 XBS 字节，返回其中未经 JSON 解析的原始 payload。
Uint8List decodeXbs(Uint8List encryptedBytes) {
  if (encryptedBytes.length < 8 || encryptedBytes.length % 4 != 0) {
    throw const FormatException('XBS 密文长度必须至少为 8 且是 4 的倍数');
  }

  final decrypted = _xxteaDecrypt(encryptedBytes);
  final payloadAreaLength = decrypted.length - 4;
  final lengthView = ByteData.sublistView(decrypted);
  final originalLength = lengthView.getUint32(
    payloadAreaLength,
    Endian.little,
  );

  if (originalLength < payloadAreaLength - 3 ||
      originalLength > payloadAreaLength) {
    throw const FormatException('XBS 原始长度标记无效');
  }

  return Uint8List.fromList(decrypted.sublist(0, originalLength));
}

Uint8List _xxteaEncrypt(Uint8List data) {
  if (data.length < 8 || data.length % 4 != 0) {
    throw const FormatException('XXTEA 输入长度必须至少为 8 且是 4 的倍数');
  }

  final words = _bytesToWords(data);
  final key = _bytesToWords(Uint8List.fromList(_xbsKeyBytes));
  final wordCount = words.length;
  final rounds = 6 + (52 ~/ wordCount);

  var sum = 0;
  var z = words[wordCount - 1];

  for (var round = 0; round < rounds; round++) {
    sum = _uint32(sum + _delta);
    final e = (sum >>> 2) & 3;

    var p = 0;
    for (p = 0; p < wordCount - 1; p++) {
      final y = words[p + 1];
      words[p] = _uint32(words[p] + _mx(y, z, p, e, sum, key));
      z = words[p];
    }

    final y = words[0];
    words[wordCount - 1] = _uint32(
      words[wordCount - 1] + _mx(y, z, p, e, sum, key),
    );
    z = words[wordCount - 1];
  }

  return _wordsToBytes(words);
}

Uint8List _xxteaDecrypt(Uint8List data) {
  if (data.length < 8 || data.length % 4 != 0) {
    throw const FormatException('XXTEA 输入长度必须至少为 8 且是 4 的倍数');
  }

  final words = _bytesToWords(data);
  final key = _bytesToWords(Uint8List.fromList(_xbsKeyBytes));
  final wordCount = words.length;
  final rounds = 6 + (52 ~/ wordCount);

  var sum = _uint32(rounds * _delta);
  var y = words[0];

  for (var round = 0; round < rounds; round++) {
    final e = (sum >>> 2) & 3;

    var p = wordCount - 1;
    for (p = wordCount - 1; p > 0; p--) {
      final z = words[p - 1];
      words[p] = _uint32(words[p] - _mx(y, z, p, e, sum, key));
      y = words[p];
    }

    final z = words[wordCount - 1];
    words[0] = _uint32(words[0] - _mx(y, z, p, e, sum, key));
    y = words[0];
    sum = _uint32(sum - _delta);
  }

  return _wordsToBytes(words);
}

int _mx(
  int y,
  int z,
  int p,
  int e,
  int sum,
  List<int> key,
) {
  final shiftedZ = _uint32((z >>> 5) ^ _uint32(y << 2));
  final shiftedY = _uint32((y >>> 3) ^ _uint32(z << 4));
  final left = _uint32(shiftedZ + shiftedY);

  final keyed = _uint32((sum ^ y) + (key[(p & 3) ^ e] ^ z));
  return _uint32(left ^ keyed);
}

List<int> _bytesToWords(Uint8List bytes) {
  if (bytes.length % 4 != 0) {
    throw const FormatException('字节长度必须是 4 的倍数');
  }

  final view = ByteData.sublistView(bytes);
  final words = <int>[];
  for (var offset = 0; offset < bytes.length; offset += 4) {
    words.add(view.getUint32(offset, Endian.little));
  }
  return words;
}

Uint8List _wordsToBytes(List<int> words) {
  final bytes = Uint8List(words.length * 4);
  final view = ByteData.sublistView(bytes);
  for (var i = 0; i < words.length; i++) {
    view.setUint32(i * 4, _uint32(words[i]), Endian.little);
  }
  return bytes;
}

int _uint32(int value) => value & _uint32Mask;
