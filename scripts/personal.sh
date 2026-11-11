#!/usr/bin/env bash
# Build/install the personal zgx app. No command launches it implicitly.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/target/personal"
APP="$OUT/Zeron Personal.app"
INSTALLED="$HOME/Applications/Zeron Personal.app"
PROFILE="${PERSONAL_PROFILE:-dev}"

build() {
  case "$PROFILE" in dev) artifact=debug ;; release) artifact=release ;; *) echo 'PERSONAL_PROFILE must be dev or release' >&2; exit 1 ;; esac
  export ZERON_PERSONAL_BUILD=1
  export CARGO_BUILD_JOBS="${CARGO_BUILD_JOBS:-6}"
  local version commit
  version="$(python3 - "$ROOT/Cargo.toml" <<'PY'
import pathlib, sys, tomllib
print(tomllib.loads(pathlib.Path(sys.argv[1]).read_text())['workspace']['package']['version'])
PY
  )"
  commit="$(git -C "$ROOT" rev-parse --short=12 HEAD)"
  export ZERON_BETA_VERSION="$version-personal.$commit"
  mkdir -p "$OUT"
  # Cargo's config is resolved from the working directory, so build each
  # workspace from its own root. Preserve upstream's dependency pins.
  (cd "$ROOT" && nice -n 10 cargo build --locked --target-dir "$ROOT/target" --profile "$PROFILE" -p zeron --bin zeron-engine)
  (cd "$ROOT/apps/zgx" && nice -n 10 cargo build --locked --target-dir "$ROOT/apps/zgx/target" --profile "$PROFILE" --features beta --bin zeron-zgx)
  local contents="$APP/Contents"
  mkdir -p "$contents/MacOS" "$contents/Resources"
  install -m 755 "$ROOT/target/$artifact/zeron-engine" "$contents/MacOS/Zeron Engine"
  install -m 755 "$ROOT/apps/zgx/target/$artifact/zeron-zgx" "$contents/MacOS/zeron"
  python3 - "$ROOT/dist/macos/Info.plist" "$contents/Info.plist" "$version" "$ZERON_BETA_VERSION" <<'PY'
import pathlib, plistlib, sys
source, destination, version, personal = sys.argv[1:]
data = plistlib.loads(pathlib.Path(source).read_bytes())
data.update(CFBundleIdentifier='sh.zeron.app.personal', CFBundleName='Zeron Personal',
            CFBundleDisplayName='Zeron Personal', CFBundleShortVersionString=version,
            CFBundleVersion=version, ZeronEngineVersion=version, ZeronVersion=personal,
            LSMinimumSystemVersion='13.0')
data['CFBundleURLTypes'] = [{'CFBundleURLName': 'sh.zeron.app.personal.conversation',
                           'CFBundleURLSchemes': ['zeron-personal']}]
pathlib.Path(destination).write_bytes(plistlib.dumps(data))
PY
  rsync -a --delete --exclude '.zgx/' --exclude '/tests/' --exclude '.lock' --exclude '.DS_Store' \
    "$ROOT/apps/zgx/ui/" "$contents/Resources/ui/"
  rsync -a --delete --exclude '.zgx/' --exclude '.DS_Store' \
    "$ROOT/apps/zgx/plugins-builtin/" "$contents/Resources/plugins-builtin/"
  mkdir -p "$contents/Resources/licenses/fonts"
  cp "$ROOT/LICENSE" "$ROOT/THIRD_PARTY_NOTICES.md" "$contents/Resources/licenses/"
  cp "$ROOT/crates/voice/NOTICE.md" "$contents/Resources/licenses/parakeet-v3.txt"
  cp "$ROOT/crates/ui/assets/fonts/licenses/"* "$ROOT/apps/zgx/fonts/"*-OFL.txt "$contents/Resources/licenses/fonts/"
  if [[ ! -f "$contents/Resources/zeron.icns" ]]; then
    local iconset="$OUT/personal.iconset"
    mkdir -p "$iconset"
    for size in 16 32 128 256 512; do
      sips -z "$size" "$size" "$ROOT/dist/macos/icon-1024.png" --out "$iconset/icon_${size}x${size}.png" >/dev/null
      sips -z "$((size * 2))" "$((size * 2))" "$ROOT/dist/macos/icon-1024.png" --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
    done
    iconutil -c icns "$iconset" -o "$contents/Resources/zeron.icns"
  fi
  codesign --force --sign - --identifier sh.zeron.app.personal.engine \
    --entitlements "$ROOT/dist/macos/Zeron.entitlements" "$contents/MacOS/Zeron Engine"
  codesign --force --sign - --entitlements "$ROOT/dist/macos/Zeron.entitlements" "$APP"
  verify "$APP"
  echo "Built: $APP"
}

verify() {
  local app="${1:-$APP}"
  codesign --verify --strict "$app"
  python3 - "$app" <<'PY'
import os, pathlib, plistlib, subprocess, sys, tempfile
app = pathlib.Path(sys.argv[1])
info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
assert info['CFBundleIdentifier'] == 'sh.zeron.app.personal'
assert info['CFBundleURLTypes'][0]['CFBundleURLSchemes'] == ['zeron-personal']
with tempfile.TemporaryDirectory(prefix='zeron-personal-isolation-') as directory:
    sentinel = pathlib.Path(directory)
    inherited = dict(os.environ, ZERON_DATA_DIR=str(sentinel), ZERON_IPC_PORT='27654', ZERON_AUTO_UPDATE='1')
    for name in ['zeron', 'Zeron Engine']:
        exe = str(app / 'Contents/MacOS' / name)
        result = subprocess.run([exe, '--version'], capture_output=True, text=True, check=True, timeout=30)
        print(result.stdout.strip())
        for args in [['update'], ['daemon', 'status']]:
            result = subprocess.run([exe, *args], capture_output=True, text=True, env=inherited, timeout=30)
            assert result.returncode != 0, (name, args)
            assert 'official updates and daemon commands are disabled' in result.stderr, result.stderr
        result = subprocess.run([exe, 'status'], capture_output=True, text=True, env=inherited, check=True, timeout=30)
        assert f'Data dir: {pathlib.Path.home() / ".zeron-personal"}' in result.stdout, result.stdout
        assert '127.0.0.1:49778' in result.stdout, result.stdout
        assert not list(sentinel.iterdir()), 'Inherited data directory was modified'
print('Verified personal identity, signature, and update/service protection.')
PY
}

case "${1:-install}" in
  build) build ;;
  install)
    # Replacing an executable under a running engine is unsafe. Stop only
    # this profile explicitly before rebuilding/installing it.
    if pgrep -f -x "$INSTALLED/Contents/MacOS/zeron" >/dev/null || \
       pgrep -f -x "$INSTALLED/Contents/MacOS/Zeron Engine" >/dev/null; then
      echo 'Zeron Personal is running. Quit its app and engine before installing.' >&2
      exit 1
    fi
    build
    mkdir -p "$(dirname "$INSTALLED")"
    # The previous app is retained for a quick binary rollback.
    if [[ -d "$INSTALLED" ]]; then
      backup="$OUT/previous-$(date +%Y%m%d-%H%M%S)"
      mkdir -p "$backup"
      ditto "$INSTALLED" "$backup/Zeron Personal.app"
    fi
    rsync -a --delete "$APP/" "$INSTALLED/"
    verify "$INSTALLED"
    echo "Installed without launching: $INSTALLED"
    ;;
  verify) verify ;;
  sync)
    cd "$ROOT"
    [[ "$(git branch --show-current)" == personal ]] || { echo 'Switch to personal first.' >&2; exit 1; }
    [[ -z "$(git status --porcelain)" ]] || { echo 'Commit or stash changes before syncing.' >&2; exit 1; }
    git fetch origin main
    git merge --no-edit origin/main
    echo 'Review the merge, then run scripts/personal.sh install.'
    ;;
  *) echo 'Usage: scripts/personal.sh [build|install|verify|sync]' >&2; exit 2 ;;
esac
