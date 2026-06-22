---
name: web-proxy-and-active-scanning
description: "Proxy-driven testing and active scanning workflows for CTF web targets using Burp Suite, OWASP ZAP, and mitmproxy. Use to capture, modify, replay, and automate HTTP attack surface exploration before manual exploit chaining."
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
- Burp se usa solo en modo headless (sin GUI), apoyado en `burp-headless`.

## Modo de ejecucion eficiente

1. Triage rapido: define scope y rutas objetivo.
2. Captura baseline: autenticacion, flujo normal y APIs.
3. Escaneo liviano: checks pasivos y activos de bajo riesgo.
4. Repeticion dirigida: Burp headless + Fuzzer CLI en parametros de alto valor.
5. Evidencia: exporta requests reproducibles para chain manual.

## Contenido base

# CTF Web - Proxy and Active Scanning

## Herramientas

- Burp Suite Professional headless (obligatorio, sin GUI)
- OWASP ZAP (spider + active scan controlado)
- mitmproxy (scripting de mutaciones y replay)

## Workflow recomendado

1. Captura todas las rutas de login, reset, upload, admin y API.
2. Ejecuta Burp en modo headless para baseline y deteccion reproducible.
3. Agrupa endpoints por funcion y nivel de privilegio.
4. Lanza escaneo activo solo en endpoints con estado reproducible.
5. Promueve findings con PoC minimo a skills de explotacion especificos.

## Quick commands

```bash
# Burp headless (obligatorio, sin GUI)
java -jar burpsuite_pro.jar \
  --headless \
  --project-file burp-project.burp \
  --config-file burp-config.json

# ZAP baseline (docker)
docker run --rm -t ghcr.io/zaproxy/zaproxy:stable \
  zap-baseline.py -t https://target.tld -m 5 -r zap-report.html

# mitmproxy script mode
mitmproxy -s mutate.py -p 8080

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
- Si Burp no esta en headless, corregir flujo antes de continuar.
