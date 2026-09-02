import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:source_reader/features/sources/application/source_controller.dart';
import 'package:source_reader/features/sources/application/source_providers.dart';
import 'package:source_reader/features/sources/data/source_repository.dart';
import 'package:source_reader/features/sources/presentation/source_list.dart';

/// Source Workbench 第一阶段页面壳。
///
/// 只负责展示加载状态与宽窄屏布局，不在 Presentation 层直接访问数据库。
final class SourcePage extends ConsumerWidget {
  const SourcePage({super.key});

  static const double _wideBreakpoint = 840;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sources = ref.watch(sourceControllerProvider);

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
        data: (items) => _SourceLayout(sources: items),
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
}

final class _SourceLayout extends StatelessWidget {
  const _SourceLayout({required this.sources});

  final List<StoredSource> sources;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= SourcePage._wideBreakpoint) {
          return Row(
            children: [
              SizedBox(
                key: const Key('source-master-pane'),
                width: 320,
                child: SourceList(sources: sources),
              ),
              const VerticalDivider(width: 1),
              const Expanded(
                key: Key('source-detail-pane'),
                child: Center(
                  child: Text('选择一个书源开始编辑'),
                ),
              ),
            ],
          );
        }

        return SizedBox.expand(
          key: const Key('source-master-pane'),
          child: SourceList(sources: sources),
        );
      },
    );
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
