import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:source_reader/app/app.dart';

void main() {
  runApp(const ProviderScope(child: SourceReaderApp()));
}
