import 'package:flutter_test/flutter_test.dart';
import 'package:lifehub/features/ai/services/storyline_service.dart';

void main() {
  test('character storyline round-trips ordered nodes and current position',
      () {
    const original = CharacterStorylineData(
      characterId: 'companion',
      nodes: [
        StorylineNode(
          id: 'start',
          title: '初始位置',
          content: 'Prada 商业活动初识',
        ),
        StorylineNode(
          id: 'greeting',
          title: '正式打招呼',
          content: '保持初识距离感',
        ),
      ],
      currentNodeId: 'greeting',
    );

    final restored = CharacterStorylineData.fromJson(original.toJson());
    expect(restored.characterId, 'companion');
    expect(restored.nodes, hasLength(2));
    expect(restored.nodes.first.content, 'Prada 商业活动初识');
    expect(restored.nodes.last.title, '正式打招呼');
    expect(restored.currentNodeId, 'greeting');
  });

  test('old three-part storyline migrates without losing text', () {
    final restored = CharacterStorylineData.fromJson({
      'character_id': 'companion',
      'premise': 'Prada 商业活动初识',
      'progress': '刚刚交换姓名',
      'direction': '保持初识距离感',
    });

    expect(restored.nodes.map((node) => node.content), [
      'Prada 商业活动初识',
      '刚刚交换姓名',
      '保持初识距离感',
    ]);
    expect(restored.currentNodeId, 'legacy_progress');
  });
}
