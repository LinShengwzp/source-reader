import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:source_reader/features/source_tester/presentation/source_tester_input_panel.dart';

void main() {
  testWidgets('行为 1：默认 keyword 空、pageIndex 为 1、高级区域收起', (tester) async {
    await tester.pumpWidget(_wrap(SourceTesterInputPanel(running: false, onRun: (_) {})));

    expect(_textOf(tester, const Key('source-tester-input-keyword')), '');
    expect(_textOf(tester, const Key('source-tester-input-page-index')), '1');

    expect(find.byKey(const Key('source-tester-input-advanced-toggle')), findsOneWidget);
    expect(find.byKey(const Key('source-tester-input-advanced')), findsNothing);
    expect(find.byKey(const Key('source-tester-input-offset')), findsNothing);
    expect(find.byKey(const Key('source-tester-input-filter')), findsNothing);
  });

  testWidgets('行为 2：展开高级区域后 offset 为 0、filter 为空且稳定 Key 可找到', (tester) async {
    await tester.pumpWidget(_wrap(SourceTesterInputPanel(running: false, onRun: (_) {})));

    await tester.ensureVisible(find.byKey(const Key('source-tester-input-advanced-toggle')));
    await tester.tap(find.byKey(const Key('source-tester-input-advanced-toggle')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('source-tester-input-advanced')), findsOneWidget);
    expect(find.byKey(const Key('source-tester-input-offset')), findsOneWidget);
    expect(find.byKey(const Key('source-tester-input-filter')), findsOneWidget);

    expect(_textOf(tester, const Key('source-tester-input-offset')), '0');
    expect(_textOf(tester, const Key('source-tester-input-filter')), '');
  });

  testWidgets('行为 3：keyword 为空时点击运行不回调且显示校验错误', (tester) async {
    var callCount = 0;

    await tester.pumpWidget(
      _wrap(
        SourceTesterInputPanel(
          running: false,
          onRun: (_) => callCount++,
        ),
      ),
    );

    await tester.ensureVisible(find.byKey(const Key('source-tester-input-run')));
    await tester.tap(find.byKey(const Key('source-tester-input-run')));
    await tester.pumpAndSettle();

    expect(callCount, 0);
    expect(_errorTexts(tester), isNotEmpty);
  });

  testWidgets('行为 4：pageIndex 非法时点击运行不回调', (tester) async {
    for (final invalid in <String>['abc', '0', '-1', '']) {
      var callCount = 0;

      await tester.pumpWidget(
        _wrap(
          SourceTesterInputPanel(
            running: false,
            onRun: (_) => callCount++,
          ),
        ),
      );

      await tester.enterText(
        find.byKey(const Key('source-tester-input-keyword')),
        '测试小说',
      );
      await tester.enterText(
        find.byKey(const Key('source-tester-input-page-index')),
        invalid,
      );
      await tester.pump();

      await tester.ensureVisible(find.byKey(const Key('source-tester-input-run')));
      await tester.tap(find.byKey(const Key('source-tester-input-run')));
      await tester.pumpAndSettle();

      expect(callCount, 0, reason: 'pageIndex=$invalid 不应触发回调');
      expect(_errorTexts(tester), isNotEmpty, reason: 'pageIndex=$invalid 应显示校验错误');
    }
  });

  testWidgets('行为 5a：offset 非整数时点击运行不回调', (tester) async {
    await _testInvalidOffset(tester, 'abc');
  });

  testWidgets('行为 5b：offset 负数时点击运行不回调', (tester) async {
    await _testInvalidOffset(tester, '-1');
  });

  testWidgets('行为 5c：offset 空值时点击运行不回调', (tester) async {
    await _testInvalidOffset(tester, '');
  });

  testWidgets('行为 6：默认高级参数运行时回调 trim 后的 keyword 与默认 pageIndex/offset/filter',
      (tester) async {
    final calls = <SourceTesterInput>[];

    await tester.pumpWidget(
      _wrap(
        SourceTesterInputPanel(
          running: false,
          onRun: calls.add,
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('source-tester-input-keyword')),
      '  测试小说  ',
    );
    await tester.pump();

    await tester.ensureVisible(find.byKey(const Key('source-tester-input-run')));
    await tester.tap(find.byKey(const Key('source-tester-input-run')));
    await tester.pumpAndSettle();

    expect(calls, hasLength(1));
    expect(calls.single.keyWord, '测试小说');
    expect(calls.single.pageIndex, 1);
    expect(calls.single.offset, 0);
    expect(calls.single.filter, '');
  });

  testWidgets('行为 7：自定义高级参数运行时回调 trim 后的值且只调用一次', (tester) async {
    final calls = <SourceTesterInput>[];

    await tester.pumpWidget(
      _wrap(
        SourceTesterInputPanel(
          running: false,
          onRun: calls.add,
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('source-tester-input-keyword')),
      '  测试小说  ',
    );
    await tester.enterText(find.byKey(const Key('source-tester-input-page-index')), '3');
    await tester.pump();

    await tester.ensureVisible(find.byKey(const Key('source-tester-input-advanced-toggle')));
    await tester.tap(find.byKey(const Key('source-tester-input-advanced-toggle')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('source-tester-input-offset')));
    await tester.enterText(find.byKey(const Key('source-tester-input-offset')), '20');
    await tester.pump();

    await tester.ensureVisible(find.byKey(const Key('source-tester-input-filter')));
    await tester.enterText(find.byKey(const Key('source-tester-input-filter')), '  完结  ');
    await tester.pump();

    await tester.ensureVisible(find.byKey(const Key('source-tester-input-run')));
    await tester.tap(find.byKey(const Key('source-tester-input-run')));
    await tester.pumpAndSettle();

    expect(calls, hasLength(1));
    expect(calls.single.keyWord, '测试小说');
    expect(calls.single.pageIndex, 3);
    expect(calls.single.offset, 20);
    expect(calls.single.filter, '完结');
  });

  testWidgets('行为 8：running 为 true 时运行按钮 disabled 且点击不回调', (tester) async {
    var callCount = 0;

    await tester.pumpWidget(
      _wrap(
        SourceTesterInputPanel(
          running: true,
          onRun: (_) => callCount++,
        ),
      ),
    );

    final button = tester.widget<ButtonStyleButton>(
      find.byKey(const Key('source-tester-input-run')),
    );
    expect(button.enabled, isFalse);

    await tester.ensureVisible(find.byKey(const Key('source-tester-input-run')));
    await tester.tap(find.byKey(const Key('source-tester-input-run')));
    await tester.pumpAndSettle();

    expect(callCount, 0);
  });
}

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));
}

String _textOf(WidgetTester tester, Key key) {
  final field = tester.widget<TextField>(
    find.descendant(of: find.byKey(key), matching: find.byType(TextField)),
  );
  return field.controller?.text ?? '';
}

List<String> _errorTexts(WidgetTester tester) {
  return tester
      .widgetList<TextField>(find.byType(TextField))
      .map((field) => field.decoration?.errorText)
      .whereType<String>()
      .where((text) => text.isNotEmpty)
      .toList();
}

Future<void> _testInvalidOffset(WidgetTester tester, String invalid) async {
  var callCount = 0;

  await tester.pumpWidget(
    _wrap(
      SourceTesterInputPanel(
        running: false,
        onRun: (_) => callCount++,
      ),
    ),
  );

  await tester.ensureVisible(find.byKey(const Key('source-tester-input-advanced-toggle')));
  await tester.tap(find.byKey(const Key('source-tester-input-advanced-toggle')));
  await tester.pumpAndSettle();

  await tester.enterText(
    find.byKey(const Key('source-tester-input-keyword')),
    '测试小说',
  );
  await tester.pumpAndSettle();

  await tester.ensureVisible(find.byKey(const Key('source-tester-input-offset')));
  await tester.enterText(find.byKey(const Key('source-tester-input-offset')), invalid);
  await tester.pumpAndSettle();

  await tester.ensureVisible(find.byKey(const Key('source-tester-input-run')));
  await tester.tap(find.byKey(const Key('source-tester-input-run')));
  await tester.pumpAndSettle();

  expect(callCount, 0, reason: 'offset=$invalid 不应触发回调');
  expect(_errorTexts(tester), isNotEmpty, reason: 'offset=$invalid 应显示校验错误');
}
