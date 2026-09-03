import 'package:flutter/material.dart';
import 'package:source_reader/features/sources/application/source_export.dart';

typedef SourceExportSelectionCallback = Future<void> Function(
  SourceExportScope scope,
  SourceExportFormat format,
);

final class SourceExportMenu extends StatelessWidget {
  const SourceExportMenu({
    super.key,
    required this.canExportCurrent,
    required this.onExport,
  });

  final bool canExportCurrent;
  final SourceExportSelectionCallback onExport;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<SourceExportScope>(
      key: const Key('source-export-menu'),
      onSelected: (scope) => _selectFormat(context, scope),
      itemBuilder: (context) => [
        PopupMenuItem<SourceExportScope>(
          key: const Key('source-export-current'),
          value: SourceExportScope.current,
          enabled: canExportCurrent,
          child: const Text('导出当前'),
        ),
        const PopupMenuItem<SourceExportScope>(
          key: Key('source-export-all'),
          value: SourceExportScope.all,
          child: Text('导出全部'),
        ),
      ],
    );
  }

  Future<void> _selectFormat(BuildContext context, SourceExportScope scope) async {
    final format = await showDialog<SourceExportFormat>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('source-export-format-dialog'),
        title: const Text('选择导出格式'),
        actions: [
          TextButton(
            key: const Key('source-export-format-json'),
            onPressed: () => Navigator.of(context).pop(SourceExportFormat.json),
            child: const Text('JSON'),
          ),
          TextButton(
            key: const Key('source-export-format-xbs'),
            onPressed: () => Navigator.of(context).pop(SourceExportFormat.xbs),
            child: const Text('XBS'),
          ),
          TextButton(
            key: const Key('source-export-format-cancel'),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
        ],
      ),
    );
    if (format == null) {
      return;
    }
    await onExport(scope, format);
  }
}
