#!/usr/bin/env sh
set -eu

INSTALL_DIR="${1:-/opt/sail-riscv}"
RELEASE="${SAIL_RISCV_RELEASE:-0.11}"

mkdir -p "$INSTALL_DIR"
curl --location "https://github.com/riscv/sail-riscv/releases/download/${RELEASE}/sail-riscv-$(uname)-$(arch).tar.gz" \
    | tar xvz --directory="$INSTALL_DIR" --strip-components=1

printf '\nadd this to PATH:\n'
printf 'export PATH=%s/bin:$PATH\n' "$INSTALL_DIR"
