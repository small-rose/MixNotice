/// 方案库本地存储（FR-11~13a, E-05/E-06）
/// 原子写：tmp 文件 + rename，保证不产生半写数据。
library;

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../core/constants.dart';
import 'models.dart';

class PresetRepository {
  File? _file;

  Future<File> _fileRef() async {
    if (_file != null) return _file!;
    final dir = await getApplicationSupportDirectory();
    final f = File('${dir.path}${Platform.pathSeparator}presets.json');
    _file = f;
    return f;
  }

  /// 读取：预设 + 自定义；损坏文件整体降级为仅预设（E-06）
  Future<List<PresetData>> loadAll() async {
    final f = await _fileRef();
    if (!f.existsSync()) return List.of(kBuiltinPresets.map(_fromBuiltin));
    try {
      final store = PresetStoreFile.fromJson(json.decode(f.readAsStringSync()));
      return List.of(kBuiltinPresets.map(_fromBuiltin))..addAll(store.custom);
    } catch (_) {
      return List.of(kBuiltinPresets.map(_fromBuiltin)); // E-06 丢弃损坏数据
    }
  }

  /// 原子写入自定义方案（E-05：失败抛出由 UI 提示，不留半写数据）
  Future<void> saveCustom(List<PresetData> custom) async {
    final f = await _fileRef();
    final tmp = File('${f.path}.tmp');
    tmp.writeAsStringSync(json.encode(PresetStoreFile(custom).toJson()), flush: true);
    tmp.renameSync(f.path); // 原子替换
  }

  static PresetData _fromBuiltin(Preset p) => PresetData(
        id: p.id,
        name: p.name,
        builtin: true,
        channels: p.tracks
            .map((t) => Channel(id: 'ch_${p.id}_${t.sourceId}', sourceId: t.sourceId, volume: t.volume))
            .toList(),
      );
}
