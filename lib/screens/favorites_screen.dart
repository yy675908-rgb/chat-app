import 'package:flutter/material.dart';

class FavoriteReplyEntry {
  const FavoriteReplyEntry({
    required this.conversationTitle,
    required this.characterName,
    required this.text,
    required this.generatedAt,
    required this.modelId,
  });

  final String conversationTitle;
  final String characterName;
  final String text;
  final DateTime generatedAt;
  final String modelId;
}

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({
    required this.entries,
    super.key,
  });

  final List<FavoriteReplyEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('收藏')),
      body: entries.isEmpty
          ? const Center(
              child: Text(
                '还没有喜欢的回复。\n点回复下方的心形，就会收进这里。',
                textAlign: TextAlign.center,
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final entry = entries[index];
                final scheme = Theme.of(context).colorScheme;
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.favorite_rounded,
                            size: 17,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              entry.conversationTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (entry.modelId.isNotEmpty)
                            Text(
                              entry.modelId,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontSize: 10.5,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SelectableText(
                        entry.text,
                        style: const TextStyle(fontSize: 14.5, height: 1.5),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
