import 'package:character_chat_app/models/chat_message.dart';
import 'package:character_chat_app/services/memory_selector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ChatMessage user(String id, String text) => ChatMessage(
        id: id,
        author: MessageAuthor.user,
        text: text,
        sentAt: DateTime.utc(2026),
      );

  test('small unrelated memory sets are not injected', () {
    final memories = ['用户喜欢陶瓷', '用户去年换过电脑', '用户常去海边散步'];
    expect(
      MemorySelector.selectRelevant(memories, [user('u', '今天下雨了')]),
      isEmpty,
    );
  });

  test('large memory sets inject only current-topic memories', () {
    final memories = [
      '用户第一次见面时带了一把黑伞',
      '用户不喜欢被连续追问',
      '用户去年换过一次电脑',
      '用户喜欢在海边散步',
      '用户喝咖啡通常不加糖',
      '用户曾提到一本历史小说',
      '用户不爱看恐怖片',
      '用户最近在整理书桌',
      '用户周末常常睡得晚',
      '用户昨天说想去公园',
      '用户最近工作比较忙',
      '用户答应下次见面带照片',
    ];

    final selected = MemorySelector.selectRelevant(
      memories,
      [user('u', '周末如果天气好，我们去海边散步吧。')],
    );

    expect(selected.length, lessThanOrEqualTo(6));
    expect(selected, contains(memories[3]));
    expect(selected, isNot(contains(memories.first)));
    expect(selected, isNot(contains(memories[1])));
    expect(selected, isNot(contains(memories.last)));
    expect(selected, isNot(contains(memories[2])));
  });

  test('generic wording alone does not pull unrelated memories forward', () {
    final memories = ['用户喜欢陶瓷'];
    final selected = MemorySelector.selectRelevant(
      memories,
      [user('u', '我喜欢下雨天。')],
    );
    expect(selected, isEmpty);
  });

  test('assistant echoes cannot keep an old memory alive by themselves', () {
    final memories = ['用户喜欢陶瓷'];
    final history = [
      user('u1', '今天下雨了。'),
      ChatMessage(
        id: 'a1',
        author: MessageAuthor.character,
        text: '你之前说过喜欢陶瓷。',
        sentAt: DateTime.utc(2026, 1, 1, 0, 1),
      ),
    ];
    expect(MemorySelector.selectRelevant(memories, history), isEmpty);
  });

  test('system prompt memory section is compacted without touching other sections', () {
    final memories = [
      '基础记忆一',
      '基础记忆二',
      '旧事三',
      '用户喜欢海边散步',
      '旧事五',
      '旧事六',
      '旧事七',
      '旧事八',
      '旧事九',
      '近期记忆十',
      '近期记忆十一',
      '近期记忆十二',
    ];
    final prompt = '角色设定\n\n'
        '你和用户的共同记忆（仅属于你们这段关系）：\n'
        '${memories.map((item) => '- $item').join('\n')}\n\n'
        '用户偏好的回应方式：\n- 简洁自然';

    final compacted = MemorySelector.compactSystemPrompt(
      prompt,
      [user('u', '还记得我们说过海边散步吗？')],
    );

    expect(compacted, contains('用户喜欢海边散步'));
    expect(compacted, contains('用户偏好的回应方式：\n- 简洁自然'));
    final memoryBlock = compacted
        .split('你和用户的共同记忆（仅属于你们这段关系）：\n')[1]
        .split('\n\n')[0];
    expect(memoryBlock.split('\n').length, lessThanOrEqualTo(6));
  });
}
