/// 桌面图标深/浅切换（Android 专属，activity-alias 方案）
///
/// Android 不允许运行时替换 `android:icon`，唯一做法是预置两个
/// activity-alias（各持一套图标资源），用 PackageManager 启停切换。
/// 已知副作用（Android 系统行为，无法避免）：
///  - 切换后桌面图标会先消失再重现，多数启动器会把它挪到最后一屏；
///  - 个别 ROM 需要重启桌面（或重启手机）才刷新。
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/analytics.dart';

class LauncherIcon {
  LauncherIcon._();

  static const _channel = MethodChannel('soughmix/app');

  /// 当前已应用到桌面的变体（'dark' | 'light'），用于去重避免反复启停组件
  static String? _applied;

  /// 是否支持（仅 Android 真机；桌面端/iOS 不支持运行时换图标）
  static bool get isSupported => !kIsWeb && Platform.isAndroid;

  /// 按 [theme]（'dark' | 'light' | 'system'）应用桌面图标。
  /// [systemDark] 为当前系统深浅色（theme == 'system' 时使用）。
  /// 失败只记埋点（老机型 ROM 可能不支持 alias 切换），不影响使用。
  static Future<void> apply(String theme, {required bool systemDark}) async {
    if (!isSupported) return;
    final target = switch (theme) {
      'light' => 'light',
      'system' => systemDark ? 'dark' : 'light',
      _ => 'dark',
    };
    if (_applied == target) return;
    try {
      final result = await _channel
          .invokeMethod<String>('setLauncherIcon', {'theme': target});
      _applied = result ?? target;
    } catch (e) {
      Analytics.instance.log('launcher_icon_error', {'error': '$e'});
    }
  }

  /// 启动时读取桌面当前实际生效的变体，同步内存去重状态（防止外部改动后失判）
  static Future<void> syncFromPlatform() async {
    if (!isSupported) return;
    try {
      _applied = await _channel.invokeMethod<String>('getLauncherIcon');
    } catch (e) {
      Analytics.instance.log('launcher_icon_error', {'error': '$e'});
    }
  }

  /// 通知权限是否已授予（Android 13+ 媒体通知也需要；其余平台恒 true）
  static Future<bool> notificationsEnabled() async {
    if (!isSupported) return true;
    try {
      return await _channel.invokeMethod<bool>('notificationsEnabled') ?? true;
    } catch (e) {
      Analytics.instance.log('launcher_icon_error', {'error': '$e'});
      return true;
    }
  }

  /// 跳转系统应用通知设置（权限被永久拒绝时的补救入口）
  static Future<void> openNotificationSettings() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod('openNotificationSettings');
    } catch (e) {
      Analytics.instance.log('launcher_icon_error', {'error': '$e'});
    }
  }

  /// 通知链路诊断：返回 channel 重要性、系统通知开关等真实状态
  static Future<Map<dynamic, dynamic>> diagnoseNotification() async {
    if (!isSupported) return {};
    try {
      return await _channel.invokeMethod('diagnoseNotification') ?? {};
    } catch (e) {
      Analytics.instance.log('launcher_icon_error', {'error': '$e'});
      return {};
    }
  }

  /// 测试用：重置内存状态
  static void resetForTest() => _applied = null;
}
