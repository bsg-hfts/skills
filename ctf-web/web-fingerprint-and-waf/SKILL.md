---
name: web-fingerprint-and-waf
description: "- [Stack and WAF Fingerprinting](#stack-and-waf-fingerprinting)"
license: MIT
compatibility: Requires filesystem-based agent (Hermes compatible)
allowed-tools: Bash Read Write Edit Glob Grep Task WebFetch WebSearch
metadata:
  user-invocable: "false"
---

<!-- Original file: ctf-web/web-fingerprint-and-waf/SKILL.md -->

# Procedimiento

Sigue los pasos y referencias del contenido base de esta habilidad.

## Guardrails de seguridad

- Ejecuta comandos de este skill solo en entornos autorizados (CTF/lab/sandbox).
- No reutilices payloads ni comandos contra infraestructura real sin permiso explicito.
- Prioriza fingerprints pasivos antes de probes activos.

## Modo de ejecucion eficiente

1. Triage rapido: identifica CDN/WAF/server/framework en 2-3 minutos.
2. Primitiva minima: confirma al menos una debilidad explotable o exclusion de vector.
3. Bucle corto: fingerprint -> test controlado -> ajustar payload/headers.
4. Pivot temprano: si hay WAF fuerte, cambia a bypass de parser o bugs logicos.

## Contenido base

# CTF Web - Fingerprinting and WAF Tooling

## Stack and WAF Fingerprinting

### Prerequisites

**Linux (apt):**
```bash
apt install whatweb wafw00f nikto
```

**Go tools:**
```bash
go install github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
```

### Quick Commands

```bash
# tecnologia y componentes
whatweb -a 3 https://target

# deteccion de WAF
wafw00f https://target

# escaneo baseline de configuracion web
nikto -h https://target

# templates de exposures y CVEs web
nuclei -u https://target -tags web,cve,misconfig -severity low,medium,high,critical
```

### Practical Mapping

- Si detectas nginx+alias quirks: revisa traversal y normalizacion de rutas.
- Si detectas proxies/CDN: revisa cache poisoning y cabeceras no keyeadas.
- Si detectas WAF estricto: prueba encoded payloads, method override y desync.
- Si detectas framework concreto (Laravel, Django, Spring): pivota a CVEs y defaults.

### Signal Over Noise

- Prioriza findings reproducibles (endpoint + request + respuesta).
- Descarta findings genericos no explotables sin impacto en reto.
- Usa nuclei en modo targeted, no full internet profile.
