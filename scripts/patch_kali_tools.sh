#!/usr/bin/env bash
set -euo pipefail

# One-shot patch script for post-install fixes on Kali/Debian Bookworm.
# Fixes:
# - Ensure /usr/sbin is available in all shells (john path issue)
# - Install build deps needed by failed Python packages
# - Retry failed Python modules in the shared venv
# - Optionally install rizin if available (r2/rz gap)

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root: sudo bash patch_kali_tools.sh" >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
export PATH="/usr/sbin:${PATH}"

VENV_PY="/opt/ctf-tools/venv/bin/python"
PROFILE_SNIPPET="/etc/profile.d/ctf-tools-path.sh"
BASHRC_GLOBAL="/etc/bash.bashrc"

echo "[1/6] Ensure /usr/sbin is in PATH for all users"
if [[ ! -f "$PROFILE_SNIPPET" ]]; then
  cat > "$PROFILE_SNIPPET" <<'EOF'
# Added by patch_kali_tools.sh
ctf_path_prepend() {
  case ":$PATH:" in
    *":$1:"*) ;;
    *) PATH="$1:$PATH" ;;
  esac
}

ctf_path_prepend /usr/sbin
ctf_path_prepend /usr/local/bin
ctf_path_prepend /opt/ctf-tools/venv/bin
ctf_path_prepend "$HOME/.local/bin"
ctf_path_prepend "$HOME/go/bin"
export PATH

unset -f ctf_path_prepend
EOF
  chmod 644 "$PROFILE_SNIPPET"
else
  if ! grep -q '/usr/sbin' "$PROFILE_SNIPPET"; then
    awk '
      /ctf_path_prepend \/usr\/local\/bin/ && !done {
        print "ctf_path_prepend /usr/sbin";
        done=1
      }
      { print }
    ' "$PROFILE_SNIPPET" > "${PROFILE_SNIPPET}.tmp"
    mv "${PROFILE_SNIPPET}.tmp" "$PROFILE_SNIPPET"
    chmod 644 "$PROFILE_SNIPPET"
  fi
fi

# Ensure interactive non-login bash shells also load profile.d snippet.
if ! grep -q "ctf-tools-path.sh" "$BASHRC_GLOBAL"; then
  {
    echo ""
    echo "# Added by patch_kali_tools.sh"
    echo "if [ -f /etc/profile.d/ctf-tools-path.sh ]; then"
    echo "  . /etc/profile.d/ctf-tools-path.sh"
    echo "fi"
  } >> "$BASHRC_GLOBAL"
fi

# Apply path changes in current run too.
if [[ -f "$PROFILE_SNIPPET" ]]; then
  # shellcheck disable=SC1090
  source "$PROFILE_SNIPPET"
fi

echo "[2/6] Install apt build dependencies for failed Python modules"
apt-get update -y
apt-get install -y --no-install-recommends \
  python3-dev build-essential pkg-config \
  libffi-dev libssl-dev \
  libgmp-dev libmpfr-dev libmpc-dev \
  libfplll-dev libntl-dev

echo "[3/6] Optional reverse tool fallback (rizin)"
if apt-cache policy rizin 2>/dev/null | awk -F': ' '/Candidate:/ {exit ($2=="(none)") ? 1 : 0}'; then
  if ! apt-get install -y --no-install-recommends rizin; then
    echo "rizin candidate exists but install failed; continuing"
  fi
else
  echo "rizin not available in current repos; skipping"
fi

echo "[4/6] Retry Python modules in shared venv"
if [[ ! -x "$VENV_PY" ]]; then
  echo "Shared venv not found at $VENV_PY" >&2
  echo "Run the main installer first." >&2
  exit 2
fi

"$VENV_PY" -m pip install --upgrade pip setuptools wheel

# Retry commonly failing modules from previous run.
RETRY_PKGS=(
  "unicorn==2.1.2"
  "cysignals"
  "fpylll==0.6.4"
  "qiling==1.4.6"
  "angr==9.2.193"
)

PIP_RETRY_FAIL=()
for pkg in "${RETRY_PKGS[@]}"; do
  if ! "$VENV_PY" -m pip install --force-reinstall "$pkg"; then
    PIP_RETRY_FAIL+=("$pkg")
  fi
done

echo "[5/6] Quick checks"
if command -v john >/dev/null 2>&1; then
  echo "[OK] john -> $(command -v john)"
elif [[ -x /usr/sbin/john ]]; then
  echo "[WARN] john exists at /usr/sbin/john (open new shell or source profile snippet)"
else
  echo "[MISSING] john"
fi

if command -v r2 >/dev/null 2>&1; then
  echo "[OK] r2 -> $(command -v r2)"
elif command -v rz >/dev/null 2>&1; then
  echo "[OK] rz -> $(command -v rz)"
else
  echo "[MISSING] r2/rz"
fi

echo "[6/6] Summary"
if [[ ${#PIP_RETRY_FAIL[@]} -gt 0 ]]; then
  echo "Python packages still failing:"
  printf "  - %s\n" "${PIP_RETRY_FAIL[@]}"
else
  echo "All retried Python packages installed successfully."
fi

echo ""
echo "Apply PATH now in current shell:"
echo "  source /etc/profile.d/ctf-tools-path.sh"

if [[ -f ./test_tools.sh ]]; then
  echo ""
  echo "You can re-run smoke test now:"
  echo "  bash ./test_tools.sh"
fi
