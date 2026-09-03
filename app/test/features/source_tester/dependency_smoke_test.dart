import 'package:enough_convert/enough_convert.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:json_path/json_path.dart';
import 'package:xpath_selector_html_parser/xpath_selector_html_parser.dart';

void main() {
  test('Source Tester dependencies resolve together', () {
    final client = http.Client();
    addTearDown(client.close);

    final jsonPath = JsonPath(r'$');
    final html = HtmlXPath.html('<html><body>ok</body></html>');

    expect(jsonPath.read(<String, Object?>{'ok': true}), isNotEmpty);
    expect(html.query('//body').nodes, isNotEmpty);
    expect(gbk.decode(gbk.encode('中文')), '中文');
  });
}
