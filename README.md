# 角色聊天 App

Flutter / Android 优先的单角色聊天 App。核心目标不是做一个普通问答框，而是让角色拥有连续的关系、记忆和状态。

## v0.1 已完成

- 单角色聊天主界面
- “正在想”状态
- 本地保存聊天记录
- 共同记忆入口和本地存储骨架
- 为角色语音、撤回改口、主动消息预留交互位置

## 下一阶段

1. 接入可配置的 AI 服务，并建立角色提示词与上下文组装器。
2. 将聊天记录、长期记忆、关系状态分层；稳定后迁移至 ObjectBox。
3. 增加主动消息、后台通知与时间连续性。

每次推送到 `main` 后，GitHub Actions 会自动生成 Android 工程、执行分析与测试，并编译 release APK。也可在本地安装 Flutter 后运行：

```bash
flutter create . --platforms=android
flutter pub get
flutter run
```
