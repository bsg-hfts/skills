---
name: web-recon-and-fingerprinting
description: "Web recon and stack fingerprinting for CTF web targets using WhatWeb, Wappalyzer-like heuristics, WAFW00F, Nikto, Nuclei, Curl, and HTTPie to quickly identify frameworks, misconfigurations, and high-value attack paths. Use this before deep exploitation when technology stack or edge defenses are unclear."
license: MIT
compatibility: Requires filesystem-based agent (Hermes compatible)
allowed-tools: Bash Read Write Edit Glob Grep Task WebFetch WebSearch
metadata:
  user-invocable: "false"
---

<!-- Original file: ctf-web/web-recon-and-fingerprinting/SKILL.md -->

# Procedimiento

Sigue los pasos y referencias del contenido base de esta habilidad.

## Guardrails de seguridad

- Ejecuta comandos de este skill solo en entornos autorizados (CTF/lab/sandbox).
- No reutilices payloads ni comandos contra infraestructura real sin permiso explicito.
- Prioriza tecnicas no destructivas en el primer pase de reconocimiento.

## Modo de ejecucion eficiente

1. Triage rapido (90-180s): define host objetivo, protocolo y superficie inicial.
2. Primitiva minima primero: headers, robots, sitemap, fingerprinting liviano.
3. Bucle corto: comando corto -> evidencia -> ajuste de wordlists/paths.
4. Pivot temprano: si no hay señal, cambia a discovery o a auth/testing.
5. Evidencia: guarda stack detectado, endpoints y findings accionables.

## Contenido base

# CTF Web - Recon and Fingerprinting

## Prerequisites

**Linux (apt):**
```bash
apt install curl nikto whatweb wafw00f
```

**Python packages:**
```bash
pip install httpie nuclei
```

**Go tools:**
```bash
go install github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
```

## Workflow rapido

1. Confirma respuesta base y headers.
2. Extrae tecnologia y framework probables.
3. Identifica WAF/CDN/proxy.
4. Ejecuta escaneo de templates de bajo ruido.
5. Entrega una lista priorizada de rutas/bugs candidatos.

## Quick commands

```bash
# Baseline HTTP profile
curl -sI https://target.tld
curl -sk https://target.tld/robots.txt
curl -sk https://target.tld/sitemap.xml

# Fingerprinting de stack
whatweb -a 3 https://target.tld

# Deteccion de WAF
wafw00f https://target.tld

# Misconfig y checks generales
nikto -h https://target.tld

# Templates de CVE/misconfig de bajo riesgo
nuclei -u https://target.tld -severity low,medium,high -rate-limit 50

# Requests reproducibles con HTTPie
http --print=HhBb GET https://target.tld/api/health
```

## Salida esperada

- Framework/librerias probables y versiones inferidas.
- WAF/CDN detectado y comportamiento basico de bloqueo.
- Endpoints interesantes y rutas administrativas.
- Hallazgos con PoC minimo (request + respuesta clave).

## Cuando pivotar

- Si hay muchas rutas candidatas sin parametro explotable, usa `content-discovery-and-fuzzing`.
- Si detectas auth/session issues, pasa a `auth-and-access` o `auth-jwt`.
- Si hay sinks server-side claros, pasa a `server-side` o `server-side-exec`.
