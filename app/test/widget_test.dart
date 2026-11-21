// 冒烟测试：核心目录数据完整性（FR-01 四组 27 音源、FR-10 八个预设）
import 'package:flutter_test/flutter_test.dart';
import 'package:sough_mix/core/constants.dart';

void main() {
  test('音源目录：27 个音源、四组齐全、素材路径唯一', () {
    expect(kSounds.length, 27);
    expect(kSounds.map((s) => s.group).toSet(), {'nature', 'rural', 'noise', 'life'});
    expect(kSounds.map((s) => s.id).toSet().length, 27);
    // v1.4 田园新音源必须存在且已登记「新增」集合
    for (final id in ['cow-moo', 'sheep-baa', 'cat-meow']) {
      expect(soundById(id), isNotNull, reason: '$id 应在目录中');
      expect(kNewSourceIds.contains(id), isTrue, reason: '$id 应标记为新增');
      expect(kSoundDesc[id], isNotNull, reason: '$id 应有状态副行文案');
    }
    // 下线音源不回归目录，但保留兼容别名映射（鸭叫/青蛙兜底到池塘）
    expect(kSounds.any((s) => s.id == 'duck-quack'), isFalse);
    expect(kSounds.any((s) => s.id == 'frog'), isFalse);
    expect(soundById('duck-quack')?.id, 'pond');
    expect(soundById('frog')?.id, 'pond');
    expect(soundById('chicken')?.id, 'hen-cackle');
  });

  test('预设方案：8 个内置，音源引用均存在', () {
    expect(kBuiltinPresets.length, 8);
    final ids = kSounds.map((s) => s.id).toSet();
    for (final p in kBuiltinPresets) {
      for (final t in p.tracks) {
        expect(ids.contains(t.sourceId), isTrue, reason: '${p.id} 引用了未知音源 ${t.sourceId}');
      }
    }
  });
}
