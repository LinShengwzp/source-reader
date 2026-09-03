import 'package:flutter/material.dart';
import 'package:source_reader/features/source_tester/domain/source_test_report.dart';

const _responseBodyDisplayLimit = 200000;

final class SourceTesterReportView extends StatelessWidget {
  const SourceTesterReportView({super.key, required this.report});

  final SearchBookTestReport report;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Column(
        key: const Key('source-tester-report'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const TabBar(
            tabs: <Widget>[
              Tab(key: Key('source-tester-tab-results'), text: '结果'),
              Tab(key: Key('source-tester-tab-request'), text: '请求'),
              Tab(key: Key('source-tester-tab-response'), text: '响应'),
              Tab(key: Key('source-tester-tab-traces'), text: '解析日志'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: <Widget>[
                _ResultsView(report: report),
                _RequestView(report: report),
                _ResponseView(report: report),
                _TracesView(report: report),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

final class _ResultsView extends StatelessWidget {
  const _ResultsView({required this.report});

  final SearchBookTestReport report;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Text(
          '共 ${report.items.length} 条结果 · ${_outcomeText(report.outcome)}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        if (report.warnings.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          for (final warning in report.warnings)
            Text('⚠ $warning', style: Theme.of(context).textTheme.bodySmall),
        ],
        const SizedBox(height: 12),
        if (report.items.isEmpty)
          const Text('没有解析到搜索结果。')
        else
          for (var index = 0; index < report.items.length; index++)
            _ResultItem(index: index, item: report.items[index]),
      ],
    );
  }
}

final class _ResultItem extends StatelessWidget {
  const _ResultItem({required this.index, required this.item});

  final int index;
  final SearchBookTestItem item;

  @override
  Widget build(BuildContext context) {
    final lines = <String>[
      if (_hasText(item.author)) '作者：${item.author}',
      if (_hasText(item.cat)) '分类：${item.cat}',
      if (_hasText(item.status)) '状态：${item.status}',
      if (_hasText(item.wordCount)) '字数：${item.wordCount}',
      if (_hasText(item.lastChapterTitle)) '最新章节：${item.lastChapterTitle}',
      if (_hasText(item.detailUrl)) '详情：${item.detailUrl}',
      if (_hasText(item.cover)) '封面：${item.cover}',
      if (_hasText(item.desc)) '简介：${item.desc}',
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              item.bookName?.trim().isNotEmpty == true
                  ? item.bookName!
                  : '结果 ${index + 1}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            for (final line in lines) ...<Widget>[
              const SizedBox(height: 4),
              SelectableText(line),
            ],
          ],
        ),
      ),
    );
  }
}

final class _RequestView extends StatelessWidget {
  const _RequestView({required this.report});

  final SearchBookTestReport report;

  @override
  Widget build(BuildContext context) {
    final request = report.request;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        _Section(title: '方法', value: request.method.name.toUpperCase()),
        _Section(title: '最终请求 URL', value: request.uri.toString()),
        _Section(title: '原始 requestInfo', value: request.originalRequestInfo),
        _Section(title: 'Headers', value: _formatHeaders(request.headers)),
      ],
    );
  }
}

final class _ResponseView extends StatelessWidget {
  const _ResponseView({required this.report});

  final SearchBookTestReport report;

  @override
  Widget build(BuildContext context) {
    final response = report.response;
    final truncated = response.decodedBody.length > _responseBodyDisplayLimit;
    final displayedBody = truncated
        ? response.decodedBody.substring(0, _responseBodyDisplayLimit)
        : response.decodedBody;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        _Section(title: 'HTTP 状态', value: '${response.statusCode}'),
        _Section(title: '最终 URL', value: response.finalUri.toString()),
        _Section(title: '耗时', value: '${response.duration.inMilliseconds} ms'),
        _Section(title: '响应大小', value: '${response.byteCount} bytes'),
        _Section(title: '解码', value: response.encoding),
        _Section(title: 'Headers', value: _formatHeaders(response.headers)),
        const SizedBox(height: 8),
        Text('Body', style: Theme.of(context).textTheme.titleSmall),
        if (truncated) ...<Widget>[
          const SizedBox(height: 4),
          const Text('正文过长，已仅显示前 200000 个字符。'),
        ],
        const SizedBox(height: 8),
        SelectableText(displayedBody),
      ],
    );
  }
}

final class _TracesView extends StatelessWidget {
  const _TracesView({required this.report});

  final SearchBookTestReport report;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        if (report.traces.isEmpty)
          const Text('没有解析日志。')
        else
          for (final trace in report.traces) _TraceCard(trace: trace),
      ],
    );
  }
}

final class _TraceCard extends StatelessWidget {
  const _TraceCard({required this.trace});

  final SourceRuleTrace trace;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    trace.field,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (trace.partial) const Text('部分执行'),
              ],
            ),
            const SizedBox(height: 8),
            SelectableText('规则：${trace.rule}'),
            if (trace.stages.isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              SelectableText('阶段：${trace.stages.join(' → ')}'),
            ],
            if (trace.outputSummary.isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              SelectableText('输出：${trace.outputSummary}'),
            ],
            for (final warning in trace.warnings) ...<Widget>[
              const SizedBox(height: 6),
              SelectableText('警告：$warning'),
            ],
            for (final error in trace.errors) ...<Widget>[
              const SizedBox(height: 6),
              SelectableText('错误：$error'),
            ],
          ],
        ),
      ),
    );
  }
}

final class _Section extends StatelessWidget {
  const _Section({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          SelectableText(value.isEmpty ? '—' : value),
        ],
      ),
    );
  }
}

String _formatHeaders(Map<String, String> headers) {
  if (headers.isEmpty) {
    return '—';
  }
  final keys = headers.keys.toList()..sort((a, b) => a.compareTo(b));
  return keys.map((key) => '$key: ${headers[key]}').join('\n');
}

String _outcomeText(SearchBookTestOutcome outcome) {
  return switch (outcome) {
    SearchBookTestOutcome.success => '成功',
    SearchBookTestOutcome.completedWithWarnings => '完成但有警告',
  };
}

bool _hasText(String? value) => value != null && value.trim().isNotEmpty;
