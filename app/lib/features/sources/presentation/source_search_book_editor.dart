import 'package:flutter/material.dart';
import 'package:source_reader/features/sources/domain/source_rule_options.dart';
import 'package:source_reader/features/sources/presentation/source_rule_fields.dart';
import 'package:source_reader/features/sources/presentation/source_search_book_draft.dart';

final class SearchBookEditor extends StatelessWidget {
  const SearchBookEditor({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final SourceSearchBookDraft value;
  final ValueChanged<SourceSearchBookDraft> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          EditorSectionCard(
            title: '搜索规则',
            children: <Widget>[
              RuleMultilineField(
                key: const Key('search-book-request-info'),
                label: '请求信息',
                value: value.requestInfo,
                onChanged: (text) => onChanged(value.copyWith(requestInfo: text)),
              ),
              const SizedBox(height: 12),
              RuleTextField(
                key: const Key('search-book-list'),
                label: '结果列表',
                value: value.list,
                onChanged: (text) => onChanged(value.copyWith(list: text)),
              ),
              const SizedBox(height: 12),
              RuleTextField(
                key: const Key('search-book-book-name'),
                label: '书名',
                value: value.bookName,
                onChanged: (text) => onChanged(value.copyWith(bookName: text)),
              ),
              const SizedBox(height: 12),
              RuleTextField(
                key: const Key('search-book-author'),
                label: '作者',
                value: value.author,
                onChanged: (text) => onChanged(value.copyWith(author: text)),
              ),
              const SizedBox(height: 12),
              RuleTextField(
                key: const Key('search-book-cover'),
                label: '封面',
                value: value.cover,
                onChanged: (text) => onChanged(value.copyWith(cover: text)),
              ),
              const SizedBox(height: 12),
              RuleTextField(
                key: const Key('search-book-desc'),
                label: '简介',
                value: value.desc,
                onChanged: (text) => onChanged(value.copyWith(desc: text)),
              ),
              const SizedBox(height: 12),
              RuleTextField(
                key: const Key('search-book-cat'),
                label: '分类',
                value: value.cat,
                onChanged: (text) => onChanged(value.copyWith(cat: text)),
              ),
              const SizedBox(height: 12),
              RuleTextField(
                key: const Key('search-book-status'),
                label: '状态',
                value: value.status,
                onChanged: (text) => onChanged(value.copyWith(status: text)),
              ),
              const SizedBox(height: 12),
              RuleTextField(
                key: const Key('search-book-word-count'),
                label: '字数',
                value: value.wordCount,
                onChanged: (text) => onChanged(value.copyWith(wordCount: text)),
              ),
              const SizedBox(height: 12),
              RuleTextField(
                key: const Key('search-book-last-chapter-title'),
                label: '最新章节',
                value: value.lastChapterTitle,
                onChanged: (text) => onChanged(value.copyWith(lastChapterTitle: text)),
              ),
              const SizedBox(height: 12),
              RuleTextField(
                key: const Key('search-book-detail-url'),
                label: '详情地址',
                value: value.detailUrl,
                onChanged: (text) => onChanged(value.copyWith(detailUrl: text)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ExpansionTile(
            key: const Key('search-book-advanced'),
            title: const Text('高级'),
            childrenPadding: const EdgeInsets.all(16),
            children: <Widget>[
              RuleEnumField(
                key: const Key('search-book-request-params-encode'),
                label: '请求参数编码',
                value: value.requestParamsEncode,
                options: SourceRuleOptions.requestParamsEncode,
                onChanged: (v) {
                  if (v != null) onChanged(value.copyWith(requestParamsEncode: v));
                },
              ),
              const SizedBox(height: 12),
              RuleEnumField(
                key: const Key('search-book-response-encode'),
                label: '响应编码',
                value: value.responseEncode,
                options: SourceRuleOptions.responseEncode,
                onChanged: (v) {
                  if (v != null) onChanged(value.copyWith(responseEncode: v));
                },
              ),
              const SizedBox(height: 12),
              RuleEnumField(
                key: const Key('search-book-response-format-type'),
                label: '响应格式',
                value: value.responseFormatType,
                options: SourceRuleOptions.responseFormatType,
                onChanged: (v) {
                  if (v != null) onChanged(value.copyWith(responseFormatType: v));
                },
              ),
              const SizedBox(height: 12),
              RuleTextField(
                key: const Key('search-book-success'),
                label: '成功判断',
                value: value.success,
                onChanged: (text) => onChanged(value.copyWith(success: text)),
              ),
              const SizedBox(height: 12),
              RuleMultilineField(
                key: const Key('search-book-js-parser'),
                label: 'JS 解析器',
                value: value.jsParser,
                onChanged: (text) => onChanged(value.copyWith(jsParser: text)),
              ),
              const SizedBox(height: 12),
              RuleMultilineField(
                key: const Key('search-book-more-keys'),
                label: '更多参数',
                value: value.moreKeysText,
                onChanged: (text) {
                  final candidate = value.copyWith(moreKeysText: text);
                  onChanged(candidate);
                },
                errorText: value.moreKeysValidationError,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
