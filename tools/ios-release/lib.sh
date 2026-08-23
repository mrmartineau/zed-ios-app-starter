# Shared by bump and tag. Source it, don't run it.
#
# Copied from the ios-release-notes skill
# (~/code/mrmartineau/agent-skills/skills/ios-release-notes/scripts). The skill
# is the source; diff against it if these ever look stale.

# Echo the path to the one .xcodeproj below here, or exit with a usable error.
resolve_project() {
  if [ -n "${1:-}" ]; then printf '%s' "$1"; return; fi
  # No mapfile: macOS ships bash 3.2 and this has to run under it.
  local found count
  found=$(find . -maxdepth 4 -name "*.xcodeproj" -not -path "*/node_modules/*" | sort)
  count=$(printf '%s' "$found" | grep -c . || true)
  case "$count" in
    0) echo "error: no .xcodeproj found below $(pwd). Pass --project." >&2; exit 1 ;;
    1) printf '%s' "$found" ;;
    *) echo "error: more than one .xcodeproj found. Pass --project:" >&2
       printf '%s\n' "$found" | sed 's/^/  /' >&2; exit 1 ;;
  esac
}

# Echo the build number every target agrees on, or exit.
current_build() {
  local pbx builds
  pbx="$1"
  [ -f "$pbx" ] || { echo "error: $pbx not found" >&2; exit 1; }
  builds=$(grep -oE 'CURRENT_PROJECT_VERSION = [0-9]+;' "$pbx" | grep -oE '[0-9]+' | sort -u)
  [ -n "$builds" ] || { echo "error: no CURRENT_PROJECT_VERSION in $pbx" >&2; exit 1; }
  if [ "$(printf '%s' "$builds" | grep -c .)" != "1" ]; then
    echo "error: targets disagree on the build number ($(echo "$builds" | tr '\n' ' ')) — fix that first" >&2
    exit 1
  fi
  printf '%s' "$builds"
}
