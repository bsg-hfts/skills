---
name: auth-and-access-2
description: "2018-era additions: bucket-collision hash auth bypass, Unicode username homograph collision, SRP A=0/A=N bypass, ArangoDB AQL MERGE privilege escalation. For foundational auth/access techniques see [a"
license: MIT
compatibility: Requires filesystem-based agent (Hermes compatible)
allowed-tools: Bash Read Write Edit Glob Grep Task WebFetch WebSearch
metadata:
  user-invocable: "false"
---

<!-- Original file: ctf-web/auth-and-access-2.md -->

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

- Objetivo inicial: confirmar una primitiva web pequeña (read, bypass o SSRF interno) antes de cadenas largas.
- Orden recomendado: recon de superficie -> validacion de input sink -> PoC minimo -> escalado.
- Tiempo maximo por hipotesis: 10-15 minutos; si no hay señal, pivota a otro bug family.
- Salida minima util: request reproducible (raw curl/Burp headless (sin GUI)), respuesta esperada y condicion de exito.

## Contenido base

# CTF Web - Auth & Access Control Attacks (Part 2)

2018-era additions: bucket-collision hash auth bypass, Unicode username homograph collision, SRP A=0/A=N bypass, ArangoDB AQL MERGE privilege escalation. For foundational auth/access techniques see [auth-and-access.md](../auth-and-access/SKILL.md). For JWT attacks see [auth-jwt.md](../auth-jwt/SKILL.md). For OAuth/OIDC/SAML/CI-CD, see [auth-infra.md](../auth-infra/SKILL.md).

## Table of Contents
- [std::unordered_set Bucket Collision Auth Bypass (Hackover 2018)](#stdunordered_set-bucket-collision-auth-bypass-hackover-2018)
- [nodeprep.prepare Homograph Username Collision (HCTF 2018)](#nodeprepprepare-homograph-username-collision-hctf-2018)
- [SRP A=0, A=N Auth Bypass (OTW Advent 2018)](#srp-a0-an-auth-bypass-otw-advent-2018)
- [ArangoDB AQL MERGE Injection for Privilege Escalation (P.W.N. CTF 2018)](#arangodb-aql-merge-injection-for-privilege-escalation-pwn-ctf-2018)

---

## std::unordered_set Bucket Collision Auth Bypass (Hackover 2018)

**Pattern:** A C++ backend stores credential hashes in `std::unordered_set<std::string>`. The set's bucket index is derived from only the first bytes of a SHA-512 digest (truncated `size_t` hash). The lookup loop aborts early after a bounded number of bucket probes (`MAX_LOOKUPS = 1000`). Flood the set with 1000+ entries that all collide in the same bucket as the `root` account — the compare for the correct entry never executes and the call returns "found" on an attacker-chosen password.

```cpp
// Vulnerable shape
std::unordered_set<std::string> users;
auto it = users.find(login_key);           // probes at most MAX_LOOKUPS
if (it != users.end()) { /* accepted */ }
```

```python
# Flood registration: every entry collides in root's bucket
import requests
for i in range(1100):
    requests.post("http://target/register",
                  data={"name": f"ro{i:04d}", "password": "ot1"})
# Log in as root with an arbitrary password — loop gives up before compare
requests.post("http://target/login", data={"name": "root", "password": "anything"})
```

**Key insight:** Hash-table implementations that truncate digests into bucket indices expose a second-preimage surface: the attacker only has to match the bucket, not the full hash. When the data structure also has a bounded probe count (DoS guard), flooding the bucket turns an authentication check into an unconditional accept. Any `unordered_map`/`unordered_set` keyed on low-entropy derivations of user input is suspect — watch for `std::hash<std::string>` implementations that reduce to `size_t` via XOR-folding.

**References:** Hackover CTF 2018 — secure-hash, writeup 11502

---

## nodeprep.prepare Homograph Username Collision (HCTF 2018)

**Pattern:** Registration calls Node's `node-xmpp-server` `nodeprep.prepare(username)` which runs RFC-3491/Stringprep normalization. Unicode characters like `ᴬ` (U+1D2C Modifier Letter Capital A) normalize to ASCII `A`, then the existing user lookup finds the already-registered `admin`. Register `ᴬdmin` with any password, and the lookup returns the real admin row — set a new password via a password-reset flow.

```text
username: \u1D2Cdmin   # ᴬdmin
nodeprep.prepare("ᴬdmin") == "admin"
```

**Key insight:** Any pipeline that (1) normalizes usernames before lookup but (2) stores the pre-normalized form separately is vulnerable. Normalize once at write-time and never accept users whose pre-normalized form collides with an existing row. Libraries to audit: `nodeprep`, `icu.normalize`, `unicodedata.normalize`, `golang.org/x/text/secure/precis`.

**References:** HCTF 2018 — admin, writeup 12132

---

## SRP A=0, A=N Auth Bypass (OTW Advent 2018)

**Pattern:** SRP (Secure Remote Password) implementations that do not validate `A % N != 0` allow the client to send `A = 0` (or `A = k*N`). The server computes `S = (A * v^u)^b mod N = 0`, so the session key is `H(0)` — known to the attacker. Bypass login without knowing the password.

```text
Client: sends A = 0
Server: computes S = 0
Session key: K = H(0)   # attacker knows this
```

**Key insight:** SRP, DH, and similar group-based protocols need explicit validation that public values are nontrivial. Spec-compliant SRP rejects `A % N == 0`; buggy implementations don't. Same attack works for `A = N, 2N, ...`.

**References:** OverTheWire Advent Bonanza 2018 — writeup 12750

---

## ArangoDB AQL MERGE Injection for Privilege Escalation (P.W.N. CTF 2018)

**Pattern:** ArangoDB's AQL query language accepts user-supplied fragments that are concatenated into `FILTER` clauses. Inject `' || 1 == 1 LET newitem = MERGE(u, {'role':'admin'}) RETURN newitem //` to turn a login check into an in-memory role upgrade — the server returns the modified user object without touching the real record.

```text
username: x' || 1 == 1 LET newitem = MERGE(u, {'role':'admin'}) RETURN newitem //
password: anything
```

**Key insight:** NoSQL databases each have their own injection grammar. AQL's `MERGE` creates a new document inheriting the found record's fields, bypassing any ACL that only checks persistent storage. Always use parameterised bind variables.

**References:** P.W.N. CTF 2018 — H!pster Startup, writeup 12067
