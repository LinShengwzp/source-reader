import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:source_reader/features/sources/application/source_providers.dart';
import 'package:source_reader/features/sources/data/source_repository.dart';

final sourceControllerProvider =
    AsyncNotifierProvider<SourceController, List<StoredSource>>(
  SourceController.new,
);

/// Source Workbench 的书源列表状态入口。
///
/// 第一阶段只负责初始加载与显式刷新，编辑/删除/导入行为后续按独立任务增加。
final class SourceController extends AsyncNotifier<List<StoredSource>> {
  @override
  Future<List<StoredSource>> build() {
    return ref.watch(sourceRepositoryProvider).listSources();
  }

  Future<void> reload() async {
    state = const AsyncLoading<List<StoredSource>>();
    state = await AsyncValue.guard(
      () => ref.read(sourceRepositoryProvider).listSources(),
    );
  }
}
