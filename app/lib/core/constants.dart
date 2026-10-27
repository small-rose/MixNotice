/// 核心常量：音源目录（FR-01）、预设方案（FR-10）
/// 音源素材：Wikimedia Commons CC0/CC BY 素材 + ffmpeg 合成噪音（见 docs/音频素材授权清单.csv）。
library;

class SoundSource {
  final String id;
  final String name;
  final String group; // nature / noise / life
  final int colorIndex; // 音源专属淡色底索引（0-7）

  // 图标：由 lib/ui/icons/sound_glyph.dart 按 id 绘制（1.8pt 描边线性图标）
  const SoundSource(this.id, this.name, this.group, this.colorIndex);

  String get asset => 'assets/audio/$id.m4a';
}

const kSoundGroups = {'nature': '自然', 'rural': '田园', 'noise': '噪音', 'life': '生活'};

const kSounds = <SoundSource>[
  // 自然（13）
  SoundSource('rain-light', '小雨', 'nature', 0),
  SoundSource('rain-heavy', '大雨', 'nature', 0),
  SoundSource('thunder', '雷声', 'nature', 1),
  SoundSource('wind', '风', 'nature', 2),
  SoundSource('stream', '溪流', 'nature', 3),
  SoundSource('waves', '海浪', 'nature', 3),
  SoundSource('birds', '鸟鸣', 'nature', 4),
  SoundSource('bird-cuckoo', '杜鹃', 'nature', 4),
  SoundSource('bird-sparrow', '麻雀', 'nature', 4),
  SoundSource('bird-nightingale', '夜莺', 'nature', 4),
  SoundSource('campfire', '篝火', 'nature', 5),
  SoundSource('forest', '森林', 'nature', 4),
  SoundSource('night-crickets', '夜晚虫鸣', 'nature', 2),
  // 田园（4）
  SoundSource('dog-bark', '狗叫', 'rural', 1),
  SoundSource('chicken', '鸡叫', 'rural', 5),
  SoundSource('goose', '鹅叫', 'rural', 3),
  SoundSource('pond', '池塘', 'rural', 0),
  // 噪音（3）
  SoundSource('noise-white', '白噪音', 'noise', 6),
  SoundSource('noise-pink', '粉噪音', 'noise', 6),
  SoundSource('noise-brown', '棕噪音', 'noise', 6),
  // 生活（3）
  SoundSource('cafe', '咖啡馆', 'life', 7),
  SoundSource('keyboard', '键盘敲击', 'life', 7),
  SoundSource('chimes', '风铃', 'life', 5),
];

SoundSource? soundById(String id) {
  for (final s in kSounds) {
    if (s.id == id) return s;
  }
  return null;
}

class PresetTrack {
  final String sourceId;
  final int volume; // 0-100
  const PresetTrack(this.sourceId, this.volume);
}

class Preset {
  final String id;
  final String name;
  final bool builtin;
  final List<PresetTrack> tracks;
  const Preset(this.id, this.name, {required this.builtin, required this.tracks});
}

/// 预设方案 8 个（FR-10）
const kBuiltinPresets = <Preset>[
  Preset('p-rain-fire', '雨天篝火', builtin: true,
      tracks: [PresetTrack('rain-light', 72), PresetTrack('campfire', 55)]),
  Preset('p-forest-morning', '森林晨间', builtin: true,
      tracks: [PresetTrack('birds', 60), PresetTrack('wind', 35), PresetTrack('forest', 40)]),
  Preset('p-sea-night', '海边夜晚', builtin: true,
      tracks: [PresetTrack('waves', 80), PresetTrack('wind', 25)]),
  Preset('p-rain-thunder', '雨夜雷声', builtin: true,
      tracks: [PresetTrack('rain-heavy', 70), PresetTrack('thunder', 30)]),
  Preset('p-stream-morning', '溪流清晨', builtin: true,
      tracks: [PresetTrack('stream', 65), PresetTrack('birds', 45)]),
  Preset('p-white-focus', '白噪音专注', builtin: true,
      tracks: [PresetTrack('noise-white', 60), PresetTrack('rain-light', 40)]),
  Preset('p-cafe-noon', '咖啡馆午后', builtin: true,
      tracks: [PresetTrack('cafe', 75), PresetTrack('chimes', 20)]),
  Preset('p-cricket-summer', '虫鸣夏夜', builtin: true,
      tracks: [PresetTrack('night-crickets', 70), PresetTrack('wind', 20)]),
];

const kMaxChannels = 6; // FR-08
const kMaxCustomPresets = 20; // FR-13
const kDefaultChannelVolume = 50; // FR-02/03 默认音量
