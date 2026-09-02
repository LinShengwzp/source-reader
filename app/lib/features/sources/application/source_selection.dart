import 'package:flutter_riverpod/flutter_riverpod.dart';

final sourceSelectionProvider =
    NotifierProvider<SourceSelectionController, int?>(
  SourceSelectionController.new,
);

/// Source Workbench 当前选中的数据库书源 id。
final class SourceSelectionController extends Notifier<int?> {
  @override
  int? build() => null;

  void select(int id) {
    state = id;
  }

  void clear() {
    state = null;
  }
}
