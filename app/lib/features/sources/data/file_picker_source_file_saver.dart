import 'package:file_picker/file_picker.dart';
import 'package:source_reader/features/sources/application/source_export.dart';
import 'package:source_reader/features/sources/application/source_file_saver.dart';

/// 使用系统保存对话框保存已经完成编码的书源 payload。
final class FilePickerSourceFileSaver implements SourceFileSaver {
  @override
  Future<bool> save(SourceExportPayload payload) async {
    final uri = await FilePicker.saveFile(
      fileName: payload.fileName,
      bytes: payload.bytes,
      mimeType: payload.mimeType,
    );
    return uri != null;
  }
}
