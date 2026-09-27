#!/usr/bin/env bash
set -euo pipefail

ci=false
only_check=false
for arg in "$@"; do
  case "$arg" in
  --ci) ci=true ;;
  --only-check) only_check=true ;;
  *)
    echo "Unknown argument: $arg" >&2
    exit 1
    ;;
  esac
done

if $ci; then
  : "${GITHUB_OUTPUT:?--ci requires GITHUB_OUTPUT}"
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

asset_url() {
  jq -er --arg name "$1" '
    [.assets[] | select(.name == $name) | .browser_download_url]
    | select(length == 1) | .[0]
    | select(type == "string" and startswith("https://github.com/imputnet/helium-linux/releases/download/"))
  ' <<<"$remote_latest"
}

prefetch_hash() {
  nix store prefetch-file --hash-type sha256 --json "$1" |
    jq -er '.hash | select(type == "string") | select(test("^sha256-[A-Za-z0-9+/]{43}=$"))'
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
  appimage_url=$(asset_url "helium-$remote-$release_arch.AppImage")
  tar_url=$(asset_url "helium-$remote-${release_arch}_linux.tar.xz")
  targets+=("$arch")

  if $only_check; then
    continue
  fi

  tar_hash=$(prefetch_hash "$tar_url")
  appimage_hash=$(prefetch_hash "$appimage_url")
  updated=$(jq --arg system "$system" --arg version "$remote" \
    --arg tar_url "$tar_url" --arg tar_hash "$tar_hash" \
    --arg appimage_url "$appimage_url" --arg appimage_hash "$appimage_hash" \
    '.[$system] = {version: $version, tar_url: $tar_url, tar_sha256: $tar_hash,
      appimage_url: $appimage_url, appimage_sha256: $appimage_hash}' <<<"$updated")
done

should_update=false
if ((${#targets[@]} > 0)); then
  should_update=true
fi

if $should_update && ! $only_check; then
  tmp=$(mktemp sources.json.XXXXXX)
  trap 'rm -f "$tmp"' EXIT
  printf '%s\n' "$updated" >"$tmp"
  chmod --reference=sources.json "$tmp"
  mv "$tmp" sources.json
fi

echo "should_update=$should_update"
if $ci; then
  echo "should_update=$should_update" >>"$GITHUB_OUTPUT"
  if $should_update && ! $only_check; then
    echo "commit_message=update: helium @ ${targets[*]} to $remote" >>"$GITHUB_OUTPUT"
  fi
fi
