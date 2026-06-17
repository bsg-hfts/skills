---
name: api-httpie-and-rest
description: "- [API Attack Workflow with HTTPie](#api-attack-workflow-with-httpie)"
license: MIT
compatibility: Requires filesystem-based agent (Hermes compatible)
allowed-tools: Bash Read Write Edit Glob Grep Task WebFetch WebSearch
metadata:
  user-invocable: "false"
---

<!-- Original file: ctf-web/api-httpie-and-rest/SKILL.md -->

# Procedimiento

Sigue los pasos y referencias del contenido base de esta habilidad.

## Guardrails de seguridad

- Ejecuta comandos de este skill solo en entornos autorizados (CTF/lab/sandbox).
- No reutilices payloads ni comandos contra infraestructura real sin permiso explicito.

## Contenido base

# CTF Web - API Testing with HTTPie

## API Attack Workflow with HTTPie

### Prerequisites

**Linux (apt):**
```bash
apt install httpie jq
```

### Quick Commands

```bash
# request JSON simple
http POST https://target/api/login user=guest pass=guest

# bearer token reuse
http GET https://target/api/admin "Authorization:Bearer <token>"

# cambiar metodo y cabeceras
http PATCH https://target/api/user/7 role=admin "X-Forwarded-For:127.0.0.1"

# fuzzing ligero de ids
for i in $(seq 1 20); do http -b GET https://target/api/orders/$i | jq .; done

# graphQL basico
http POST https://target/graphql query='{"query":"{me{username role}}"}'
```

### API Attack Checklist

- BOLA/IDOR en recursos numericos o UUID predecibles.
- Mass assignment en cuerpos JSON (role, isAdmin, plan, balance).
- Verb tampering (GET/POST/PUT/PATCH/DELETE) en misma ruta.
- Header trust (`X-Forwarded-*`, `X-Original-URL`, `X-HTTP-Method-Override`).
- GraphQL introspection, batching y alias abuse.
