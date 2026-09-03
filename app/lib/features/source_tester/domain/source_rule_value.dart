/// 规则解析层对第三方 parser 类型的隔离值。
sealed class SourceRuleValue {
  const SourceRuleValue();
}

final class SourceRuleScalar extends SourceRuleValue {
  const SourceRuleScalar(this.value);

  final Object? value;
}

final class SourceRuleList extends SourceRuleValue {
  SourceRuleList(List<SourceRuleValue> values)
      : values = List<SourceRuleValue>.unmodifiable(values);

  final List<SourceRuleValue> values;
}

/// parser 私有上下文对 application 层暴露的最小边界。
abstract interface class SourceRuleContext {
  SourceRuleValue summarize();
}
