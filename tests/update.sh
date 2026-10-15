#!/usr/bin/env bash
set -euo pipefail
root=$(mktemp -d)
trap 'rm -rf "$root"' EXIT
mkdir -p "$root/repo/.github" "$root/bin"
cp .github/update.sh "$root/repo/.github/"
cp sources.json "$root/original.json"
export FIXTURE="$root/release.json"
export PATH="$root/bin:$PATH"
cat >"$root/bin/curl" <<'STUB'
#!/usr/bin/env bash
if [[ ${FAIL_API:-false} == true ]]; then exit 22; fi
cat "$FIXTURE"
STUB
sed -i "1c#!$(command -v bash)" "$root/bin/"*
chmod +x "$root/bin/"*
hash=sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
fixture() {
  jq -n --arg version "$1" --arg hash "$hash" '{tag_name: $version, assets: [
    ("x86_64", "arm64") as $arch | (".AppImage", "_linux.tar.xz") as $suffix |
    ("helium-" + $version + "-" + $arch + $suffix) as $name |
    {name: $name, digest: $hash,
      browser_download_url: ("https://github.com/imputnet/helium-linux/releases/download/" + $version + "/" + $name)}
  ]}' >"$FIXTURE"
}
reset() {
  cp "$root/original.json" "$root/repo/sources.json"
  chmod u+w "$root/repo/sources.json"
  rm -f "$root/github-output"
}
run() { GITHUB_OUTPUT="$root/github-output" bash "$root/repo/.github/update.sh" "$@" >"$root/output" 2>&1; }
unchanged() { cmp "$root/original.json" "$root/repo/sources.json"; }
reset
fixture "$(jq -r '.["x86_64-linux"].version' sources.json)"
run
grep -q 'Up to date' "$root/output"
[[ ! -e "$root/github-output" ]]
unchanged
fixture 99.0.0
run
jq -e --arg hash "$hash" 'all(.[]; .version == "99.0.0" and .tar_sha256 == $hash and .appimage_sha256 == $hash)' "$root/repo/sources.json" >/dev/null
jq -e '.["aarch64-linux"].tar_url | endswith("/99.0.0/helium-99.0.0-arm64_linux.tar.xz")' "$root/repo/sources.json" >/dev/null
grep -q '^commit_message=update: helium @ x86_64 aarch64 to 99.0.0$' "$root/github-output"
reset
export FAIL_API=true
if run; then exit 1; fi
unchanged
unset FAIL_API
jq '.assets |= map(select(.name | contains("arm64") | not))' "$FIXTURE" >"$root/missing.json"
mv "$root/missing.json" "$FIXTURE"
if run; then exit 1; fi
unchanged
fixture 99.0.0
jq '.assets[0].digest = null' "$FIXTURE" >"$root/missing.json"
mv "$root/missing.json" "$FIXTURE"
if run; then exit 1; fi
unchanged
printf '{"message":"rate limited"}\n' >"$FIXTURE"
if run; then exit 1; fi
unchanged
fixture 99.0.0
if run --unknown; then exit 1; fi
unchanged
printf 'Updater tests passed: no-op, update, API failure, missing asset, missing digest, invalid release, unknown option.\n'
