---
name: web-recon-cli-stack
description: "Provides operational guidance for WhatWeb, WAFW00F, Nikto, Gobuster, and FFUF to map web attack surface with low noise and clear pivot criteria."
license: MIT
compatibility: Requires filesystem-based agent (Hermes compatible)
allowed-tools: Bash Read Write Edit Glob Grep Task WebFetch WebSearch
metadata:
  user-invocable: "false"
---

# Procedimiento

Sigue los pasos de este skill para ejecutar recon web con baja friccion y decisiones de pivot claras.

## Guardrails de seguridad

- Ejecuta comandos solo en entornos autorizados (CTF/lab/sandbox).
- Comienza con probes pasivos y aumenta intensidad de forma gradual.
- Evita escaneos recursivos largos sin hipotesis concreta.

## Modo de ejecucion eficiente

1. Fingerprint primero: tecnologia, WAF/CDN, y headers.
2. Discovery corto: wordlist pequena para detectar rutas de alto valor.
3. Ajuste de filtros: reduce falsos positivos por status/size.
4. Pivot temprano: pasa a skill de exploit cuando haya una primitiva clara.

## Contenido base

# Web Recon CLI Stack

## Cuando usar cada herramienta

- `whatweb`: detectar stack, framework, y componentes visibles.
- `wafw00f`: confirmar presencia y tipo de WAF.
- `nikto`: baseline de misconfig y exposicion comun.
- `gobuster`: enumeracion de rutas y archivos con wordlist controlada.
- `ffuf`: fuzzing rapido de rutas, parametros y vhosts.

## Secuencia recomendada

```bash
TARGET="https://target"

# 1) fingerprint
whatweb -a 3 "$TARGET"
wafw00f "$TARGET"

# 2) baseline config
nikto -h "$TARGET"

# 3) discovery rutas
ffuf -u "$TARGET/FUZZ" -w wordlist.txt -mc 200,301,302,401,403 -fc 404

# 4) discovery alternativo
gobuster dir -u "$TARGET" -w wordlist.txt -x php,txt,bak -s 200,204,301,302,307,401,403
```

## Heuristicas de decision

- Si detectas WAF estricto, reduce concurrencia y prueba normalizacion de payloads.
- Si aparece `/admin`, `/api`, `/debug`, pivota a auth/server-side.
- Si hay parametros reflejados, pivota a xss-automation o client-side.
- Si hay endpoints con SQL-like errors, pivota a sql-injection.

## Evidencia minima a guardar

- Comando exacto ejecutado.
- Endpoint/parametro hallado.
- Status code y diferencia de body relevante.
- Siguiente hipotesis y skill destino.
