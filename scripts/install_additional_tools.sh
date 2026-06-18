#!/usr/bin/env bash
set -euo pipefail

# Additional tooling installer (Kali/Debian Bookworm friendly)
# Installs:
# - nikto, whatweb, wafw00f, gobuster
# - nuclei (+ templates)
# - XSStrike
# - Playwright + Chromium (+ deps)

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root: sudo bash install_additional_tools.sh" >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
export PATH="/usr/sbin:/usr/local/bin:${PATH}"

BASE_APT=(
  git curl jq
  python3 python3-pip python3-venv python3-dev
  build-essential pkg-config
  libffi-dev libssl-dev
  nikto whatweb wafw00f gobuster ffuf
)

MISSING_APT=()
AVAILABLE_APT=()

apt_has_candidate() {
  local pkg="$1"
  local candidate
  candidate="$(apt-cache policy "$pkg" 2>/dev/null | awk -F': ' '/Candidate:/ {print $2; exit}')"
  [[ -n "$candidate" && "$candidate" != "(none)" ]]
}

echo "[1/7] apt update"
apt-get update -y

echo "[2/7] install base apt tools"
for pkg in "${BASE_APT[@]}"; do
  if apt_has_candidate "$pkg"; then
    AVAILABLE_APT+=("$pkg")
  else
    MISSING_APT+=("$pkg")
  fi
done

if [[ ${#AVAILABLE_APT[@]} -gt 0 ]]; then
  apt-get install -y --no-install-recommends "${AVAILABLE_APT[@]}"
fi

echo "[3/7] install Go if needed (for nuclei)"
if ! command -v go >/dev/null 2>&1; then
  if apt_has_candidate golang-go; then
    apt-get install -y --no-install-recommends golang-go
  else
    echo "golang-go is not available in current repos; nuclei install will be skipped" >&2
  fi
fi

echo "[4/7] install nuclei"
if command -v go >/dev/null 2>&1; then
  # Install globally so SSH sessions/users can run nuclei without extra PATH tweaks.
  GOBIN=/usr/local/bin go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest || true
  if command -v nuclei >/dev/null 2>&1; then
    nuclei -update-templates || true
  fi
else
  echo "Skipping nuclei: go not available"
fi

echo "[5/7] install XSStrike"
if [[ ! -d /opt/XSStrike/.git ]]; then
  rm -rf /opt/XSStrike
  git clone https://github.com/s0md3v/XSStrike.git /opt/XSStrike
else
  git -C /opt/XSStrike pull --ff-only || true
fi

echo "[6/7] install Python deps for XSStrike + Playwright"
if [[ ! -d /opt/ctf-tools/venv ]]; then
  python3 -m venv /opt/ctf-tools/venv
fi

VENV_PY="/opt/ctf-tools/venv/bin/python"
"$VENV_PY" -m pip install --upgrade pip setuptools wheel
"$VENV_PY" -m pip install -r /opt/XSStrike/requirements.txt
"$VENV_PY" -m pip install playwright
"$VENV_PY" -m playwright install chromium
"$VENV_PY" -m playwright install-deps chromium || true

echo "[7/7] quick verification"
check_cmd() {
  local name="$1"
  if command -v "$name" >/dev/null 2>&1; then
    printf "  [OK] %s -> %s\n" "$name" "$(command -v "$name")"
  else
    printf "  [MISSING] %s\n" "$name"
  fi
}

check_cmd nikto
check_cmd whatweb
check_cmd wafw00f
check_cmd gobuster
check_cmd ffuf
check_cmd nuclei

if [[ -f /opt/XSStrike/xsstrike.py ]]; then
  echo "  [OK] XSStrike -> /opt/XSStrike/xsstrike.py"
else
  echo "  [MISSING] XSStrike"
fi

if "$VENV_PY" -m playwright --help >/dev/null 2>&1; then
  echo "  [OK] playwright (python module in /opt/ctf-tools/venv)"
else
  echo "  [MISSING] playwright"
fi

echo ""
if [[ ${#MISSING_APT[@]} -gt 0 ]]; then
  echo "APT packages not available in this repo:"
  printf "  - %s\n" "${MISSING_APT[@]}"
  echo ""
fi

echo "Done."
echo "If needed in this shell: source /etc/profile.d/ctf-tools-path.sh"
