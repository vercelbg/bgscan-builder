#!/usr/bin/env bash
# ==============================================================================
# bgscan-builder release generator
# ==============================================================================
#
# ⚠️ IMPORTANT:
#   This script is designed ONLY for GitHub Actions (CI/CD).
#   Do NOT run manually in production or local environments.
#
# PURPOSE:
#   - Reads compiled binaries from ./dist
#   - Generates SHA256 checksums
#   - Builds GitHub-ready release notes (Markdown)
#   - Normalizes platform + architecture naming
#
# OUTPUT:
#   ./release/
#     ├── checksum.txt
#     └── release_notes.md
#
# ==============================================================================

set -euo pipefail

# ==============================================================================
# INPUT VALIDATION
# ==============================================================================
if [ -z "${1:-}" ]; then
  echo "Usage: $0 <tag_version>"
  exit 1
fi

TAG_VERSION="$1"

ROOT_DIR="$PWD"
DIST_DIR="$ROOT_DIR/dist"
RELEASE_DIR="$ROOT_DIR/release"

CHECKSUM_FILE="$RELEASE_DIR/checksum.txt"
NOTES_FILE="$RELEASE_DIR/release_notes.md"

REPO_URL="${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY:-user/repo}"

mkdir -p "$RELEASE_DIR"

# ==============================================================================
# LOGGER
# ==============================================================================
log() {
  echo
  echo "===================================================="
  echo "$*"
  echo "===================================================="
}

# ==============================================================================
# PLATFORM / ARCH MAPPING (SOURCE OF TRUTH)
# ==============================================================================
declare -A OS_MAP=(
  ["linux"]="🐧 Linux"
  ["windows"]="🪟 Windows"
  ["android"]="🤖 Android"
  ["macos"]="🍏 macOS"
)

declare -A ARCH_MAP=(
  # Linux
  ["linux-amd64"]="AMD64 / Intel x64"
  ["linux-arm64"]="ARM64"
  ["linux-arm32-v7a"]="ARM32 (ARMv7)"
  ["linux-386"]="x86 / 32-bit"

  # Windows
  ["windows-64"]="AMD64 / Intel x64"
  ["windows-arm64"]="ARM64"

  # Android
  ["android-arm64-v8a"]="ARM64 / ARM64-v8a"
  ["android-armeabi-v7a"]="ARM32 (armeabi-v7a)"
  ["android-x86"]="x86 / 32-bit"
  ["android-x86_64"]="AMD64 / Intel x64"

  # macOS
  ["macos-arm64"]="ARM64 / Apple Silicon"
  ["macos-64"]="AMD64 / Intel x64"
)

# ==============================================================================
# VALIDATION
# ==============================================================================
log "Checking dist directory"

if [ ! -d "$DIST_DIR" ] || [ -z "$(ls -A "$DIST_DIR")" ]; then
  echo "ERROR: dist/ is empty"
  exit 1
fi

# ==============================================================================
# CHECKSUM GENERATION
# ==============================================================================
log "Generating checksum file"

: >"$CHECKSUM_FILE"
cd "$DIST_DIR"

FILES=()

for file in *; do
  [ -f "$file" ] || continue
  sha256sum "$file" >>"$CHECKSUM_FILE"
  FILES+=("$file")
done

# ==============================================================================
# RELEASE NOTES GENERATION
# ==============================================================================
log "Generating release notes"

: >"$NOTES_FILE"

cat <<EOF >>"$NOTES_FILE"
# 🚀 bgscan-builder Release $TAG_VERSION

Automated multi-platform build artifacts generated via GitHub Actions.

All binaries are raw executables (no compression).

---

## 📦 Download Table

| 🌍 Platform | 🧬 Architecture | 📥 Download |
|------------|----------------|------------|
EOF

# ==============================================================================
# TABLE GENERATION
# ==============================================================================
for file in "${FILES[@]}"; do

  # remove "bgscan-" prefix
  key="${file#bgscan-}"

  OS_KEY="${key%%-*}"
  ARCH_KEY="$key"

  OS_NAME="${OS_MAP[$OS_KEY]}"
  ARCH_NAME="${ARCH_MAP[$ARCH_KEY]}"

  [ -z "$OS_NAME" ] && OS_NAME="❓ Unknown"
  [ -z "$ARCH_NAME" ] && ARCH_NAME="$ARCH_KEY"

  LINK="[$file]($REPO_URL/releases/download/$TAG_VERSION/$file)"

  echo "| $OS_NAME | $ARCH_NAME | $LINK |" >>"$NOTES_FILE"

done

# ==============================================================================
# CHECKSUM TABLE (CLEAN FORMAT)
# ==============================================================================
cat <<EOF >>"$NOTES_FILE"

---

## 🔐 SHA256 Checksums

| File | SHA256 |
|------|--------|
EOF

while read -r hash file; do
  echo "| $file | $hash |" >>"$NOTES_FILE"
done <"$CHECKSUM_FILE"

# ==============================================================================
# FOOTER
# ==============================================================================
cat <<EOF >>"$NOTES_FILE"

---

## ⚙️ Build Info

- Project: bgscan-builder
- Version: $TAG_VERSION
- Pipeline: GitHub Actions CI
EOF

# ==============================================================================
log "DONE"
echo "Release generated in: $RELEASE_DIR"
ls -lh "$RELEASE_DIR"
