import 'package:flutter/material.dart';
import 'package:source_reader/features/sources/data/source_repository.dart';
import 'package:source_reader/features/sources/domain/source_document.dart';
import 'package:source_reader/features/sources/presentation/source_editor_draft.dart';

typedef SourceDocumentSaveCallback = Future<void> Function(SourceDocument document);

final class SourceEditor extends StatefulWidget {
  const SourceEditor({super.key, required this.source, required this.onSave, this.onBack});

  final StoredSource source;
  final SourceDocumentSaveCallback onSave;
  final VoidCallback? onBack;

  @override
  State<SourceEditor> createState() => _SourceEditorState();
}

final class _SourceEditorState extends State<SourceEditor> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _urlController;
  late final TextEditingController _weightController;
  bool _enabled = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _urlController = TextEditingController();
    _weightController = TextEditingController();
    _loadSource(widget.source);
  }

  @override
  void didUpdateWidget(covariant SourceEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source.id != widget.source.id) {
      _loadSource(widget.source);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _loadSource(StoredSource source) {
    final draft = SourceEditorDraft.fromDocument(source.document);
    _nameController.text = draft.sourceName;
    _urlController.text = draft.sourceUrl;
    _weightController.text = draft.weight;
    _enabled = draft.enabled;
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    try {
      final draft = SourceEditorDraft(
        sourceName: _nameController.text,
        sourceUrl: _urlController.text,
        enabled: _enabled,
        weight: _weightController.text,
      );
      await widget.onSave(draft.applyTo(widget.source.document));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          if (widget.onBack != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('source-editor-back'),
                onPressed: widget.onBack,
                child: const Text('返回'),
              ),
            ),
          TextFormField(
            key: const Key('source-editor-name'),
            controller: _nameController,
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
            controller: _urlController,
            decoration: const InputDecoration(labelText: '书源地址'),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              const Text('启用'),
              const SizedBox(width: 12),
              Switch(
                key: const Key('source-editor-enabled'),
                value: _enabled,
                onChanged: (value) => setState(() => _enabled = value),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('source-editor-weight'),
            controller: _weightController,
            decoration: const InputDecoration(labelText: '权重'),
            validator: (value) {
              if (value == null || int.tryParse(value.trim()) == null) {
                return '权重必须是整数';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('source-editor-save'),
            onPressed: _saving ? null : _save,
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}
