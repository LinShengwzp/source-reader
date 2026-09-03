import 'package:flutter/material.dart';
import 'package:source_reader/features/sources/domain/source_rule_options.dart';

/// 规则编辑器使用的通用文本输入字段。
///
/// 不持有业务状态，不知道 SourceDocument 或 raw JSON。
final class RuleTextField extends StatelessWidget {
  const RuleTextField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.maxLines = 1,
    this.minLines,
    this.errorText,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final int? maxLines;
  final int? minLines;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        errorText: errorText,
        border: const OutlineInputBorder(),
      ),
      maxLines: maxLines,
      minLines: minLines,
      onChanged: onChanged,
    );
  }
}

/// 规则编辑器使用的多行文本输入字段。
final class RuleMultilineField extends StatelessWidget {
  const RuleMultilineField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.errorText,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return RuleTextField(
      label: label,
      value: value,
      onChanged: onChanged,
      maxLines: null,
      minLines: 3,
      errorText: errorText,
    );
  }
}

/// 规则编辑器使用的枚举选择字段。
///
/// 能安全合并未知当前值：如果 [value] 不在 [options] 中，
/// 会额外添加一个临时选项，避免 DropdownButton 抛异常。
final class RuleEnumField extends StatelessWidget {
  const RuleEnumField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<SourceRuleOption> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final knownValues = options.map((o) => o.value).toSet();
    final hasUnknown = value != null && !knownValues.contains(value);

    final items = <DropdownMenuItem<String>>[
      ...options.map(
        (o) => DropdownMenuItem<String>(
          value: o.value,
          child: Text(o.label),
        ),
      ),
      if (hasUnknown)
        DropdownMenuItem<String>(
          value: value,
          child: Text('未知值：$value'),
        ),
    ];

    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: items,
      onChanged: onChanged,
    );
  }
}

/// 规则编辑器中分组的卡片容器。
final class EditorSectionCard extends StatelessWidget {
  const EditorSectionCard({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}
