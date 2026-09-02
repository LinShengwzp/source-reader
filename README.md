# Source Reader

Source Reader 正在 `revival/flutter-workbench` 分支上以 Flutter 重构。

当前产品路线：

1. **Source Workbench**：导入、查看、编辑、校验、持久化和导出香色闺阁书源。
2. **Source Tester**：测试搜索、详情、目录、正文规则，并展示请求、响应、解析结果与错误。
3. **Reader**：在前两阶段稳定后增加书架、搜索加书、阅读进度与缓存。

## 当前技术栈

- Flutter 3.47.x
- Dart 3.13.x
- Riverpod 3.x
- Drift + SQLite
- `flutter_test`

当前 revival 分支不再包含可运行的 Vue/Vite/Tauri 或 Electron 工程。唯一的客户端应用位于 `app/`。

## 开发

```bash
cd app
flutter pub get
dart run build_runner build
flutter analyze
flutter test
flutter run
```

如果 Drift schema 发生变化，需要重新执行：

```bash
dart run build_runner build
```

## 目录

```text
app/                                Flutter 应用
docs/revival/                       重构架构与约束
docs/superpowers/specs/             已批准设计文档
docs/superpowers/plans/             实施计划
docs/omniroute/                     受控 OmniRoute 工单
docs/legacy/source-reference/       从旧项目抽取的迁移参考源码
```

## 旧项目

完整的 2023 年 Vue + Tauri 1 项目仍保留在 `main` 分支和 Git 历史中。

revival 分支只保留少量仍有迁移价值的历史源码，位于 `docs/legacy/source-reference/`。这些文件仅作为 XBS 行为、书源字段、帮助文档和旧交互的参考，不参与 Flutter 构建，也不应重新引入旧 Tauri/Node 运行时依赖。

## CI

`.github/workflows/flutter-ci.yml` 负责执行 Flutter 依赖安装、Drift codegen、静态分析和全量测试。
