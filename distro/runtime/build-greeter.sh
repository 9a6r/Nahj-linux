#!/usr/bin/env bash
# Build the original greeter using the payload's fonts, not the builder's defaults.
set -euo pipefail
payload=$(realpath -e "${1:?payload directory required}")
out=${2:?output directory required}
repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
fontconfig=$(mktemp -d)
trap 'rm -rf "$fontconfig"' EXIT
python3 - "$payload" "$fontconfig" <<'PY'
from pathlib import Path
import sys
import xml.etree.ElementTree as ET
root = ET.Element('fontconfig')
ET.SubElement(root, 'dir').text = str(Path(sys.argv[1]) / 'usr/share/fonts')
ET.SubElement(root, 'cachedir').text = str(Path(sys.argv[2]) / 'cache')
ET.ElementTree(root).write(Path(sys.argv[2]) / 'fonts.conf', encoding='utf-8', xml_declaration=True)
PY
export FONTCONFIG_FILE="$fontconfig/fonts.conf"
[[ $(fc-match -f '%{family}' 'Space Grotesk') == *'Space Grotesk'* ]] || {
    echo 'Required Space Grotesk font missing from the image payload.' >&2; exit 1;
}
bash "$repo/sddm/build-assets.sh" "$out"
