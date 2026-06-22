---
name: spa-frontend-analysis
description: "Provides techniques for reverse engineering Single Page Application (SPA) frontends to discover hidden routes, extract secrets from client-side JavaScript bundles, and analyze Angular/React/Vue compiled artifacts. Use when the target is a SPA (Angular, React, Vue, Ember) and you need to: enumerate hidden/orphaned routes not linked in the UI, extract API keys or tokens hardcoded in production bundles, analyze minified/bundled JavaScript (main.js, chunk.js) for attack surface, discover admin panels or debug routes from client-side route definitions, or understand client-side business logic that controls access gates."
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
- Prioriza pruebas no destructivas y confirma cambios de estado antes de acciones invasivas.

## Modo de ejecucion eficiente

1. Triage rapido (90-180s): identifica si es Angular, React o Vue antes de descargar bundles.
2. Primitiva minima primero: grep de rutas/secretos antes de analisis completo del bundle.
3. Bucle corto de iteracion: descarga -> formato legible -> busqueda dirigida -> hipotesis.
4. Pivot temprano: si no hay rutas ocultas en el router, busca flags/tokens/credenciales hardcodeadas.
5. Evidencia y salida: conserva rutas descubiertas, secretos extraidos y payloads reproducibles.

### Checklist operativo
- Define objetivo verificable (ruta oculta, secreto, logica de acceso).
- Descarga el bundle principal antes de analizar.
- Busca patrones especificos (router, paths, keys, tokens) con grep dirigido.
- Valida rutas descubiertas directamente via HTTP antes de escalar.
- Documenta inmediatamente hallazgos y siguiente paso.

## Modo de ejecucion eficiente por categoria

- Objetivo inicial: identificar el framework SPA y obtener el bundle principal en texto legible.
- Orden recomendado: fingerprint SPA -> descarga bundle -> pretty-print -> extraccion de rutas -> busqueda de secretos.
- Tiempo maximo por hipotesis: 10-15 minutos; si no hay rutas interesantes, pivota a secretos/logica.
- Salida minima util: lista de rutas ocultas o secretos con evidencia del bundle (linea/patron).

## Contenido base

# CTF Web - SPA Frontend Reverse Engineering

## Table of Contents
- [Fingerprint SPA Framework](#fingerprint-spa-framework)
- [Download and Pretty-Print JavaScript Bundles](#download-and-pretty-print-javascript-bundles)
- [Angular Route Extraction from main.js](#angular-route-extraction-from-mainjs)
- [React Route Extraction](#react-route-extraction)
- [Vue Route Extraction](#vue-route-extraction)
- [Secret Hunting in Client-Side Code](#secret-hunting-in-client-side-code)
- [Orphaned Route Discovery Methodology](#orphaned-route-discovery-methodology)
- [Accessing Hidden/Admin Routes](#accessing-hiddenadmin-routes)
- [Extracting Runtime State via Browser Console](#extracting-runtime-state-via-browser-console)
- [Source Map Exploitation](#source-map-exploitation)
- [Angular Guard Bypass via Direct Navigation](#angular-guard-bypass-via-direct-navigation)

---

## Fingerprint SPA Framework

**Detection signals:**
```bash
# Angular: ng-version attribute, /runtime.js, /polyfills.js, /main.js, Zone.js
curl -s http://target/ | grep -iE 'ng-version|angular|zone\.js|__ngContext'

# React: _reactFiber, __REACT_DEVTOOLS, react-dom
curl -s http://target/ | grep -iE 'react|_reactFiber|__webpack_require__'

# Vue: __vue__, Vue.version, vue.runtime
curl -s http://target/ | grep -iE '__vue__|vue\.runtime|VueRouter'
```

**JavaScript bundle enumeration:**
```bash
# Common Angular bundle names
curl -s http://target/ | grep -oE 'src="[^"]*\.js"' | sort -u

# Typical structure:
# Angular:  main.<hash>.js, polyfills.<hash>.js, runtime.<hash>.js, vendor.<hash>.js
# React/CRA: static/js/main.<hash>.js, static/js/chunk.<hash>.js
# Vite:     assets/index-<hash>.js
```

---

## Download and Pretty-Print JavaScript Bundles

```bash
# Install js-beautify (Python)
pip install jsbeautifier

# Download and format bundle
curl -s http://target/main.js -o main.min.js
js-beautify main.min.js -o main.pretty.js

# Or with prettier (Node.js)
npm install -g prettier
prettier --parser babel main.min.js > main.pretty.js

# Download all JS assets referenced in HTML
curl -s http://target/ | grep -oP 'src="\K[^"]+\.js' | while read f; do
    curl -s "http://target/$f" -o "$(basename $f).min.js"
done

# Quick search without full download (streaming grep)
curl -s http://target/main.js | python3 -c "
import sys, re
data = sys.stdin.read()
# Find all string literals
strings = re.findall(r'[\"\\x27]([^\"\\x27]{8,})[\"\\x27]', data)
for s in strings:
    if any(k in s.lower() for k in ['secret','token','key','admin','password','api','flag']):
        print(s)
"
```

---

## Angular Route Extraction from main.js

Angular Router compiles route definitions into the bundle. After pretty-printing:

```bash
# Pattern 1: loadChildren lazy routes (most modern Angular apps)
grep -oE '"path":"[^"]*"' main.pretty.js | sort -u

# Pattern 2: RouterModule.forRoot / forChild component array
grep -oP '(?<=path:\s")[^"]+' main.pretty.js | sort -u

# Pattern 3: routes array object pattern
python3 << 'EOF'
import re, sys

with open("main.pretty.js") as f:
    content = f.read()

# Extract path values from route config objects
paths = re.findall(r'path\s*:\s*["\']([^"\']*)["\']', content)
for p in sorted(set(paths)):
    print(p)
EOF
```

**Common Juice Shop / Angular hidden routes to look for:**
- `/score-board` — unlocks challenge scoreboard
- `/administration` — admin panel (often guarded by role check, bypassable via direct nav)
- `/privacy-policy` — often contains interesting metadata
- `/support/chat` or `/contact` — features not linked in nav
- `/about` — may expose version/team info
- Debug/dev routes: `/debug`, `/test`, `/dev`
- `**` wildcard routes with redirects that reveal structure

```bash
# Check for route guards (canActivate) — these are security gates but routes still exist
grep -E 'canActivate|canLoad|AuthGuard|AdminGuard' main.pretty.js
```

---

## React Route Extraction

```bash
# React Router: look for Route / Switch / path= patterns
grep -oP '(?<=path=["\\\x27])[^"\\x27]+' main.pretty.js | sort -u

# React Router v6: Routes / Route element pattern
grep -oP '(?<=path=")[^"]+' main.pretty.js | sort -u

# Look for react-router Link / NavLink hrefs
grep -oP '(?<=to=["\\\x27])[^"\\x27/][^"\\x27]*' main.pretty.js | grep '^/' | sort -u

# Extract from compiled chunk files too
for f in *.min.js; do
    js-beautify "$f" | grep -oP '(?<=path=")[^"]+' | sort -u
done
```

---

## Vue Route Extraction

```bash
# Vue Router: routes array with path property
grep -oP '(?<=path:\s*["\\\x27])[^"\\x27]+' main.pretty.js | sort -u

# Vue Router lazy-load components
grep -oE '"path":\s*"[^"]*"' main.pretty.js | tr -d '"path":' | tr -d '"' | sort -u
```

---

## Secret Hunting in Client-Side Code

**High-value patterns to search:**
```bash
# API keys and tokens (generic patterns)
grep -iE '(api[_-]?key|apikey|api_secret|client[_-]?secret|auth[_-]?token|access[_-]?token)\s*[:=]\s*["\x27][^\x27"]{8,}' main.pretty.js

# Hardcoded credentials
grep -iE '(password|passwd|secret|credential)\s*[:=]\s*["\x27][^\x27"]{4,}["\x27]' main.pretty.js

# JWT secrets
grep -iE '(jwt[_-]?secret|signing[_-]?key|token[_-]?secret)\s*[:=]\s*["\x27][^\x27"]{4,}' main.pretty.js

# AWS/GCP/Azure keys
grep -E '(AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{35}|ya29\.[^\s]+)' main.pretty.js

# Private keys / certificates
grep -E 'BEGIN (RSA |EC )?PRIVATE KEY|BEGIN CERTIFICATE' main.pretty.js

# Hardcoded admin credentials (common in CTFs)
grep -iE '(admin|superuser|root)\s*[:=,]\s*["\x27][^\x27"]{4,}' main.pretty.js

# Debug flags / feature toggles
grep -iE '(debug|isDev|devMode|showScoreboard|enableAdmin)\s*[:=]\s*(true|false|1|0)' main.pretty.js
```

**Automated extraction script:**
```python
import re, sys

PATTERNS = {
    'api_key':     r'(?:api[_-]?key|apikey)["\s]*[:=]["\s]*["\x27]([^\x27"]{8,})["\x27]',
    'secret':      r'(?:secret|token|password|credential)["\s]*[:=]["\s]*["\x27]([^\x27"]{6,})["\x27]',
    'hardcoded_url': r'https?://(?!cdn|assets|fonts)[^\s"\']{10,}',
    'jwt_like':    r'eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}',
    'hex_key':     r'[0-9a-fA-F]{32,64}(?=[^0-9a-fA-F])',
}

with open(sys.argv[1]) as f:
    content = f.read()

for name, pattern in PATTERNS.items():
    matches = set(re.findall(pattern, content, re.IGNORECASE))
    for m in sorted(matches)[:10]:  # cap at 10 per category
        print(f'[{name}] {m}')
```

---

## Orphaned Route Discovery Methodology

Systematic approach to find routes not linked in the UI:

```bash
# Step 1: Extract all string literals that look like URL paths
python3 << 'EOF'
import re

with open("main.pretty.js") as f:
    content = f.read()

# Paths: start with / and contain only URL-safe chars
paths = re.findall(r'["\x27](/[a-zA-Z0-9_\-/:.?=&%#]+)["\x27]', content)
# Filter obvious noise (cdn, font, image paths)
filtered = [p for p in set(paths)
            if not any(x in p for x in ['.png', '.svg', '.css', '.woff', 'googleapis', 'gstatic', 'jquery'])
            and len(p) > 1]
for p in sorted(filtered):
    print(p)
EOF

# Step 2: Try each discovered path
while read path; do
    code=$(curl -s -o /dev/null -w '%{http_code}' "http://target$path")
    echo "$code $path"
done < paths.txt | grep -v '^404'

# Step 3: Check if SPA serves the same HTML for all routes (typical for SPA routing)
# If all return 200 with same HTML, the routing is client-side — navigate in browser
```

---

## Accessing Hidden/Admin Routes

**Browser navigation (most reliable for Angular/React):**
```javascript
// Angular: navigate programmatically (browser console)
// Find the Angular router instance
const router = window.getAllAngularRootElements()[0].__ngContext__[8];  // may vary
router.navigate(['/administration']);

// Or simply navigate the browser URL bar directly
// Angular router handles hash/history routing client-side
location.href = 'http://target/#/administration';         // Hash routing
history.pushState({}, '', '/administration');             // History routing (SPA)
```

**Direct URL access:**
```bash
# Just navigate to the path — SPA will handle routing client-side
# The server returns index.html for all paths; Angular loads the route component
curl http://target/administration   # may redirect to /index.html
# In browser: just type http://target/#/administration
```

**Angular Guard bypass (canActivate):**
```javascript
// Guards run client-side — if you can navigate before guards check, you win
// Modify guard condition in browser console:
// 1. Find guard service in Angular injector
// 2. Override the canActivate method

// Simpler: intercept HTTP requests to authorization endpoint and return 200
// Use browser extension or mitmproxy to modify responses
```

---

## Extracting Runtime State via Browser Console

Once the SPA is loaded, the browser console gives deep access:

```javascript
// Angular: get all registered routes
const router = ng.probe(document.querySelector('[ng-version]')).injector.get(ng.coreTokens.Router);
console.log(router.config);  // Array of all route definitions

// React DevTools: inspect component tree
// Install React DevTools extension, then:
$r  // gives current component's instance/props

// Vue DevTools:
window.__VUE_DEVTOOLS_GLOBAL_HOOK__.apps[0]._instance  // root Vue instance

// General: find all XHR/fetch calls made by the app
// Open Network tab, filter XHR/Fetch, interact with app to see endpoints

// Intercept Angular HttpClient to log all API calls
const http = ng.getInjector(document.body).get(ng.core.HttpClient);
```

---

## Source Map Exploitation

Many production SPAs accidentally ship source maps, revealing original TypeScript/JSX source:

```bash
# Check if .map files are exposed
curl -I http://target/main.js.map
curl -I http://target/static/js/main.chunk.js.map

# If available, download and reconstruct original source
# Install source-map CLI
npm install -g source-map

# Download the compiled JS and its map
curl -s http://target/main.js -o main.js
curl -s http://target/main.js.map -o main.js.map

# Use browser DevTools: Sources tab > right-click > "Add source map..."
# Or use sourcemapper tool:
pip install sourcemapper
sourcemapper -url http://target/main.js.map -output ./src-recovered/
```

**What to look for in recovered source:**
- Route guard implementations (canActivate logic)
- Hardcoded admin check conditions (e.g., `role === 'admin'`)
- API endpoint definitions
- Hardcoded tokens or secrets in TypeScript service files
- Test/debug components left in production builds

---

## Angular Guard Bypass via Direct Navigation

**Pattern:** Angular guards (`canActivate`, `canLoad`) are client-side — they only prevent navigation within the SPA, not direct server-side access to the route's underlying API.

```bash
# 1. Find the protected route path from bundle analysis
# Example: /administration requires AdminGuard

# 2. The guard's backing API is usually still accessible
# Try the underlying API endpoints directly:
curl -H "Authorization: Bearer $TOKEN" http://target/api/admin/users
curl -H "Authorization: Bearer $TOKEN" http://target/api/metrics

# 3. For UI-only guard bypass: modify localStorage/sessionStorage
# The guard often reads: localStorage.getItem('user').role === 'admin'
localStorage.setItem('user', JSON.stringify({...JSON.parse(localStorage.getItem('user')), role: 'admin'}));
location.reload();
```

**Key insight:** Client-side route guards protect navigation flow, not data. The real security boundary is the backend API. However, in CTFs like Juice Shop, the guard bypass via local storage manipulation or direct URL navigation can unlock challenges/scoreboards without API calls.
