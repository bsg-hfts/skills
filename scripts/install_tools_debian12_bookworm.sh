#!/usr/bin/env bash
set -euo pipefail

# One-shot installer for tools referenced by scripts in this repository.
# Target OS: Debian 12 (Bookworm)

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root (sudo bash scripts/install_tools_debian12_bookworm.sh)" >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

APT_MISSING=()
PIP_FAILED=()
GEM_FAILED=()

APT_PACKAGES=(
  python3 python3-venv python3-pip python3-dev build-essential
  git curl wget ca-certificates jq
  ruby ruby-dev
  gdb binutils binwalk foremost libimage-exiftool-perl
  tshark sleuthkit ffmpeg steghide testdisk john pcapfix
  nmap whois dnsutils hashcat strace ltrace imagemagick
  apktool qemu-system-x86 sagemath qrencode
  ffuf
  libgmp-dev libmpc-dev libmpfr-dev
  libffi-dev libssl-dev
)

PIP_PACKAGES=(
  "pwntools==4.15.0"
  "pycryptodome==3.23.0"
  "z3-solver==4.13.0.0"
  "sympy==1.14.0"
  "gmpy2==2.3.0"
  "hashpumpy==1.2"
  "fpylll==0.6.4"
  "py_ecc==8.0.0"
  "angr==9.2.193"
  "frida-tools==14.8.0"
  "qiling==1.4.6"
  "requests==2.32.5"
  "flask-unsign==1.2.1"
  "sqlmap==1.10.3"
  "ropper==1.13.13"
  "ROPgadget==7.7"
  "volatility3==2.27.0"
  "yara-python==4.5.4"
  "pefile==2024.8.26"
  "capstone==5.0.3"
  "oletools==0.60.2"
  "unicorn==2.1.2"
  "scapy==2.7.0"
  "Pillow==11.3.0"
  "numpy==2.2.6"
  "matplotlib==3.10.8"
  "shodan==1.31.0"
  "uncompyle6==3.9.3"
  "lief==0.17.6"
  "dnspython==2.8.0"
  "dnslib==0.9.26"
  "dissect.cobaltstrike==1.2.1"
)

GEM_PACKAGES=(
  one_gadget
  seccomp-tools
  zsteg
)

GLOBAL_VENV="/opt/ctf-tools/venv"
PROFILED_PATH_FILE="/etc/profile.d/ctf-tools-path.sh"
BASHRC_GLOBAL="/etc/bash.bashrc"

echo "[1/6] apt update"
apt-get update -y

echo "[2/6] apt install (${#APT_PACKAGES[@]} packages)"
APT_AVAILABLE=()

apt_has_candidate() {
  local pkg="$1"
  local candidate
  candidate="$(apt-cache policy "$pkg" 2>/dev/null | awk -F': ' '/Candidate:/ {print $2; exit}')"
  [[ -n "$candidate" && "$candidate" != "(none)" ]]
}

for pkg in "${APT_PACKAGES[@]}"; do
  if apt_has_candidate "$pkg"; then
    APT_AVAILABLE+=("$pkg")
  else
    APT_MISSING+=("$pkg")
  fi
done

# Kali/Bookworm compatibility fallbacks.
if apt_has_candidate "radare2"; then
  APT_AVAILABLE+=("radare2")
elif apt_has_candidate "rizin"; then
  APT_AVAILABLE+=("rizin")
else
  APT_MISSING+=("radare2" "rizin")
fi

if apt_has_candidate "upx"; then
  APT_AVAILABLE+=("upx")
elif apt_has_candidate "upx-ucl"; then
  APT_AVAILABLE+=("upx-ucl")
else
  APT_MISSING+=("upx" "upx-ucl")
fi

if [[ ${#APT_AVAILABLE[@]} -gt 0 ]]; then
  apt-get install -y --no-install-recommends "${APT_AVAILABLE[@]}"
fi

echo "[3/6] python virtualenv and pip tools"
python3 -m venv "$GLOBAL_VENV"
"$GLOBAL_VENV/bin/python" -m pip install --upgrade pip setuptools wheel
for pkg in "${PIP_PACKAGES[@]}"; do
  if ! "$GLOBAL_VENV/bin/python" -m pip install "$pkg"; then
    PIP_FAILED+=("$pkg")
  fi
done

echo "[4/6] ruby gems"
for gem_pkg in "${GEM_PACKAGES[@]}"; do
  if ! gem install "$gem_pkg" --no-document --bindir /usr/local/bin; then
    GEM_FAILED+=("$gem_pkg")
  fi
done

echo "[5/6] PATH for all bash/SSH sessions"
cat > "$PROFILED_PATH_FILE" <<'EOF'
# Added by scripts/install_tools_debian12_bookworm.sh
# Make CTF tooling available for all users in login shells (including SSH).
ctf_path_prepend() {
  case ":$PATH:" in
    *":$1:"*) ;;
    *) PATH="$1:$PATH" ;;
  esac
}

ctf_path_prepend /usr/local/bin
ctf_path_prepend /opt/ctf-tools/venv/bin
ctf_path_prepend "$HOME/.local/bin"
ctf_path_prepend "$HOME/go/bin"
export PATH

unset -f ctf_path_prepend
EOF
chmod 644 "$PROFILED_PATH_FILE"

# Ensure interactive non-login bash shells also get the profile.d PATH.
if ! grep -q "ctf-tools-path.sh" "$BASHRC_GLOBAL"; then
  {
    echo ""
    echo "# Added by scripts/install_tools_debian12_bookworm.sh"
    echo "if [ -f /etc/profile.d/ctf-tools-path.sh ]; then"
    echo "  . /etc/profile.d/ctf-tools-path.sh"
    echo "fi"
  } >> "$BASHRC_GLOBAL"
fi

echo "[6/6] quick verification"
check_cmd() {
  local name="$1"
  if command -v "$name" >/dev/null 2>&1; then
    printf "  [OK] %s -> %s\n" "$name" "$(command -v "$name")"
  else
    printf "  [MISSING] %s\n" "$name"
  fi
}

check_any_cmd() {
  local label="$1"
  shift
  local alt
  for alt in "$@"; do
    if command -v "$alt" >/dev/null 2>&1; then
      printf "  [OK] %s -> %s\n" "$label" "$(command -v "$alt")"
      return 0
    fi
  done
  printf "  [MISSING] %s\n" "$label"
}

check_cmd python3
check_cmd pip3
check_cmd gdb
check_any_cmd "r2/rz" r2 rz
check_cmd objdump
check_cmd binwalk
check_cmd exiftool
check_cmd tshark
check_cmd ffmpeg
check_cmd steghide
check_cmd testdisk
check_cmd john
check_cmd nmap
check_cmd whois
check_cmd dig
check_cmd hashcat
check_cmd strace
check_cmd ltrace
check_cmd convert
check_cmd apktool
check_any_cmd "upx/upx-ucl" upx upx-ucl
check_cmd qemu-system-x86_64
check_cmd sage
check_cmd qrencode
check_cmd ffuf
check_cmd one_gadget
check_cmd seccomp-tools
check_cmd zsteg

echo ""
if [[ ${#APT_MISSING[@]} -gt 0 ]]; then
  echo "APT packages not available in this repo:"
  printf "  - %s\n" "${APT_MISSING[@]}"
  echo ""
fi

if [[ ${#PIP_FAILED[@]} -gt 0 ]]; then
  echo "Pip packages failed to install:"
  printf "  - %s\n" "${PIP_FAILED[@]}"
  echo ""
fi

if [[ ${#GEM_FAILED[@]} -gt 0 ]]; then
  echo "Ruby gems failed to install:"
  printf "  - %s\n" "${GEM_FAILED[@]}"
  echo ""
fi

echo "Install complete."
echo "For current shell: source /etc/profile.d/ctf-tools-path.sh"
echo "For new SSH sessions: PATH is loaded automatically."
