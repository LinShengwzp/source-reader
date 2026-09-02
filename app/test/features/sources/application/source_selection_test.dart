import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:source_reader/features/sources/application/source_selection.dart';

void main() {
  test('selection 初始为空，select 按数据库 id 选择，clear 清空', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(sourceSelectionProvider), isNull);

    container.read(sourceSelectionProvider.notifier).select(42);
    expect(container.read(sourceSelectionProvider), 42);

    container.read(sourceSelectionProvider.notifier).clear();
    expect(container.read(sourceSelectionProvider), isNull);
  });
}
