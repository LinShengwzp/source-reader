import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:source_reader/features/sources/data/source_repository.dart';
import 'package:source_reader/features/sources/domain/source_document.dart';
import 'package:source_reader/features/sources/presentation/source_list.dart';

void main() {
  testWidgets('点击回传数据库 id', (tester) async {
    final selectedIds = <int>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SourceList(
            sources: <StoredSource>[
              _storedSource(id: 1, name: '书源 A'),
              _storedSource(id: 2, name: '书源 B'),
            ],
            selectedId: null,
            onSelected: selectedIds.add,
          ),
        ),
      ),
    );

    await tester.tap(find.text('书源 B'));
    await tester.pump();

    expect(selectedIds, <int>[2]);
  });

  testWidgets('selectedId 控制视觉选中态', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SourceList(
            sources: <StoredSource>[
              _storedSource(id: 1, name: '书源 A'),
              _storedSource(id: 2, name: '书源 B'),
            ],
            selectedId: 2,
            onSelected: (_) {},
          ),
        ),
      ),
    );

    final tile1 = tester.widget<ListTile>(
      find.byKey(const Key('source-list-tile-1')),
    );
    final tile2 = tester.widget<ListTile>(
      find.byKey(const Key('source-list-tile-2')),
    );

    expect(tile1.selected, isFalse);
    expect(tile2.selected, isTrue);
  });

  testWidgets('列表重排后仍按 id 选择', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SourceList(
            sources: <StoredSource>[
              _storedSource(id: 1, name: '书源 A'),
              _storedSource(id: 2, name: '书源 B'),
            ],
            selectedId: 2,
            onSelected: (_) {},
          ),
        ),
      ),
    );

    expect(
      tester.widget<ListTile>(find.byKey(const Key('source-list-tile-2'))).selected,
      isTrue,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SourceList(
            sources: <StoredSource>[
              _storedSource(id: 2, name: '书源 B'),
              _storedSource(id: 1, name: '书源 A'),
            ],
            selectedId: 2,
            onSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      tester.widget<ListTile>(find.byKey(const Key('source-list-tile-2'))).selected,
      isTrue,
    );
    expect(
      tester.widget<ListTile>(find.byKey(const Key('source-list-tile-1'))).selected,
      isFalse,
    );
  });
}

StoredSource _storedSource({
  required int id,
  required String name,
  bool enabled = true,
}) {
  final timestamp = DateTime.utc(2026, 9, 2, 8);
  return StoredSource(
    id: id,
    platform: 'StandarReader',
    document: SourceDocument.fromRaw(<String, Object?>{
      'sourceName': name,
      'enable': enabled ? '1' : '0',
      'weight': '0',
    }),
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}
