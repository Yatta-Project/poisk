#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DIST_DIR="${ROOT_DIR}/dist"

VERSION="1.1.0"

echo "=== Poisk Package Builder ==="
mkdir -p "${DIST_DIR}"

# 1. Package GNOME Shell Extension
echo "-> Packaging GNOME Shell extension..."
(
    cd "${ROOT_DIR}/data/gnome-shell-extension"
    zip -FS -r "${DIST_DIR}/poisk-blur@mrlogiousbanana.github.io.zip" . -x "*.git*"
)
echo "   Saved: ${DIST_DIR}/poisk-blur@mrlogiousbanana.github.io.zip"

# 2. Source tarball
echo "-> Creating source tarball (poisk-${VERSION}.tar.gz)..."
tar -czf "${DIST_DIR}/poisk-${VERSION}.tar.gz" \
    --exclude-vcs \
    --exclude="build*" \
    --exclude="dist" \
    --exclude="result*" \
    --exclude="*.p" \
    --transform "s,^,poisk-${VERSION}/," \
    -C "${ROOT_DIR}" .
echo "   Saved: ${DIST_DIR}/poisk-${VERSION}.tar.gz"

echo "=== Packaging complete! Output files in ${DIST_DIR} ==="
ls -lh "${DIST_DIR}"
