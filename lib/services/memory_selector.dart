import '../models/chat_message.dart';

class MemorySelector {
  const MemorySelector._();

  static const _maxInjectedMemories = 6;
  static const _contextUserTurns = 2;
  static const _memoryMarkers = <String>[
    '你和用户的共同记忆（仅属于你们这段关系）：\n',
    '你和用户的共同记忆：\n',
  ];
  static const _genericFeatures = <String>{
    '用户',
    '我们',
    '你们',
    '他们',
    '自己',
    '这个',
    '那个',
    '这里',
    '那里',
    '现在',
    '今天',
    '昨天',
    '明天',
    '最近',
    '之前',
    '以后',
    '时候',
    '一个',
    '一些',
    '比较',
    '有点',
    '可能',
    '应该',
    '需要',
    '可以',
    '还是',
    '已经',
    '没有',
    '不会',
    '不是',
    '就是',
    '觉得',
    '感觉',
    '想要',
    '喜欢',
    '知道',
    '记得',
    '事情',
    '东西',
    '聊天',
    '回复',
    '消息',
    '关系',
    '对话',
    'user',
    'users',
    'like',
    'likes',
    'liked',
    'want',
    'wants',
    'wanted',
    'today',
    'yesterday',
    'tomorrow',
    'recent',
    'recently',
  };

  static String compactSystemPrompt(
    String systemPrompt,
    List<ChatMessage> history,
  ) {
    String? marker;
    var markerIndex = -1;
    for (final candidate in _memoryMarkers) {
      final index = systemPrompt.indexOf(candidate);
      if (index >= 0 && (markerIndex < 0 || index < markerIndex)) {
        marker = candidate;
        markerIndex = index;
      }
    }
    if (marker == null) return systemPrompt;

    final bodyStart = markerIndex + marker.length;
    final sectionEnd = systemPrompt.indexOf('\n\n', bodyStart);
    final bodyEnd = sectionEnd < 0 ? systemPrompt.length : sectionEnd;
    final rawBody = systemPrompt.substring(bodyStart, bodyEnd);
    final memories = rawBody
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.startsWith('- '))
        .map((line) => line.substring(2).trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final selected = selectRelevant(memories, history);
    final replacement = selected.map((memory) => '- $memory').join('\n');
    return systemPrompt.replaceRange(bodyStart, bodyEnd, replacement);
  }

  static List<String> selectRelevant(
    List<String> memories,
    List<ChatMessage> history,
  ) {
    if (memories.isEmpty || history.isEmpty) return const [];

    final visible = history
        .where(
          (message) =>
              message.author != MessageAuthor.system && !message.isRetracted,
        )
        .toList();
    if (visible.isEmpty) return const [];

    final userTurns = visible
        .where((message) => message.author == MessageAuthor.user)
        .toList();
    final basis = userTurns.isNotEmpty ? userTurns : visible;
    final start = basis.length > _contextUserTurns
        ? basis.length - _contextUserTurns
        : 0;
    final context = basis.sublist(start).map((message) => message.text).join(' ');
    final contextFeatures = _features(context);
    if (contextFeatures.isEmpty) return const [];

    final scored = <_ScoredMemory>[];
    for (var index = 0; index < memories.length; index++) {
      final features = _features(memories[index]);
      var score = 0;
      for (final feature in features) {
        if (contextFeatures.contains(feature)) {
          score += feature.length >= 3 ? 3 : 2;
        }
      }
      if (score > 0) {
        scored.add(_ScoredMemory(index: index, score: score));
      }
    }
    scored.sort((a, b) {
      final scoreOrder = b.score.compareTo(a.score);
      if (scoreOrder != 0) return scoreOrder;
      return b.index.compareTo(a.index);
    });

    final selected = scored.take(_maxInjectedMemories).toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    return selected.map((item) => memories[item.index]).toList();
  }

  static Set<String> _features(String text) {
    final lower = text.toLowerCase();
    final features = <String>{};
    for (final match in RegExp(r'[\u4e00-\u9fff]+|[a-z0-9]+').allMatches(lower)) {
      final token = match.group(0)!;
      if (RegExp(r'^[a-z0-9]+$').hasMatch(token)) {
        if (token.length >= 2 && !_genericFeatures.contains(token)) {
          features.add(token);
        }
        continue;
      }
      final runes = token.runes.toList();
      if (runes.length == 1) continue;
      for (var width = 2; width <= 3; width++) {
        if (runes.length < width) continue;
        for (var index = 0; index <= runes.length - width; index++) {
          final feature = String.fromCharCodes(
            runes.sublist(index, index + width),
          );
          if (!_genericFeatures.contains(feature)) features.add(feature);
        }
      }
    }
    return features;
  }
}

class _ScoredMemory {
  const _ScoredMemory({required this.index, required this.score});

  final int index;
  final int score;
}
