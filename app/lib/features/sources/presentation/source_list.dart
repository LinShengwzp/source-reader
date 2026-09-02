import 'package:flutter/material.dart';
import 'package:source_reader/features/sources/data/source_repository.dart';

/// 只负责展示当前书源列表，不直接读取 Provider 或访问持久化层。
final class SourceList extends StatelessWidget {
  const SourceList({
    super.key,
    required this.sources,
  });

  final List<StoredSource> sources;

  @override
  Widget build(BuildContext context) {
    if (sources.isEmpty) {
      return const Center(
        child: Text('还没有书源'),
      );
    }

    return ListView.separated(
      itemCount: sources.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final source = sources[index];
        final name = source.document.sourceName;

        return ListTile(
          title: Text(
            name == null || name.trim().isEmpty ? '未命名书源' : name,
          ),
          subtitle: Text(source.platform),
          trailing: Text(source.document.enabled ? '启用' : '停用'),
        );
      },
    );
  }
}
