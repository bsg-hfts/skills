---
name: 3d-printing
description: "- [PrusaSlicer Binary G-code (.g / .bgcode)](#prusaslicer-binary-g-code-g--bgcode)"
license: MIT
compatibility: Requires filesystem-based agent (Hermes compatible)
allowed-tools: Bash Read Write Edit Glob Grep Task WebFetch WebSearch
metadata:
  user-invocable: "false"
---

<!-- Original file: ctf-forensics/3d-printing.md -->

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

- Objetivo inicial: identificar rapidamente el artefacto con mayor probabilidad de flag (timeline + magic bytes).
- Orden recomendado: metadata -> carving -> correlacion temporal -> decodificacion especializada.
- No hagas brute force ciego sin una hipotesis de formato/estructura.
- Salida minima util: comando de extraccion + evidencia de origen (archivo/offset/frame/packet).

## Contenido base

# CTF Forensics - 3D Printing / CAD File Forensics

## Table of Contents
- [PrusaSlicer Binary G-code (.g / .bgcode)](#prusaslicer-binary-g-code-g--bgcode)
- [QOIF (Quite OK Image Format)](#qoif-quite-ok-image-format)
- [G-code Analysis Tips](#g-code-analysis-tips)
- [G-code Side View Visualization (0xFun 2026)](#g-code-side-view-visualization-0xfun-2026)
- [Uncommon File Magic Bytes](#uncommon-file-magic-bytes)

---

## PrusaSlicer Binary G-code (.g / .bgcode)

**File magic:** `GCDE` (4 bytes)

The `.g` extension is PrusaSlicer's binary G-code format (bgcode). It stores G-code in a block-based structure with compression.

**File structure:**
```text
Header: "GCDE"(4) + version(4) + checksum_type(2)
Blocks: [type(2) + compression(2) + uncompressed_size(4)
         + compressed_size(4) if compressed
         + type-specific fields
         + data + CRC32(4)]
```

**Block types:**
- 0 = FileMetadata (has encoding field, 2 bytes)
- 1 = GCode (has encoding field, 2 bytes)
- 2 = SlicerMetadata (has encoding field, 2 bytes)
- 3 = PrinterMetadata (has encoding field, 2 bytes)
- 4 = PrintMetadata (has encoding field, 2 bytes)
- 5 = Thumbnail (has format(2) + width(2) + height(2))

**Compression types:** 0=None, 1=Deflate, 2=Heatshrink(11,4), 3=Heatshrink(12,4)

**Thumbnail formats:** 0=PNG, 1=JPEG, 2=QOI (Quite OK Image)

**Parsing and extracting G-code:**
```python
import struct, zlib
import heatshrink2  # pip install heatshrink2

with open('file.g', 'rb') as f:
    data = f.read()

pos = 10  # After header
while pos < len(data) - 8:
    block_type = struct.unpack('<H', data[pos:pos+2])[0]
    compression = struct.unpack('<H', data[pos+2:pos+4])[0]
    uncompressed_size = struct.unpack('<I', data[pos+4:pos+8])[0]
    pos += 8
    if compression != 0:
        compressed_size = struct.unpack('<I', data[pos:pos+4])[0]
        pos += 4
    else:
        compressed_size = uncompressed_size
    # Type-specific extra header fields
    if block_type in [0,1,2,3,4]:
        pos += 2  # encoding field
    elif block_type == 5:
        pos += 6  # format + width + height
    block_data = data[pos:pos+compressed_size]
    pos += compressed_size + 4  # data + CRC32

    if block_type == 1:  # GCode block
        if compression == 3:  # Heatshrink 12/4
            gcode = heatshrink2.decompress(block_data, window_sz2=12, lookahead_sz2=4)
        elif compression == 1:  # Deflate (zlib)
            gcode = zlib.decompress(block_data)
        # Search gcode for hidden comments/flags
```

**Common hiding spots:**
- G-code comments (`;=== FLAG_CHAR ... ===`) at specific layer heights
- Custom G-code sections (`;TYPE:Custom`)
- Metadata fields (object names, filament info)
- Thumbnail images (extract and view QOIF/PNG)

## QOIF (Quite OK Image Format)

**Magic:** `qoif` (4 bytes) + width(4 BE) + height(4 BE) + channels(1) + colorspace(1)

Lightweight image format used in PrusaSlicer thumbnails. Decode with Python struct or use the `qoi` library.

## G-code Analysis Tips

```bash
# Search for flag patterns in decompressed gcode
grep -i "flag\|meta\|ctf\|secret" output.gcode

# Look for custom comments at layer changes
grep ";.*FLAG\|;.*LAYER_CHANGE" output.gcode

# Extract XY coordinates for visual patterns
grep "^G1" output.gcode | awk '{print $2, $3}' > coords.txt
```

## G-code Side View Visualization (0xFun 2026)

**Pattern (PrintedParts):** Plot X vs Z (side view) with Y filtering. Extrusion segments at specific Y ranges form readable text.

```bash
# Extract XY coordinates from G-code
grep "^G1" output.gcode | awk '{print $2, $3}' > coords.txt
# Plot with matplotlib for visual patterns
```

**Lesson:** G-code is just coordinate lists. Side projections (XZ or YZ) reveal embossed/engraved text.

---

## Uncommon File Magic Bytes

| Magic | Format | Extension | Notes |
|-------|--------|-----------|-------|
| `GCDE` | PrusaSlicer binary G-code | `.g`, `.bgcode` | 3D printing, heatshrink compressed |
| `qoif` | Quite OK Image Format | `.qoi` | Lightweight image format, often embedded |
| `OggS` | Ogg container | `.ogg` | Audio/video |
| `RIFF` | RIFF container | `.wav`,`.avi` | Check subformat |
| `%PDF` | PDF | `.pdf` | Check metadata & embedded objects |
