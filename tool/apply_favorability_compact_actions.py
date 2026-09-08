from pathlib import Path
import re


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly 1 match, found {count}')
    return text.replace(old, new, 1)


chat_path = Path('lib/screens/chat_screen.dart')
chat = chat_path.read_text()

chat = replace_once(
    chat,
    "'关系亲密度：${character.userIntimacy}/100'",
    "'用户好感度：${character.userIntimacy}/100'",
    'group roster label',
)
chat = replace_once(
    chat,
    "'群聊成员与用户亲密度：\\n$roster\\n\\n'",
    "'用户对群聊各角色的好感度：\\n$roster\\n\\n'",
    'group intent request label',
)
chat = replace_once(
    chat,
    "'请完全依据“${character.name}”的完整设定、当前关系和最近对话，'\n"
    "            '当前关系不是背景资料：${_intimacyBehavior(character.userIntimacy)}'\n"
    "            '亲密度必须参与是否主动接话、是否在意用户或其他角色的判断，'\n"
    "            '但不得盖过角色性格和当前情境。'",
    "'请完全依据“${character.name}”的完整设定、当前关系和最近对话，'\n"
    "            '用户对这个角色的好感度：${_intimacyBehavior(character.userIntimacy)}'\n"
    "            '好感度可以影响角色是否想主动接话、争取注意或改变用户观感，'\n"
    "            '但它不是关系定义；具体权重由角色性格、真实关系和当前情境决定。'",
    'group intent semantics',
)

start_marker = "    final intimacyInstruction = _currentConversation?.isGroup == true"
end_marker = "    final groupInstruction ="
start = chat.find(start_marker)
end = chat.find(end_marker, start)
if start < 0 or end < 0:
    raise SystemExit('main favorability instruction block not found')
new_block = """    final intimacyInstruction = _currentConversation?.isGroup == true
        ? '\\n\\n用户对群聊各角色的好感度如下，所有参与角色都知道这些信息：\\n'
              '${_groupParticipants.map((item) => '- ${item.name}：${item.userIntimacy}/100（${_intimacyLabel(item.userIntimacy)}）').join('\\n')}\\n'
              '好感度只表示用户对某个角色的主观好感和接受程度，不定义任何关系类型。'
              '当前角色对这个数值的感知：${_intimacyBehavior(activeCharacter.userIntimacy)}'
              '角色可以按自己的性格决定是否在意、是否想提高、维持或改变用户的好感，'
              '并让这种动机自然影响主动程度、接话、试探、关心、争取注意或保持距离等行为。'
              '但不得仅凭好感度推断恋爱、暧昧、伴侣、亲属或其他关系，也不要机械迎合用户。'
        : '\\n\\n用户当前对你的好感度为${activeCharacter.userIntimacy}/100'
              '（${_intimacyLabel(activeCharacter.userIntimacy)}）。'
              '好感度只表示用户对你的主观好感和接受程度，不定义你们是什么关系。'
              '你能感知这个数值，并可以按自己的性格和当前处境决定是否在意、'
              '是否希望提高、维持或改变它，再把这种动机自然反映到你的行为上。'
              '你可以尝试讨用户喜欢、试探、拉近或拉开距离，也可以不把提高好感当目标。'
              '真正的关系由角色设定、共同经历和当前对话决定；'
              '不要仅凭好感度推断恋爱、暧昧、伴侣、亲属或其他固定关系，也不要机械迎合用户。';
"""
chat = chat[:start] + new_block + chat[end:]

chat = replace_once(
    chat,
    "                  '亲密度',",
    "                  '用户好感度',",
    'drawer favorability heading',
)
chat = replace_once(
    chat,
    "                '作为角色的关系行为基线；会影响主动、边界与在意程度，'\n"
    "                '群聊中成员也能感知差异。',",
    "                '表示你对这个角色的好感，不等于关系类型；角色能感知这个数值，'\n"
    "                '并会按自己的性格决定如何反应。',",
    'drawer favorability explanation',
)
chat = replace_once(
    chat,
    "                          label: groupScope ? '角色与亲密度' : '角色设定',",
    "                          label: groupScope ? '角色与好感度' : '角色设定',",
    'group drawer shortcut',
)
old_functions = """String _intimacyLabel(int value) {
  if (value < 20) return '疏远';
  if (value < 40) return '保留';
  if (value < 60) return '普通';
  if (value < 80) return '亲近';
  return '很亲密';
}

String _intimacyBehavior(int value) {
  if (value < 20) {
    return '保持明显距离：少主动追问或索取关注，边界感强，关心也更克制，不默认拥有亲密关系中的权利。';
  }
  if (value < 40) {
    return '关系仍在试探：可以关心和记住细节，但主动程度有限，亲昵、吃醋或占有感应很轻或不出现。';
  }
  if (value < 60) {
    return '关系熟悉但未深度绑定：会自然延续话题、追问重要后续，偶尔表达偏好或不满，同时保留彼此空间。';
  }
  if (value < 80) {
    return '关系亲近：会更主动地关心、追问、挽留或争取注意；符合性格时可以护短、吃醋、偏心或表达依赖。';
  }
  return '关系高度亲密：把彼此视为持续存在的重要联结，会主动维护关系、表达需要和偏爱；符合性格时可更直接地亲昵、吃醋、护短、约束或争取用户，同时尊重明确边界。';
}
"""
new_functions = """String _intimacyLabel(int value) {
  if (value < 20) return '很低';
  if (value < 40) return '偏低';
  if (value < 60) return '一般';
  if (value < 80) return '较高';
  return '很高';
}

String _intimacyBehavior(int value) {
  return '$value/100（${_intimacyLabel(value)}）。'
      '这是用户对角色的主观好感和接受程度，不是关系类型。'
      '角色可以自行决定是否在意，以及是否想提高、维持或改变它。';
}
"""
chat = replace_once(chat, old_functions, new_functions, 'favorability label and guidance')
chat_path.write_text(chat)

bubble_path = Path('lib/widgets/message_bubble.dart')
bubble = bubble_path.read_text()
bubble = replace_once(
    bubble,
    "                    Wrap(\n                      spacing: 7,\n                      runSpacing: 7,",
    "                    Wrap(\n                      spacing: 4,\n                      runSpacing: 4,",
    'action wrap spacing',
)
bubble = replace_once(
    bubble,
    "        borderRadius: BorderRadius.circular(11),\n"
    "        clipBehavior: Clip.antiAlias,\n"
    "        child: InkWell(\n"
    "          onTap: onPressed,\n"
    "          child: SizedBox(\n"
    "            width: 36,\n"
    "            height: 34,\n"
    "            child: Icon(icon, size: 17, color: foreground),",
    "        borderRadius: BorderRadius.circular(10),\n"
    "        clipBehavior: Clip.antiAlias,\n"
    "        child: InkWell(\n"
    "          onTap: onPressed,\n"
    "          child: SizedBox(\n"
    "            width: 32,\n"
    "            height: 30,\n"
    "            child: Icon(icon, size: 16, color: foreground),",
    'bubble action size',
)
bubble = replace_once(
    bubble,
    "      offset: const Offset(0, 38),",
    "      offset: const Offset(0, 34),",
    'retry menu offset',
)
bubble = replace_once(
    bubble,
    "        borderRadius: BorderRadius.circular(11),\n"
    "        clipBehavior: Clip.antiAlias,\n"
    "        child: SizedBox(\n"
    "          width: 40,\n"
    "          height: 34,",
    "        borderRadius: BorderRadius.circular(10),\n"
    "        clipBehavior: Clip.antiAlias,\n"
    "        child: SizedBox(\n"
    "          width: 36,\n"
    "          height: 30,",
    'retry button size',
)
bubble = replace_once(
    bubble,
    "                size: 19,",
    "                size: 17,",
    'retry refresh icon size',
)
bubble = replace_once(
    bubble,
    "                size: 13,",
    "                size: 11,",
    'retry dropdown icon size',
)
bubble = replace_once(
    bubble,
    "      height: 34,\n"
    "      decoration: BoxDecoration(\n"
    "        color: scheme.surfaceContainerLow,\n"
    "        borderRadius: BorderRadius.circular(11),",
    "      height: 30,\n"
    "      decoration: BoxDecoration(\n"
    "        color: scheme.surfaceContainerLow,\n"
    "        borderRadius: BorderRadius.circular(10),",
    'version control size',
)
bubble = replace_once(
    bubble,
    "                fontSize: 11.5,",
    "                fontSize: 11,",
    'version label font size',
)
bubble = replace_once(
    bubble,
    "          width: 30,\n"
    "          height: 34,\n"
    "          child: Icon(\n"
    "            icon,\n"
    "            size: 19,",
    "          width: 26,\n"
    "          height: 30,\n"
    "          child: Icon(\n"
    "            icon,\n"
    "            size: 17,",
    'version arrows size',
)
bubble_path.write_text(bubble)

pubspec = Path('pubspec.yaml')
version_text = pubspec.read_text()
version_text, count = re.subn(
    r'^version:\s*.*$',
    'version: 0.9.15+25',
    version_text,
    count=1,
    flags=re.M,
)
if count != 1:
    raise SystemExit('version line not found')
pubspec.write_text(version_text)

print('favorability semantics and compact message actions applied')
