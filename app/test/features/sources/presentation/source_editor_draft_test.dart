import 'package:flutter_test/flutter_test.dart';
import 'package:source_reader/features/sources/domain/source_document.dart';
import 'package:source_reader/features/sources/presentation/source_editor_draft.dart';

void main() {
  test('从 SourceDocument 提取四个基础编辑字段', () {
    final original = SourceDocument.fromRaw(<String, Object?>{
      'sourceName': '旧名称',
      'sourceUrl': ' https://old.example ',
      'enable': '1',
      'weight': '7',
      'futureRule': <String, Object?>{
        'nested': <Object?>['keep', 42],
      },
    });

    final draft = SourceEditorDraft.fromDocument(original);

    expect(draft.sourceName, '旧名称');
    expect(draft.sourceUrl, ' https://old.example ');
    expect(draft.enabled, isTrue);
    expect(draft.weight, '7');
  });

  test('applyTo 只修改已知字段并保留未知 raw JSON 与历史表达类型', () {
    final original = SourceDocument.fromRaw(<String, Object?>{
      'sourceName': '旧名称',
      'sourceUrl': ' https://old.example ',
      'enable': '1',
      'weight': '7',
      'futureRule': <String, Object?>{
        'nested': <Object?>['keep', 42],
      },
    });

    final updated = const SourceEditorDraft(
      sourceName: '  新名称  ',
      sourceUrl: ' https://new.example ',
      enabled: false,
      weight: ' 12 ',
    ).applyTo(original);

    expect(updated.sourceName, '新名称');
    expect(updated.sourceUrl, 'https://new.example');
    expect(updated.enabled, isFalse);
    expect(updated.weight, 12);
    expect(updated.toRaw()['enable'], '0');
    expect(updated.toRaw()['weight'], '12');
    expect(
      updated.toRaw()['futureRule'],
      equals(original.toRaw()['futureRule']),
    );

    final typedOriginal = SourceDocument.fromRaw(<String, Object?>{
      'enable': true,
      'weight': 3,
    });
    final typedDraft = SourceEditorDraft.fromDocument(typedOriginal);
    expect(typedDraft.sourceName, '');
    expect(typedDraft.sourceUrl, '');

    final typedUpdated = const SourceEditorDraft(
      sourceName: '名称',
      sourceUrl: '',
      enabled: false,
      weight: '9',
    ).applyTo(typedOriginal);

    expect(typedUpdated.toRaw()['enable'], isA<bool>());
    expect(typedUpdated.toRaw()['enable'], isFalse);
    expect(typedUpdated.toRaw()['weight'], isA<int>());
    expect(typedUpdated.toRaw()['weight'], 9);
  });
}
