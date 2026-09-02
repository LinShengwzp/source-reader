# Legacy Source Reference

这里保存从 2023 年 Vue/Tauri 版本中抽取的少量迁移参考源码。

这些文件只作为 Source Reader revival 的领域资料、XBS 行为基准和旧交互参考，不属于当前可运行应用，也不会参与 Flutter 构建或测试。文件中的 `@/...`、Vue、Element Plus 等 import 可能无法在本目录独立解析，这是预期行为。

完整旧应用仍保留在 Git 历史和 `main` 分支中。需要追溯旧运行时、Tauri/Rust、Pinia、旧 SQLite 实现或完整 Vue 页面时，应查看 `main`，不要把这些运行时依赖重新带回 `revival/flutter-workbench`。

## 保留内容

- `Models.ts`：书源平台、类型、编码枚举及旧领域接口资料。
- `Strutil.ts`：旧 JSON/stringify 辅助行为参考。
- `xbsTool/xbsTools.ts`：XBS codec 的历史行为基准。
- `xbsTool/xbsFileTools.ts`：XBS/JSON 文件导入产品行为参考。
- `nodes/ModifyFormModel.ts`：规则字段、分组和帮助文档的主要资料来源。
- `nodes/NodeDetail.vue`：旧版节点详情编辑的数据流与交互参考。
- `nodes/NodeDocs.vue`：旧规则帮助内容参考。
- `nodes/NodeList.vue`：旧列表交互参考。
- `nodes/NodeModify.vue`：旧节点修改交互参考。

## 明确不迁移

- Tauri/Rust 宿主与命令层。
- `tauri-plugin-sql-api` 和旧通用 SQL builder。
- 旧 Pinia store。
- Vite/Vue 运行时工程配置。
- 旧 Release workflow。

revival 分支的唯一可运行客户端位于 `app/`，技术栈为 Flutter。
