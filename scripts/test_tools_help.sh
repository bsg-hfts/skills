#!/usr/bin/env bash
set -uo pipefail

# Smoke-test tool availability.
# - CLI tools: run with --help (fallback -h) to verify they are callable.
# - Python libraries without CLI: verify import in the shared venv.

HELP_TIMEOUT="${HELP_TIMEOUT:-8}"
PYTHON_BIN="${PYTHON_BIN:-/opt/ctf-tools/venv/bin/python}"

OK=0
MISSING=0
WARN=0
FAIL=0

print_ok() { printf "[OK] %s\n" "$1"; OK=$((OK + 1)); }
print_missing() { printf "[MISSING] %s\n" "$1"; MISSING=$((MISSING + 1)); }
print_warn() { printf "[WARN] %s\n" "$1"; WARN=$((WARN + 1)); }
print_fail() { printf "[FAIL] %s\n" "$1"; FAIL=$((FAIL + 1)); }

run_help_check() {
  local label="$1"
  local cmd="$2"
  local tmp
  local rc=0

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
    print_warn "$label ($cmd timed out with --help/-h; command exists)"
  elif [[ -s "$tmp" ]]; then
    # Many tools print usage and still exit non-zero.
    print_warn "$label ($cmd responded but returned non-zero)"
  else
    print_fail "$label ($cmd did not respond to help flags)"
  fi

  rm -f "$tmp"
}

run_any_help_check() {
  local label="$1"
  shift
  local candidate

  for candidate in "$@"; do
    if command -v "$candidate" >/dev/null 2>&1; then
      run_help_check "$label" "$candidate"
      return
    fi
  done

  print_missing "$label (none of: $*)"
}

run_python_import_check() {
  local module="$1"
  if [[ ! -x "$PYTHON_BIN" ]]; then
    print_missing "python-import:$module (python not found at $PYTHON_BIN)"
    return
  fi

  "$PYTHON_BIN" -c "import $module" >/dev/null 2>&1
  if [[ $? -eq 0 ]]; then
    print_ok "python-import:$module"
  else
    print_fail "python-import:$module"
  fi
}

echo "=== CLI tools (--help smoke test) ==="

run_help_check "python3" "python3"
run_help_check "pip3" "pip3"
run_help_check "gdb" "gdb"
run_any_help_check "r2/rz" "r2" "rz"
run_help_check "objdump" "objdump"
run_help_check "binwalk" "binwalk"
run_help_check "exiftool" "exiftool"
run_help_check "tshark" "tshark"
run_help_check "ffmpeg" "ffmpeg"
run_help_check "steghide" "steghide"
run_help_check "testdisk" "testdisk"
run_help_check "john" "john"
run_help_check "nmap" "nmap"
run_help_check "whois" "whois"
run_help_check "dig" "dig"
run_help_check "hashcat" "hashcat"
run_help_check "strace" "strace"
run_help_check "ltrace" "ltrace"
run_help_check "convert" "convert"
run_help_check "apktool" "apktool"
run_any_help_check "upx/upx-ucl" "upx" "upx-ucl"
run_help_check "qemu-system-x86_64" "qemu-system-x86_64"
run_help_check "sage" "sage"
run_help_check "qrencode" "qrencode"
run_help_check "ffuf" "ffuf"
run_help_check "one_gadget" "one_gadget"
run_help_check "seccomp-tools" "seccomp-tools"
run_help_check "zsteg" "zsteg"

# CLI tools provided by some pip packages.
run_help_check "pwn (pwntools)" "pwn"
run_help_check "flask-unsign" "flask-unsign"
run_help_check "sqlmap" "sqlmap"
run_help_check "ropper" "ropper"
run_help_check "ROPgadget" "ROPgadget"
run_help_check "vol (volatility3)" "vol"

echo ""
echo "=== Python modules (import smoke test) ==="

run_python_import_check "Crypto"
run_python_import_check "z3"
run_python_import_check "sympy"
run_python_import_check "gmpy2"
run_python_import_check "hashpumpy"
run_python_import_check "fpylll"
run_python_import_check "py_ecc"
run_python_import_check "angr"
run_python_import_check "frida"
run_python_import_check "qiling"
run_python_import_check "requests"
run_python_import_check "volatility3"
run_python_import_check "yara"
run_python_import_check "pefile"
run_python_import_check "capstone"
run_python_import_check "oletools"
run_python_import_check "unicorn"
run_python_import_check "scapy"
run_python_import_check "PIL"
run_python_import_check "numpy"
run_python_import_check "matplotlib"
run_python_import_check "shodan"
run_python_import_check "uncompyle6"
run_python_import_check "lief"
run_python_import_check "dns"
run_python_import_check "dnslib"
run_python_import_check "dissect.cobaltstrike"

echo ""
echo "=== Summary ==="
echo "OK:      $OK"
echo "WARN:    $WARN"
echo "MISSING: $MISSING"
echo "FAIL:    $FAIL"

if [[ $FAIL -gt 0 || $MISSING -gt 0 ]]; then
  exit 1
fi

exit 0
