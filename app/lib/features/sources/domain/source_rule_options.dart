/// 规则编辑器使用的固定值与展示标签。
///
/// 定义放在 domain-neutral 位置，避免 presentation 把历史协议值写死在 Widget 内。
final class SourceRuleOption {
  const SourceRuleOption(this.value, this.label);

  final String value;
  final String label;
}

abstract final class SourceRuleOptions {
  static const requestParamsEncode = <SourceRuleOption>[
    SourceRuleOption('utf-8', 'utf-8'),
    SourceRuleOption('2147485234', 'gbk'),
  ];

  static const responseEncode = <SourceRuleOption>[
    SourceRuleOption('utf-8', 'utf-8'),
    SourceRuleOption('2147485232', '简体中文(gb2312)'),
    SourceRuleOption('2147485234', '简体中文(gbk)'),
  ];

  static const responseFormatType = <SourceRuleOption>[
    SourceRuleOption('str', '普通字符串'),
    SourceRuleOption('base64str', 'Base64 字符串'),
    SourceRuleOption('html', 'DOM'),
    SourceRuleOption('xml', 'XML 结构'),
    SourceRuleOption('json', 'JSON 结构'),
    SourceRuleOption('data', '原始数据流'),
    SourceRuleOption('filePath', '文件路径'),
  ];
}
