from pathlib import Path
import re

FILES = [
    Path('lib/screens/chat_screen.dart'),
    Path('lib/screens/app_settings_screen.dart'),
    Path('lib/screens/api_settings_screen.dart'),
    Path('lib/screens/memory_screen.dart'),
    Path('lib/screens/style_preferences_screen.dart'),
    Path('lib/screens/character_screen.dart'),
]


def ensure_textfields_manual_focus(path: Path) -> None:
    lines = path.read_text().splitlines(keepends=True)
    out = []
    i = 0
    while i < len(lines):
        line = lines[i]
        out.append(line)
        if 'TextField(' in line:
            j = i + 1
            while j < len(lines) and j <= i + 16:
                out.append(lines[j])
                if 'controller:' in lines[j]:
                    lookahead = ''.join(lines[j + 1 : min(len(lines), j + 14)])
                    indent = re.match(r'(\s*)', lines[j]).group(1)
                    if 'autofocus:' not in lookahead:
                        out.append(f'{indent}autofocus: false,\n')
                    if 'onTapOutside:' not in lookahead:
                        out.append(
                            f'{indent}onTapOutside: (_) => FocusScope.of(context).unfocus(),\n'
                        )
                    i = j
                    break
                j += 1
            else:
                raise SystemExit(f'{path}: TextField without controller near line {i + 1}')
        i += 1
    path.write_text(''.join(out))


main_path = Path('lib/main.dart')
main = main_path.read_text()
observer = '''\nclass _KeyboardDismissNavigatorObserver extends NavigatorObserver {\n  void _clearFocus() {\n    final focus = FocusManager.instance.primaryFocus;\n    if (focus != null && focus.hasFocus) focus.unfocus();\n  }\n\n  @override\n  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {\n    _clearFocus();\n    super.didPush(route, previousRoute);\n  }\n\n  @override\n  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {\n    _clearFocus();\n    super.didPop(route, previousRoute);\n  }\n\n  @override\n  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {\n    _clearFocus();\n    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);\n  }\n\n  @override\n  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {\n    _clearFocus();\n    super.didRemove(route, previousRoute);\n  }\n}\n'''
if 'class _KeyboardDismissNavigatorObserver' not in main:
    marker = 'class CharacterChatApp extends StatelessWidget {'
    if marker not in main:
        raise SystemExit('main.dart: app class marker not found')
    main = main.replace(marker, observer + '\n' + marker, 1)
if 'navigatorObservers:' not in main:
    marker = '    return MaterialApp(\n'
    if marker not in main:
        raise SystemExit('main.dart: MaterialApp marker not found')
    main = main.replace(
        marker,
        marker + '      navigatorObservers: [_KeyboardDismissNavigatorObserver()],\n',
        1,
    )
main_path.write_text(main)

for path in FILES:
    ensure_textfields_manual_focus(path)

chat_path = Path('lib/screens/chat_screen.dart')
chat = chat_path.read_text()
retry_old = '''  Future<void> _retryReply(int replyIndex, RetryModelOption option) async {\n    if (_isBusy) return;\n'''
retry_new = '''  Future<void> _retryReply(int replyIndex, RetryModelOption option) async {\n    if (_isBusy) return;\n    FocusManager.instance.primaryFocus?.unfocus();\n'''
if retry_new not in chat:
    if retry_old not in chat:
        raise SystemExit('chat_screen.dart: retry function marker not found')
    chat = chat.replace(retry_old, retry_new, 1)
chat_path.write_text(chat)

pubspec = Path('pubspec.yaml')
text = pubspec.read_text()
text, count = re.subn(
    r'^version:\s*.*$',
    'version: 0.9.17+27',
    text,
    count=1,
    flags=re.M,
)
if count != 1:
    raise SystemExit('pubspec.yaml: version line not found')
pubspec.write_text(text)

for path in Path('lib/screens').glob('*.dart'):
    text = path.read_text()
    if 'autofocus: true' in text or 'requestFocus(' in text:
        raise SystemExit(f'{path}: automatic focus call remains')
    starts = [m.start() for m in re.finditer(r'TextField\(', text)]
    for start in starts:
        snippet = text[start : start + 1000]
        if 'autofocus: false' not in snippet:
            raise SystemExit(f'{path}: TextField lacks explicit autofocus false')

print('keyboard focus guard applied and audited')
