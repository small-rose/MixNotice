/// 数据模型：音轨、混音、方案（FR-13a 结构化 JSON + 版本号，V1.1 云同步预留）
library;

import '../core/constants.dart';

class Channel {
  final String id; // 实例唯一 ID
  final String sourceId;
  int volume; // 0-100
  bool muted;

  Channel({required this.id, required this.sourceId, this.volume = kDefaultChannelVolume, this.muted = false});

  double get effective => muted ? 0 : volume / 100;

  Map<String, dynamic> toJson() => {'sourceId': sourceId, 'volume': volume, 'muted': muted};

  factory Channel.fromJson(Map<String, dynamic> j, String id) => Channel(
        id: id,
        sourceId: j['sourceId'] as String,
        volume: (j['volume'] as num?)?.toInt() ?? kDefaultChannelVolume,
        muted: (j['muted'] as bool?) ?? false,
      );
}

class PresetData {
  final String id;
  final String name;
  final bool builtin;
  final List<Channel> channels;

  const PresetData({required this.id, required this.name, required this.builtin, required this.channels});

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'builtin': builtin,
        'channels': channels.map((c) => c.toJson()).toList(),
      };

  factory PresetData.fromJson(Map<String, dynamic> j) => PresetData(
        id: j['id'] as String,
        name: j['name'] as String,
        builtin: (j['builtin'] as bool?) ?? false,
        channels: ((j['channels'] as List?) ?? [])
            .whereType<Map<String, dynamic>>()
            .map((c) => Channel.fromJson(c, _genId()))
            .toList(),
      );

  static String _genId() => 'ch_${DateTime.now().microsecondsSinceEpoch}_'
      '${(DateTime.now().microsecondsSinceEpoch % 9973)}';
}

/// 本地方案库文件格式（E-06：版本不识别的条目丢弃）
class PresetStoreFile {
  static const int version = 1;
  final List<PresetData> custom;

  const PresetStoreFile(this.custom);

  Map<String, dynamic> toJson() => {
        'schemaVersion': version, // FR-13a 迁移预留
        'presets': custom.map((p) => p.toJson()).toList(),
      };

  /// 逐条解析，损坏条目跳过（E-06）
  static PresetStoreFile fromJson(Map<String, dynamic> j) {
    final list = ((j['presets'] as List?) ?? []).whereType<Map<String, dynamic>>();
    final ok = <PresetData>[];
    for (final item in list) {
      try {
        if (item['schemaVersion'] != null && item['schemaVersion'] != version) continue;
        ok.add(PresetData.fromJson(item));
      } catch (_) {/* 跳过损坏条目 */}
    }
    return PresetStoreFile(ok);
  }
}
