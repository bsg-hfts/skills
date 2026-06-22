#!/usr/bin/env python3
"""Inject efficiency playbook blocks into all SKILL.md files.

v1: universal execution efficiency block.
v2: category-specific execution block.
"""

from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
SKILLS = sorted(
    p for p in ROOT.glob('**/SKILL.md') if '.venv' not in p.parts and '.git' not in p.parts
)

BLOCK = """
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
""".strip("\n")

CATEGORY_BLOCKS = {
    "ctf-web": """
## Modo de ejecucion eficiente por categoria

- Objetivo inicial: confirmar una primitiva web pequeña (read, bypass o SSRF interno) antes de cadenas largas.
- Orden recomendado: recon de superficie -> validacion de input sink -> PoC minimo -> escalado.
- Tiempo maximo por hipotesis: 10-15 minutos; si no hay señal, pivota a otro bug family.
- Salida minima util: request reproducible (raw curl/mitmdump), respuesta esperada y condicion de exito.
""".strip("\n"),
    "ctf-pwn": """
## Modo de ejecucion eficiente por categoria

- Objetivo inicial: obtener leak estable (canary/libc/pie) antes de construir cadena final.
- Orden recomendado: checksec + offset exacto -> leak -> control RIP/PC -> exploit final.
- Prioriza primitivas deterministas sobre bruteforce salvo que el servicio forkee y el costo sea bajo.
- Salida minima util: script de exploit de 1 comando y condiciones de version/libc documentadas.
""".strip("\n"),
    "ctf-crypto": """
## Modo de ejecucion eficiente por categoria

- Objetivo inicial: clasificar familia criptografica y propiedad debil (oracle, nonce reuse, small exponent, etc.).
- Orden recomendado: fingerprint del esquema -> test de vulnerabilidad -> solver corto -> validacion con vector conocido.
- Evita implementar desde cero si existe ataque estandar en Sage/sympy/fpylll.
- Salida minima util: notebook/script que pasa de input del reto a flag sin pasos manuales ambiguos.
""".strip("\n"),
    "ctf-reverse": """
## Modo de ejecucion eficiente por categoria

- Objetivo inicial: localizar la logica de validacion o transformacion del input, no desensamblar todo.
- Orden recomendado: strings/metadata -> funciones candidatas -> trazas dinamicas -> parche o solver.
- Si hay ofuscacion, busca invariantes de I/O y hooks en puntos de comparacion.
- Salida minima util: script de emulacion/patch o extractor de clave reproducible.
""".strip("\n"),
    "ctf-forensics": """
## Modo de ejecucion eficiente por categoria

- Objetivo inicial: identificar rapidamente el artefacto con mayor probabilidad de flag (timeline + magic bytes).
- Orden recomendado: metadata -> carving -> correlacion temporal -> decodificacion especializada.
- No hagas brute force ciego sin una hipotesis de formato/estructura.
- Salida minima util: comando de extraccion + evidencia de origen (archivo/offset/frame/packet).
""".strip("\n"),
    "ctf-osint": """
## Modo de ejecucion eficiente por categoria

- Objetivo inicial: fijar 2-3 pivots verificables (usuario, dominio, coordenada, timestamp).
- Orden recomendado: fuente primaria -> corroboracion cruzada -> narrowing -> evidencia final.
- Evita rabbit holes sin señal; usa checkpoints de 10 minutos por pivot.
- Salida minima util: cadena de evidencia con URLs, capturas y razonamiento trazable.
""".strip("\n"),
    "ctf-malware": """
## Modo de ejecucion eficiente por categoria

- Objetivo inicial: extraer IoCs/config sin ejecutar binario completo si no es necesario.
- Orden recomendado: triage estatico -> desempaquetado -> config extract -> dinamica acotada.
- Aisla entorno y registra artefactos (strings, mutex, C2, keys) desde el primer minuto.
- Salida minima util: extractor reproducible de config/clave/comando C2.
""".strip("\n"),
    "ctf-ai-ml": """
## Modo de ejecucion eficiente por categoria

- Objetivo inicial: identificar tipo de modelo/ataque (weights, adversarial, prompt injection) en menos de 5 minutos.
- Orden recomendado: inspeccion de formato -> baseline de inferencia -> ataque minimo -> iteracion.
- Evita tuning largo sin metrica; define umbral de exito por intento.
- Salida minima util: script que reproduce el comportamiento objetivo (leak/bypass/clase target).
""".strip("\n"),
    "ctf-misc": """
## Modo de ejecucion eficiente por categoria

- Objetivo inicial: detectar patron dominante (encoding, jail, game logic, protocol quirk).
- Orden recomendado: normalizacion de datos -> prueba de patron -> automatizacion corta.
- Si hay varios layers, resuelve y valida uno por vez con checkpoints.
- Salida minima util: pipeline scriptable de decodificacion/resolucion por etapas.
""".strip("\n"),
    "ctf-writeup": """
## Modo de ejecucion eficiente por categoria

- Objetivo inicial: producir un writeup validable en menos de una lectura.
- Orden recomendado: metadata completa -> 1 ruta de solucion -> script final -> flag.
- Elimina tangentes y deja solo decisiones que cambian el resultado.
- Salida minima util: `writeup.md` con pasos reproducibles y script ejecutable.
""".strip("\n"),
    "solve-challenge": """
## Modo de ejecucion eficiente por categoria

- Objetivo inicial: clasificar bien el reto para delegar al skill correcto en el primer intento.
- Orden recomendado: triage del enunciado -> hipotesis de categoria -> delegacion -> validacion de progreso.
- Si la delegacion no progresa, re-clasifica y pivota rapido sin repetir trabajo.
- Salida minima util: plan de ataque corto + skill elegido + criterio de exito.
""".strip("\n"),
    "readme": """
## Modo de ejecucion eficiente por categoria

- Objetivo inicial: encontrar rapido skill adecuado y forma de invocarlo.
- Orden recomendado: identificar categoria -> abrir skill raiz -> saltar a sub-skill relevante.
- Evita lectura lineal completa; usa navegación por enlaces internos.
- Salida minima util: ruta exacta al skill que resuelve el caso.
""".strip("\n"),
    "security": """
## Modo de ejecucion eficiente por categoria

- Objetivo inicial: validar uso autorizado y riesgos operativos antes de ejecutar técnicas ofensivas.
- Orden recomendado: alcance/permisos -> entorno aislado -> ejecución mínima necesaria.
- Registra decisiones de riesgo para trazabilidad.
- Salida minima util: checklist de cumplimiento previo a ejecución.
""".strip("\n"),
}


def detect_category(path: Path, text: str) -> str:
    rel = path.relative_to(ROOT)
    top = rel.parts[0].lower() if rel.parts else ""
    if top in CATEGORY_BLOCKS:
        return top

    m = re.search(r"<!--\s*Original file:\s*([^>]+?)\s*-->", text)
    if m:
        original = m.group(1).strip().replace("\\", "/")
        top2 = original.split("/", 1)[0].lower()
        if top2 in CATEGORY_BLOCKS:
            return top2
    return "readme"


def inject_block(text: str) -> tuple[str, bool]:
    if '## Modo de ejecucion eficiente' in text:
        return text, False

    guardrails_header = '## Guardrails de seguridad'
    contenido_header = '## Contenido base'

    if contenido_header not in text:
        return text + '\n\n' + BLOCK + '\n', True

    if guardrails_header in text:
        gpos = text.find(guardrails_header)
        cpos = text.find(contenido_header)
        if gpos != -1 and cpos != -1 and gpos < cpos:
            insert_at = cpos
            new_text = text[:insert_at].rstrip() + '\n\n' + BLOCK + '\n\n' + text[insert_at:]
            return new_text, True

    # fallback: insert before contenido base
    cpos = text.find(contenido_header)
    new_text = text[:cpos].rstrip() + '\n\n' + BLOCK + '\n\n' + text[cpos:]
    return new_text, True


def inject_category_block(path: Path, text: str) -> tuple[str, bool]:
    if '## Modo de ejecucion eficiente por categoria' in text:
        return text, False

    category = detect_category(path, text)
    block = CATEGORY_BLOCKS.get(category, CATEGORY_BLOCKS['readme'])

    contenido_header = '## Contenido base'
    universal_header = '## Modo de ejecucion eficiente'

    if universal_header in text and contenido_header in text:
        upos = text.find(universal_header)
        cpos = text.find(contenido_header)
        if upos != -1 and cpos != -1 and upos < cpos:
            insert_at = cpos
            new_text = text[:insert_at].rstrip() + '\n\n' + block + '\n\n' + text[insert_at:]
            return new_text, True

    if contenido_header in text:
        cpos = text.find(contenido_header)
        new_text = text[:cpos].rstrip() + '\n\n' + block + '\n\n' + text[cpos:]
        return new_text, True

    return text + '\n\n' + block + '\n', True


def main() -> None:
    changed = 0
    updated_category = 0
    updated_universal = 0
    for p in SKILLS:
        txt = p.read_text(encoding='utf-8', errors='ignore')
        updated, did_universal = inject_block(txt)
        updated2, did_category = inject_category_block(p, updated)
        if did_universal:
            updated_universal += 1
        if did_category:
            updated_category += 1

        if updated2 != txt:
            p.write_text(updated2, encoding='utf-8')
            changed += 1

    print(f'skills_total={len(SKILLS)}')
    print(f'updated={changed}')
    print(f'universal_added={updated_universal}')
    print(f'category_added={updated_category}')


if __name__ == '__main__':
    main()
