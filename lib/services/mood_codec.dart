import 'package:flutter/material.dart';

class MoodParseResult {
  const MoodParseResult({
    required this.text,
    required this.mood,
    required this.hasMetadata,
  });

  final String text;
  final String mood;
  final bool hasMetadata;
}

class MoodCodec {
  const MoodCodec._();

  static final RegExp _tailMetadataPattern = RegExp(
    r'(?:^|\r?\n)[ \t]*\[\[(心绪|状态)\s*[:：]\s*([^\]\r\n]{1,40})\]\][ \t]*$',
  );

  static MoodParseResult parse(String raw) {
    final match = _tailMetadataPattern.firstMatch(raw);
    if (match == null) {
      return MoodParseResult(
        text: raw.trimRight(),
        mood: '',
        hasMetadata: false,
      );
    }
    return MoodParseResult(
      text: raw.substring(0, match.start).trimRight(),
      mood: normalizeMood(match.group(2) ?? ''),
      hasMetadata: true,
    );
  }

  static String stripMetadata(String raw) => parse(raw).text;

  static String visibleTextWhileStreaming(String raw) {
    final parsed = parse(raw);
    if (parsed.hasMetadata) return parsed.text;

    final lineStart = raw.lastIndexOf('\n') + 1;
    if (lineStart <= 0 || lineStart >= raw.length) return raw;
    final tail = raw.substring(lineStart).trimLeft();
    if (!_looksLikeMoodMarkerPrefix(tail)) return raw;
    return raw.substring(0, lineStart).trimRight();
  }

  static bool _looksLikeMoodMarkerPrefix(String tail) {
    if (!tail.startsWith('[[')) return false;
    final body = tail.substring(2).trimLeft();
    if (body.isEmpty) return true;
    for (final label in const ['心绪', '状态']) {
      if (label.startsWith(body)) return true;
      if (!body.startsWith(label)) continue;
      final rest = body.substring(label.length).trimLeft();
      return rest.isEmpty || rest.startsWith(':') || rest.startsWith('：');
    }
    return false;
  }

  static String normalizeMood(String raw) {
    var value = raw
        .replaceAll(RegExp(r'[\[\]\r\n]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (value.characters.length > 10) {
      value = value.characters.take(10).join();
    }
    return value;
  }
}
