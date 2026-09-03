import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:source_reader/features/source_tester/application/source_request_builder.dart';
import 'package:source_reader/features/source_tester/application/source_tester_providers.dart';
import 'package:source_reader/features/source_tester/domain/source_test_error.dart';
import 'package:source_reader/features/source_tester/domain/source_test_report.dart';
import 'package:source_reader/features/source_tester/presentation/source_tester_input_panel.dart';
import 'package:source_reader/features/source_tester/presentation/source_tester_report_view.dart';
import 'package:source_reader/features/sources/application/source_providers.dart';
import 'package:source_reader/features/sources/data/source_repository.dart';

final class SourceTesterPage extends ConsumerStatefulWidget {
  const SourceTesterPage({super.key, required this.sourceId});

  final int sourceId;

  @override
  ConsumerState<SourceTesterPage> createState() => _SourceTesterPageState();
}

final class _SourceTesterPageState extends ConsumerState<SourceTesterPage> {
  late Future<StoredSource?> _sourceFuture;
  bool _running = false;
  SearchBookTestReport? _report;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _sourceFuture = _loadSource();
  }

  @override
  void didUpdateWidget(covariant SourceTesterPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sourceId != widget.sourceId) {
      _sourceFuture = _loadSource();
      _report = null;
      _errorText = null;
      _running = false;
    }
  }

  Future<StoredSource?> _loadSource() {
    return ref.read(sourceRepositoryProvider).getSource(widget.sourceId);
  }

  Future<void> _run(SourceTesterInput input) async {
    if (_running) {
      return;
    }
    setState(() {
      _running = true;
      _report = null;
      _errorText = null;
    });

    try {
      final report = await ref.read(searchBookTestRunnerProvider).run(
            sourceId: widget.sourceId,
            input: SearchBookTestInput(
              keyWord: input.keyWord,
              pageIndex: input.pageIndex,
              offset: input.offset,
              filter: input.filter,
            ),
          );
      if (!mounted) {
        return;
      }
      setState(() => _report = report);
    } on SourceTestException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _errorText = _formatSourceTestError(error));
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _errorText = '测试失败：$error');
    } finally {
      if (mounted) {
        setState(() => _running = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('书源测试')),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            FutureBuilder<StoredSource?>(
              future: _sourceFuture,
              builder: (context, snapshot) {
                final source = snapshot.data;
                final sourceName = source?.document.sourceName?.trim();
                final title = sourceName == null || sourceName.isEmpty
                    ? '书源 #${widget.sourceId}'
                    : sourceName;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        key: const Key('source-tester-source-name'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '测试使用已保存版本',
                        key: Key('source-tester-persisted-note'),
                      ),
                      if (snapshot.hasError) ...<Widget>[
                        const SizedBox(height: 4),
                        Text('读取书源信息失败：${snapshot.error}'),
                      ],
                    ],
                  ),
                );
              },
            ),
            SourceTesterInputPanel(running: _running, onRun: _run),
            if (_running)
              const LinearProgressIndicator(key: Key('source-tester-progress')),
            if (_errorText case final errorText?)
              Padding(
                key: const Key('source-tester-error'),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  errorText,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            Expanded(
              child: _report case final report?
                  ? SourceTesterReportView(report: report)
                  : const Center(child: Text('输入关键词后运行搜索测试。')),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatSourceTestError(SourceTestException error) {
  final base = switch (error.reason) {
    SourceTestFailureReason.sourceNotFound => '已保存书源不存在或已被删除',
    SourceTestFailureReason.unsupportedPlatform => '当前书源平台暂不支持测试',
    SourceTestFailureReason.searchBookMissing => '当前书源没有 searchBook 规则',
    SourceTestFailureReason.requestInfoMissing => 'searchBook.requestInfo 缺失',
    SourceTestFailureReason.unsupportedScriptRequest => '当前版本不支持脚本请求（@js / %@js）',
    SourceTestFailureReason.unknownPlaceholder => '请求中存在当前版本不支持的占位符',
    SourceTestFailureReason.invalidBaseUrl => '书源基础地址无效，无法解析请求 URL',
    SourceTestFailureReason.invalidHeaders => 'HTTP Headers 配置无效',
    SourceTestFailureReason.unsupportedRequestEncoding => '当前版本不支持该请求参数编码',
    SourceTestFailureReason.transportFailure => '网络请求失败',
    SourceTestFailureReason.timeout => '网络请求超时',
    SourceTestFailureReason.responseTooLarge => '响应超过 5 MiB 上限',
    SourceTestFailureReason.unsupportedResponseEncoding => '当前版本不支持该响应编码',
    SourceTestFailureReason.unsupportedResponseFormat => '当前版本不支持该响应格式',
    SourceTestFailureReason.responseParseFailure => '响应内容无法解析',
    SourceTestFailureReason.listRuleFailure => 'searchBook.list 规则无法执行',
  };
  final detail = error.message?.trim();
  return detail == null || detail.isEmpty ? base : '$base：$detail';
}
