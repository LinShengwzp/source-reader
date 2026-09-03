import 'package:flutter/material.dart';
import 'package:source_reader/features/sources/data/source_repository.dart';
import 'package:source_reader/features/sources/domain/source_document.dart';
import 'package:source_reader/features/sources/presentation/source_basic_editor_section.dart';
import 'package:source_reader/features/sources/presentation/source_editor_draft.dart';
import 'package:source_reader/features/sources/presentation/source_search_book_draft.dart';
import 'package:source_reader/features/sources/presentation/source_search_book_editor.dart';

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
  late SourceSearchBookDraft _searchBookDraft;
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
    final basic = SourceEditorDraft.fromDocument(source.document);
    _nameController.text = basic.sourceName;
    _urlController.text = basic.sourceUrl;
    _weightController.text = basic.weight;
    _enabled = basic.enabled;
    _searchBookDraft = SourceSearchBookDraft.fromDocument(source.document.searchBook);
  }

  Future<void> _save() async {
    if (_saving) return;

    final basicValid = _formKey.currentState!.validate();
    final searchBookValid = _searchBookDraft.moreKeysValidationError == null;
    if (!basicValid || !searchBookValid) return;

    setState(() => _saving = true);
    try {
      final basicDraft = SourceEditorDraft(
        sourceName: _nameController.text,
        sourceUrl: _urlController.text,
        enabled: _enabled,
        weight: _weightController.text,
      );
      final withBasicFields = basicDraft.applyTo(widget.source.document);
      final document = _searchBookDraft.applyTo(withBasicFields);
      await widget.onSave(document);
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
          SourceBasicEditorSection(
            nameController: _nameController,
            urlController: _urlController,
            weightController: _weightController,
            enabled: _enabled,
            onEnabledChanged: (value) => setState(() => _enabled = value),
          ),
          const SizedBox(height: 24),
          SearchBookEditor(
            key: ValueKey<int>(widget.source.id),
            value: _searchBookDraft,
            onChanged: (value) {
              setState(() => _searchBookDraft = value);
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
