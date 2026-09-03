import 'package:source_reader/features/sources/application/source_export.dart';

/// 将已经完成编码的书源导出 payload 交给平台保存流程。
abstract interface class SourceFileSaver {
  /// 返回 true 表示保存完成，false 表示用户取消。
  Future<bool> save(SourceExportPayload payload);
}
