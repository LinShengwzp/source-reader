import 'package:flutter/material.dart';

final class SourceTesterInput {
  const SourceTesterInput({
    required this.keyWord,
    required this.pageIndex,
    required this.offset,
    required this.filter,
  });

  final String keyWord;
  final int pageIndex;
  final int offset;
  final String filter;
}

final class SourceTesterInputPanel extends StatelessWidget {
  const SourceTesterInputPanel({
    super.key,
    required this.running,
    required this.onRun,
  });

  final bool running;
  final ValueChanged<SourceTesterInput> onRun;

  @override
  Widget build(BuildContext context) {
    return _SourceTesterInputForm(running: running, onRun: onRun);
  }
}

class _SourceTesterInputForm extends StatefulWidget {
  const _SourceTesterInputForm({
    required this.running,
    required this.onRun,
  });

  final bool running;
  final ValueChanged<SourceTesterInput> onRun;

  @override
  State<_SourceTesterInputForm> createState() => _SourceTesterInputFormState();
}

class _SourceTesterInputFormState extends State<_SourceTesterInputForm> {
  final _formKey = GlobalKey<FormState>();
  final _keywordController = TextEditingController();
  final _pageIndexController = TextEditingController(text: '1');
  final _offsetController = TextEditingController(text: '0');
  final _filterController = TextEditingController();
  bool _advancedExpanded = false;

  @override
  void dispose() {
    _keywordController.dispose();
    _pageIndexController.dispose();
    _offsetController.dispose();
    _filterController.dispose();
    super.dispose();
  }

  void _handleRun() {
    if (widget.running) return;

    final offset = int.tryParse(_offsetController.text.trim());
    if (offset == null || offset < 0) {
      if (!_advancedExpanded) {
        setState(() => _advancedExpanded = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _formKey.currentState?.validate();
          }
        });
      } else {
        _formKey.currentState?.validate();
      }
      return;
    }

    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) return;

    final pageIndex = int.tryParse(_pageIndexController.text.trim());
    if (pageIndex == null) return;

    widget.onRun(
      SourceTesterInput(
        keyWord: _keywordController.text.trim(),
        pageIndex: pageIndex,
        offset: offset,
        filter: _filterController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextFormField(
              key: const Key('source-tester-input-keyword'),
              controller: _keywordController,
              decoration: const InputDecoration(
                labelText: '关键词',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入关键词';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('source-tester-input-page-index'),
              controller: _pageIndexController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '页码',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final text = (value ?? '').trim();
                final parsed = int.tryParse(text);
                if (parsed == null || parsed < 1) {
                  return '页码必须为大于等于 1 的整数';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              key: const Key('source-tester-input-advanced-toggle'),
              title: const Text('高级参数'),
              trailing: Icon(
                _advancedExpanded ? Icons.expand_less : Icons.expand_more,
              ),
              onTap: () =>
                  setState(() => _advancedExpanded = !_advancedExpanded),
            ),
            if (_advancedExpanded)
              Padding(
                key: const Key('source-tester-input-advanced'),
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextFormField(
                      key: const Key('source-tester-input-offset'),
                      controller: _offsetController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '偏移量',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final text = (value ?? '').trim();
                        final parsed = int.tryParse(text);
                        if (parsed == null || parsed < 0) {
                          return '偏移量必须为大于等于 0 的整数';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const Key('source-tester-input-filter'),
                      controller: _filterController,
                      decoration: const InputDecoration(
                        labelText: '过滤',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('source-tester-input-run'),
              onPressed: widget.running ? null : _handleRun,
              child: const Text('运行'),
            ),
          ],
        ),
      ),
    );
  }
}
