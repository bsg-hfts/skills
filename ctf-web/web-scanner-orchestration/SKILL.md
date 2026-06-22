---
name: web-scanner-orchestration
description: "- [Toolchain Orchestration for Web Attacks](#toolchain-orchestration-for-web-attacks)"
license: MIT
compatibility: Requires filesystem-based agent (Hermes compatible)
allowed-tools: Bash Read Write Edit Glob Grep Task WebFetch WebSearch
metadata:
  user-invocable: "false"
---

<!-- Original file: ctf-web/web-scanner-orchestration/SKILL.md -->

# Procedimiento

Sigue los pasos y referencias del contenido base de esta habilidad.

## Guardrails de seguridad

- Ejecuta comandos de este skill solo en entornos autorizados (CTF/lab/sandbox).
- Mantiene bajo control concurrencia, ruido y tiempos para no cegar el analisis.

## Contenido base

# CTF Web - Scanner Orchestration

## Toolchain Orchestration for Web Attacks

Objetivo: coordinar escaneres sin perder trazabilidad ni generar ruido inutil.

### Recommended Sequence

1. Fingerprint: whatweb + wafw00f.
2. Discovery: ffuf/feroxbuster con wordlist corta.
3. Exposure sweep: nuclei targeted templates.
4. Endpoint deepening: sqlmap/commix/jwttool segun hallazgo.
5. Manual validation: mitmdump + curl/HTTPie.

### Minimal Script Pattern

```bash
TARGET="https://target"
whatweb -a 3 "$TARGET"
wafw00f "$TARGET"
ffuf -u "$TARGET/FUZZ" -w wordlist.txt -fc 404 -mc 200,301,302,401,403
nuclei -u "$TARGET" -tags web,cve,misconfig -severity medium,high,critical
```

### Output Hygiene

- Guarda resultados por herramienta en archivos separados.
- Normaliza endpoints unicos antes de siguiente fase.
- Marca hallazgos confirmados vs sospechosos.
- Evita rerun completo si solo cambio un parametro.
