import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:source_reader/features/sources/data/source_repository.dart';
import 'package:source_reader/features/sources/domain/source_document.dart';
import 'package:source_reader/features/sources/presentation/source_editor.dart';

void main() {
  testWidgets('行为 A：四字段从 StoredSource 初始化', (tester) async {
    final source = _storedSource(
      id: 1,
      raw: <String, Object?>{
        'sourceName': '测试书源',
        'sourceUrl': 'https://old.example',
        'enable': '1',
        'weight': '7',
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SourceEditor(source: source, onSave: (_) async {})),
      ),
    );

    expect(
      tester.widget<TextFormField>(find.byKey(const Key('source-editor-name'))).controller?.text,
      '测试书源',
    );
    expect(
      tester.widget<TextFormField>(find.byKey(const Key('source-editor-url'))).controller?.text,
      'https://old.example',
    );
    expect(tester.widget<Switch>(find.byKey(const Key('source-editor-enabled'))).value, isTrue);
    expect(
      tester.widget<TextFormField>(find.byKey(const Key('source-editor-weight'))).controller?.text,
      '7',
    );
  });

  testWidgets('行为 B：保存四字段且未知 raw JSON 不丢', (tester) async {
    final original = SourceDocument.fromRaw(<String, Object?>{
      'sourceName': '旧名称',
      'sourceUrl': 'https://old.example',
      'enable': '1',
      'weight': '7',
      'futureRule': <String, Object?>{
        'nested': <Object?>['keep', 42],
      },
    });
    final source = _storedSource(id: 1, raw: original.toRaw());
    SourceDocument? saved;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SourceEditor(
            source: source,
            onSave: (doc) async {
              saved = doc;
            },
          ),
        ),
      ),
    );

    await tester.enterText(find.byKey(const Key('source-editor-name')), '新名称');
    await tester.enterText(find.byKey(const Key('source-editor-url')), 'https://new.example');
    await tester.enterText(find.byKey(const Key('source-editor-weight')), '12');
    final enabledSwitch = find.byKey(const Key('source-editor-enabled'));
    expect(tester.widget<Switch>(enabledSwitch).value, isTrue);
    await tester.tap(enabledSwitch);
    await tester.pump();

    await tester.tap(find.byKey(const Key('source-editor-save')));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.sourceName, '新名称');
    expect(saved!.sourceUrl, 'https://new.example');
    expect(saved!.enabled, isFalse);
    expect(saved!.weight, 12);
    expect(saved!.toRaw()['futureRule'], original.toRaw()['futureRule']);
  });

  testWidgets('行为 C：空名称拒绝保存', (tester) async {
    final source = _storedSource(
      id: 1,
      raw: <String, Object?>{
        'sourceName': '旧名称',
        'sourceUrl': 'https://old.example',
        'enable': '1',
        'weight': '0',
      },
    );
    var calls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SourceEditor(
            source: source,
            onSave: (_) async {
              calls += 1;
            },
          ),
        ),
      ),
    );

    await tester.enterText(find.byKey(const Key('source-editor-name')), '   ');
    await tester.tap(find.byKey(const Key('source-editor-save')));
    await tester.pump();

    expect(find.text('书源名称不能为空'), findsOneWidget);
    expect(calls, 0);
  });

  testWidgets('行为 D：非法权重拒绝保存', (tester) async {
    final source = _storedSource(
      id: 1,
      raw: <String, Object?>{
        'sourceName': '旧名称',
        'sourceUrl': 'https://old.example',
        'enable': '1',
        'weight': '0',
      },
    );
    var calls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SourceEditor(
            source: source,
            onSave: (_) async {
              calls += 1;
            },
          ),
        ),
      ),
    );

    await tester.enterText(find.byKey(const Key('source-editor-weight')), 'abc');
    await tester.tap(find.byKey(const Key('source-editor-save')));
    await tester.pump();

    expect(find.text('权重必须是整数'), findsOneWidget);
    expect(calls, 0);
  });

  testWidgets('行为 E：保存过程中禁止重复提交', (tester) async {
    final source = _storedSource(
      id: 1,
      raw: <String, Object?>{
        'sourceName': '旧名称',
        'sourceUrl': 'https://old.example',
        'enable': '1',
        'weight': '0',
      },
    );
    final completer = Completer<void>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SourceEditor(source: source, onSave: (_) => completer.future),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('source-editor-save')));
    await tester.pump();

    final button = tester.widget<FilledButton>(find.byKey(const Key('source-editor-save')));
    expect(button.onPressed, isNull);

    completer.complete();
    await tester.pumpAndSettle();

    final button2 = tester.widget<FilledButton>(find.byKey(const Key('source-editor-save')));
    expect(button2.onPressed, isNotNull);
  });

  testWidgets('行为 F：返回按钮只在 onBack 存在时显示', (tester) async {
    final source = _storedSource(
      id: 1,
      raw: <String, Object?>{
        'sourceName': '旧名称',
        'sourceUrl': 'https://old.example',
        'enable': '1',
        'weight': '0',
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SourceEditor(source: source, onSave: (_) async {})),
      ),
    );
    expect(find.byKey(const Key('source-editor-back')), findsNothing);

    var backCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SourceEditor(
            source: source,
            onSave: (_) async {},
            onBack: () => backCalls += 1,
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('source-editor-back')), findsOneWidget);
    await tester.tap(find.byKey(const Key('source-editor-back')));
    await tester.pump();
    expect(backCalls, 1);
  });

  testWidgets('行为 G：同一个 mounted Editor 切换 source.id 时重载草稿', (tester) async {
    final sourceA = _storedSource(
      id: 1,
      raw: <String, Object?>{
        'sourceName': 'A',
        'sourceUrl': 'https://a.example',
        'enable': '1',
        'weight': '1',
      },
    );
    final sourceB = _storedSource(
      id: 2,
      raw: <String, Object?>{
        'sourceName': 'B',
        'sourceUrl': 'https://b.example',
        'enable': '0',
        'weight': '9',
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SourceEditor(source: sourceA, onSave: (_) async {})),
      ),
    );

    expect(
      tester.widget<TextFormField>(find.byKey(const Key('source-editor-name'))).controller?.text,
      'A',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SourceEditor(source: sourceB, onSave: (_) async {})),
      ),
    );
    await tester.pump();

    expect(
      tester.widget<TextFormField>(find.byKey(const Key('source-editor-name'))).controller?.text,
      'B',
    );
    expect(
      tester.widget<TextFormField>(find.byKey(const Key('source-editor-url'))).controller?.text,
      'https://b.example',
    );
    expect(tester.widget<Switch>(find.byKey(const Key('source-editor-enabled'))).value, isFalse);
    expect(
      tester.widget<TextFormField>(find.byKey(const Key('source-editor-weight'))).controller?.text,
      '9',
    );
  });

  testWidgets('行为 H：现有 searchBook 规则在 SourceEditor 中可见', (tester) async {
    _useTallSurface(tester);
    final source = _storedSource(
      id: 1,
      raw: <String, Object?>{
        'sourceName': 'A',
        'weight': '1',
        'searchBook': <String, Object?>{
          'actionID': 'searchBook',
          'parserID': 'DOM',
          'requestInfo': '/search?q=%@keyWord',
          'bookName': './/h3/text()',
        },
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SourceEditor(source: source, onSave: (_) async {})),
      ),
    );

    expect(find.byKey(const Key('search-book-request-info')), findsOneWidget);
    expect(find.byKey(const Key('search-book-book-name')), findsOneWidget);
    expect(
      _ruleTextFormField(tester, const Key('search-book-request-info')).initialValue,
      '/search?q=%@keyWord',
    );
    expect(
      _ruleTextFormField(tester, const Key('search-book-book-name')).initialValue,
      './/h3/text()',
    );
  });

  testWidgets('行为 I：基础字段与 searchBook 规则一次保存为同一文档', (tester) async {
    _useTallSurface(tester);
    final source = _storedSource(
      id: 1,
      raw: <String, Object?>{
        'sourceName': '旧名称',
        'sourceUrl': 'https://old.example',
        'enable': '1',
        'weight': '7',
        'searchBook': <String, Object?>{
          'actionID': 'searchBook',
          'parserID': 'DOM',
          'requestInfo': '/old-search',
          'bookName': './/h3/text()',
        },
      },
    );
    SourceDocument? saved;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SourceEditor(
            source: source,
            onSave: (document) async => saved = document,
          ),
        ),
      ),
    );

    await tester.enterText(find.byKey(const Key('source-editor-name')), '新名称');
    await tester.enterText(
      _ruleTextFieldFinder(const Key('search-book-request-info')),
      '/new-search',
    );
    await tester.enterText(
      _ruleTextFieldFinder(const Key('search-book-book-name')),
      './/h2/text()',
    );
    await tester.tap(find.byKey(const Key('source-editor-save')));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.sourceName, '新名称');
    expect(saved!.searchBook?.action.requestInfo, '/new-search');
    expect(saved!.searchBook?.bookName, './/h2/text()');
  });

  testWidgets('行为 J：一次联合保存保留顶层与 searchBook 未知字段', (tester) async {
    _useTallSurface(tester);
    final original = SourceDocument.fromRaw(<String, Object?>{
      'sourceName': '旧名称',
      'weight': '7',
      'futureTop': <String, Object?>{
        'nested': <Object?>['keep', 42],
      },
      'searchBook': <String, Object?>{
        'actionID': 'searchBook',
        'parserID': 'DOM',
        'bookName': './/h3/text()',
        'futureSearchField': <String, Object?>{
          'deep': <Object?>[true, 9],
        },
      },
    });
    final source = _storedSource(id: 1, raw: original.toRaw());
    SourceDocument? saved;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SourceEditor(
            source: source,
            onSave: (document) async => saved = document,
          ),
        ),
      ),
    );

    await tester.enterText(find.byKey(const Key('source-editor-name')), '新名称');
    await tester.enterText(
      _ruleTextFieldFinder(const Key('search-book-book-name')),
      './/h2/text()',
    );
    await tester.tap(find.byKey(const Key('source-editor-save')));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.toRaw()['futureTop'], original.toRaw()['futureTop']);
    expect(
      saved!.searchBook?.toRaw()['futureSearchField'],
      original.searchBook?.toRaw()['futureSearchField'],
    );
  });

  testWidgets('行为 K：非法结构化 moreKeys 阻止整个 SourceEditor 保存', (tester) async {
    _useTallSurface(tester);
    final source = _storedSource(
      id: 1,
      raw: <String, Object?>{
        'sourceName': 'A',
        'weight': '1',
        'searchBook': <String, Object?>{
          'actionID': 'searchBook',
          'parserID': 'DOM',
          'moreKeys': <String, Object?>{'pageSize': 20},
        },
      },
    );
    var saveCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SourceEditor(
            source: source,
            onSave: (_) async => saveCalls += 1,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('search-book-advanced')));
    await tester.pumpAndSettle();
    await tester.enterText(
      _ruleTextFieldFinder(const Key('search-book-more-keys')),
      '{bad json',
    );
    await tester.pumpAndSettle();

    expect(find.text('moreKeys 必须是有效 JSON 对象或数组'), findsOneWidget);

    await tester.tap(find.byKey(const Key('source-editor-save')));
    await tester.pump();

    expect(saveCalls, 0);
    expect(find.text('moreKeys 必须是有效 JSON 对象或数组'), findsOneWidget);
  });

  testWidgets('行为 L：切换 source.id 同时重载基础字段与 searchBook 草稿', (tester) async {
    _useTallSurface(tester);
    final sourceA = _storedSource(
      id: 1,
      raw: <String, Object?>{
        'sourceName': 'A',
        'weight': '1',
        'searchBook': <String, Object?>{
          'actionID': 'searchBook',
          'parserID': 'DOM',
          'requestInfo': '/a-search',
          'bookName': './/a/text()',
        },
      },
    );
    final sourceB = _storedSource(
      id: 2,
      raw: <String, Object?>{
        'sourceName': 'B',
        'weight': '9',
        'searchBook': <String, Object?>{
          'actionID': 'searchBook',
          'parserID': 'DOM',
          'requestInfo': '/b-search',
          'bookName': './/b/text()',
        },
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SourceEditor(source: sourceA, onSave: (_) async {})),
      ),
    );

    await tester.enterText(find.byKey(const Key('source-editor-name')), 'A 草稿');
    await tester.enterText(
      _ruleTextFieldFinder(const Key('search-book-book-name')),
      'A 搜索草稿',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SourceEditor(source: sourceB, onSave: (_) async {})),
      ),
    );
    await tester.pump();

    expect(
      tester.widget<TextFormField>(find.byKey(const Key('source-editor-name'))).controller?.text,
      'B',
    );
    expect(
      _ruleTextFormField(tester, const Key('search-book-request-info')).initialValue,
      '/b-search',
    );
    expect(
      _ruleTextFormField(tester, const Key('search-book-book-name')).initialValue,
      './/b/text()',
    );
  });
}

StoredSource _storedSource({required int id, required Map<String, Object?> raw}) {
  final ts = DateTime.utc(2026, 9, 2, 8);
  return StoredSource(
    id: id,
    platform: 'StandarReader',
    document: SourceDocument.fromRaw(raw),
    createdAt: ts,
    updatedAt: ts,
  );
}

void _useTallSurface(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1200, 3000);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

TextFormField _ruleTextFormField(WidgetTester tester, Key key) {
  return tester.widget<TextFormField>(
    find.descendant(of: find.byKey(key), matching: find.byType(TextFormField)),
  );
}

Finder _ruleTextFieldFinder(Key key) {
  return find.descendant(of: find.byKey(key), matching: find.byType(TextField));
}
