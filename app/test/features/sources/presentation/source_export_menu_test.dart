import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:source_reader/features/sources/application/source_export.dart';
import 'package:source_reader/features/sources/presentation/source_export_menu.dart';

void main() {
  group('SourceExportMenu', () {
    testWidgets('canExportCurrent=false 时 current 可见但禁用 all 可打开格式对话框',
        (tester) async {
      final calls = <(SourceExportScope, SourceExportFormat)>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SourceExportMenu(
              canExportCurrent: false,
              onExport: (scope, format) async {
                calls.add((scope, format));
              },
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('source-export-menu')), findsOneWidget);

      await tester.tap(find.byKey(const Key('source-export-menu')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('source-export-current')), findsOneWidget);
      expect(find.byKey(const Key('source-export-all')), findsOneWidget);

      final currentItem = tester.widget<PopupMenuItem<SourceExportScope>>(
        find.byKey(const Key('source-export-current')),
      );
      expect(currentItem.enabled, isFalse);

      final allItem = tester.widget<PopupMenuItem<SourceExportScope>>(
        find.byKey(const Key('source-export-all')),
      );
      expect(allItem.enabled, isTrue);

      await tester.tap(find.byKey(const Key('source-export-current')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('source-export-format-dialog')), findsNothing);
      expect(calls, isEmpty);

      await tester.tap(find.byKey(const Key('source-export-all')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('source-export-format-dialog')), findsOneWidget);
      expect(find.byKey(const Key('source-export-format-json')), findsOneWidget);
      expect(find.byKey(const Key('source-export-format-xbs')), findsOneWidget);
      expect(find.byKey(const Key('source-export-format-cancel')), findsOneWidget);
    });

    testWidgets('canExportCurrent=true 时 current 可打开格式对话框', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SourceExportMenu(
              canExportCurrent: true,
              onExport: (_, _) async {},
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('source-export-menu')));
      await tester.pumpAndSettle();

      final currentItem = tester.widget<PopupMenuItem<SourceExportScope>>(
        find.byKey(const Key('source-export-current')),
      );
      expect(currentItem.enabled, isTrue);

      await tester.tap(find.byKey(const Key('source-export-current')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('source-export-format-dialog')), findsOneWidget);
    });

    testWidgets('current + JSON 回调精确为 current/json 且只调用一次', (tester) async {
      final calls = <(SourceExportScope, SourceExportFormat)>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SourceExportMenu(
              canExportCurrent: true,
              onExport: (scope, format) async {
                calls.add((scope, format));
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('source-export-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('source-export-current')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('source-export-format-json')));
      await tester.pumpAndSettle();

      expect(calls, hasLength(1));
      expect(calls.single.$1, SourceExportScope.current);
      expect(calls.single.$2, SourceExportFormat.json);
      expect(find.byKey(const Key('source-export-format-dialog')), findsNothing);
    });

    testWidgets('current + XBS 回调精确为 current/xbs 且只调用一次', (tester) async {
      final calls = <(SourceExportScope, SourceExportFormat)>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SourceExportMenu(
              canExportCurrent: true,
              onExport: (scope, format) async {
                calls.add((scope, format));
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('source-export-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('source-export-current')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('source-export-format-xbs')));
      await tester.pumpAndSettle();

      expect(calls, hasLength(1));
      expect(calls.single.$1, SourceExportScope.current);
      expect(calls.single.$2, SourceExportFormat.xbs);
    });

    testWidgets('all + JSON 回调精确为 all/json 且只调用一次', (tester) async {
      final calls = <(SourceExportScope, SourceExportFormat)>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SourceExportMenu(
              canExportCurrent: false,
              onExport: (scope, format) async {
                calls.add((scope, format));
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('source-export-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('source-export-all')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('source-export-format-json')));
      await tester.pumpAndSettle();

      expect(calls, hasLength(1));
      expect(calls.single.$1, SourceExportScope.all);
      expect(calls.single.$2, SourceExportFormat.json);
    });

    testWidgets('all + XBS 回调精确为 all/xbs 且只调用一次', (tester) async {
      final calls = <(SourceExportScope, SourceExportFormat)>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SourceExportMenu(
              canExportCurrent: true,
              onExport: (scope, format) async {
                calls.add((scope, format));
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('source-export-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('source-export-all')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('source-export-format-xbs')));
      await tester.pumpAndSettle();

      expect(calls, hasLength(1));
      expect(calls.single.$1, SourceExportScope.all);
      expect(calls.single.$2, SourceExportFormat.xbs);
    });

    testWidgets('取消静默不调用 onExport', (tester) async {
      final calls = <(SourceExportScope, SourceExportFormat)>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SourceExportMenu(
              canExportCurrent: true,
              onExport: (scope, format) async {
                calls.add((scope, format));
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('source-export-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('source-export-all')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('source-export-format-cancel')));
      await tester.pumpAndSettle();

      expect(calls, isEmpty);
      expect(find.byKey(const Key('source-export-format-dialog')), findsNothing);
    });

    testWidgets('对话框 barrier dismiss 不调用 onExport', (tester) async {
      final calls = <(SourceExportScope, SourceExportFormat)>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SourceExportMenu(
              canExportCurrent: true,
              onExport: (scope, format) async {
                calls.add((scope, format));
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('source-export-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('source-export-current')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('source-export-format-dialog')), findsOneWidget);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(calls, isEmpty);
    });
  });
}
