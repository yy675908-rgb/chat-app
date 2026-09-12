import 'package:character_chat_app/services/mood_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('extracts strict hidden mood metadata from the reply tail', () {
    final parsed = MoodCodec.parse('正文回复。\n[[心绪:有点开心]]');

    expect(parsed.text, '正文回复。');
    expect(parsed.mood, '有点开心');
    expect(parsed.hasMetadata, isTrue);
  });

  test('keeps ordinary prose containing mood wording untouched', () {
    final parsed = MoodCodec.parse('说真的，我现在的心绪：有点烦。');

    expect(parsed.text, '说真的，我现在的心绪：有点烦。');
    expect(parsed.mood, isEmpty);
    expect(parsed.hasMetadata, isFalse);
  });

  test('keeps ordinary prose containing status wording untouched', () {
    final parsed = MoodCodec.parse('当前状态：还不错。');

    expect(parsed.text, '当前状态：还不错。');
    expect(parsed.mood, isEmpty);
    expect(parsed.hasMetadata, isFalse);
  });

  test('supports the old bracketed status marker only as legacy metadata', () {
    final parsed = MoodCodec.parse('正文。\n[[状态:平静]]');

    expect(parsed.text, '正文。');
    expect(parsed.mood, '平静');
    expect(parsed.hasMetadata, isTrue);
  });

  test('does not treat malformed single-bracket markers as metadata', () {
    final parsed = MoodCodec.parse('正文。\n[心绪:开心]');

    expect(parsed.text, '正文。\n[心绪:开心]');
    expect(parsed.mood, isEmpty);
    expect(parsed.hasMetadata, isFalse);
  });

  test('hides a strict mood marker while it is still streaming', () {
    expect(
      MoodCodec.visibleTextWhileStreaming('正文回复。\n[[心绪:'),
      '正文回复。',
    );
    expect(
      MoodCodec.visibleTextWhileStreaming('正文回复。\n[[心绪:开心'),
      '正文回复。',
    );
    expect(
      MoodCodec.visibleTextWhileStreaming('正文回复。\n[[心绪:开心]]'),
      '正文回复。',
    );
  });

  test('streaming ordinary mood prose stays visible', () {
    expect(
      MoodCodec.visibleTextWhileStreaming('正文里说，我的心绪：平静'),
      '正文里说，我的心绪：平静',
    );
  });

  test('mood is normalized and capped to ten grapheme characters', () {
    expect(MoodCodec.normalizeMood('  开心   但有点困  '), '开心 但有点困');
    expect(MoodCodec.normalizeMood('一二三四五六七八九十十一十二'), '一二三四五六七八九十');
  });
}
