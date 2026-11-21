#!/usr/bin/env bash
#
# Author: Andrea Giachero <Andrea.Giachero@mib.infn.it>
# Date  : 09 Agosto 2010 (revised 2026)
# Desc  : Copy the scripts in scripts/ to a bin directory, removing the
#         .sh extension (fanreport.sh -> fanreport).
#
# Usage : ./install.sh [DEST]     (default DEST: ~/.local/bin)

set -euo pipefail

SRC=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/scripts
#DEST=${1:-$HOME/.local/bin}
DEST=${1:-$HOME/bin}

mkdir -p -- "$DEST"

for script in "$SRC"/*.sh; do
    [[ -f $script ]] || continue
    name=$(basename -- "$script" .sh)
    echo " Installing $name in $DEST"
    install -m 755 -- "$script" "$DEST/$name"
done
