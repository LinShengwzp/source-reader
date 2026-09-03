import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:source_reader/features/source_tester/presentation/source_tester_page.dart';
import 'package:source_reader/features/sources/application/source_controller.dart';
import 'package:source_reader/features/sources/application/source_export.dart';
import 'package:source_reader/features/sources/application/source_providers.dart';
import 'package:source_reader/features/sources/application/source_selection.dart';
import 'package:source_reader/features/sources/data/source_repository.dart';
import 'package:source_reader/features/sources/domain/source_document.dart';
import 'package:source_reader/features/sources/presentation/source_editor.dart';
import 'package:source_reader/features/sources/presentation/source_export_menu.dart';
import 'package:source_reader/features/sources/presentation/source_list.dart';

/// Source Workbench 第一阶段页面壳。
///
/// 负责列表、当前选择与编辑器的组合，不在 Presentation 层直接访问数据库。
final class SourcePage extends ConsumerWidget {
  const SourcePage({super.key});

  static const double _wideBreakpoint = 840;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sources = ref.watch(sourceControllerProvider);
    final selectedId = ref.watch(sourceSelectionProvider);

    ref.listen(sourceControllerProvider, (previous, next) {
      next.whenData((items) {
        final currentId = ref.read(sourceSelectionProvider);
        if (currentId == null) {
          return;
        }
        final stillExists = items.any((item) => item.id == currentId);
        if (!stillExists) {
          ref.read(sourceSelectionProvider.notifier).clear();
        }
      });
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Source Workbench'),
        actions: [
          IconButton(
            tooltip: '导入书源',
            onPressed: () => _importSource(context, ref),
            icon: const Icon(Icons.file_upload_outlined),
          ),
          IconButton(
            key: const Key('source-test-action'),
            tooltip: '测试书源',
            onPressed: selectedId == null
                ? null
                : () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => SourceTesterPage(sourceId: selectedId),
                      ),
                    );
                  },
            icon: const Icon(Icons.science_outlined),
          ),
          SourceExportMenu(
            canExportCurrent: selectedId != null,
            onExport: (scope, format) => _exportSource(
              context,
              ref,
              scope: scope,
              format: format,
              selectedId: selectedId,
            ),
          ),
          IconButton(
            tooltip: '重新加载',
            onPressed: () {
              ref.read(sourceControllerProvider.notifier).reload();
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: sources.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stackTrace) => _ErrorState(
          onRetry: () {
            ref.read(sourceControllerProvider.notifier).reload();
          },
        ),
        data: (items) => _SourceLayout(
          sources: items,
          selectedId: selectedId,
          onSelected: (id) {
            ref.read(sourceSelectionProvider.notifier).select(id);
          },
          onBack: () {
            ref.read(sourceSelectionProvider.notifier).clear();
          },
          onSave: (source, document) =>
              _saveSource(context, ref, source, document),
        ),
      ),
    );
  }

  Future<void> _importSource(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final payload = await ref.read(sourceFilePickerProvider).pickSourceFile();
    if (payload == null) {
      return;
    }

    try {
      final result =
          await ref.read(sourceControllerProvider.notifier).importPayload(
                payload,
              );
      messenger.showSnackBar(
        SnackBar(content: Text('已导入 ${result.importedCount} 个书源')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('导入失败：$e')),
      );
    }
  }

  /// 只从持久化 Repository 构建导出内容，不读取编辑器中的未保存 Draft。
  Future<void> _exportSource(
    BuildContext context,
    WidgetRef ref, {
    required SourceExportScope scope,
    required SourceExportFormat format,
    required int? selectedId,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final service = ref.read(sourceExportServiceProvider);
      final payload = switch (scope) {
        SourceExportScope.current => await service.buildCurrent(
            id: selectedId!,
            format: format,
          ),
        SourceExportScope.all => await service.buildAll(format: format),
      };
      final saved = await ref.read(sourceFileSaverProvider).save(payload);
      if (!saved || !messenger.mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('已导出 ${payload.exportedCount} 个书源')),
      );
    } on SourceExportException catch (error) {
      if (!messenger.mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text(_exportErrorMessage(error.reason))),
      );
    } catch (error) {
      if (!messenger.mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('导出失败：$error')),
      );
    }
  }

  Future<void> _saveSource(
    BuildContext context,
    WidgetRef ref,
    StoredSource source,
    SourceDocument document,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(sourceControllerProvider.notifier).updateSource(
            id: source.id,
            document: document,
          );
      if (!messenger.mounted) {
        return;
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('已保存')),
      );
    } catch (error) {
      if (!messenger.mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('保存失败：$error')),
      );
    }
  }
}

String _exportErrorMessage(SourceExportFailureReason reason) {
  return switch (reason) {
    SourceExportFailureReason.notFound => '当前书源已不存在',
    SourceExportFailureReason.unsupportedPlatform => '当前书源平台暂不支持导出',
    SourceExportFailureReason.empty => '没有可导出的书源',
    SourceExportFailureReason.encodingFailed => '导出编码失败',
  };
}

typedef _SourceSaveCallback = Future<void> Function(
  StoredSource source,
  SourceDocument document,
);

final class _SourceLayout extends StatelessWidget {
  const _SourceLayout({
    required this.sources,
    required this.selectedId,
    required this.onSelected,
    required this.onBack,
    required this.onSave,
  });

  final List<StoredSource> sources;
  final int? selectedId;
  final ValueChanged<int> onSelected;
  final VoidCallback onBack;
  final _SourceSaveCallback onSave;

  @override
  Widget build(BuildContext context) {
    final selectedSource = _findSelectedSource();

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= SourcePage._wideBreakpoint) {
          return Row(
            children: [
              SizedBox(
                key: const Key('source-master-pane'),
                width: 320,
                child: SourceList(
                  sources: sources,
                  selectedId: selectedId,
                  onSelected: onSelected,
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                key: const Key('source-detail-pane'),
                child: selectedSource == null
                    ? const Center(
                        child: Text('选择一个书源开始编辑'),
                      )
                    : SourceEditor(
                        source: selectedSource,
                        onSave: (document) => onSave(selectedSource, document),
                      ),
              ),
            ],
          );
        }

        if (selectedSource != null) {
          return SizedBox.expand(
            child: SourceEditor(
              source: selectedSource,
              onSave: (document) => onSave(selectedSource, document),
              onBack: onBack,
            ),
          );
        }

        return SizedBox.expand(
          key: const Key('source-master-pane'),
          child: SourceList(
            sources: sources,
            selectedId: selectedId,
            onSelected: onSelected,
          ),
        );
      },
    );
  }

  StoredSource? _findSelectedSource() {
    final id = selectedId;
    if (id == null) {
      return null;
    }
    for (final source in sources) {
      if (source.id == id) {
        return source;
      }
    }
    return null;
  }
}

final class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('加载书源失败'),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onRetry,
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }
}
