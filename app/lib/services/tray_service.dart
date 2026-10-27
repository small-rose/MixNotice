/// 桌面托盘（FR-23）：播放/暂停、最近 5 个方案、退出；状态与主窗口实时同步。
/// E-12：图标加载失败降级为默认图标，菜单功能不受影响。
library;

import 'dart:io';

import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';

import '../data/preset_controller.dart';
import '../audio/playback_controller.dart';

class TrayService with WindowListener {
  TrayService._();

  static final TrayService instance = TrayService._();

  final _tray = SystemTray();
  PlaybackController? _playback;
  PresetController? _presets;

  Future<void> init(PlaybackController playback, PresetController presets) async {
    _playback = playback;
    _presets = presets;
    playback.addListener(_syncPlayPause);
    presets.addListener(_rebuildMenu);

    try {
      await _tray.initSystemTray(
        title: 'MixNoticeApp',
        iconPath: _iconPath(), // E-12：缺失时抛异常走降级
      );
    } catch (_) {
      await _tray.initSystemTray(title: 'MixNoticeApp', iconPath: _iconPath());
    }
    await _rebuildMenu();
    _tray.registerSystemTrayEventHandler((eventName) {
      if (eventName == kSystemTrayEventClick) {
        windowManager.show(); // 单击唤起主窗口
      }
    });
    windowManager.setPreventClose(true); // 关闭 = 隐藏到托盘（FR-23）
    windowManager.addListener(this);
  }

  @override
  void onWindowClose() async {
    await windowManager.hide(); // 常驻托盘而非退出
  }

  Future<void> _syncPlayPause() => _rebuildMenu();

  Future<void> _rebuildMenu() async {
    final playback = _playback;
    if (playback == null) return;
    final menu = Menu();
    await menu.buildFrom([
      MenuItemLabel(
        label: playback.isPlaying ? '暂停' : '播放',
        onClicked: (_) {
          playback.isPlaying ? playback.pause() : playback.resume();
        },
      ),
      MenuSeparator(),
      // 最近 5 个方案（FR-23）
      for (final p in _presets!.presets.take(5))
        MenuItemLabel(label: p.name, onClicked: (_) => playback.loadPreset(p)),
      MenuSeparator(),
      MenuItemLabel(
        label: '退出',
        onClicked: (_) async {
          windowManager.setPreventClose(false);
          await playback.stopAll();
          await _tray.destroy();
          exit(0);
        },
      ),
    ]);
    await _tray.setContextMenu(menu);
  }

  String _iconPath() {
    // TODO(W6)：随打包资源替换正式托盘图标（深浅两态）
    return 'assets/tray/icon.ico';
  }
}
