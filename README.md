# <img src="brand/app-icon-1024.png" width="36" align="top" alt=""> 枕声 SoughMix

**混一场自然声，睡一个安稳觉。**

一款注重隐私的自然声音混音 App：真实采集的雨声、风声、篝火与虫鸣，自由叠加成属于你的环境声。无账号、无广告、无埋点——所有数据只存在你的设备里。

![platform](https://img.shields.io/badge/platform-Android%20%7C%20Windows-2E7D5C)
![flutter](https://img.shields.io/badge/Flutter-3.47+-4CAF87)
![version](https://img.shields.io/badge/version-1.2.0-2E7D5C)
![license-sounds](https://img.shields.io/badge/sounds-CC0%20%2F%20CC%20BY%20%2F%20CC%20BY--SA-5C6B62)

- 官网：<https://mix.zhangxiaocai.cn>
- 下载：见 [Releases](../../releases)（v1.2.0 提供 arm64 / armv7 / x86_64 三个架构包，正式签名）

---

## ✨ 功能特性

| | |
|---|---|
| 🎚️ **多轨混音台** | 最多 6 轨同时播放，每轨独立音量与静音，总音量一键调节 |
| 🌙 **睡眠 / 休息倒计时** | 5–480 分钟睡眠定时，结束前 5 分钟音量渐弱；休息模式反向渐强 |
| 🎵 **后台播放** | 前台服务 + 系统媒体通知，息屏照常播放，基于系统墙钟不漂移 |
| 🎨 **主题随心** | 晨雾、夜林等 4 套内置主题，强调色自定义，主题支持导入导出 |
| 📱 **双桌面图标** | 浅色 / 深色 / 跟随系统，设置页一键切换桌面应用图标 |
| 🔔 **通知栏控制** | 锁屏与下拉通知栏常驻播放控制，暂停后仍可继续操控 |
| 💾 **100% 本地** | 无账号体系、无埋点上报、无第三方 SDK，卸载即无痕 |
| 🖥️ **Windows 桌面端** | 同一套 Flutter 代码，系统托盘常驻 |

## 🌿 声音库（27 个真实音源）

| 分组 | 音源 |
|---|---|
| 🌿 自然（13） | 小雨、大雨、雷声、风、溪流、海浪、鸟鸣、杜鹃、麻雀、夜莺、篝火、森林、夜晚虫鸣 |
| 🚜 田园（8） | 公鸡、母鸡、狗叫、鹅叫、牛哞、羊咩、猫叫、池塘 |
| 🏙️ 生活（3） | 咖啡馆、键盘敲击、风铃 |
| 🌫️ 噪音（3） | 白噪音、粉噪音、棕噪音 |

内置 8 组方案：雨天篝火、森林晨间、海边夜晚、雨夜雷声、溪流清晨、白噪音专注、咖啡馆午后、虫鸣夏夜。

所有音源均为真实录音（非合成），经响度归一化（loudnorm）与无缝循环（1s 交叉淡化）处理。

## 📦 下载安装

1. 从 [Releases](../../releases) 下载 APK（v1.2.0：`SoughMix-v1.2.0-release-<abi>-release-20261121.apk`，正式签名）
2. 允许「安装未知来源应用」后安装（未上架商店前需要）
3. 要求 Android 5.0+（API 21），架构包选择：arm64（推荐，2016 年后绝大多数机型）/ armv7（老设备）/ x86_64（模拟器）

| 架构包 | 体积 | SHA-1 |
|---|---|---|
| `SoughMix-v1.2.0-release-arm64-release-20261121.apk` | 46.7 MB | `1BCD38BA26783CF5CD9130EB756637205F520369` |
| `SoughMix-v1.2.0-release-armv7-release-20261121.apk` | 44.3 MB | `3C529EA0A8C055B873F5625C70FE5C9FFE6DCA93` |
| `SoughMix-v1.2.0-release-x64-release-20261121.apk` | 48.1 MB | `7E5533C07E58EE5D53BB00FEE5C985367694F928` |

> ⚠️ 签名证书 SHA-1：`07A7FA6BA207C0962F7A8C1D4DCA0CD3A888CC35`（三架构一致）。v1.0.0 起使用正式签名，与早期 debug 签名的 fix 包不通用——装有旧 fix 包请先卸载再安装。

> 🏷️ **应用更名为「枕声 SoughMix」（原 MixNotice）**；v1.2.0 起包名由 `com.mixnotice.mixnotice` 变更为 `com.soughmix.app`。包名变更意味着应用身份变更：与旧版 MixNotice 可共存安装（不会覆盖升级），旧配置不会自动迁移（可先在旧版导出方案与主题）。

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

也可以用仓库自带的构建脚本（自动读取 pubspec 版本号、同步设置页「版本」显示、规范产物命名 `SoughMix-v<version>-<tag>-<abi>-<mode>.apk`）：

```powershell
tools\build_apk.ps1 -Tag release                          # arm64 + debug
tools\build_apk.ps1 -Tag release -Abi arm64 -Mode release -Stamp  # 带日期戳的 release 包
tools\build_apk.ps1 -Tag release -Abi universal -Mode release     # 三架构合一
tools\build_apk.ps1 -Tag release -DryRun                  # 只看计划不构建
```

> 💡 脚本会按 `pubspec.yaml` 的 `version` 自动重写 `app/lib/core/app_version.dart`（设置页「关于」的版本号来源），因此升级只需改 pubspec 一处。

> 💡 国内网络建议：`gradlew --stop` 后使用 `--offline`（依赖已缓存时）可避免 Maven/Google 仓库下载卡死；`android/gradle.properties` 中堆内存已调至 `-Xmx3G` 以降低页面文件压力。

## 🗂️ 目录结构

```
.
├── app/                    # Flutter 主工程
│   ├── lib/                # 源码（ui / theme / services / core）
│   ├── test/               # 布局回归、主题锁定、Logo 渲染等测试
│   ├── assets/             # 27 个成品音源（m4a）+ 品牌图
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

- [x] Android arm64 / armv7 / x86_64（v1.0 起）
- [ ] Windows 桌面端打磨与发布
- [ ] iOS 版本
- [ ] 自定义音源导入

## 📜 更新日志

### v1.2.0（2026-11-21）

**新增**
- 播放器式后台控制台（重做）：锁屏 / 下拉通知栏显示标准媒体卡片，含方案名、音轨数、倒计时剩余时间，支持 上一首 / 播放暂停 / 下一首 三键，上/下一首循环切换方案库，倒计时每秒实时刷新
- 全新品牌「枕声 SoughMix」：应用名、图标、官网、文档全面统一；包名改为 `com.soughmix.app`
- 双桌面图标：浅色 / 深色 / 跟随系统，设置页「品牌」区一键切换手机桌面应用图标
- 内置方案 8 → 11：新增牧场黄昏、农家清晨、粉噪深眠，并调整森林晨间 / 虫鸣夏夜 / 咖啡馆午后组合

**优化**
- 修复计时器点击倒计时后环形进度不变化的问题（改为剩余比例递减 + 修短弧绘制 bug）
- 睡眠启动默认方案改为「雨天篝火」；睡眠页强调色调为更柔和的暖琥珀
- 声音库分组顺序调整为 自然 → 田园 → 生活 → 噪音，生活类音源前移
- 设置页「版本」号改为从构建脚本生成的版本常量读取，升级只需改 pubspec 一处，不再漏改
- 状态栏小图标改为全透明剪影，消除播放器卡片主图右下角重复的第二个 logo

> 完整发布说明见 [docs/RELEASE_NOTES-v1.2.0.md](docs/RELEASE_NOTES-v1.2.0.md)。

### v1.1.0（2026-11-19）

**新增**
- 田园音源 4 → 8：新增公鸡、母鸡、牛哞、羊咩、猫叫；原「鸡叫」拆分为公鸡 / 母鸡，「鸭叫」下线
- 声音库卡片副行文案（每个音源一句话描述）与「新增」amber 徽标
- 动物音源专属线性图标，分组按「家禽 → 家畜 → 其他 → 环境」重排序

**优化**
- 音效素材重制：狗叫、鹅叫、大小雨替换为更长高品质版本，动物叫声统一垫底噪
- 旧配置兼容：v1.0.0 预设 / 音轨中下线音源 ID 自动映射（chicken → 母鸡，duck-quack / frog → 池塘），不错音
- 声音库页面重构，29 项测试全绿

> 完整发布说明见 [docs/RELEASE_NOTES-v1.1.0.md](docs/RELEASE_NOTES-v1.1.0.md)。

### v1.0.0（2026-10-27）

- 首个正式版：6 轨混音台、23 个真实音源、8 组内置方案、睡眠 / 休息倒计时、后台播放、4 套主题与导入导出
- 正式签名密钥，提供 arm64 / armv7 / x86_64 三架构包

> 完整发布说明见 [docs/RELEASE_NOTES-v1.0.0.md](docs/RELEASE_NOTES-v1.0.0.md)。

## 许可

- 代码：[MIT License](LICENSE)
- 音频素材：**不受 MIT 覆盖**，各自遵循上游 CC 许可（CC0 / CC BY / CC BY-SA），逐条出处见 [docs/音频素材授权清单.csv](docs/音频素材授权清单.csv)
- 官网与品牌资源：© zhangxiaocai.cn
