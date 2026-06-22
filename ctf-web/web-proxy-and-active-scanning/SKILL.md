---
name: web-proxy-and-active-scanning
description: "Proxy-driven testing and active scanning workflows for CTF web targets using OWASP ZAP and mitmproxy/mitmdump. Use to capture, modify, replay, and automate HTTP attack surface exploration before manual exploit chaining."
license: MIT
compatibility: Requires filesystem-based agent (Hermes compatible)
allowed-tools: Bash Read Write Edit Glob Grep Task WebFetch WebSearch
metadata:
  user-invocable: "false"
---

<!-- Original file: ctf-web/web-proxy-and-active-scanning/SKILL.md -->

# Procedimiento

Sigue los pasos y referencias del contenido base de esta habilidad.

## Guardrails de seguridad

- Ejecuta comandos de este skill solo en entornos autorizados (CTF/lab/sandbox).
- No ejecutes escaneos agresivos sin limitar scope y tasa.
- Mantiene evidencia limpia: request/response base antes de mutar payloads.
- Usa mitmdump como flujo base para ejecucion CLI reproducible.

## Modo de ejecucion eficiente

1. Triage rapido: define scope y rutas objetivo.
2. Captura baseline: autenticacion, flujo normal y APIs.
3. Escaneo liviano: checks pasivos y activos de bajo riesgo.
4. Repeticion dirigida: mitmdump + Fuzzer CLI en parametros de alto valor.
5. Evidencia: exporta requests reproducibles para chain manual.

## Contenido base

# CTF Web - Proxy and Active Scanning

## Herramientas

- OWASP ZAP (spider + active scan controlado)
- mitmdump (captura/replay headless)
- mitmproxy (scripting de mutaciones y replay)

## Workflow recomendado

1. Captura todas las rutas de login, reset, upload, admin y API.
2. Ejecuta mitmdump para baseline y deteccion reproducible por CLI.
3. Agrupa endpoints por funcion y nivel de privilegio.
4. Lanza escaneo activo solo en endpoints con estado reproducible.
5. Promueve findings con PoC minimo a skills de explotacion especificos.

## Quick commands

```bash
# ZAP baseline (docker)
docker run --rm -t ghcr.io/zaproxy/zaproxy:stable \
  zap-baseline.py -t https://target.tld -m 5 -r zap-report.html

# mitmdump script mode
mitmdump -s mutate.py -p 8080

# mitmdump headless para guardar trafico
mitmdump -w traffic.mitm -p 8080
```

## Plantilla minima de mutate.py

```python
from mitmproxy import http

PAYLOADS = ["'", '"', "{{7*7}}", "<svg/onload=alert(1)>"]

def request(flow: http.HTTPFlow) -> None:
    if "application/json" in flow.request.headers.get("content-type", ""):
        for p in PAYLOADS:
            if p not in flow.request.text:
                flow.request.text = flow.request.text.replace("test", p, 1)
                break
```

## Cuando pivotar

- Findings de SQLi -> `sql-injection`.
- Findings de SSTI/SSRF/RCE -> `server-side` o `server-side-exec`.
- Findings de XSS/DOM/CSP -> `client-side` o `client-side-advanced`.
- Si no hay trazas reproducibles en mitmdump, corrige flujo antes de continuar.
