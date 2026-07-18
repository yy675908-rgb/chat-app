# 角色聊天 App

Flutter / Android 优先的单角色聊天 App。核心目标不是做一个普通问答框，而是让角色拥有连续的关系、记忆和状态。

## v0.3 已完成

- 内置角色“林”，支持编辑名字、状态、开场白和角色设定
- 可配置 OpenAI 兼容 API 地址、模型和 API Key
- 流式显示模型回复与“正在想”状态
- 聊天记录、角色档案和共同记忆保存在本机
- API Key 使用 Android 加密存储
- 最近对话与共同记忆会自动加入角色上下文

## 下一阶段

1. 将聊天记录、长期记忆、关系状态分层；稳定后迁移至 SQLite。
2. 增加主动消息、后台通知与时间连续性。
3. 增加角色卡导入、世界书与多角色。

每次推送到 `main` 后，GitHub Actions 会自动生成 Android 工程、执行分析与测试，并编译 release APK。也可在本地安装 Flutter 后运行：

```bash
flutter create . --platforms=android
flutter pub get
flutter run
```
