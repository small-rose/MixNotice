# MixNoticeApp 主题 Token 代码骨架（Flutter）

> 对应规范：《docs/UI设计规范-MixNoticeApp-v1.1.md》第八章。本骨架可直接拷入 Flutter 工程的 `lib/` 使用（仅依赖 Flutter SDK 本体；持久化需另加 `shared_preferences`）。

## 文件结构

```
lib/
├── main.dart                      # 接线示例：MaterialApp + 控制器 + 图标占位映射表
└── theme/
    ├── app_tokens.dart            # L1 语义 Token（AppTokens extends ThemeExtension）+ 4 套内置色值
    ├── app_themes.dart            # L2 主题注册表 + buildAppTheme()（Material 3 桥接：滑杆/弹窗/字阶/tabular-nums）
    ├── mtheme.dart                # .mtheme JSON 解析/导出 + WCAG 对比度守卫（<4.5:1 自动校正）
    └── theme_controller.dart      # L3 用户层：基准主题 + 自定义强调色 + 冷暖基调(±8° 色相)
```

## 组件层使用方式（唯一的取色入口）

```dart
final t = context.tokens;              // 扩展定义在 app_tokens.dart
Container(color: t.surface);           // 卡片底
Slider(activeColor: t.primary);        // 音轨滑杆
Text('30:00', style: Theme.of(context).textTheme.displayLarge); // 倒计时数字已内置 tabular-nums
```

## 与规范的对应关系

| 规范条目 | 代码落点 |
|----------|----------|
| 8.1 Token 三层架构 | app_tokens(L1) / app_themes 内置注册(L2) / theme_controller(L3) |
| 8.2 .mtheme 格式 schemaVersion=1 | mtheme.dart `MTheme.fromJson/toJson` |
| 8.3 缺省回落、不白屏 | fromJson 中非法/缺省 token 回落基准主题 |
| 8.3 对比度守卫 4.5:1 | `AppTokensContrastGuard.withContrastGuard()` |
| 2.1 四套内置主题 | `kBuiltinThemes`：night-forest / deep-space / morning-mist / warm-sand |
| 三·数字等宽防跳动 | buildAppTheme 的 displayLarge `FontFeature.tabularFigures()` |
| 四·主题切换 300ms 过渡 | main.dart `AnimatedTheme(duration: 300ms)` |
| 音源图标 emoji 占位 | main.dart `kSoundEmojiPlaceholder` 映射表（上线前整表换线性图标） |

## 工程接入待办

1. 把 `lib/theme/` 拷入 Flutter 工程；`main.dart` 仅作示例参考。
2. `AppThemeController` 中已留 TODO：接入 `shared_preferences` 持久化 baseId/accent/warmth/followSystem。
3. 新增内置主题 = 在 `app_tokens.dart` 加一个 `AppTokens` 常量并在 `kBuiltinThemes` 注册，组件零改动。
4. 状态管理如团队用 provider/riverpod，替换示例中的 `DefaultValues` InheritedWidget 即可，theme/ 目录不受影响。
