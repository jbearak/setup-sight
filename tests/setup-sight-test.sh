#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="${RUNNER_TEMP:-/tmp}/setup-sight-tests"
rm -rf "$test_root"
mkdir -p "$test_root/fake-curl" "$test_root/releases" "$test_root/github-paths"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

make_release_asset() {
  local asset="$1"
  local source="$2"
  mkdir -p "$test_root/releases/v0.0.0"
  cp "$source" "$test_root/releases/v0.0.0/$asset"
  local digest
  if command -v sha256sum >/dev/null 2>&1; then
    digest="$(sha256sum "$test_root/releases/v0.0.0/$asset" | awk '{print $1; exit}')"
  else
    digest="$(shasum -a 256 "$test_root/releases/v0.0.0/$asset" | awk '{print $1; exit}')"
  fi
  printf '%s  %s\n' "$digest" "$asset" > "$test_root/releases/v0.0.0/$asset.sha256"
}

cat > "$test_root/fake-curl/curl" <<'FAKE_CURL'
#!/usr/bin/env bash
set -euo pipefail

output=""
url=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    -o)
      output="$2"
      shift 2
      ;;
    -*)
      shift
      ;;
    *)
      url="$1"
      shift
      ;;
  esac
done

asset="${url##*/}"
tag="${url%/download/*}"
tag="${tag##*/}"
source="${SETUP_SIGHT_TEST_RELEASES}/${tag}/${asset}"
test -f "$source" || {
  echo "missing fake release asset: $source" >&2
  exit 22
}
cp "$source" "$output"
FAKE_CURL
chmod +x "$test_root/fake-curl/curl"

run_install() {
  local os="$1"
  local arch="$2"
  local github_path="$test_root/github-paths/${os}-${arch}"
  : > "$github_path"
  PATH="$test_root/fake-curl:$PATH" \
    SETUP_SIGHT_TEST_RELEASES="$test_root/releases" \
    SIGHT_VERSION="v0.0.0" \
    RUNNER_OS="$os" \
    RUNNER_ARCH="$arch" \
    RUNNER_TEMP="$test_root/tmp-${os}-${arch}" \
    GITHUB_PATH="$github_path" \
    bash "$repo_root/setup-sight.sh"
  local installed_dir
  installed_dir="$(tail -n 1 "$github_path")"
  test -n "$installed_dir" || fail "GITHUB_PATH was not updated for $os/$arch"
  printf '%s\n' "$installed_dir"
}

make_release_asset "sight-linux-x64" "$repo_root/tests/fixtures/bin/sight"
installed_linux="$(run_install Linux X64)"
test -x "$installed_linux/sight" || fail "linux install did not create sight"
"$installed_linux/sight" --version | grep -q "sight 0.0.0-test" || fail "linux sight smoke failed"

make_release_asset "sight-windows-x64.exe" "$repo_root/tests/fixtures/bin/sight.exe"
installed_windows="$(run_install Windows X64)"
test -x "$installed_windows/sight.exe" || fail "windows install did not create sight.exe"
"$installed_windows/sight.exe" --version | grep -q "sight 0.0.0-test" || fail "windows sight.exe smoke failed"

if SIGHT_VERSION="v0.0.0" RUNNER_OS="macOS" RUNNER_ARCH="X64" bash "$repo_root/setup-sight.sh" >"$test_root/macos-x64.log" 2>&1; then
  fail "macOS x64 unexpectedly succeeded"
fi
grep -q "unsupported runner architecture for macOS" "$test_root/macos-x64.log" || fail "macOS x64 error was unclear"

echo "setup-sight tests passed"
