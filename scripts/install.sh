#!/usr/bin/env bash
# Download, verify and install a Shoalcheck release. Used by action.yml and by test/selftest.sh.
# Env: VERSION (required, leading v accepted)  DEST (install dir, required)
#      SHOALCHECK_REPO (default Shoalcheck/shoalcheck)
# Verification order: cosign signature of checksums.txt (key pinned in this repo, cross-checked against the
# cosign.pub of the source repo at the same tag), then the archive's sha256. Nothing is installed on any failure.
set -euo pipefail
ver="${VERSION:?VERSION is required}"; ver="${ver#v}"
dest="${DEST:?DEST is required}"
repo="${SHOALCHECK_REPO:-Shoalcheck/shoalcheck}"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "$(uname -s)" in
  Linux) os=linux ;; Darwin) os=darwin ;; MINGW*|MSYS*|CYGWIN*) os=windows ;;
  *) echo "unsupported OS: $(uname -s)" >&2; exit 1 ;;
esac
case "$(uname -m)" in
  x86_64|amd64) arch=amd64 ;; arm64|aarch64) arch=arm64 ;;
  *) echo "unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac
if [ "$os" = windows ]; then ext=zip; bin=shoalcheck.exe; else ext=tar.gz; bin=shoalcheck; fi
archive="shoalcheck_${ver}_${os}_${arch}.${ext}"
base="https://github.com/$repo/releases/download/v$ver"

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
for f in "$archive" checksums.txt checksums.txt.sigstore.json; do
  curl -fsSL --retry 3 -o "$tmp/$f" "$base/$f"
done
curl -fsSL --retry 3 -o "$tmp/cosign.tag.pub" "https://raw.githubusercontent.com/$repo/v$ver/cosign.pub"
if ! diff -q <(tr -d '\r' < "$here/../cosign.pub") <(tr -d '\r' < "$tmp/cosign.tag.pub") >/dev/null; then
  echo "cosign.pub at $repo v$ver differs from the key pinned in this action; refusing" >&2; exit 1
fi

cosign verify-blob --key "$here/../cosign.pub" --bundle "$tmp/checksums.txt.sigstore.json" "$tmp/checksums.txt"
want="$(awk -v f="$archive" '$2==f {print $1}' "$tmp/checksums.txt")"
[ -n "$want" ] || { echo "checksums.txt has no entry for $archive" >&2; exit 1; }
if command -v sha256sum >/dev/null; then got="$(sha256sum "$tmp/$archive" | awk '{print $1}')"
else got="$(shasum -a 256 "$tmp/$archive" | awk '{print $1}')"; fi
[ "$want" = "$got" ] || { echo "sha256 mismatch for $archive: want $want got $got" >&2; exit 1; }

mkdir -p "$dest"
if [ "$ext" = zip ]; then unzip -oq "$tmp/$archive" "$bin" -d "$dest"; else tar xzf "$tmp/$archive" -C "$dest" "$bin"; fi
chmod +x "$dest/$bin"
echo "installed $bin $ver ($os/$arch) to $dest"
