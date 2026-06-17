---
name: jwt-token-tooling
description: "Operational tooling for JWT/JWS/JWE attacks in CTF web challenges using jwt_tool, hashcat mode 16500, and scripted token mutation/validation. Use when token tampering, weak secrets, kid/jku/jwk abuse, or replay logic is part of the exploit chain."
license: MIT
compatibility: Requires filesystem-based agent (Hermes compatible)
allowed-tools: Bash Read Write Edit Glob Grep Task WebFetch WebSearch
metadata:
  user-invocable: "false"
---

<!-- Original file: ctf-web/jwt-token-tooling/SKILL.md -->

# Procedimiento

Sigue los pasos y referencias del contenido base de esta habilidad.

## Guardrails de seguridad

- Ejecuta comandos de este skill solo en entornos autorizados (CTF/lab/sandbox).
- No reutilices secretos o tokens fuera del challenge.
- Verifica formato y expiracion antes de declarar un bypass.

## Contenido base

# CTF Web - JWT Tooling

## Prerequisites

**Python packages:**
```bash
pip install jwt-tool pyjwt cryptography
```

**Cracking:**
```bash
apt install hashcat
```

## Workflow

1. Decodificar token y mapear claims de autorizacion.
2. Probar fallos de verificacion (`alg`, `kid`, `jku`, `jwk`).
3. Evaluar replay y logica de negocio ligada a claims.
4. Si hay secreto debil, crackear y forjar token valido.

## Quick commands

```bash
# Analisis rapido
jwt_tool <token>

# Pruebas automaticas comunes (none/confusion/kid)
jwt_tool <token> -T

# Crack de secreto HS* (diccionario)
jwt_tool <token> -C -d wordlist.txt

# Hashcat JWT (HS256/384/512)
hashcat -m 16500 jwt_hash.txt wordlist.txt

# Decodificar payload sin verificar
echo '<token>' | cut -d. -f2 | base64 -d 2>/dev/null | jq .
```

## Integracion

- Usa junto a `auth-jwt` para tecnicas avanzadas y casos historicos.
- Usa junto a `auth-and-access` cuando el token sea solo un paso del chain.
