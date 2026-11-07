#!/usr/bin/env bash
# Security checks for the image (or a running container).
#   security-check.sh image <image-ref>
#   security-check.sh container <container-name>
# Copies files out with `docker cp` and parses them on the host, so the image
# itself doesn't need openssl. Exits non-zero if any check fails.
set -euo pipefail

mode=${1:?image|container}; ref=${2:?image or container}
min_brotli="1.2.1"
bad_cns=("emSign ECC Root CA - G3" "AAA Certificate Services")
work=$(mktemp -d); trap 'rm -rf "$work"; [ -n "${cid:-}" ] && docker rm -f "$cid" >/dev/null 2>&1 || true' EXIT

if [ "$mode" = image ]; then
    cid=$(docker create "$ref"); src=$cid
else
    src=$ref
fi

fail=0
docker cp "$src:/lib/apk/db/installed" "$work/installed" >/dev/null
echo "== Alpine release: $(docker cp "$src:/etc/alpine-release" - | tar -xO)"

# Brotli (apk)
brotli=$(awk '/^P:brotli-libs$/{f=1} f&&/^V:/{print substr($0,3); exit}' "$work/installed")
echo "== brotli-libs: ${brotli:-not installed}"
if [ -n "$brotli" ]; then
    lowest=$(printf '%s\n%s\n' "$min_brotli" "${brotli%%-r*}" | sort -V | head -1)
    if [ "$lowest" != "$min_brotli" ]; then echo "   FAIL: < $min_brotli"; fail=1; else echo "   OK (>= $min_brotli)"; fi
fi

check_bundle() {
    local f=$1 label=$2 total n cn
    total=$(openssl crl2pkcs7 -nocrl -certfile "$f" | openssl pkcs7 -print_certs -noout | grep -c '^subject=' || true)
    echo "== $label: $total certificates"
    for cn in "${bad_cns[@]}"; do
        n=$(openssl crl2pkcs7 -nocrl -certfile "$f" | openssl pkcs7 -print_certs -noout \
            | grep '^subject=' | grep -Ec "CN ?= ?${cn}(,|$)" || true)
        if [ "$n" -eq 0 ]; then echo "   OK   0 x '$cn'"; else echo "   FAIL $n x '$cn'"; fail=1; fi
    done
}

docker cp -L "$src:/etc/ssl/certs/ca-certificates.crt" "$work/system.crt" >/dev/null
check_bundle "$work/system.crt" "/etc/ssl/certs/ca-certificates.crt"

# Every cacert.pem (certifi / pip vendored bundles) in the filesystem
docker export "$( [ "$mode" = image ] && echo "$cid" || echo "$src")" | tar -t 2>/dev/null \
    | grep -E '(^|/)cacert\.pem$' > "$work/pems" || true
echo "== cacert.pem files: $(wc -l < "$work/pems" | tr -d ' ')"
while read -r p; do
    [ -n "$p" ] || continue
    docker cp -L "$src:/$p" "$work/c.pem" >/dev/null
    check_bundle "$work/c.pem" "/$p"
done < "$work/pems"

# Python packages of interest
echo "== Python: certifi.where() / brotli"
docker cp "$src:/usr/lib" - 2>/dev/null | tar -t 2>/dev/null \
    | grep -Ei 'site-packages/(brotli|brotlicffi|certifi)[^/]*\.(dist|egg)-info/$' | sed 's,^,   ,' || true

[ "$fail" -eq 0 ] && echo "RESULT: PASS" || echo "RESULT: FAIL"
exit "$fail"
