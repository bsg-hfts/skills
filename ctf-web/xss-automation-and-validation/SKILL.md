---
name: xss-automation-and-validation
description: "XSS discovery and validation workflow for CTF web apps using XSStrike/XSser-style automation patterns, reflected/stored/DOM triage, and payload minimization for admin-bot and CSP-constrained targets. Use when multiple reflection points require fast sink confirmation."
license: MIT
compatibility: Requires filesystem-based agent (Hermes compatible)
allowed-tools: Bash Read Write Edit Glob Grep Task WebFetch WebSearch
metadata:
  user-invocable: "false"
---

<!-- Original file: ctf-web/xss-automation-and-validation/SKILL.md -->

# Procedimiento

Sigue los pasos y referencias del contenido base de esta habilidad.

## Guardrails de seguridad

- Ejecuta comandos de este skill solo en entornos autorizados (CTF/lab/sandbox).
- Prioriza payloads de prueba inocuos (`alert`/marker) antes de exfiltracion.
- Registra contexto exacto (HTML attr, JS string, URL, script block) para evitar falsos positivos.

## Contenido base

# CTF Web - XSS Automation and Validation

## Prerequisites

```bash
pip install xsser xsstrike
```

## Workflow

1. Localiza reflexiones y clasificalas por contexto.
2. Ejecuta deteccion automatica para priorizar sinks reales.
3. Confirma manualmente con payload minimo por contexto.
4. Adapta a bot/CSP/encoding constraints.
5. Escala a accion objetivo (cookie no HttpOnly, CSRF action, flag leak).

## Quick commands

```bash
# XSSer baseline
xsser -u 'https://target.tld/search?q=test'

# XSSer con crawling ligero
xsser -u 'https://target.tld/' --Cw 2

# XSStrike param test
python -m xsstrike -u 'https://target.tld/search?q=test'

# Reflected probe reproducible
curl 'https://target.tld/search?q=%3Csvg%2Fonload%3Dalert(1)%3E'
```

## Checklist de validacion

- Se ejecuta JavaScript o solo se refleja texto.
- El sink depende de evento usuario o auto-ejecuta.
- La ejecucion ocurre en usuario privilegiado (admin bot) o anonimo.
- Hay CSP, sandbox o restricciones de salida de red.

## Cuando pivotar

- Si el bloqueo es CSP/DOM complejo -> `client-side-advanced`.
- Si el objetivo requiere robo de sesion/auth -> `auth-and-access`.
- Si la XSS solo habilita SSRF/backend action -> `server-side`.
