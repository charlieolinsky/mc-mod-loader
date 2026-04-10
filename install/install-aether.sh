#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  bash install/install-aether.sh [--manifest PATH_OR_URL] [--minecraft-dir PATH] [--profile-name NAME] [--dry-run]

Examples:
  bash install/install-aether.sh
  bash install/install-aether.sh --dry-run
  bash install/install-aether.sh --manifest https://example.com/aether-fabric-1.21.1.json
EOF
}

log() {
  printf '[aether-installer] %s\n' "$*"
}

fail() {
  printf '[aether-installer] ERROR: %s\n' "$*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
}

json_get() {
  /usr/bin/osascript -l JavaScript - "$1" "$2" <<'JXA'
ObjC.import('Foundation');
function readText(path) {
  const value = $.NSString.stringWithContentsOfFileEncodingError(path, $.NSUTF8StringEncoding, null);
  return ObjC.unwrap(value);
}
function dig(obj, path) {
  return path.split('.').reduce(function (acc, key) {
    return acc && Object.prototype.hasOwnProperty.call(acc, key) ? acc[key] : null;
  }, obj);
}
function run(argv) {
  const data = JSON.parse(readText(argv[0]));
  const value = dig(data, argv[1]);
  if (value === null || value === undefined) {
    return '';
  }
  return typeof value === 'object' ? JSON.stringify(value) : String(value);
}
JXA
}

json_mod_lines() {
  /usr/bin/osascript -l JavaScript - "$1" <<'JXA'
ObjC.import('Foundation');
function readText(path) {
  const value = $.NSString.stringWithContentsOfFileEncodingError(path, $.NSUTF8StringEncoding, null);
  return ObjC.unwrap(value);
}
function run(argv) {
  const data = JSON.parse(readText(argv[0]));
  return data.mods.map(function (mod) {
    return [mod.slug, mod.name, mod.filename, mod.url, mod.sha1].join('\t');
  }).join('\n');
}
JXA
}

update_launcher_profile() {
  /usr/bin/osascript -l JavaScript - "$1" "$2" "$3" "$4" <<'JXA'
ObjC.import('Foundation');
function readText(path) {
  const value = $.NSString.stringWithContentsOfFileEncodingError(path, $.NSUTF8StringEncoding, null);
  return ObjC.unwrap(value);
}
function writeText(path, text) {
  $(text).writeToFileAtomicallyEncodingError(path, true, $.NSUTF8StringEncoding, null);
}
function run(argv) {
  const profilesPath = argv[0];
  const profileName = argv[1];
  const versionId = argv[2];
  const gameDir = argv[3];
  const now = (new Date()).toISOString();

  const data = JSON.parse(readText(profilesPath));
  if (!data.profiles) {
    data.profiles = {};
  }

  const existing = data.profiles[profileName] || {};
  data.profiles[profileName] = {
    created: existing.created || now,
    gameDir: gameDir,
    icon: existing.icon || 'Grass',
    lastUsed: existing.lastUsed || '1970-01-01T00:00:00.000Z',
    lastVersionId: versionId,
    name: profileName,
    type: 'custom'
  };

  writeText(profilesPath, JSON.stringify(data, null, 2) + '\n');
  return profileName;
}
JXA
}

find_java() {
  local candidate

  while IFS= read -r candidate; do
    if [[ -n "$candidate" && -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done < <(find "$MINECRAFT_DIR/runtime" /Applications -type f -path '*/bin/java' 2>/dev/null)

  if command -v java >/dev/null 2>&1; then
    command -v java
    return 0
  fi

  fail "Could not find Java. Open the official Minecraft Launcher once first, or install Java."
}

download_file() {
  local url="$1"
  local output_path="$2"
  curl --fail --location --retry 3 --retry-delay 2 --silent --show-error "$url" -o "$output_path"
}

verify_sha1() {
  local file_path="$1"
  local expected="$2"
  local actual
  actual="$(shasum -a 1 "$file_path" | awk '{print $1}')"
  [[ "$actual" == "$expected" ]] || fail "Checksum mismatch for $(basename "$file_path"): expected $expected, got $actual"
}

remove_old_versions() {
  local slug="$1"
  local keep_filename="$2"
  local existing
  for existing in "$MODS_DIR"/"$slug"*.jar; do
    [[ -e "$existing" ]] || continue
    if [[ "$(basename "$existing")" != "$keep_filename" ]]; then
      rm -f "$existing"
    fi
  done
}

MANIFEST_INPUT=""
PROFILE_NAME_OVERRIDE="${PROFILE_NAME:-}"
MINECRAFT_DIR="${MINECRAFT_DIR:-$HOME/Library/Application Support/minecraft}"
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --manifest)
      [[ $# -ge 2 ]] || fail "--manifest requires a path or URL"
      MANIFEST_INPUT="$2"
      shift 2
      ;;
    --minecraft-dir)
      [[ $# -ge 2 ]] || fail "--minecraft-dir requires a path"
      MINECRAFT_DIR="$2"
      shift 2
      ;;
    --profile-name)
      [[ $# -ge 2 ]] || fail "--profile-name requires a value"
      PROFILE_NAME_OVERRIDE="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "Unknown argument: $1"
      ;;
  esac
done

[[ "$(uname -s)" == "Darwin" ]] || fail "This script is for macOS. Use install/install-aether.ps1 on Windows."
require_cmd curl
require_cmd shasum
require_cmd mktemp
require_cmd /usr/bin/osascript

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" >/dev/null 2>&1 && pwd)"
DEFAULT_MANIFEST="$SCRIPT_DIR/../manifests/aether-fabric-1.21.1.json"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

if [[ -z "$MANIFEST_INPUT" ]]; then
  MANIFEST_INPUT="$DEFAULT_MANIFEST"
fi

if [[ "$MANIFEST_INPUT" =~ ^https?:// ]]; then
  MANIFEST_FILE="$TMP_DIR/manifest.json"
  log "Downloading manifest from $MANIFEST_INPUT"
  download_file "$MANIFEST_INPUT" "$MANIFEST_FILE"
else
  MANIFEST_FILE="$MANIFEST_INPUT"
fi

[[ -f "$MANIFEST_FILE" ]] || fail "Manifest not found: $MANIFEST_FILE"
[[ -d "$MINECRAFT_DIR" ]] || fail "Minecraft directory not found: $MINECRAFT_DIR"
LAUNCHER_PROFILES="$MINECRAFT_DIR/launcher_profiles.json"
[[ -f "$LAUNCHER_PROFILES" ]] || fail "launcher_profiles.json not found. Open the official Minecraft Launcher once before running this."

PACK_NAME="$(json_get "$MANIFEST_FILE" 'name')"
PROFILE_NAME="$(json_get "$MANIFEST_FILE" 'profileName')"
INSTANCE_DIR_NAME="$(json_get "$MANIFEST_FILE" 'instanceDirName')"
MC_VERSION="$(json_get "$MANIFEST_FILE" 'minecraftVersion')"
FABRIC_LOADER_VERSION="$(json_get "$MANIFEST_FILE" 'loader.version')"

if [[ -n "$PROFILE_NAME_OVERRIDE" ]]; then
  PROFILE_NAME="$PROFILE_NAME_OVERRIDE"
fi

INSTANCE_DIR="$MINECRAFT_DIR/$INSTANCE_DIR_NAME"
MODS_DIR="$INSTANCE_DIR/mods"
FABRIC_VERSION_ID="fabric-loader-${FABRIC_LOADER_VERSION}-${MC_VERSION}"
BACKUP_DIR="$MINECRAFT_DIR/copilot-backups"
JAVA_BIN="$(find_java)"

log "Pack: $PACK_NAME"
log "Minecraft dir: $MINECRAFT_DIR"
log "Instance dir: $INSTANCE_DIR"
log "Launcher profile: $PROFILE_NAME"
log "Java: $JAVA_BIN"

if [[ "$DRY_RUN" -eq 1 ]]; then
  log "Dry run complete. No files were changed."
  exit 0
fi

mkdir -p "$MODS_DIR" "$BACKUP_DIR"
BACKUP_FILE="$BACKUP_DIR/launcher_profiles.$(date +%Y%m%d-%H%M%S).json"
cp "$LAUNCHER_PROFILES" "$BACKUP_FILE"
log "Backed up launcher profiles to $BACKUP_FILE"

INSTALLER_VERSION="$(curl -fsSL 'https://meta.fabricmc.net/v2/versions/installer' | grep -m1 -Eo '"version"[[:space:]]*:[[:space:]]*"[^"]*"' | sed -E 's/.*"([^"]*)"/\1/')"
[[ -n "$INSTALLER_VERSION" ]] || fail "Could not determine the latest Fabric installer version"
INSTALLER_JAR="$TMP_DIR/fabric-installer-${INSTALLER_VERSION}.jar"
download_file "https://maven.fabricmc.net/net/fabricmc/fabric-installer/${INSTALLER_VERSION}/fabric-installer-${INSTALLER_VERSION}.jar" "$INSTALLER_JAR"
log "Installing Fabric loader ${FABRIC_LOADER_VERSION} for Minecraft ${MC_VERSION}"
"$JAVA_BIN" -jar "$INSTALLER_JAR" client -dir "$MINECRAFT_DIR" -mcversion "$MC_VERSION" -loader "$FABRIC_LOADER_VERSION" -noprofile
[[ -d "$MINECRAFT_DIR/versions/$FABRIC_VERSION_ID" ]] || fail "Fabric install did not create $FABRIC_VERSION_ID"

while IFS=$'\t' read -r slug mod_name filename url sha1; do
  [[ -n "$slug" ]] || continue
  remove_old_versions "$slug" "$filename"
  destination="$MODS_DIR/$filename"

  if [[ -f "$destination" ]]; then
    current_sha1="$(shasum -a 1 "$destination" | awk '{print $1}')"
    if [[ "$current_sha1" == "$sha1" ]]; then
      log "Already up to date: $mod_name"
      continue
    fi
  fi

  log "Downloading $mod_name"
  download_file "$url" "$destination"
  verify_sha1 "$destination" "$sha1"
done < <(json_mod_lines "$MANIFEST_FILE")

update_launcher_profile "$LAUNCHER_PROFILES" "$PROFILE_NAME" "$FABRIC_VERSION_ID" "$INSTANCE_DIR" >/dev/null

log "Done. Open the Minecraft Launcher and select the '$PROFILE_NAME' profile."
log "Your Aether mods live in: $MODS_DIR"
