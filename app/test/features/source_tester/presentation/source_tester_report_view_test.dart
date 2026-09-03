import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:source_reader/features/source_tester/domain/source_http.dart';
import 'package:source_reader/features/source_tester/domain/source_test_report.dart';
import 'package:source_reader/features/source_tester/presentation/source_tester_report_view.dart';

void main() {
  testWidgets('四个调试 Tab 展示结果、请求、响应与解析日志', (tester) async {
    final report = _report();
    await tester.pumpWidget(_wrap(SourceTesterReportView(report: report)));

    expect(find.byKey(const Key('source-tester-tab-results')), findsOneWidget);
    expect(find.text('测试书籍'), findsOneWidget);
    expect(find.text('作者甲'), findsOneWidget);

    await tester.tap(find.byKey(const Key('source-tester-tab-request')));
    await tester.pumpAndSettle();
    expect(find.textContaining('GET'), findsWidgets);
    expect(find.textContaining('https://example.com/search?q=test'), findsOneWidget);
    expect(find.textContaining('X-Test: yes'), findsOneWidget);

    await tester.tap(find.byKey(const Key('source-tester-tab-response')));
    await tester.pumpAndSettle();
    expect(find.textContaining('200'), findsWidgets);
    expect(find.textContaining('utf8'), findsOneWidget);
    expect(find.textContaining('<html>ok</html>'), findsOneWidget);

    await tester.tap(find.byKey(const Key('source-tester-tab-traces')));
    await tester.pumpAndSettle();
    expect(find.textContaining('detailUrl'), findsOneWidget);
    expect(find.textContaining('//a/@href || @js: result'), findsOneWidget);
    expect(find.textContaining('JS 阶段未执行'), findsOneWidget);
    expect(find.textContaining('部分执行'), findsOneWidget);
  });

  testWidgets('响应正文超过 200000 字符时截断并显示提示', (tester) async {
    final body = '${'a' * 200000}TAIL_SHOULD_NOT_RENDER';
    await tester.pumpWidget(
      _wrap(SourceTesterReportView(report: _report(body: body))),
    );

    await tester.tap(find.byKey(const Key('source-tester-tab-response')));
    await tester.pumpAndSettle();

    expect(find.textContaining('正文过长，已仅显示前 200000 个字符'), findsOneWidget);
    expect(find.textContaining('TAIL_SHOULD_NOT_RENDER'), findsNothing);
  });
}

SearchBookTestReport _report({String body = '<html>ok</html>'}) {
  return SearchBookTestReport(
    sourceId: 7,
    sourceName: '已保存书源',
    platform: 'StandarReader',
    input: const SearchBookTestInputSnapshot(
      keyWord: 'test',
      pageIndex: 1,
      offset: 0,
      filter: '',
    ),
    request: SourceTestRequestSnapshot(
      originalRequestInfo: '/search?q=%@keyWord',
      uri: Uri.parse('https://example.com/search?q=test'),
      method: SourceHttpMethod.get,
      headers: const <String, String>{'X-Test': 'yes'},
    ),
    response: SourceTestResponseSnapshot(
      statusCode: 200,
      finalUri: Uri.parse('https://example.com/search?q=test'),
      headers: const <String, String>{'content-type': 'text/html'},
      duration: const Duration(milliseconds: 125),
      byteCount: body.length,
      encoding: 'utf8',
      decodedBody: body,
    ),
    items: const <SearchBookTestItem>[
      SearchBookTestItem(
        bookName: '测试书籍',
        author: '作者甲',
        detailUrl: 'https://example.com/book/1',
      ),
    ],
    traces: <SourceRuleTrace>[
      SourceRuleTrace(
        field: 'detailUrl',
        rule: '//a/@href || @js: result',
        stages: const <String>['//a/@href', '@js: result'],
        outputSummary: 'https://example.com/book/1',
        warnings: const <String>['JS 阶段未执行: @js: result'],
        errors: const <String>[],
        partial: true,
      ),
    ],
    warnings: const <String>['detailUrl 含未执行脚本'],
    outcome: SearchBookTestOutcome.completedWithWarnings,
  );
}

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}
