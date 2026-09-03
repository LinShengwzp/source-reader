import 'package:flutter_test/flutter_test.dart';
import 'package:source_reader/features/source_tester/domain/source_test_error.dart';

void main() {
  test('SourceTestException 保留 reason/message/cause', () {
    const cause = FormatException('bad');
    const ex = SourceTestException(
      SourceTestFailureReason.unknownPlaceholder,
      message: 'unknown %@foo',
      cause: cause,
    );
    expect(ex.reason, SourceTestFailureReason.unknownPlaceholder);
    expect(ex.message, 'unknown %@foo');
    expect(ex.cause, cause);
  });

  test('SourceTestException 作为 Exception 可被捕获', () {
    expect(
      () => throw const SourceTestException(SourceTestFailureReason.timeout),
      throwsA(isA<SourceTestException>()),
    );
  });

  test('所有失败原因枚举值存在', () {
    expect(SourceTestFailureReason.values.length, 16);
    expect(SourceTestFailureReason.values, contains(SourceTestFailureReason.sourceNotFound));
    expect(SourceTestFailureReason.values, contains(SourceTestFailureReason.listRuleFailure));
  });
}
