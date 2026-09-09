/// 内置表情包（后端 sticker 目录表对齐）。
/// id = slug = 本地素材文件名（assets/stickers/<id>.png）；description 即"见过"的
/// 存档描述（预置中文），后端 AI 解析/历史标签用它，前端离线时也能展示。
class Sticker {
  const Sticker({
    required this.id,
    required this.name,
    required this.description,
    this.sort = 0,
  });

  final String id; // slug，如 happy
  final String name; // 显示名（中文）
  final String description; // 中文描述（AI 上下文 / 历史标签）
  final int sort;

  factory Sticker.fromJson(Map<String, dynamic> json) {
    return Sticker(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      sort: (json['sort'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 离线兜底目录（后端不可达/未下发时仍可渲染本地素材；数据与 sticker_seeds.py 一致）。
const defaultStickers = [
  Sticker(id: 'happy', name: '开心', description: '咧嘴大笑，超开心'),
  Sticker(id: 'cry', name: '大哭', description: '嚎啕大哭，委屈爆发'),
  Sticker(id: 'aggrieved', name: '委屈', description: '扁嘴委屈，快哭了'),
  Sticker(id: 'angry', name: '生气', description: '气鼓鼓，别惹我'),
  Sticker(id: 'kiss', name: '亲亲', description: '飞吻亲亲，爱你'),
  Sticker(id: 'laugh', name: '大笑', description: '笑得前仰后合'),
  Sticker(id: 'awkward', name: '尴尬', description: '尴尬挠头，好难为情'),
  Sticker(id: 'gnight', name: '晚安', description: '盖好被子，晚安好梦'),
  Sticker(id: 'love', name: '爱你', description: '比心表白，爱你哟'),
  Sticker(id: 'gogogo', name: '加油', description: '握拳打气，加油冲'),
  Sticker(id: 'proud', name: '得意', description: '叉腰得意，我可太棒了'),
  Sticker(id: 'shocked', name: '震惊', description: '瞪大眼睛，吓一跳'),
  Sticker(id: 'confused', name: '疑惑', description: '歪头问号，一脸懵'),
  Sticker(id: 'shy', name: '害羞', description: '捂脸害羞，脸红了'),
  Sticker(id: 'lazy', name: '摆烂', description: '瘫倒摆烂，不想动'),
  Sticker(id: 'yeah', name: '耶', description: '举双手耶，太好了'),
  Sticker(id: 'hungry', name: '饿', description: '饿到贴肚皮，想吃东西'),
  Sticker(id: 'oops', name: '坏了', description: '捂嘴糟了，闯祸了'),
  Sticker(id: 'bye', name: '拜拜', description: '挥手告别，下次见'),
  Sticker(id: 'ok', name: '好的', description: '比 OK 手势，收到明白'),
];
