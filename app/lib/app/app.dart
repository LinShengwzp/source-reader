import 'package:flutter/material.dart';
import 'package:source_reader/features/sources/presentation/source_page.dart';

final class SourceReaderApp extends StatelessWidget {
  const SourceReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Source Reader',
      home: SourcePage(),
    );
  }
}
