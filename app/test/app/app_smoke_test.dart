import 'package:flutter_test/flutter_test.dart';
import 'package:source_reader/app/app.dart';

void main() {
  testWidgets('应用启动后显示 Source Workbench 首页', (tester) async {
    await tester.pumpWidget(const SourceReaderApp());

    expect(find.text('Source Workbench'), findsOneWidget);
  });
}
