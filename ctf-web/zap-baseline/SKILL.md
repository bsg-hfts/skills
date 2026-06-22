---
name: zap-baseline
description: "- [OWASP ZAP Baseline and API Scan](#owasp-zap-baseline-and-api-scan)"
license: MIT
compatibility: Requires filesystem-based agent (Hermes compatible)
allowed-tools: Bash Read Write Edit Glob Grep Task WebFetch WebSearch
metadata:
  user-invocable: "false"
---

<!-- Original file: ctf-web/zap-baseline/SKILL.md -->

# Procedimiento

Sigue los pasos y referencias del contenido base de esta habilidad.

## Guardrails de seguridad

- Ejecuta comandos de este skill solo en entornos autorizados (CTF/lab/sandbox).
- No reutilices escaneos activos contra infraestructura real sin permiso explicito.
- Inicia en baseline/pasivo para evitar efectos no deseados.

## Contenido base

# CTF Web - OWASP ZAP Tooling

## OWASP ZAP Baseline and API Scan

### Prerequisites

**Linux (apt):**
```bash
apt install zaproxy
```

### Quick Commands

```bash
# baseline scan (pasivo)
zap-baseline.py -t https://target -r zap-report.html

# API scan (OpenAPI)
zap-api-scan.py -t openapi.yaml -f openapi -r zap-api-report.html

# daemon mode para integracion con scripts
zaproxy -daemon -host 127.0.0.1 -port 8090 -config api.disablekey=true
```

### Usage Strategy

- Usa ZAP para coverage inicial y deteccion de misconfig basica.
- Confirma hallazgos manualmente en Burp headless/curl antes de invertir tiempo.
- Para retos CTF de logica compleja, no dependas solo de scanner automatico.
