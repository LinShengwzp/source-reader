import 'package:flutter_test/flutter_test.dart';
import 'package:source_reader/features/sources/domain/source_action_document.dart';
import 'package:source_reader/features/sources/domain/source_rule_options.dart';

void main() {
  test('读取共同 action 字段并只改显式已知字段', () {
    final input = <String, Object?>{
      'actionID': 'searchBook',
      'parserID': 'DOM',
      'requestInfo': 'old-request',
      'responseFormatType': 'future-format',
      'moreKeys': <String, Object?>{'pageSize': 20},
      'futureActionField': <String, Object?>{'keep': true},
    };
    final original = SourceActionDocument.fromRaw(input);

    expect(original.actionId, 'searchBook');
    expect(original.parserId, 'DOM');
    expect(original.requestInfo, 'old-request');
    expect(original.responseFormatType, 'future-format');
    expect(original.moreKeysRaw, <String, Object?>{'pageSize': 20});

    input['requestInfo'] = 'mutated-outside';
    expect(original.requestInfo, 'old-request');

    final changed = original.copyWithKnownFields(
      requestInfo: 'new-request',
      responseEncode: 'utf-8',
    );
    expect(changed.requestInfo, 'new-request');
    expect(changed.responseEncode, 'utf-8');
    expect(changed.toRaw()['actionID'], 'searchBook');
    expect(changed.toRaw()['parserID'], 'DOM');
    expect(
      changed.toRaw()['futureActionField'],
      <String, Object?>{'keep': true},
    );
    expect(changed.toRaw()['responseFormatType'], 'future-format');

    final exported = changed.toRaw();
    exported['requestInfo'] = 'mutated-copy';
    expect(changed.requestInfo, 'new-request');
  });

  test('规则枚举常量保持香色闺阁历史值与展示标签', () {
    expect(
      SourceRuleOptions.requestParamsEncode
          .map((option) => (option.value, option.label))
          .toList(),
      <(String, String)>[
        ('utf-8', 'utf-8'),
        ('2147485234', 'gbk'),
      ],
    );
    expect(
      SourceRuleOptions.responseEncode
          .map((option) => (option.value, option.label))
          .toList(),
      <(String, String)>[
        ('utf-8', 'utf-8'),
        ('2147485232', '简体中文(gb2312)'),
        ('2147485234', '简体中文(gbk)'),
      ],
    );
    expect(
      SourceRuleOptions.responseFormatType
          .map((option) => (option.value, option.label))
          .toList(),
      <(String, String)>[
        ('str', '普通字符串'),
        ('base64str', 'Base64 字符串'),
        ('html', 'DOM'),
        ('xml', 'XML 结构'),
        ('json', 'JSON 结构'),
        ('data', '原始数据流'),
        ('filePath', '文件路径'),
      ],
    );
  });
}
