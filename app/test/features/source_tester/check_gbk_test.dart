import 'package:flutter_test/flutter_test.dart';
import 'package:enough_convert/enough_convert.dart';

void main() {
  test('check gbk bytes', () {
    final bytes = gbk.encode('三体');
    print('BYTES: $bytes');
    print('ENCODED: ${bytes.map((b) => '%${b.toRadixString(16).toUpperCase().padLeft(2,'0')}').join()}');
  });
}
