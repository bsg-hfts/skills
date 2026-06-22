---
name: recon-content-discovery
description: "- [Rapid Surface Enumeration](#rapid-surface-enumeration)"
license: MIT
compatibility: Requires filesystem-based agent (Hermes compatible)
allowed-tools: Bash Read Write Edit Glob Grep Task WebFetch WebSearch
metadata:
  user-invocable: "false"
---

<!-- Original file: ctf-web/recon-content-discovery/SKILL.md -->

# Procedimiento

Sigue los pasos y referencias del contenido base de esta habilidad.

## Guardrails de seguridad

- Ejecuta comandos de este skill solo en entornos autorizados (CTF/lab/sandbox).
- No reutilices payloads ni comandos contra infraestructura real sin permiso explicito.
- Revisa y adapta rutas, hosts y credenciales placeholders antes de ejecutar.
- Prioriza pruebas no destructivas y confirma cambios de estado antes de acciones invasivas.

## Modo de ejecucion eficiente

1. Triage rapido (90-180s): identifica stack y rutas clave antes de lanzar fuzzing pesado.
2. Primitiva minima primero: confirma una ruta valida por metodo antes de escalar wordlists.
3. Bucle corto de iteracion: ejecutar -> medir respuestas utiles -> ajustar filtros y wordlist.
4. Pivot temprano: si la entropia de respuestas es alta, cambia de tecnica (params/vhosts/extensions).
5. Evidencia y salida: guarda endpoints confirmados y codigos de estado repetibles.

## Contenido base

# CTF Web - Content Discovery Tooling

## Rapid Surface Enumeration

Objetivo: descubrir rutas, archivos, parametros y vhosts con minimo ruido y maxima señal.

### Prerequisites

**Linux (apt):**
```bash
apt install feroxbuster gobuster wfuzz dirsearch
```

**Go tools:**
```bash
go install github.com/ffuf/ffuf/v2@latest
```

### Workflow

1. Baseline de respuestas para 200/301/302/401/403/404.
2. Enumeracion de rutas con una wordlist corta.
3. Enumeracion de extensiones relevantes (.php, .jsp, .aspx, .js, .bak, .old).
4. Enumeracion de parametros y vhosts.
5. Verificacion manual en mitmdump/curl de hallazgos criticos.

### Quick Commands

```bash
# ffuf: rutas basicas
ffuf -u https://target/FUZZ -w wordlist.txt -fc 404 -mc 200,301,302,401,403

# ffuf: extensiones
ffuf -u https://target/FUZZ -w wordlist.txt -e .php,.txt,.bak,.old -fc 404

# ffuf: vhost fuzzing
ffuf -u https://target/ -H "Host: FUZZ.target" -w subdomains.txt -fs 0

# feroxbuster: recursion moderada
feroxbuster -u https://target -x php,txt,bak,old -C 404 -t 20 -d 2

# gobuster: directorios
gobuster dir -u https://target -w wordlist.txt -x php,txt,bak -s 200,204,301,302,307,401,403

# dirsearch: rutas y archivos
dirsearch -u https://target -e php,txt,bak,old --exclude-status=404

# wfuzz: parametros ocultos
wfuzz -c -z file,param-names.txt -u "https://target/search?FUZZ=test" --hc 404
```

### Tuning Heuristics

- Usa filtros por tamano y palabras cuando 404 devuelve 200 constante.
- Reduce concurrencia si hay rate-limit o WAF agresivo.
- Separa descubrimiento de rutas y descubrimiento de parametros para evitar ruido.
- Valida 403/401: suelen esconder paneles o APIs sensibles.

### Pivot Conditions

- Si solo hay frontend estatico, pivota a JS recon y client-side.
- Si aparece admin/debug/api privada, pivota a auth-and-access/server-side.
- Si hay respuestas distintas por Host, pivota a host-header y cache poisoning.
