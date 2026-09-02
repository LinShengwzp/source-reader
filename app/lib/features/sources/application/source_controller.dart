import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:source_reader/features/sources/application/source_import.dart';
import 'package:source_reader/features/sources/application/source_providers.dart';
import 'package:source_reader/features/sources/data/source_repository.dart';
import 'package:source_reader/features/sources/domain/source_document.dart';

final sourceControllerProvider =
    AsyncNotifierProvider<SourceController, List<StoredSource>>(
  SourceController.new,
);

/// Source Workbench 的书源列表状态入口。
///
/// 负责列表加载、显式刷新，以及在导入或保存成功后协调列表刷新。
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

  /// 导入成功后刷新列表；导入失败时保持当前列表状态并继续抛出原异常。
  Future<SourceImportResult> importPayload(SourceImportPayload payload) async {
    final result = await ref.read(sourceImportServiceProvider).importPayload(
          payload,
        );
    await reload();
    return result;
  }

  /// 保存成功后刷新列表；保存失败时保留当前列表状态并继续抛出原异常。
  Future<void> updateSource({
    required int id,
    required SourceDocument document,
  }) async {
    await ref.read(sourceRepositoryProvider).updateSource(id, document);
    await reload();
  }
}
