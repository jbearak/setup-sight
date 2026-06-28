#!/usr/bin/env bash
set -euo pipefail

version="${SIGHT_VERSION:-latest}"
release_repository="${SIGHT_RELEASE_REPOSITORY:-jbearak/sight}"

fail() {
  echo "::error::$1" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "$1 is required to install Sight"
}

if [ "$version" != "latest" ] && ! [[ "$version" =~ ^v[0-9]+(\.[0-9]+){0,2}([-+][A-Za-z0-9._-]+)?$ ]]; then
  fail "version must be 'latest' or a Sight release tag (e.g. v0.8.4)"
fi

runner_os="${RUNNER_OS:-$(uname -s)}"
case "$runner_os" in
  Linux | linux* | GNU/Linux)
    os="linux"
    ;;
  macOS | Darwin | darwin*)
    os="darwin"
    ;;
  Windows | Windows_NT | windows* | MINGW* | MSYS* | CYGWIN*)
    os="windows"
    ;;
  *)
    fail "unsupported runner OS: ${runner_os}. setup-sight supports Linux, macOS, and Windows runners."
    ;;
esac

runner_arch="${RUNNER_ARCH:-$(uname -m)}"
case "$runner_arch" in
  X64 | x86_64 | amd64)
    arch="x64"
    ;;
  ARM64 | arm64 | aarch64)
    arch="arm64"
    ;;
  *)
    fail "unsupported runner architecture: ${runner_arch}. setup-sight supports x64 and arm64 runners."
    ;;
esac

if [ "$os" = "darwin" ] && [ "$arch" = "x64" ]; then
  fail "unsupported runner architecture for macOS: x64. Sight publishes macOS arm64 binaries only."
fi

asset="sight-${os}-${arch}"
bin_name="sight"
if [ "$os" = "windows" ]; then
  asset="${asset}.exe"
  bin_name="sight.exe"
fi

if [ "$version" = "latest" ]; then
  release_base="https://github.com/${release_repository}/releases/latest/download"
else
  release_base="https://github.com/${release_repository}/releases/download/${version}"
fi

runner_temp="${RUNNER_TEMP:-/tmp}"
runner_temp="${runner_temp//\\//}"
mkdir -p "$runner_temp"
workdir="$(mktemp -d "${runner_temp}/setup-sight-${os}-${arch}.XXXXXX")"
bin_dir="${workdir}/bin"
downloaded_binary="${workdir}/${asset}"
checksum_file="${workdir}/${asset}.sha256"

mkdir -p "$bin_dir"

require_command curl

echo "Downloading ${asset} from ${release_repository} (${version})"
curl -fsSL --retry 3 --retry-delay 2 -o "$downloaded_binary" "${release_base}/${asset}"
curl -fsSL --retry 3 --retry-delay 2 -o "$checksum_file" "${release_base}/${asset}.sha256"

read -r expected_checksum expected_name extra < "$checksum_file" || true
expected_name="${expected_name#\*}"
if [ -n "${extra:-}" ] || ! [[ "$expected_checksum" =~ ^[0-9a-fA-F]{64}$ ]]; then
  fail "malformed checksum file for ${asset}"
fi
if [ "$expected_name" != "$asset" ]; then
  fail "checksum file names '${expected_name:-<missing>}', expected '${asset}'"
fi

if command -v sha256sum >/dev/null 2>&1; then
  actual_checksum="$(sha256sum "$downloaded_binary" | awk '{print $1; exit}')"
elif command -v shasum >/dev/null 2>&1; then
  actual_checksum="$(shasum -a 256 "$downloaded_binary" | awk '{print $1; exit}')"
else
  fail "sha256sum or shasum is required to verify Sight"
fi

if [ "$actual_checksum" != "$expected_checksum" ]; then
  fail "checksum mismatch for ${asset}: expected ${expected_checksum}, got ${actual_checksum}"
fi

echo "Checksum verified for ${asset}"

if [ ! -f "$downloaded_binary" ] || [ -L "$downloaded_binary" ]; then
  fail "downloaded asset must be a regular ${asset} file"
fi

cp "$downloaded_binary" "${bin_dir}/${bin_name}"
chmod +x "${bin_dir}/${bin_name}"

if [ -n "${GITHUB_PATH:-}" ]; then
  echo "$bin_dir" >> "$GITHUB_PATH"
fi

"${bin_dir}/${bin_name}" --version
