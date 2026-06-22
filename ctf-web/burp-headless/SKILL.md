---
name: burp-headless
description: "Burp Suite Professional in enforced headless mode for CTF web workflows. Use this skill whenever Burp is required and do not use GUI tools like Proxy/Repeater/Intruder windows."
license: MIT
compatibility: Requires filesystem-based agent (Hermes compatible)
allowed-tools: Bash Read Write Edit Glob Grep Task WebFetch WebSearch
metadata:
  user-invocable: "false"
---

<!-- Original file: ctf-web/burp-headless/SKILL.md -->

# Procedimiento

Sigue los pasos y referencias del contenido base de esta habilidad.

## Guardrails de seguridad

- Ejecuta comandos de este skill solo en entornos autorizados (CTF/lab/sandbox).
- Burp es obligatorio en modo headless (sin GUI).
- Si un paso depende de interfaz grafica de Burp, reemplazalo por CLI reproducible.

## Modo de ejecucion eficiente

1. Define scope (host/rutas) antes de iniciar escaneo.
2. Ejecuta Burp con `--headless` y proyecto dedicado por target.
3. Exporta evidencia en archivos y confirma hallazgos con curl/HTTPie.
4. Escala a ZAP/mitmdump solo para cobertura complementaria, no para sustituir el requisito headless de Burp.

## Contenido base

# CTF Web - Burp Headless Enforcement

## Requisito operativo

- No abrir Burp GUI.
- No usar flujos manuales de Proxy/Repeater/Intruder.
- Toda ejecucion de Burp debe ser por linea de comandos y con salida versionable.

## Quick Commands

```bash
# Burp Suite Professional headless (requerido)
java -jar burpsuite_pro.jar \
  --headless \
  --project-file burp-project.burp \
  --config-file burp-config.json

# Variante con configuracion de usuario separada
java -jar burpsuite_pro.jar \
  --headless \
  --project-file burp-project.burp \
  --user-config-file burp-user-config.json \
  --config-file burp-config.json
```

## Checklist de cumplimiento

- El comando incluye `--headless`.
- Existe `--project-file` para trazabilidad.
- El scope esta definido en config y no apunta fuera del target autorizado.
- Los hallazgos se validan con request CLI reproducible (curl/HTTPie).

## Cuando bloquear y corregir

- Si alguien propone abrir Burp GUI, detener y corregir a flujo headless.
- Si no hay Burp Pro disponible para headless, documentar bloqueo y continuar con ZAP/mitmdump solo como soporte temporal.
