import 'package:file_picker/file_picker.dart';
import 'package:source_reader/features/sources/application/source_file_picker.dart';
import 'package:source_reader/features/sources/application/source_import.dart';

/// 基于 file_picker 的系统原生文件选择实现。
///
/// 仅处理单文件选择和字节读取；解析、校验、持久化由上层完成。
final class FilePickerSourceFilePicker implements SourceFilePicker {
  FilePickerSourceFilePicker();

  @override
  Future<SourceImportPayload?> pickSourceFile() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const <String>['json', 'xbs'],
    );

    if (file == null) {
      return null;
    }

    final bytes = await file.readAsBytes();

    return SourceImportPayload(name: file.name, bytes: bytes);
  }
}
