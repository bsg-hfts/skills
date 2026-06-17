#!/usr/bin/env python3
"""Audit Hermes-style SKILL.md files for safety and quality signals.

Outputs:
- security/skills-audit-detailed.json
- security/skills-audit-summary.md
"""

from __future__ import annotations

from dataclasses import dataclass, asdict
from pathlib import Path
import json
import re

ROOT = Path(__file__).resolve().parents[1]
OUT_JSON = ROOT / "security" / "skills-audit-detailed.json"
OUT_MD = ROOT / "security" / "skills-audit-summary.md"

SKILLS = sorted(
    p for p in ROOT.glob("**/SKILL.md") if ".venv" not in p.parts and ".git" not in p.parts
)

RISK_PATTERNS = {
    "remote_exec_pipe": re.compile(r"(curl|wget)\s+[^\n|]+\|\s*(sh|bash|python|perl)", re.I),
    "powershell_iex": re.compile(r"(IEX\s*\(|Invoke-Expression|powershell\s+-e)", re.I),
    "destructive_cmd": re.compile(r"\brm\s+-rf\s+/|\bmkfs\b|\bdd\s+if=.*\bof=/dev/", re.I),
    "reverse_shell": re.compile(r"\b(bash\s+-i|/dev/tcp/|nc\s+-e|python\s+-c\s+[\"']import\s+socket)", re.I),
    "inline_eval_exec": re.compile(r"\beval\s*\(|\bexec\s*\(|marshal\.loads", re.I),
}

SECRET_PATTERNS = {
    "github_token": re.compile(r"ghp_[A-Za-z0-9]{20,}"),
    "aws_access_key": re.compile(r"AKIA[0-9A-Z]{16}"),
    "google_api_key": re.compile(r"AIza[0-9A-Za-z-_]{20,}"),
    "slack_token": re.compile(r"xox[baprs]-[A-Za-z0-9-]{10,}"),
    "private_key_block": re.compile(r"-----BEGIN (RSA|OPENSSH|EC|DSA) PRIVATE KEY-----"),
}

URL_RE = re.compile(r"https?://[^\s)\]>\"']+", re.I)
FM_KEY_RE = re.compile(r"^([A-Za-z0-9_-]+):\s*(.*)$")


@dataclass
class SkillAudit:
    file: str
    has_frontmatter: bool
    has_name: bool
    has_description: bool
    has_procedimiento: bool
    has_contenido_base: bool
    relative_links_checked: int
    broken_relative_links: list[str]
    risk_hits: dict[str, int]
    secret_hits: dict[str, int]
    external_hosts: list[str]
    notes: list[str]


def parse_frontmatter(text: str) -> dict[str, str]:
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return {}

    result: dict[str, str] = {}
    i = 1
    while i < len(lines):
        if lines[i].strip() == "---":
            break
        m = FM_KEY_RE.match(lines[i].strip())
        if m:
            result[m.group(1)] = m.group(2).strip().strip('"').strip("'")
        i += 1
    return result


def relative_link_targets(text: str) -> list[str]:
    # markdown links [text](target)
    links = re.findall(r"\[[^\]]+\]\(([^)]+)\)", text)
    out: list[str] = []
    for link in links:
        l = link.strip()
        if l.startswith("http://") or l.startswith("https://") or l.startswith("#"):
            continue
        # strip optional title and anchors
        l = l.split()[0]
        l = l.split("#")[0]
        if l:
            out.append(l)
    return out


def audit_file(path: Path) -> SkillAudit:
    text = path.read_text(encoding="utf-8", errors="ignore")
    fm = parse_frontmatter(text)

    risk_hits = {k: len(v.findall(text)) for k, v in RISK_PATTERNS.items()}
    secret_hits = {k: len(v.findall(text)) for k, v in SECRET_PATTERNS.items()}

    # Link check
    rel_links = relative_link_targets(text)
    broken: list[str] = []
    for target in rel_links:
        t = (path.parent / target).resolve()
        if not t.exists():
            broken.append(target)

    # External host inventory
    hosts = sorted({u.split("//", 1)[1].split("/", 1)[0].lower() for u in URL_RE.findall(text)})

    notes: list[str] = []
    if any(secret_hits.values()):
        notes.append("Potential embedded secret material detected.")
    if risk_hits["remote_exec_pipe"] > 0 or risk_hits["destructive_cmd"] > 0:
        notes.append("Contains potentially dangerous direct-exec/destructive commands.")
    if broken:
        notes.append("Contains broken relative links.")

    return SkillAudit(
        file=str(path.relative_to(ROOT)).replace("\\", "/"),
        has_frontmatter=text.startswith("---\n") or text.startswith("---\r\n"),
        has_name="name" in fm,
        has_description="description" in fm,
        has_procedimiento=("# Procedimiento" in text),
        has_contenido_base=("## Contenido base" in text),
        relative_links_checked=len(rel_links),
        broken_relative_links=broken,
        risk_hits=risk_hits,
        secret_hits=secret_hits,
        external_hosts=hosts,
        notes=notes,
    )


def main() -> None:
    audits = [audit_file(p) for p in SKILLS]

    totals = {
        "skills_total": len(audits),
        "with_frontmatter": sum(1 for a in audits if a.has_frontmatter),
        "with_name": sum(1 for a in audits if a.has_name),
        "with_description": sum(1 for a in audits if a.has_description),
        "with_procedimiento": sum(1 for a in audits if a.has_procedimiento),
        "with_contenido_base": sum(1 for a in audits if a.has_contenido_base),
        "broken_link_files": sum(1 for a in audits if a.broken_relative_links),
        "risk_totals": {
            k: sum(a.risk_hits.get(k, 0) for a in audits) for k in RISK_PATTERNS
        },
        "secret_totals": {
            k: sum(a.secret_hits.get(k, 0) for a in audits) for k in SECRET_PATTERNS
        },
    }

    payload = {
        "totals": totals,
        "files": [asdict(a) for a in audits],
    }
    OUT_JSON.write_text(json.dumps(payload, indent=2, ensure_ascii=False), encoding="utf-8")

    # Markdown summary
    high_risk = [
        a for a in audits if a.risk_hits["remote_exec_pipe"] or a.risk_hits["destructive_cmd"]
    ]
    potential_secrets = [a for a in audits if any(a.secret_hits.values())]
    broken_link_files = [a for a in audits if a.broken_relative_links]

    lines: list[str] = []
    lines.append("# Skills Audit Summary")
    lines.append("")
    lines.append(f"- Skills analizados: **{totals['skills_total']}**")
    lines.append(f"- Frontmatter válido: **{totals['with_frontmatter']}**")
    lines.append(f"- Con `# Procedimiento`: **{totals['with_procedimiento']}**")
    lines.append(f"- Con `## Contenido base`: **{totals['with_contenido_base']}**")
    lines.append(f"- Archivos con enlaces relativos rotos: **{totals['broken_link_files']}**")
    lines.append("")
    lines.append("## Riesgo (conteo bruto de patrones)")
    for k, v in totals["risk_totals"].items():
        lines.append(f"- {k}: {v}")
    lines.append("")
    lines.append("## Secretos (conteo bruto de patrones)")
    for k, v in totals["secret_totals"].items():
        lines.append(f"- {k}: {v}")
    lines.append("")
    lines.append("## Archivos de alta prioridad para revisión manual")
    if not (high_risk or potential_secrets or broken_link_files):
        lines.append("- Ninguno")
    else:
        for a in sorted({x.file: x for x in (high_risk + potential_secrets + broken_link_files)}.values(), key=lambda x: x.file):
            reasons = []
            if a.risk_hits["remote_exec_pipe"] or a.risk_hits["destructive_cmd"]:
                reasons.append("dangerous command pattern")
            if any(a.secret_hits.values()):
                reasons.append("possible secret")
            if a.broken_relative_links:
                reasons.append("broken links")
            lines.append(f"- `{a.file}`: {', '.join(reasons)}")

    OUT_MD.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Wrote: {OUT_JSON}")
    print(f"Wrote: {OUT_MD}")


if __name__ == "__main__":
    main()
