/// 设置存储（FR-24~27）
library;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier {
  String quality; // 'standard' | 'high'（FR-24，默认 high）
  String defaultPresetId; // 空 = 不自动播放（FR-25）；默认「雨天篝火」
  String restLinkedPresetId; // 休息倒计时联动方案（FR-19，默认溪流清晨）
  bool autoStart; // 开机自启（FR-26，仅桌面）
  String logoTheme; // App 内品牌标记取色：'auto' | 'dark' | 'light'（默认 auto，跟随主题）
  String iconTheme; // 桌面图标：'dark' | 'light' | 'system'（默认深色，仅 Android 生效）

  AppSettings({
    this.quality = 'high',
    this.defaultPresetId = 'p-rain-fire',
    this.restLinkedPresetId = 'p-stream-morning',
    this.autoStart = false,
    this.logoTheme = 'auto',
    this.iconTheme = 'dark',
  });

  /// UI 修改字段后调用：通知监听者（ChangeNotifier.notifyListeners 为 protected，
  /// 页面层不允许直接调用，统一走此入口）
  void notifyChanged() => notifyListeners();

  /// 启动 bootstrap：用磁盘读取值覆盖默认值（启动时序：先 runApp 后加载，
  /// 加载完成后通知设置页刷新）。
  void updateFrom(AppSettings other) {
    quality = other.quality;
    defaultPresetId = other.defaultPresetId;
    restLinkedPresetId = other.restLinkedPresetId;
    autoStart = other.autoStart;
    logoTheme = other.logoTheme;
    iconTheme = other.iconTheme;
    notifyListeners();
  }
}

class SettingsRepository {
  static const _kQuality = 'settings.quality';
  static const _kDefaultPreset = 'settings.defaultPreset';
  static const _kRestLinked = 'settings.restLinkedPreset';
  static const _kAutoStart = 'settings.autoStart';
  static const _kLogoTheme = 'settings.logoTheme';
  static const _kIconTheme = 'settings.iconTheme';

  Future<AppSettings> load() async {
    final sp = await SharedPreferences.getInstance();
    return AppSettings(
      quality: sp.getString(_kQuality) ?? 'high',
      defaultPresetId: sp.getString(_kDefaultPreset) ?? 'p-rain-fire',
      restLinkedPresetId: sp.getString(_kRestLinked) ?? 'p-stream-morning',
      autoStart: sp.getBool(_kAutoStart) ?? false,
      logoTheme: sp.getString(_kLogoTheme) ?? 'auto',
      iconTheme: sp.getString(_kIconTheme) ?? 'dark',
    );
  }

  Future<void> save(AppSettings s) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kQuality, s.quality);
    await sp.setString(_kDefaultPreset, s.defaultPresetId);
    await sp.setString(_kRestLinked, s.restLinkedPresetId);
    await sp.setBool(_kAutoStart, s.autoStart);
    await sp.setString(_kLogoTheme, s.logoTheme);
    await sp.setString(_kIconTheme, s.iconTheme);
  }
}
