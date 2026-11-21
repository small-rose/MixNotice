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

const kSoundGroups = {'nature': '自然', 'rural': '田园', 'life': '生活', 'noise': '噪音'};

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
  // 田园（8）—— 原「鸡叫」拆成公鸡 / 母鸡两个独立音源
  // v1.4：鸭叫下线；动物叫声全部带垫底噪；按「家禽→家畜→其他→环境」排序
  SoundSource('rooster-crow', '公鸡', 'rural', 5),
  SoundSource('hen-cackle', '母鸡', 'rural', 5),
  SoundSource('dog-bark', '狗叫', 'rural', 1),
  SoundSource('goose', '鹅叫', 'rural', 3),
  SoundSource('cow-moo', '牛哞', 'rural', 7),
  SoundSource('sheep-baa', '羊咩', 'rural', 2),
  SoundSource('cat-meow', '猫叫', 'rural', 1),
  SoundSource('pond', '池塘', 'rural', 0),
  // 生活（3）
  SoundSource('cafe', '咖啡馆', 'life', 7),
  SoundSource('keyboard', '键盘敲击', 'life', 7),
  SoundSource('chimes', '风铃', 'life', 5),
  // 噪音（3）
  SoundSource('noise-white', '白噪音', 'noise', 6),
  SoundSource('noise-pink', '粉噪音', 'noise', 6),
  SoundSource('noise-brown', '棕噪音', 'noise', 6),
];

/// v1.1 兼容：v1.0.0 的自定义预设 / 已保存音轨里可能仍存着下线的 'chicken' id。
/// 不映射的话 soundById 返回 null，音频引擎会兜底播放小雨，属于明显错音。
const kLegacySourceAliases = <String, String>{'chicken': 'hen-cackle', 'duck-quack': 'pond', 'frog': 'pond'};

SoundSource? soundById(String id) {
  final resolved = kLegacySourceAliases[id] ?? id;
  for (final s in kSounds) {
    if (s.id == resolved) return s;
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

/// 预设方案 11 个（FR-10；v1.2 优化：田园组入列 + 助眠音源补齐）
const kBuiltinPresets = <Preset>[
  Preset('p-rain-fire', '雨天篝火', builtin: true,
      tracks: [PresetTrack('rain-light', 72), PresetTrack('campfire', 55)]),
  Preset('p-forest-morning', '森林晨间', builtin: true,
      tracks: [PresetTrack('birds', 55), PresetTrack('wind', 30), PresetTrack('forest', 40), PresetTrack('bird-nightingale', 25)]),
  Preset('p-sea-night', '海边夜晚', builtin: true,
      tracks: [PresetTrack('waves', 80), PresetTrack('wind', 25)]),
  Preset('p-rain-thunder', '雨夜雷声', builtin: true,
      tracks: [PresetTrack('rain-heavy', 70), PresetTrack('thunder', 30)]),
  Preset('p-stream-morning', '溪流清晨', builtin: true,
      tracks: [PresetTrack('stream', 65), PresetTrack('birds', 45)]),
  Preset('p-white-focus', '白噪音专注', builtin: true,
      tracks: [PresetTrack('noise-white', 60), PresetTrack('rain-light', 40)]),
  Preset('p-cafe-noon', '咖啡馆午后', builtin: true,
      tracks: [PresetTrack('cafe', 70), PresetTrack('chimes', 20), PresetTrack('keyboard', 15)]),
  Preset('p-cricket-summer', '虫鸣夏夜', builtin: true,
      tracks: [PresetTrack('night-crickets', 65), PresetTrack('pond', 35), PresetTrack('wind', 20)]),
  // v1.2 新增：田园组 + 助眠音源补齐
  Preset('p-pasture-dusk', '牧场黄昏', builtin: true,
      tracks: [PresetTrack('cow-moo', 35), PresetTrack('sheep-baa', 30), PresetTrack('wind', 25)]),
  Preset('p-farm-morning', '农家清晨', builtin: true,
      tracks: [PresetTrack('rooster-crow', 35), PresetTrack('hen-cackle', 30), PresetTrack('stream', 30)]),
  Preset('p-pink-sleep', '粉噪深眠', builtin: true,
      tracks: [PresetTrack('noise-pink', 60), PresetTrack('campfire', 30)]),
];

const kMaxChannels = 6; // FR-08
const kMaxCustomPresets = 20; // FR-13
const kDefaultChannelVolume = 50; // FR-02/03 默认音量

/// 新增音源：声音库卡片与组标题显示「新增」amber 徽标
const kNewSourceIds = <String>{'cow-moo', 'sheep-baa', 'cat-meow'};

/// 卡片状态副行文案（默认态展示；播放/已加入/试听由 UI 状态覆盖）
const kSoundDesc = <String, String>{
  'rain-light': '细密持续的雨声',
  'rain-heavy': '磅礴大雨倾泻',
  'thunder': '远处闷雷滚过',
  'wind': '舒缓的风声',
  'stream': '清浅溪水流动',
  'waves': '海浪反复冲刷',
  'birds': '清脆鸟鸣点缀',
  'bird-cuckoo': '杜鹃「布谷」远鸣',
  'bird-sparrow': '麻雀叽喳成群',
  'bird-nightingale': '夜莺婉转鸣唱',
  'campfire': '柴火噼啪燃烧',
  'forest': '林间环境声',
  'night-crickets': '夏夜虫鸣阵阵',
  'dog-bark': '2~3 声连叫，间隔有长有短',
  'rooster-crow': '清晨打鸣，一声悠长',
  'hen-cackle': '产蛋后的咯咯哒',
  'goose': '1~3 声一组',
  'pond': '池塘蛙声与水珠',
  'cow-moo': '低沉哞叫，间隔长',
  'sheep-baa': '2~3 声连叫',
  'cat-meow': '轻柔喵叫',
  'noise-white': '均匀嘶嘶声',
  'noise-pink': '柔和的低频粉噪',
  'noise-brown': '低沉如瀑布',
  'cafe': '环境人声与杯碟',
  'keyboard': '机械键盘敲击',
  'chimes': '风铃清脆作响',
};
