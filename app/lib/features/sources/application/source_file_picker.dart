import 'package:source_reader/features/sources/application/source_import.dart';

abstract interface class SourceFilePicker {
  Future<SourceImportPayload?> pickSourceFile();
}
