#!/usr/bin/env bash
#
# Copy this template into a new project, renamed throughout.
#
#   ./scaffold.sh MyNewApp
#   ./scaffold.sh MyNewApp --display-name "My New App" --bundle-id com.example.MyNewApp
#
# Creates a sibling directory next to this one by default. Everything the old
# name touched — directories, the .xcodeproj, the scheme, the @main struct, the
# bundle identifier, the StoreKit product IDs, the README — is renamed, and a
# fresh git repo is initialised with one commit.

set -euo pipefail

TEMPLATE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_NAME="AppStarter"
TEMPLATE_BUNDLE_ID="wtf.zander.AppStarter"
TEMPLATE_DISPLAY_NAME="App Starter"

usage() {
  cat <<'USAGE'
Usage: ./scaffold.sh <ProjectName> [options]

  <ProjectName>            Target/product name. Must be a valid Swift
                           identifier: letters, digits and underscores, not
                           starting with a digit. e.g. MyNewApp

Options:
  --bundle-id <id>         Bundle identifier. Default: wtf.zander.<ProjectName>
  --display-name <name>    Home-screen name. Default: <ProjectName>
  --dest <path>            Where to create the project. Default: a sibling
                           directory named <ProjectName>
  --no-git                 Skip creating a git repository
  -h, --help               Show this message
USAGE
}

die() { printf 'error: %s\n' "$1" >&2; exit 1; }

# --- arguments ---------------------------------------------------------------

[ $# -ge 1 ] || { usage; exit 1; }

case "$1" in
  -h|--help) usage; exit 0 ;;
  -*) die "expected a project name as the first argument" ;;
esac

NAME="$1"; shift
BUNDLE_ID=""
DISPLAY_NAME=""
DEST=""
INIT_GIT=1

while [ $# -gt 0 ]; do
  case "$1" in
    --bundle-id)     [ $# -ge 2 ] || die "--bundle-id needs a value";     BUNDLE_ID="$2";    shift 2 ;;
    --display-name)  [ $# -ge 2 ] || die "--display-name needs a value";  DISPLAY_NAME="$2"; shift 2 ;;
    --dest)          [ $# -ge 2 ] || die "--dest needs a value";          DEST="$2";         shift 2 ;;
    --no-git)        INIT_GIT=0; shift ;;
    -h|--help)       usage; exit 0 ;;
    *)               die "unknown option: $1" ;;
  esac
done

# The name becomes a Swift type (`struct <Name>App`) and an Xcode target, so it
# has to be a plain identifier. Catching it here beats a confusing build error.
[[ "$NAME" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] \
  || die "'$NAME' is not a valid Swift identifier (letters, digits, underscores; can't start with a digit)"

if [ "$NAME" = "$TEMPLATE_NAME" ]; then
  die "pick a name other than $TEMPLATE_NAME"
fi

BUNDLE_ID="${BUNDLE_ID:-wtf.zander.$NAME}"
DISPLAY_NAME="${DISPLAY_NAME:-$NAME}"
DEST="${DEST:-$(dirname "$TEMPLATE_DIR")/$NAME}"

[ -e "$DEST" ] && die "$DEST already exists"

# --- copy --------------------------------------------------------------------

printf 'Creating %s\n' "$DEST"
mkdir -p "$DEST"

# Copy tracked-looking content only: no .git, no build output, no user state.
# --exclude with a trailing slash-free name matches at any depth.
if command -v rsync >/dev/null 2>&1; then
  rsync -a \
    --exclude '.git' \
    --exclude '.DS_Store' \
    --exclude 'build' \
    --exclude 'DerivedData' \
    --exclude 'xcuserdata' \
    --exclude '*.xcuserstate' \
    "$TEMPLATE_DIR"/ "$DEST"/
else
  cp -R "$TEMPLATE_DIR"/. "$DEST"/
  rm -rf "$DEST/.git"
  find "$DEST" \( -name '.DS_Store' -o -name 'xcuserdata' -o -name 'DerivedData' -o -name 'build' \) \
    -exec rm -rf {} + 2>/dev/null || true
fi

cd "$DEST"

# --- rename ------------------------------------------------------------------

# Directories and files first, deepest-first so a renamed parent never
# invalidates a path still queued for renaming.
find . -depth -name "*${TEMPLATE_NAME}*" -print0 | while IFS= read -r -d '' path; do
  parent="$(dirname "$path")"
  base="$(basename "$path")"
  mv "$path" "$parent/${base//$TEMPLATE_NAME/$NAME}"
done

# Then contents. The bundle ID and display name are substituted before the bare
# name so their occurrences aren't half-rewritten by the generic rule.
#
# -print0/-0 handles paths with spaces; -type f skips the directories we just
# renamed. Binary files (the app icon PNG, if any) are skipped by extension.
find . -type f \
  ! -path './.git/*' \
  ! -name '*.png' ! -name '*.jpg' ! -name '*.pdf' ! -name '*.xcuserstate' \
  -print0 |
while IFS= read -r -d '' file; do
  LC_ALL=C sed -i '' \
    -e "s|${TEMPLATE_BUNDLE_ID}|${BUNDLE_ID}|g" \
    -e "s|${TEMPLATE_DISPLAY_NAME}|${DISPLAY_NAME}|g" \
    -e "s|${TEMPLATE_NAME}|${NAME}|g" \
    "$file"
done

# The scaffold script itself has now been rewritten to refer to the new project,
# which would make it useless. Remove it — the template keeps the original.
rm -f scaffold.sh

# --- git ---------------------------------------------------------------------

if [ "$INIT_GIT" -eq 1 ] && command -v git >/dev/null 2>&1; then
  git init -q
  git add -A
  git -c user.useConfigOnly=false commit -q -m "Scaffold $NAME from AppStarter template"
  printf 'Initialised a git repository with one commit.\n'
fi

# --- done --------------------------------------------------------------------

cat <<DONE

Done.

  Project:     $NAME
  Display:     $DISPLAY_NAME
  Bundle ID:   $BUNDLE_ID
  Location:    $DEST

Next:

  open "$DEST/$NAME.xcodeproj"

  xcodebuild -project "$DEST/$NAME.xcodeproj" -scheme "$NAME" \\
    -destination 'generic/platform=iOS Simulator' build

Optional modules are off by default — see Support/AppFeatures.swift.
DONE
