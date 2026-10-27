// 冒烟测试：核心目录数据完整性（FR-01 三组 16 音源、FR-10 八个预设）
import 'package:flutter_test/flutter_test.dart';
import 'package:mixnotice/core/constants.dart';

void main() {
  test('音源目录：23 个音源、四组齐全、素材路径唯一', () {
    expect(kSounds.length, 23);
    expect(kSounds.map((s) => s.group).toSet(), {'nature', 'rural', 'noise', 'life'});
    expect(kSounds.map((s) => s.id).toSet().length, 23);
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
