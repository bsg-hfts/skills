#!/usr/bin/env python3
"""Hardening pass for Hermes SKILL.md files.

Actions:
1) Fix internal markdown links (*.md) after migration to folder-based SKILL.md layout.
2) Insert a safety guardrails section if missing.
"""

from __future__ import annotations

from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
SKILLS = sorted(
    p for p in ROOT.glob("**/SKILL.md") if ".venv" not in p.parts and ".git" not in p.parts
)

ORIGINAL_RE = re.compile(r"<!--\s*Original file:\s*([^>]+?)\s*-->")
LINK_RE = re.compile(r"\[([^\]]+)\]\(([^)]+)\)")

GUARDRAILS_BLOCK = """
## Guardrails de seguridad

- Ejecuta comandos de este skill solo en entornos autorizados (CTF/lab/sandbox).
- No reutilices payloads ni comandos contra infraestructura real sin permiso explícito.
- Revisa y adapta rutas, hosts y credenciales placeholders antes de ejecutar.
- Prioriza pruebas no destructivas y confirma cambios de estado antes de acciones invasivas.
""".strip("\n")


def normalize_posix(path_str: str) -> Path:
    return Path(path_str.replace("\\", "/"))


def map_old_target_to_new(old_target: Path) -> Path:
    # Old world: category/file.md or category/SKILL.md
    # New world: category/file/SKILL.md OR category/SKILL.md
    if old_target.name.lower() == "skill.md":
        return old_target
    return old_target.parent / old_target.stem / "SKILL.md"


def fix_links(text: str, current_skill: Path) -> tuple[str, int]:
    m = ORIGINAL_RE.search(text)
    if not m:
        return text, 0

    original_file = normalize_posix(m.group(1).strip())
    old_base = original_file.parent
    cur_dir = current_skill.parent

    updates = 0

    def repl(match: re.Match[str]) -> str:
        nonlocal updates
        label = match.group(1)
        target = match.group(2).strip()

        if target.startswith("http://") or target.startswith("https://") or target.startswith("#"):
            return match.group(0)

        # Keep optional title and anchor intact if present
        target_main = target.split()[0]
        suffix = target[len(target_main):]

        anchor = ""
        if "#" in target_main:
            target_main, anchor = target_main.split("#", 1)
            anchor = "#" + anchor

        if not target_main.lower().endswith(".md"):
            return match.group(0)

        old_target = (old_base / target_main).resolve()
        try:
            old_target_rel = old_target.relative_to(ROOT)
        except ValueError:
            return match.group(0)

        new_target_rel = map_old_target_to_new(old_target_rel)
        new_target_abs = ROOT / new_target_rel
        if not new_target_abs.exists():
            return match.group(0)

        # compute relative path from current skill directory
        import os

        rel_str = os.path.relpath(str(new_target_abs), start=str(cur_dir)).replace("\\", "/")
        rewritten = f"[{label}]({rel_str}{anchor}{suffix})"
        if rewritten != match.group(0):
            updates += 1
        return rewritten

    updated_text = LINK_RE.sub(repl, text)
    return updated_text, updates


def ensure_guardrails(text: str) -> tuple[str, bool]:
    if "## Guardrails de seguridad" in text:
        return text, False

    marker = "## Contenido base"
    idx = text.find(marker)
    if idx == -1:
        # Append near top if structure differs
        return text + "\n\n" + GUARDRAILS_BLOCK + "\n", True

    new_text = text[:idx].rstrip() + "\n\n" + GUARDRAILS_BLOCK + "\n\n" + text[idx:]
    return new_text, True


def main() -> None:
    changed = 0
    total_link_updates = 0
    guardrails_added = 0

    for skill in SKILLS:
        txt = skill.read_text(encoding="utf-8", errors="ignore")

        txt2, n_updates = fix_links(txt, skill)
        txt3, added = ensure_guardrails(txt2)

        if txt3 != txt:
            skill.write_text(txt3, encoding="utf-8")
            changed += 1
        total_link_updates += n_updates
        if added:
            guardrails_added += 1

    print(f"skills_total={len(SKILLS)}")
    print(f"files_changed={changed}")
    print(f"link_updates={total_link_updates}")
    print(f"guardrails_added={guardrails_added}")


if __name__ == "__main__":
    main()
