/// 方案控制器（FR-10~13a）
library;

import 'package:flutter/foundation.dart';

import '../core/analytics.dart';
import '../core/constants.dart';
import '../data/models.dart';
import '../data/preset_repository.dart';

class PresetController extends ChangeNotifier {
  PresetController(this._repo);

  final PresetRepository _repo;
  final List<PresetData> presets = [];
  int _customSeq = 1;

  List<PresetData> get builtin => presets.where((p) => p.builtin).toList();
  List<PresetData> get custom => presets.where((p) => !p.builtin).toList();

  Future<void> load() async {
    presets
      ..clear()
      ..addAll(await _repo.loadAll());
    _customSeq = custom.length + 1;
    notifyListeners();
  }

  /// 保存当前混音为自定义方案。返回 null=成功，否则为提示文案。
  Future<String?> saveCurrent(List<Channel> current, {String? name}) async {
    if (custom.length >= kMaxCustomPresets) return '方案已满，请删除后再保存'; // FR-13
    final preset = PresetData(
      id: 'c-${DateTime.now().millisecondsSinceEpoch}',
      name: name?.trim().isNotEmpty == true ? name!.trim() : '我的方案 $_customSeq', // FR-11
      builtin: false,
      channels: current
          .map((c) => Channel(id: 'ch_${c.id}', sourceId: c.sourceId, volume: c.volume, muted: c.muted))
          .toList(),
    );
    presets.add(preset);
    _customSeq++;
    try {
      await _repo.saveCustom(custom);
    } catch (_) {
      presets.remove(preset); // E-05：失败回滚，不留半写数据
      _customSeq--;
      return '保存失败，请检查存储空间';
    }
    Analytics.instance.log('mix_save', {'channels': preset.channels.length});
    notifyListeners();
    return null;
  }

  /// FR-12 重命名（仅自定义）
  Future<String?> rename(PresetData preset, String newName) async {
    if (preset.builtin) return '预设方案不可修改';
    final i = presets.indexOf(preset);
    presets[i] = PresetData(id: preset.id, name: newName.trim(), builtin: false, channels: preset.channels);
    try {
      await _repo.saveCustom(custom);
    } catch (_) {
      return '保存失败，请检查存储空间';
    }
    notifyListeners();
    return null;
  }

  /// FR-12 删除（仅自定义；二次确认由 UI 层处理）
  Future<String?> delete(PresetData preset) async {
    if (preset.builtin) return '预设方案不可删除';
    presets.remove(preset);
    try {
      await _repo.saveCustom(custom);
    } catch (_) {
      presets.add(preset); // 失败回滚
      return '删除失败，请检查存储空间';
    }
    notifyListeners();
    return null;
  }
}
