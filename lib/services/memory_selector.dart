import '../models/chat_message.dart';

class MemorySelector {
  const MemorySelector._();

  static const _maxInjectedMemories = 6;
  static const _memoryMarkers = <String>[
    '你和用户的共同记忆（仅属于你们这段关系）：\n',
    '你和用户的共同记忆：\n',
  ];

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
    final visible = history
        .where((message) => message.author != MessageAuthor.system)
        .toList();
    final start = visible.length > 8 ? visible.length - 8 : 0;
    final context = visible.sublist(start).map((message) => message.text).join(' ');
    final contextFeatures = _features(context);

    final selectedIndexes = <int>{};

    final scored = <_ScoredMemory>[];
    for (var index = 0; index < memories.length; index++) {
      if (selectedIndexes.contains(index)) continue;
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
    for (final item in scored) {
      if (selectedIndexes.length >= _maxInjectedMemories) break;
      selectedIndexes.add(item.index);
    }

    final ordered = selectedIndexes.toList()..sort();
    return ordered.map((index) => memories[index]).toList();
  }

  static Set<String> _features(String text) {
    final lower = text.toLowerCase();
    final features = <String>{};
    for (final match in RegExp(r'[\u4e00-\u9fff]+|[a-z0-9]+').allMatches(lower)) {
      final token = match.group(0)!;
      if (RegExp(r'^[a-z0-9]+$').hasMatch(token)) {
        if (token.length >= 2) features.add(token);
        continue;
      }
      final runes = token.runes.toList();
      if (runes.length == 1) {
        features.add(token);
        continue;
      }
      for (var width = 2; width <= 3; width++) {
        if (runes.length < width) continue;
        for (var index = 0; index <= runes.length - width; index++) {
          features.add(String.fromCharCodes(runes.sublist(index, index + width)));
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
