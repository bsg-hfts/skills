#!/usr/bin/env python3
from pathlib import Path
import shutil
import re

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'output'
IGNORED_DIRS = {
    'output',
    '.git',
    '__pycache__',
    'node_modules',
    '.venv',
    'venv',
    '.pytest_cache',
    '.mypy_cache',
}


def extract_frontmatter_and_body(text):
    lines = text.splitlines()
    if not lines or lines[0].strip() != '---':
        return {}, text

    fm = {}
    i = 1
    while i < len(lines):
        line = lines[i]
        if line.strip() == '---':
            break
        m = re.match(r'^([A-Za-z0-9_-]+):\s*(.*)$', line)
        if m:
            key = m.group(1).strip()
            value = m.group(2).strip().strip('"').strip("'")
            fm[key] = value
        i += 1

    if i >= len(lines):
        return {}, text

    body = '\n'.join(lines[i + 1 :]).lstrip('\n')
    return fm, body

def first_description(text):
    # find first non-empty paragraph that's not a heading
    for line in text.splitlines():
        s = line.strip()
        if not s:
            continue
        if s == '---':
            continue
        if s.startswith('#'):
            continue
        return s[:200]
    return ''


def sanitize_name(name):
    cleaned = re.sub(r'[^a-zA-Z0-9._-]+', '-', name).strip('-').lower()
    return cleaned or 'skill'


def to_bool_string(value, default='false'):
    if value is None:
        return default
    v = str(value).strip().lower()
    if v in {'true', 'yes', '1'}:
        return 'true'
    if v in {'false', 'no', '0'}:
        return 'false'
    return default


if OUT.exists():
    shutil.rmtree(OUT)
OUT.mkdir(parents=True, exist_ok=True)

count = 0
created = []
for path in ROOT.rglob('*.md'):
    if any(part in IGNORED_DIRS for part in path.parts):
        continue

    rel = path.relative_to(ROOT)
    if rel.as_posix() == 'METHODOLOGY.md':
        continue

    parent = rel.parent
    name = sanitize_name(path.stem)
    text = path.read_text(encoding='utf-8')
    src_fm, src_body = extract_frontmatter_and_body(text)

    desc = src_fm.get('description') or first_description(src_body or text)
    desc = (desc or 'Runbook para esta habilidad.').strip()

    # Determine skill folder and skill name
    if path.name.lower() == 'skill.md':
        skill_folder = OUT / parent
        skill_name = sanitize_name(parent.name)
    else:
        skill_folder = OUT / parent / name
        skill_name = name

    skill_folder.mkdir(parents=True, exist_ok=True)
    out_file = skill_folder / 'SKILL.md'

    # choose user-invocable heuristics
    user_invocable = to_bool_string(None, 'false')
    lc = str(rel).lower()
    if 'writeup' in lc or 'solve-challenge' in lc or 'ctf-writeup' in lc:
        user_invocable = 'true'
    if 'metadata' in src_fm:
        pass
    # Preserve user-invocable if explicitly defined in source frontmatter
    if 'user-invocable' in src_fm:
        user_invocable = to_bool_string(src_fm.get('user-invocable'), user_invocable)

    safe_desc = desc.replace('"', '\\"')

    front = [
        '---',
        f'name: {skill_name}',
        f'description: "{safe_desc}"',
        'license: MIT',
        'compatibility: Requires filesystem-based agent (Hermes compatible)',
        'allowed-tools: Bash Read Write Edit Glob Grep Task WebFetch WebSearch',
        'metadata:',
        f'  user-invocable: "{user_invocable}"',
        '---',
        '\n'
    ]

    body = []
    body.append(f'<!-- Original file: {rel.as_posix()} -->\n')
    body.append('# Procedimiento\n')
    body.append('Sigue los pasos y referencias del contenido base de esta habilidad.\n')
    body.append('## Contenido base\n')
    body.append(src_body or text)

    content = '\n'.join(front) + '\n'.join(body)
    out_file.write_text(content, encoding='utf-8')
    created.append(out_file)
    count += 1

print(f'Converted {count} markdown files into Hermes SKILLs under output/ (generated {len(created)} files).')
