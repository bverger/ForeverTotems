#!/bin/bash
# Copies the addon into the game folder so you can /reload and test it.
set -e
here="$(cd "$(dirname "$0")" && pwd)"
target="/mnt/c/Program Files (x86)/World of Warcraft/_classic_beta_/Interface/AddOns/ForeverTotems"
mkdir -p "$target"
cp "$here/ForeverTotems/"*.lua "$here/ForeverTotems/"*.toc "$here/ForeverTotems/README.txt" "$target/"
echo "Copiado a $target"
