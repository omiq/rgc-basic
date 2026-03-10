#!/bin/bash
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 <version>   (e.g. 0.1.0 or v0.1.0)"
  exit 1
fi

# Strip everything except digits and dots, so inputs like 'v0.1.0'
# or 'release-1.2' become '0.1.0' and '1.2' respectively.
RAW_VERSION="$1"
VERSION="$(printf '%s' "$RAW_VERSION" | tr -cd '0-9.')"

if [ -z "$VERSION" ]; then
  echo "Error: could not extract numeric version from '$RAW_VERSION'"
  exit 1
fi

# 1) Make sure main is up to date
git checkout main
git pull

# 2) Create an annotated tag
git tag -a "v$VERSION" -m "cbm-basic v$VERSION"

# 3) Push main and the tag to GitHub
git push
git push origin "v$VERSION"

# 4) GitHub Actions workflow will build artifacts and create a Release for v$VERSION
