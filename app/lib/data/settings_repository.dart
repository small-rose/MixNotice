/// 设置存储（FR-24~27）
library;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier {
  String quality; // 'standard' | 'high'（FR-24，默认 high）
  String defaultPresetId; // 空 = 不自动播放（FR-25）
  String restLinkedPresetId; // 休息倒计时联动方案（FR-19，默认溪流清晨）
  bool autoStart; // 开机自启（FR-26，仅桌面）

  AppSettings({
    this.quality = 'high',
    this.defaultPresetId = '',
    this.restLinkedPresetId = 'p-stream-morning',
    this.autoStart = false,
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
    notifyListeners();
  }
}

class SettingsRepository {
  static const _kQuality = 'settings.quality';
  static const _kDefaultPreset = 'settings.defaultPreset';
  static const _kRestLinked = 'settings.restLinkedPreset';
  static const _kAutoStart = 'settings.autoStart';

  Future<AppSettings> load() async {
    final sp = await SharedPreferences.getInstance();
    return AppSettings(
      quality: sp.getString(_kQuality) ?? 'high',
      defaultPresetId: sp.getString(_kDefaultPreset) ?? '',
      restLinkedPresetId: sp.getString(_kRestLinked) ?? 'p-stream-morning',
      autoStart: sp.getBool(_kAutoStart) ?? false,
    );
  }

  Future<void> save(AppSettings s) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kQuality, s.quality);
    await sp.setString(_kDefaultPreset, s.defaultPresetId);
    await sp.setString(_kRestLinked, s.restLinkedPresetId);
    await sp.setBool(_kAutoStart, s.autoStart);
  }
}
