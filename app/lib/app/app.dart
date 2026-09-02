import 'package:flutter/material.dart';

final class SourceReaderApp extends StatelessWidget {
  const SourceReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Source Reader',
      home: Scaffold(
        body: Center(
          child: Text('Source Workbench'),
        ),
      ),
    );
  }
}
