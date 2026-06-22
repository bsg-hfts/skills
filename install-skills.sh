#!/usr/bin/env bash
# install-skills.sh
# Removes old skill folders from ~/.hermes/skills and installs
# all skill folders from this repo.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HERMES_SKILLS="${HOME}/.hermes/skills"

SKILL_FOLDERS=(
  ctf-ai-ml
  ctf-crypto
  ctf-forensics
  ctf-malware
  ctf-misc
  ctf-osint
  ctf-pwn
  ctf-reverse
  ctf-web
  ctf-writeup
  readme
  security
  solve-challenge
)

echo "[*] Target directory: ${HERMES_SKILLS}"
mkdir -p "${HERMES_SKILLS}"

echo "[*] Removing old skill folders..."
for folder in "${SKILL_FOLDERS[@]}"; do
  target="${HERMES_SKILLS}/${folder}"
  if [ -d "${target}" ]; then
    rm -rf "${target}"
    echo "    removed: ${folder}"
  fi
done

echo "[*] Installing skill folders..."
for folder in "${SKILL_FOLDERS[@]}"; do
  src="${REPO_ROOT}/${folder}"
  if [ -d "${src}" ]; then
    cp -r "${src}" "${HERMES_SKILLS}/${folder}"
    echo "    installed: ${folder}"
  else
    echo "    [WARN] source not found, skipping: ${folder}"
  fi
done

echo "[+] Done. Skills installed to: ${HERMES_SKILLS}"
