import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:source_reader/app/app.dart';
import 'package:source_reader/features/sources/application/source_providers.dart';
import 'package:source_reader/features/sources/data/source_repository.dart';
import 'package:source_reader/features/sources/domain/source_document.dart';

void main() {
  testWidgets('应用启动后显示真实 Source Workbench 首页', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sourceRepositoryProvider.overrideWithValue(
            const _EmptySourceRepository(),
          ),
        ],
        child: const SourceReaderApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Source Workbench'), findsOneWidget);
    expect(find.text('还没有书源'), findsOneWidget);
  });
}

final class _EmptySourceRepository implements SourceRepository {
  const _EmptySourceRepository();

  @override
  Future<List<StoredSource>> listSources() async => <StoredSource>[];

  @override
  Future<StoredSource?> getSource(int id) => throw UnimplementedError();

  @override
  Future<int> insertSource({
    required String platform,
    required SourceDocument document,
  }) => throw UnimplementedError();

  @override
  Future<void> updateSource(int id, SourceDocument document) =>
      throw UnimplementedError();

  @override
  Future<void> deleteSource(int id) => throw UnimplementedError();
}
