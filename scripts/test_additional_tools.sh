#!/usr/bin/env bash
set -uo pipefail

# Additional tools smoke test.
# Validates availability of tools installed by install_additional_tools.sh.

export PATH="/usr/sbin:/usr/local/bin:${PATH}"

HELP_TIMEOUT="${HELP_TIMEOUT:-10}"
VENV_PY="${VENV_PY:-/opt/ctf-tools/venv/bin/python}"

OK=0
WARN=0
MISSING=0
FAIL=0

print_ok() { printf "[OK] %s\n" "$1"; OK=$((OK + 1)); }
print_warn() { printf "[WARN] %s\n" "$1"; WARN=$((WARN + 1)); }
print_missing() { printf "[MISSING] %s\n" "$1"; MISSING=$((MISSING + 1)); }
print_fail() { printf "[FAIL] %s\n" "$1"; FAIL=$((FAIL + 1)); }

help_check() {
  local label="$1"
  local cmd="$2"
  local tmp
  local rc

  if ! command -v "$cmd" >/dev/null 2>&1; then
    print_missing "$label ($cmd not in PATH)"
    return
  fi

  tmp="$(mktemp)"
  timeout "$HELP_TIMEOUT" "$cmd" --help >"$tmp" 2>&1
  rc=$?
  if [[ $rc -eq 0 ]]; then
    print_ok "$label ($cmd --help)"
    rm -f "$tmp"
    return
  fi

  timeout "$HELP_TIMEOUT" "$cmd" -h >"$tmp" 2>&1
  rc=$?
  if [[ $rc -eq 0 ]]; then
    print_ok "$label ($cmd -h)"
  elif [[ $rc -eq 124 ]]; then
    print_warn "$label ($cmd help timed out; binary exists)"
  elif [[ -s "$tmp" ]]; then
    print_warn "$label ($cmd responded but returned non-zero)"
  else
    print_fail "$label ($cmd did not respond to help flags)"
  fi

  rm -f "$tmp"
}

echo "=== Additional CLI tools ==="
help_check "nikto" "nikto"
help_check "whatweb" "whatweb"
help_check "wafw00f" "wafw00f"
help_check "gobuster" "gobuster"
help_check "ffuf" "ffuf"
help_check "nuclei" "nuclei"

echo ""
echo "=== XSStrike ==="
if [[ -f /opt/XSStrike/xsstrike.py ]]; then
  if [[ -x "$VENV_PY" ]]; then
    timeout "$HELP_TIMEOUT" "$VENV_PY" /opt/XSStrike/xsstrike.py --help >/dev/null 2>&1
    case $? in
      0) print_ok "XSStrike (/opt/XSStrike/xsstrike.py --help)" ;;
      124) print_warn "XSStrike help timed out; script exists" ;;
      *) print_warn "XSStrike exists but help returned non-zero" ;;
    esac
  else
    print_warn "XSStrike present but venv python missing at $VENV_PY"
  fi
else
  print_missing "XSStrike (/opt/XSStrike/xsstrike.py)"
fi

echo ""
echo "=== Playwright + Chromium ==="
if [[ ! -x "$VENV_PY" ]]; then
  print_missing "venv python ($VENV_PY)"
else
  "$VENV_PY" -m playwright --help >/dev/null 2>&1
  if [[ $? -eq 0 ]]; then
    print_ok "playwright module"
  else
    print_fail "playwright module"
  fi

  CHROMIUM_PATH="$($VENV_PY - <<'PY'
from pathlib import Path
try:
    from playwright.sync_api import sync_playwright
    p = sync_playwright().start()
    path = Path(p.chromium.executable_path)
    print(path)
    p.stop()
except Exception:
    print("")
PY
)"

  if [[ -n "$CHROMIUM_PATH" && -x "$CHROMIUM_PATH" ]]; then
    print_ok "playwright chromium binary ($CHROMIUM_PATH)"
  elif [[ -n "$CHROMIUM_PATH" ]]; then
    print_warn "playwright chromium path found but not executable ($CHROMIUM_PATH)"
  else
    print_fail "playwright chromium binary not found"
  fi
fi

echo ""
echo "=== Summary ==="
echo "OK:      $OK"
echo "WARN:    $WARN"
echo "MISSING: $MISSING"
echo "FAIL:    $FAIL"

if [[ $MISSING -gt 0 || $FAIL -gt 0 ]]; then
  exit 1
fi

exit 0
