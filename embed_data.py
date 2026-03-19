"""Embed current actions.json into index.html as fallback data."""
import json, re, sys

data_path = sys.argv[1] if len(sys.argv) > 1 else 'data/actions.json'
html_path = sys.argv[2] if len(sys.argv) > 2 else 'index.html'

with open(data_path, 'r', encoding='utf-8-sig') as f:
    data = json.load(f)

# Compact JSON (no indentation) to keep HTML small
compact = json.dumps(data, ensure_ascii=False, separators=(',', ':'))

with open(html_path, 'r', encoding='utf-8') as f:
    html = f.read()

# Replace between markers
pattern = r'/\*EMBEDDED_DATA_START\*/.*?/\*EMBEDDED_DATA_END\*/'
replacement = f'/*EMBEDDED_DATA_START*/{compact}/*EMBEDDED_DATA_END*/'

new_html, count = re.subn(pattern, replacement, html, count=1, flags=re.DOTALL)

if count == 0:
    print('embed_data: ERROR - markers not found in index.html')
    sys.exit(1)

with open(html_path, 'w', encoding='utf-8') as f:
    f.write(new_html)

print(f'embed_data: embedded {len(data["actions"])} entries ({len(compact)//1024}KB compact)')
