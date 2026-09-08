from pathlib import Path
import re

changed = []
for path in Path('lib').rglob('*.dart'):
    text = path.read_text()
    original = text
    text = re.sub(r'autofocus:\s*true', 'autofocus: false', text)
    if text != original:
        path.write_text(text)
        changed.append(str(path))

pubspec = Path('pubspec.yaml')
text = pubspec.read_text()
text = re.sub(r'^version:\s*.*$', 'version: 0.9.14+24', text, count=1, flags=re.M)
pubspec.write_text(text)

print('Changed autofocus in:', ', '.join(changed) if changed else 'none')
