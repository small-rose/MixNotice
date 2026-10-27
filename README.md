# <img src="brand/app-icon-1024.png" width="36" align="top" alt=""> MixNotice

**混一场自然声，睡一个安稳觉。**

一款注重隐私的自然声音混音 App：真实采集的雨声、风声、篝火与虫鸣，自由叠加成属于你的环境声。无账号、无广告、无埋点——所有数据只存在你的设备里。

![platform](https://img.shields.io/badge/platform-Android%20%7C%20Windows-2E7D5C)
![flutter](https://img.shields.io/badge/Flutter-3.47+-4CAF87)
![version](https://img.shields.io/badge/version-1.0.0--fix10-C77E2E)
![license-sounds](https://img.shields.io/badge/sounds-CC0%20%2F%20CC%20BY%20%2F%20CC%20BY--SA-5C6B62)

- 官网：<https://mix.zhangxiaocai.cn>
- 下载：见 [Releases](../../releases)（Android APK，arm64-v8a）

---

## ✨ 功能特性

| | |
|---|---|
| 🎚️ **多轨混音台** | 最多 6 轨同时播放，每轨独立音量与静音，总音量一键调节 |
| 🌙 **睡眠 / 休息倒计时** | 5–480 分钟睡眠定时，结束前 5 分钟音量渐弱；休息模式反向渐强 |
| 🎵 **后台播放** | 前台服务 + 系统媒体通知，息屏照常播放，基于系统墙钟不漂移 |
| 🎨 **主题随心** | 晨雾、夜林等 4 套内置主题，强调色自定义，主题支持导入导出 |
| 💾 **100% 本地** | 无账号体系、无埋点上报、无第三方 SDK，卸载即无痕 |
| 🖥️ **Windows 桌面端** | 同一套 Flutter 代码，系统托盘常驻 |

## 🌿 声音库（23 个真实音源）

| 分组 | 音源 |
|---|---|
| 🌿 自然（13） | 小雨、大雨、雷声、风、溪流、海浪、鸟鸣、杜鹃、麻雀、夜莺、篝火、森林、夜晚虫鸣 |
| 🚜 田园（4） | 狗叫、鸡叫、鹅叫、池塘 |
| 🌫️ 噪音（3） | 白噪音、粉噪音、棕噪音 |
| 🏙️ 生活（3） | 咖啡馆、键盘敲击、风铃 |

内置 8 组方案：雨天篝火、森林晨间、海边夜晚、雨夜雷声、溪流清晨、白噪音专注、咖啡馆午后、虫鸣夏夜。

所有音源均为真实录音（非合成），经响度归一化（loudnorm）与无缝循环（1s 交叉淡化）处理。

## 📦 下载安装

1. 从 [Releases](../../releases) 下载 APK（如 `MixNotice-v1.0.0-fix10-arm64-debug.apk`）
2. 允许「安装未知来源应用」后安装（未上架商店前需要）
3. 要求 Android 5.0+（API 21），arm64-v8a 设备（2016 年后绝大多数机型）

> Windows 桌面端在路线图中，代码骨架已就位（`app/windows/`）。

## 🔨 从源码构建

```bash
# 环境要求：Flutter 3.47+（含 Android SDK / JDK 17）

cd app
flutter pub get
flutter build apk --release            # 全 ABI
# 或仅构建 arm64（体积减半）：
cd android && ./gradlew assembleDebug -Ptarget-platform=android-arm64
```

也可以用仓库自带的构建脚本（自动读取版本号、规范产物命名 `MixNotice-v<version>-<tag>-<abi>-<mode>.apk`）：

```bat
tools\build_apk.bat -Tag fix11                       :: arm64 + debug
tools\build_apk.bat -Tag rc1 -Mode release -Stamp    :: 带日期戳的 release 包
tools\build_apk.bat -Tag fix11 -DryRun               :: 只看计划不构建
```

> 💡 国内网络建议：`gradlew --stop` 后使用 `--offline`（依赖已缓存时）可避免 Maven/Google 仓库下载卡死；`android/gradle.properties` 中堆内存已调至 `-Xmx3G` 以降低页面文件压力。

## 🗂️ 目录结构

```
.
├── app/                    # Flutter 主工程
│   ├── lib/                # 源码（ui / theme / services / core）
│   ├── test/               # 布局回归、主题锁定、Logo 渲染等测试
│   ├── assets/             # 23 个成品音源（m4a）+ 品牌图
│   ├── assets_src/         # 原始授权素材（ogg/mp3，处理前的素材）
│   ├── android/            # 安卓工程（自适应图标、前台服务）
│   ├── windows/  ios/      # 桌面 / iOS 工程骨架（路线图）
│   └── tools/              # 音源抓取与处理脚本（Wikimedia Commons 等）
├── site/                   # 官网整站（纯静态，可部署 CF Pages / Vercel）
├── docs/                   # PRD、UI 设计规范、产品规划、音源授权清单
├── brand/                  # Logo 矢量源文件与导出图
├── tools/                  # 构建脚本（产物命名规范）
└── flutter_theme_skeleton/ # 主题系统骨架参考工程
```

## 📄 音源授权

所有音源来自 Wikimedia Commons 等平台的 CC 授权素材（CC0 / CC BY / CC BY-SA），**逐条出处与作者见 [docs/音频素材授权清单.csv](docs/音频素材授权清单.csv)**。`app/tools/` 中的脚本可完整复现「原始素材 → 成品音源」的处理链路。

## 🗺️ 路线图

- [x] Android arm64（v1.0）
- [ ] Windows 桌面端打磨与发布
- [ ] iOS 版本
- [ ] 自定义音源导入

## 许可

- 代码许可证：待定（建议 MIT，欢迎提 issue 讨论）
- 音频素材：各自遵循上游 CC 许可，见授权清单
- 官网与品牌资源：© zhangxiaocai.cn
