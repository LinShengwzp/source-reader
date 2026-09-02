# OR-001 Generate Flutter Platform Runners

## 目标

为当前 Flutter 应用生成官方平台 runner，只做 Flutter 模板生成，不修改任何业务代码。

## 工作范围

- 工作分支：`revival/flutter-workbench`
- 工作目录：`app/`
- 唯一目标：生成 Android、iOS、Linux、macOS、Windows 平台 runner。

允许新增：

```text
app/android/**
app/ios/**
app/linux/**
app/macos/**
app/windows/**
```

禁止修改：

```text
app/lib/**
app/test/**
docs/**
.github/**
```

禁止新增依赖。
禁止修改业务逻辑。
禁止修改数据库 schema。
禁止修改 JSON/XBS codec。
禁止顺手重构。
禁止修改旧 Vue/Tauri 代码。

## 执行前检查

在仓库根目录确认：

```bash
git status --short
git branch --show-current
```

必须满足：

```text
当前分支 = revival/flutter-workbench
工作区无未提交修改
```

如果不满足，停止执行并报告，不要自行处理已有修改。

## 执行

进入 `app/`：

```bash
cd app
```

运行：

```bash
flutter create --platforms=android,ios,linux,macos,windows --project-name source_reader --org com.linshengwzp .
```

## 清理 Flutter 模板的越界修改

执行：

```bash
git status --short
git diff -- app/pubspec.yaml app/lib app/test
```

Flutter 模板可能会尝试修改已有非平台文件。

如果以下位置发生变化，必须恢复到执行前状态：

```text
app/pubspec.yaml
app/lib/**
app/test/**
```

可以使用 Git 恢复这些越界修改，但不得恢复新生成的平台目录。

最终允许保留的修改只能位于：

```text
app/android/**
app/ios/**
app/linux/**
app/macos/**
app/windows/**
```

若仍存在其他文件修改，停止并报告，不要提交。

## 验收

在 `app/` 目录执行：

```bash
flutter pub get
dart run build_runner build
flutter analyze
flutter test
```

必须全部通过。

然后回到仓库根目录检查：

```bash
cd ..
git status --short
git diff --stat
```

确认只有平台 runner 文件变化。

## Commit

仅在验收全部通过后提交：

```bash
git add app/android app/ios app/linux app/macos app/windows
git commit -m "chore: generate Flutter platform runners"
```

不要 push，除非用户明确要求。

## 最终反馈格式

只报告以下内容：

1. 当前分支。
2. 实际执行的 `flutter create` 命令。
3. 新增的平台目录。
4. 是否发现并恢复了 `pubspec.yaml` / `lib` / `test` 越界修改。
5. `flutter analyze` 结果。
6. `flutter test` 结果。
7. Commit SHA 和 commit message。
8. `git status --short` 最终是否为空。

不要额外重构或提出与本工单无关的修改。
