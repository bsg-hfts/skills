---
name: nuclei-targeted-workflows
description: "Provides targeted Nuclei workflows for CTF web challenges, including template strategy, severity/tag filtering, and output triage to reduce false positives."
license: MIT
compatibility: Requires filesystem-based agent (Hermes compatible)
allowed-tools: Bash Read Write Edit Glob Grep Task WebFetch WebSearch
metadata:
  user-invocable: "false"
---

# Procedimiento

Usa este skill para operar Nuclei de forma dirigida, evitando ruido y priorizando hallazgos explotables.

## Guardrails de seguridad

- Ejecuta Nuclei solo contra objetivos autorizados.
- Evita scans masivos sin alcance definido.
- Valida manualmente todo finding antes de asumir impacto.

## Modo de ejecucion eficiente

1. Actualiza templates una vez por sesion.
2. Arranca con tags/severity acotados.
3. Filtra y deduplica findings antes de pivotar.
4. Reproduce el finding con request manual.

## Contenido base

# Nuclei Targeted Workflows

## Setup minimo

```bash
nuclei -update-templates
```

## Scans recomendados

```bash
TARGET="https://target"

# Sweep inicial enfocado
nuclei -u "$TARGET" -tags web,misconfig,cve -severity medium,high,critical

# Validacion de tecnologias especificas (ejemplo)
nuclei -u "$TARGET" -tags nginx,apache,php,node

# JSON output para triage
nuclei -u "$TARGET" -tags web,cve -severity high,critical -jsonl -o nuclei-findings.jsonl
```

## Triage practico

- Elimina duplicados por endpoint+template-id.
- Prioriza findings con evidencia directa de lectura/escritura/exec.
- Descarta findings informativos sin primitiva explotable en el reto.

## Pivot map

- `exposed-panel`, `default-login` -> auth-and-access.
- `lfi`, `rfi`, `ssti`, `ssrf` -> server-side.
- `xss` -> xss-automation o client-side.
- `sql` -> sql-injection.

## Plantilla de reporte minimo

- target
- template-id
- request reproducible
- respuesta observada
- impacto CTF esperado (flag path/bypass/read/exec)
