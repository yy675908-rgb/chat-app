class CharacterProfile {
  const CharacterProfile({
    required this.name,
    required this.status,
    required this.firstMetAt,
  });

  final String name;
  final String status;
  final DateTime firstMetAt;

  int get daysTogether {
    final now = DateTime.now();
    final start = DateTime(firstMetAt.year, firstMetAt.month, firstMetAt.day);
    final today = DateTime(now.year, now.month, now.day);
    return today.difference(start).inDays + 1;
  }
}
