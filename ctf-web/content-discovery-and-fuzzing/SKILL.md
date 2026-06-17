---
name: content-discovery-and-fuzzing
description: "Directory, file, parameter, and virtual host discovery for web CTF targets using FFUF, Feroxbuster, Gobuster, Dirsearch, and Wfuzz. Use when the visible application surface is limited and hidden routes or parameters are likely required to reach the exploit path."
license: MIT
compatibility: Requires filesystem-based agent (Hermes compatible)
allowed-tools: Bash Read Write Edit Glob Grep Task WebFetch WebSearch
metadata:
  user-invocable: "false"
---

<!-- Original file: ctf-web/content-discovery-and-fuzzing/SKILL.md -->

# Procedimiento

Sigue los pasos y referencias del contenido base de esta habilidad.

## Guardrails de seguridad

- Ejecuta comandos de este skill solo en entornos autorizados (CTF/lab/sandbox).
- Comienza con baja concurrencia y aumenta solo si el servidor tolera carga.
- Evita wordlists gigantes sin criterio; prioriza listas contextuales.

## Modo de ejecucion eficiente

1. Triage rapido: define host, extensiones, codigos validos y baseline 404.
2. Primitiva minima: un escaneo corto con top 2000 paths.
3. Bucle corto: ajustar filtros por tamano/status para reducir falsos positivos.
4. Pivot temprano: si no aparecen rutas nuevas, fuzz de parametros o vhosts.
5. Evidencia: reporte de rutas y parametros nuevos con request reproducible.

## Contenido base

# CTF Web - Content Discovery and Fuzzing

## Prerequisites

**Go tools:**
```bash
go install github.com/ffuf/ffuf/v2@latest
go install github.com/OJ/gobuster/v3@latest
go install github.com/epi052/feroxbuster@latest
```

**Python packages:**
```bash
pip install dirsearch wfuzz
```

## Baseline recomendado

- Verifica respuesta 404 normal (status, body length, title).
- Usa filtros de longitud para eliminar respuestas comodin.
- Añade extensiones comunes: php, asp, aspx, js, json, txt, bak.

## Quick commands

```bash
# FFUF directorios
ffuf -u https://target.tld/FUZZ -w wordlist.txt -mc 200,204,301,302,307,401,403 -fs 0

# FFUF parametros GET
ffuf -u 'https://target.tld/search?FUZZ=test' -w params.txt -mc all -fs 0

# FFUF vhosts
ffuf -u https://target.tld -H 'Host: FUZZ.target.tld' -w subdomains.txt -fc 400

# Feroxbuster recursivo
feroxbuster -u https://target.tld -w wordlist.txt -x php,js,txt,json -C 404

# Gobuster directories
gobuster dir -u https://target.tld -w wordlist.txt -x php,txt,html -k

# Dirsearch rapido
python -m dirsearch -u https://target.tld -e php,aspx,jsp,js,txt -t 25

# Wfuzz por parametro
wfuzz -c -z file,params.txt -u 'https://target.tld/page?FUZZ=1' --hc 404
```

## Heuristicas utiles

- Una ruta `403` puede ser mas valiosa que un `200` vacio.
- Diferencias pequenas de longitud o tiempo pueden revelar validaciones.
- Repite sobre subrutas prometedoras (`/api/`, `/admin/`, `/internal/`).

## Cuando pivotar

- Si encuentras endpoints con input reflejado o parser raro, pasa a `client-side` o `server-side`.
- Si descubres login/admin oculto, pasa a `auth-and-access`.
- Si hay API tokens/sesiones, pasa a `auth-jwt` o `auth-infra`.
