#!/usr/bin/env bash
set -euo pipefail
root=$(mktemp -d)
trap 'rm -rf "$root"' EXIT
mkdir -p "$root/repo/.github" "$root/bin"
cp .github/update.sh "$root/repo/.github/"
cp sources.json "$root/original.json"
export FIXTURE="$root/release.json"
export PREFETCH_CALLS="$root/calls"
export PATH="$root/bin:$PATH"
cat >"$root/bin/curl" <<'STUB'
#!/usr/bin/env bash
if [[ ${FAIL_API:-false} == true ]]; then exit 22; fi
cat "$FIXTURE"
STUB
cat >"$root/bin/nix" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$PREFETCH_CALLS"
if [[ ${FAIL_ARM:-false} == true && $* == *arm64* ]]; then exit 1; fi
if [[ ${BAD_HASH:-false} == true ]]; then echo '{"hash":"bad"}'; else
  echo '{"hash":"sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="}'
fi
STUB
sed -i "1c#!$(command -v bash)" "$root/bin/"*
chmod +x "$root/bin/"*
fixture() {
  jq -n --arg version "$1" '{tag_name: $version, assets: [
    ("x86_64", "arm64") as $arch | (".AppImage", "_linux.tar.xz") as $suffix |
    ("helium-" + $version + "-" + $arch + $suffix) as $name |
    {name: $name, browser_download_url: ("https://github.com/imputnet/helium-linux/releases/download/" + $version + "/" + $name)}
  ]}' >"$FIXTURE"
}
reset() {
  cp "$root/original.json" "$root/repo/sources.json"
  chmod u+w "$root/repo/sources.json"
  : >"$PREFETCH_CALLS"
}
run() { bash "$root/repo/.github/update.sh" "$@" >"$root/output" 2>&1; }
unchanged() { cmp "$root/original.json" "$root/repo/sources.json"; }
reset
fixture "$(jq -r '.["x86_64-linux"].version' sources.json)"
run --only-check
grep -q 'should_update=false' "$root/output"
[[ ! -s $PREFETCH_CALLS ]]
fixture 99.0.0
run --only-check
grep -q 'should_update=true' "$root/output"
[[ ! -s $PREFETCH_CALLS ]]
unchanged
run
jq -e 'all(.[]; .version == "99.0.0")' "$root/repo/sources.json" >/dev/null
[[ $(wc -l <"$PREFETCH_CALLS") == 4 ]]
reset
export FAIL_API=true
if run; then exit 1; fi
unchanged
unset FAIL_API
export FAIL_ARM=true
if run; then exit 1; fi
unchanged
unset FAIL_ARM
export BAD_HASH=true
if run; then exit 1; fi
unchanged
unset BAD_HASH
jq '.assets |= map(select(.name | contains("arm64") | not))' "$FIXTURE" >"$root/missing.json"
mv "$root/missing.json" "$FIXTURE"
if run; then exit 1; fi
unchanged
printf '{"message":"rate limited"}\n' >"$FIXTURE"
if run; then exit 1; fi
unchanged
fixture 99.0.0
export GITHUB_OUTPUT="$root/github-output"
run --ci
grep -q '^should_update=true$' "$GITHUB_OUTPUT"
grep -q '^commit_message=update: helium @ x86_64 aarch64 to 99.0.0$' "$GITHUB_OUTPUT"
if run --unknown; then exit 1; fi
printf 'Updater tests passed: no-op, check-only, update, API failure, partial download, invalid hash, missing asset, invalid release, CI output, unknown option.\n'
