import 'package:flutter/material.dart';

/// SourceEditor 的基础书源信息区。
///
/// 只负责四个已知字段的表单展示与本地校验；编辑 session 仍由外层 SourceEditor 持有。
final class SourceBasicEditorSection extends StatelessWidget {
  const SourceBasicEditorSection({
    super.key,
    required this.nameController,
    required this.urlController,
    required this.weightController,
    required this.enabled,
    required this.onEnabledChanged,
  });

  final TextEditingController nameController;
  final TextEditingController urlController;
  final TextEditingController weightController;
  final bool enabled;
  final ValueChanged<bool> onEnabledChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextFormField(
          key: const Key('source-editor-name'),
          controller: nameController,
          decoration: const InputDecoration(labelText: '书源名称'),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return '书源名称不能为空';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: const Key('source-editor-url'),
          controller: urlController,
          decoration: const InputDecoration(labelText: '书源地址'),
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            const Text('启用'),
            const SizedBox(width: 12),
            Switch(
              key: const Key('source-editor-enabled'),
              value: enabled,
              onChanged: onEnabledChanged,
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: const Key('source-editor-weight'),
          controller: weightController,
          decoration: const InputDecoration(labelText: '权重'),
          validator: (value) {
            if (value == null || int.tryParse(value.trim()) == null) {
              return '权重必须是整数';
            }
            return null;
          },
        ),
      ],
    );
  }
}
