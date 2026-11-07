#!/usr/bin/env bash
# Print every installed package (apk + Python) in an image, one per line, sorted.
# Two images with the same output have the same software, whatever their digests.
#   package-manifest.sh <image-ref>
set -euo pipefail
docker run --rm --entrypoint sh "${1:?image}" -c '
    apk info -v 2>/dev/null | sed "s/^/apk /"
    python3 -c "import importlib.metadata as m; [print(\"py\", d.metadata[\"Name\"].lower() + \"-\" + d.version) for d in m.distributions()]"
' | sort -u
