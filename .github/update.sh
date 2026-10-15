#!/usr/bin/env bash
set -euo pipefail

if (($# > 0)); then
  echo "Usage: $0" >&2
  exit 1
fi

cd "$(dirname "${BASH_SOURCE[0]}")/.."

curl_args=(--fail --silent --show-error --location --retry 3 --connect-timeout 15 --max-time 120)
if [[ -n ${GH_TOKEN:-} ]]; then
  curl_args+=(-H "Authorization: Bearer $GH_TOKEN")
fi
remote_latest=$(curl "${curl_args[@]}" -H 'Accept: application/vnd.github+json' \
  'https://api.github.com/repos/imputnet/helium-linux/releases/latest')
remote=$(jq -er '.tag_name | select(type == "string") | select(test("^[0-9]+(\\.[0-9]+)+$"))' <<<"$remote_latest")

sources=$(cat sources.json)
updated=$sources
targets=()

asset() {
  jq -ec --arg name "$1" '
    [.assets[] | select(.name == $name)]
    | select(length == 1) | .[0]
    | select(.browser_download_url | type == "string" and startswith("https://github.com/imputnet/helium-linux/releases/download/"))
    | select(.digest | type == "string" and test("^sha256:[0-9a-f]{64}$"))
    | {url: .browser_download_url, hash: .digest}
  ' <<<"$remote_latest"
}

for arch in x86_64 aarch64; do
  system="$arch-linux"
  local_version=$(jq -er --arg system "$system" '.[$system].version | select(type == "string")' <<<"$sources")
  echo "Checking helium @ $system: local=$local_version remote=$remote"
  if [[ $local_version == "$remote" ]]; then
    continue
  fi

  release_arch=$arch
  if [[ $arch == aarch64 ]]; then
    release_arch=arm64
  fi
  tar=$(asset "helium-$remote-${release_arch}_linux.tar.xz")
  appimage=$(asset "helium-$remote-$release_arch.AppImage")
  updated=$(jq --arg system "$system" --arg version "$remote" \
    --argjson tar "$tar" --argjson appimage "$appimage" \
    '.[$system] = {version: $version, tar_url: $tar.url, tar_sha256: $tar.hash,
      appimage_url: $appimage.url, appimage_sha256: $appimage.hash}' <<<"$updated")
  targets+=("$arch")
done

if ((${#targets[@]} == 0)); then
  echo "Up to date"
  exit 0
fi

tmp=$(mktemp sources.json.XXXXXX)
trap 'rm -f "$tmp"' EXIT
printf '%s\n' "$updated" >"$tmp"
chmod --reference=sources.json "$tmp"
mv "$tmp" sources.json

message="update: helium @ ${targets[*]} to $remote"
echo "$message"
if [[ -n ${GITHUB_OUTPUT:-} ]]; then
  echo "commit_message=$message" >>"$GITHUB_OUTPUT"
fi
