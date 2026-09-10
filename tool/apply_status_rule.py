from pathlib import Path
import re

chat = Path('lib/screens/chat_screen.dart')
text = chat.read_text()

text = text.replace(
    "'心绪只写1—12个字；状态写2—16个字，描述此刻真实的态度、活动或关系状态。'",
    "'心绪只写1—12个字；状态由你自己决定写什么，只要真实反映你此刻的状态即可。状态最多10个字符，可用文字、emoji、符号或混合表达，但不要使用颜文字。'",
)
text = text.replace(
    "if (value.characters.length > 16) {\n      value = value.characters.take(16).join();\n    }",
    "if (value.characters.length > 10) {\n      value = value.characters.take(10).join();\n    }",
    1,
)
text = text.replace(
    "${repairStatus ? '状态用2—16个字描述此刻真实态度、活动或关系状态；若上一轮已有状态且你判断本轮没有实质变化，输出 SAME。上一轮未记录时不得输出 SAME。' : ''}",
    "${repairStatus ? '状态由角色自己决定写什么，只要真实反映此刻状态即可；最多10个字符，可用文字、emoji、符号或混合表达，但不要使用颜文字。若上一轮已有状态且你判断本轮没有实质变化，输出 SAME。上一轮未记录时不得输出 SAME。' : ''}",
)

if '状态写2—16个字' in text or '状态用2—16个字' in text:
    raise SystemExit('old status wording remains')
if 'characters.length > 16' in text and '_normalizeStatus' in text:
    raise SystemExit('old status hard cap may remain')
chat.write_text(text)

pubspec = Path('pubspec.yaml')
pub = pubspec.read_text()
pub, count = re.subn(r'^version:\s*.*$', 'version: 0.9.19+29', pub, count=1, flags=re.M)
if count != 1:
    raise SystemExit('version line not found')
pubspec.write_text(pub)

print('status rule applied')
