---
name: playwright-and-xsstrike-validation
description: "Provides browser-backed XSS validation workflows with XSStrike and Playwright/Chromium, including payload verification, context checks, and reproducible evidence capture."
license: MIT
compatibility: Requires filesystem-based agent (Hermes compatible)
allowed-tools: Bash Read Write Edit Glob Grep Task WebFetch WebSearch
metadata:
  user-invocable: "false"
---

# Procedimiento

Usa este skill cuando necesites confirmar ejecucion real de payloads en navegador, no solo reflejo en respuesta HTTP.

## Guardrails de seguridad

- Ejecuta payloads solo en objetivos autorizados de CTF/lab.
- Empieza con payloads de verificacion no destructivos (`alert`, `console.log`).
- No uses callbacks externos reales sin necesidad del reto.

## Modo de ejecucion eficiente

1. Detecta parametros candidatos con XSStrike.
2. Selecciona 1-2 payloads por contexto (HTML, attr, JS string).
3. Valida ejecucion en Chromium headless con Playwright.
4. Guarda evidencia minima reproducible y pivota.

## Contenido base

# XSStrike + Playwright Validation

## XSStrike rapido

```bash
python3 /opt/XSStrike/xsstrike.py -u "https://target/search?q=test"
```

## Playwright smoke check

```bash
/opt/ctf-tools/venv/bin/python -m playwright --help
/opt/ctf-tools/venv/bin/python -m playwright install chromium
```

## Validacion browser-backed (script base)

```python
from playwright.sync_api import sync_playwright

url = "https://target/search?q=%3Csvg/onload=alert(1)%3E"
with sync_playwright() as p:
    browser = p.chromium.launch(headless=True)
    page = browser.new_page()
    dialogs = []
    page.on("dialog", lambda d: (dialogs.append(d.message), d.dismiss()))
    page.goto(url, wait_until="domcontentloaded")
    print({"dialog_count": len(dialogs), "dialogs": dialogs})
    browser.close()
```

## Criterios de confirmacion

- `dialog_count > 0` o side effect observable controlado.
- Payload ejecuta en el contexto esperado (no solo reflected text).
- Reproducible en al menos dos cargas consecutivas.

## Pivot map

- Si requiere sesion privilegiada/admin bot -> client-side-advanced.
- Si hay CSP fuerte -> client-side-advanced (bypass strategies).
- Si impacto permite token/session theft -> auth-and-access.
