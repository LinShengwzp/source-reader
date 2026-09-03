import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:source_reader/features/sources/domain/source_document.dart';
import 'package:source_reader/features/sources/presentation/source_search_book_draft.dart';
import 'package:source_reader/features/sources/presentation/source_search_book_editor.dart';

void main() {
  testWidgets('行为 A：从 Draft 初始化代表字段', (tester) async {
    final draft = _draftWithRepresentativeValues();

    await tester.pumpWidget(_wrap(SearchBookEditor(value: draft, onChanged: (_) {})));

    expect(find.byKey(const Key('search-book-request-info')), findsOneWidget);
    expect(find.byKey(const Key('search-book-book-name')), findsOneWidget);
    expect(find.byKey(const Key('search-book-author')), findsOneWidget);

    expect(
      _textFormFieldForKey(tester, const Key('search-book-request-info')).initialValue,
      '/search?q=%@keyWord',
    );
    expect(
      _textFormFieldForKey(tester, const Key('search-book-book-name')).initialValue,
      './/h3/text()',
    );
    expect(
      _textFormFieldForKey(tester, const Key('search-book-author')).initialValue,
      './/span/text()',
    );

    await tester.ensureVisible(find.byKey(const Key('search-book-advanced')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('search-book-advanced')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('search-book-response-format-type')), findsOneWidget);
    expect(find.byKey(const Key('search-book-js-parser')), findsOneWidget);
    expect(find.byKey(const Key('search-book-more-keys')), findsOneWidget);

    expect(find.text('JSON 结构'), findsOneWidget);

    expect(
      _textFormFieldForKey(tester, const Key('search-book-js-parser')).initialValue,
      'return result;',
    );
    expect(
      _textFormFieldForKey(tester, const Key('search-book-more-keys')).initialValue,
      '{"pageSize":20}',
    );
  });

  testWidgets('行为 B：编辑 bookName 发出新 Draft 且其他值不变', (tester) async {
    final original = SourceSearchBookDraft.fromDocument(null).copyWith(
      bookName: '旧书名规则',
      author: '作者规则',
      requestInfo: '请求规则',
    );
    SourceSearchBookDraft? changed;

    await tester.pumpWidget(
      _wrap(SearchBookEditor(value: original, onChanged: (v) => changed = v)),
    );

    await tester.enterText(
      _textFieldFinderForKey(const Key('search-book-book-name')),
      '新书名规则',
    );
    await tester.pump();

    expect(changed, isNotNull);
    expect(changed!.bookName, '新书名规则');
    expect(changed!.author, original.author);
    expect(changed!.requestInfo, original.requestInfo);
  });

  testWidgets('行为 C：已知 enum 选择传协议值', (tester) async {
    final draft = SourceSearchBookDraft.fromDocument(null).copyWith(responseFormatType: 'str');
    SourceSearchBookDraft? changed;

    await tester.pumpWidget(
      _wrap(SearchBookEditor(value: draft, onChanged: (v) => changed = v)),
    );

    await tester.ensureVisible(find.byKey(const Key('search-book-advanced')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('search-book-advanced')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('search-book-response-format-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('search-book-response-format-type')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('JSON 结构').last);
    await tester.pumpAndSettle();

    expect(changed, isNotNull);
    expect(changed!.responseFormatType, 'json');
  });

  testWidgets('行为 D：未知 enum 原样展示', (tester) async {
    final draft = SourceSearchBookDraft.fromDocument(null).copyWith(
      responseFormatType: 'future-format',
    );
    var callCount = 0;

    await tester.pumpWidget(
      _wrap(SearchBookEditor(value: draft, onChanged: (_) => callCount++)),
    );

    await tester.ensureVisible(find.byKey(const Key('search-book-advanced')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('search-book-advanced')));
    await tester.pumpAndSettle();

    expect(find.text('未知值：future-format'), findsOneWidget);
    expect(callCount, 0);
  });

  testWidgets('行为 E：高级字段可达且多行', (tester) async {
    final draft = SourceSearchBookDraft.fromDocument(null);

    await tester.pumpWidget(_wrap(SearchBookEditor(value: draft, onChanged: (_) {})));

    expect(find.byKey(const Key('search-book-advanced')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('search-book-advanced')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('search-book-advanced')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('search-book-js-parser')), findsOneWidget);
    expect(find.byKey(const Key('search-book-more-keys')), findsOneWidget);

    expect(_isMultiline(tester, const Key('search-book-js-parser')), isTrue);
    expect(_isMultiline(tester, const Key('search-book-more-keys')), isTrue);
    expect(_isMultiline(tester, const Key('search-book-request-info')), isTrue);
  });

  testWidgets('行为 F：非法结构化 moreKeys 显示 Draft 的本地错误', (tester) async {
    final source = SourceDocument.fromRaw(<String, Object?>{
      'searchBook': <String, Object?>{
        'actionID': 'searchBook',
        'parserID': 'DOM',
        'moreKeys': <String, Object?>{'pageSize': 20},
      },
    });
    SourceSearchBookDraft draft = SourceSearchBookDraft.fromDocument(source.searchBook);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return SingleChildScrollView(
                child: SearchBookEditor(
                  value: draft,
                  onChanged: (v) => setState(() => draft = v),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.byKey(const Key('search-book-advanced')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('search-book-advanced')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('search-book-more-keys')));
    await tester.pumpAndSettle();
    await tester.enterText(
      _textFieldFinderForKey(const Key('search-book-more-keys')),
      '{bad json',
    );
    await tester.pumpAndSettle();

    expect(find.text('moreKeys 必须是有效 JSON 对象或数组'), findsOneWidget);
  });
}

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));
}

SourceSearchBookDraft _draftWithRepresentativeValues() {
  return SourceSearchBookDraft.fromDocument(null).copyWith(
    requestInfo: '/search?q=%@keyWord',
    list: '//div[@class="book"]',
    bookName: './/h3/text()',
    author: './/span/text()',
    cover: './/img/@src',
    desc: './/p/text()',
    cat: './/i/text()',
    status: './/b/text()',
    wordCount: './/em/text()',
    lastChapterTitle: './/a/text()',
    detailUrl: './/a/@href',
    requestParamsEncode: 'utf-8',
    responseEncode: 'utf-8',
    responseFormatType: 'json',
    success: 'true',
    jsParser: 'return result;',
    moreKeysText: '{"pageSize":20}',
  );
}

TextFormField _textFormFieldForKey(WidgetTester tester, Key key) {
  return tester.widget<TextFormField>(
    find.descendant(of: find.byKey(key), matching: find.byType(TextFormField)),
  );
}

Finder _textFieldFinderForKey(Key key) {
  return find.descendant(of: find.byKey(key), matching: find.byType(TextField));
}

bool _isMultiline(WidgetTester tester, Key key) {
  final textField = tester.widget<TextField>(_textFieldFinderForKey(key));
  final maxLines = textField.maxLines;
  final minLines = textField.minLines;
  if (maxLines == null) return true;
  if (maxLines > 1) return true;
  if (minLines != null && minLines > 1) return true;
  return false;
}
