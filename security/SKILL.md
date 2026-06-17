---
name: security
description: "This repository contains offensive security techniques documented for **authorized CTF (Capture The Flag) competitions, security research, and education**. The techniques described — including exploit"
license: MIT
compatibility: Requires filesystem-based agent (Hermes compatible)
allowed-tools: Bash Read Write Edit Glob Grep Task WebFetch WebSearch
metadata:
  user-invocable: "false"
---

<!-- Original file: SECURITY.md -->

# Procedimiento

Sigue los pasos y referencias del contenido base de esta habilidad.

## Guardrails de seguridad

- Ejecuta comandos de este skill solo en entornos autorizados (CTF/lab/sandbox).
- No reutilices payloads ni comandos contra infraestructura real sin permiso explícito.
- Revisa y adapta rutas, hosts y credenciales placeholders antes de ejecutar.
- Prioriza pruebas no destructivas y confirma cambios de estado antes de acciones invasivas.

## Modo de ejecucion eficiente

1. Triage rapido (90-180s): identifica entrada, objetivo y restriccion principal antes de ejecutar comandos largos.
2. Primitiva minima primero: busca leak/bypass/read de menor costo antes de encadenar explotacion completa.
3. Bucle corto de iteracion: ejecutar -> medir salida -> ajustar hipotesis en pasos pequenos y reversibles.
4. Pivot temprano: si en 2-3 iteraciones no hay progreso real, cambia a la tecnica o sub-skill mas probable.
5. Evidencia y salida: conserva comandos, payloads y resultados minimos reproducibles para writeup o handoff.

### Checklist operativo
- Define objetivo verificable (que dato/flag esperas obtener en este paso).
- Ejecuta solo lo necesario para confirmar o descartar una hipotesis.
- Evita ruido: elimina pruebas redundantes y comandos sin criterio de exito.
- Documenta inmediatamente el hallazgo util y el siguiente paso.

## Modo de ejecucion eficiente por categoria

- Objetivo inicial: validar uso autorizado y riesgos operativos antes de ejecutar técnicas ofensivas.
- Orden recomendado: alcance/permisos -> entorno aislado -> ejecución mínima necesaria.
- Registra decisiones de riesgo para trazabilidad.
- Salida minima util: checklist de cumplimiento previo a ejecución.

## Contenido base

# Security Policy

## About This Repository

This repository contains offensive security techniques documented for **authorized CTF (Capture The Flag) competitions, security research, and education**. The techniques described — including exploitation, injection, cryptographic attacks, and reverse engineering — are intentionally offensive in nature. That is the purpose of the project.

## Reporting Security Issues

Please report the following via [GitHub Security Advisories](https://github.com/ljagiello/ctf-skills/security/advisories/new):

- **Leaked credentials or PII** — Real API keys, passwords, tokens, or personally identifiable information accidentally included from writeup sources
- **Malicious links** — URLs pointing to live malicious infrastructure rather than CTF challenge servers
- **Payloads targeting real infrastructure** — Examples that reference production systems, real IP addresses, or non-example domains (outside of `example.com`, `attacker.com`, etc.)

## What Is NOT a Security Issue

- Techniques describing how to exploit vulnerabilities — that is the intended content
- Code snippets that perform offensive operations (shellcode, ROP chains, injection payloads, etc.)
- References to real CVEs or public security advisories
- Links to published CTF writeups, tools, or documentation

## Responsible Use

Users of these materials are expected to apply them only in:

- CTF competitions
- Authorized penetration testing engagements
- Security research with proper authorization
- Educational and training environments

Misuse of these techniques against systems without authorization is illegal and unethical.
