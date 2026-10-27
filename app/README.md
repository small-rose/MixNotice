# MixNoticeApp V1.0（MVP 工程）

依据《PRD-MixNoticeApp-V1.0.md》《UI设计规范-MixNoticeApp-v1.1.md》实现的 Flutter 单代码库双端工程。

## 运行

```bash
cd app
flutter pub get
flutter run            # 移动端真机/模拟器
flutter run -d windows # Windows 桌面（需 VS C++ 工具链）
```

> 本仓库代码已通过 `flutter analyze`（0 错误 0 警告）与 `flutter test`（2/2 通过）。
> Windows 构建需安装 Visual Studio 2022（含「使用 C++ 的桌面开发」负载）；Android 构建需 Android SDK。

## 目录

```
lib/
├── main.dart                  # 入口：Provider 装配、桌面窗口/托盘初始化
├── core/
│   ├── constants.dart         # 音源目录(16, FR-01) + 预设方案(8, FR-10) + 上限常量
│   └── analytics.dart         # 匿名埋点本地队列（FR-28, E-07 失败静默补报）
├── data/
│   ├── models.dart            # Channel/PresetData/存储格式（FR-13a 版本字段）
│   ├── preset_repository.dart # 方案 JSON 原子写（E-05）、损坏条目跳过（E-06）
│   ├── settings_repository.dart
│   └── preset_controller.dart # 保存/重命名/删除（FR-11~13）
├── audio/
│   ├── audio_engine.dart      # audioplayers 多实例 = 多轨；独立音量/总音量/试听
│   ├── playback_controller.dart # 状态机 idle/playing/paused（PRD 9.1）
│   └── timer_controller.dart  # 墙钟倒计时、睡眠渐弱、休息提示音（FR-14~20）
├── services/tray_service.dart # 托盘：播放暂停/最近5方案/退出（FR-23, E-12 降级）
├── theme/                     # Token 主题体系（4 套内置 + 对比度守卫）
└── ui/                        # 五页：声音库/混音台/方案库/计时器/设置 + 迷你播放条
assets/audio/                  # 开发期占位音频（tools/gen_placeholder_audio.py 合成）
tools/gen_placeholder_audio.py # 正式素材到位后覆盖同名文件即可
```

## PRD 覆盖情况

- **已实现**：FR-01~29 逻辑层全部 + 移动端三 Tab UI + 桌面托盘 + 双主题。
- **待平台联调（需真机/完整工具链）**：FR-21/22 息屏续播与通知栏（需 Android 前台服务配置、iOS 后台音频模式声明）；FR-23 托盘已在代码中，需 Windows 构建后实测。
- **待正式素材**：16 个音源当前为合成占位 WAV，正式素材到位后覆盖 `assets/audio/`（PRD 13.1 阻塞依赖）。
- **待接入**：埋点上报端点（`core/analytics.dart` 中 `_endpoint` 占位）。
