set -eo pipefail

# Derivate temporary paths
TMPDIR="${NYX_TEMP:-${TMPDIR}}"
NIX_BUILD_TOP="${NYX_TEMP:-${NIX_BUILD_TOP}}"
TMP="${NYX_TEMP:-${TMP}}"
TEMP="${NYX_TEMP:-${TEMP}}"
TEMPDIR="${NYX_TEMP:-${TEMPDIR}}"

# Options (2)
NYX_FLAGS="${NYX_FLAGS:---accept-flake-config --no-link}"
NYX_WD="${NYX_WD:-$(mktemp -d)}"
NYX_HOME="${NYX_HOME:-$HOME/.nyx}"
CACHIX_REPO="${CACHIX_REPO:-chaotic-nyx}"

# Colors
R='\033[0;31m'
G='\033[0;32m'
Y='\033[1;33m'
C='\033[1;36m'
W='\033[0m'

# Echo helpers
function echo_warning() {
  echo -ne "${Y}WARNING:${W} "
  echo "$@"
}

function echo_error() {
  echo -ne "${R}ERROR:${W} " 1>&2
  echo "$@" 1>&2
}

# That's how we start
function prepare() {
  # A place for persistent advetures
  [ ! -e "$NYX_HOME" ] && mkdir -p "$NYX_HOME"

  # Create empty logs and artifacts
  [ ! -e "$NYX_WD" ] && mkdir -p "$NYX_WD"
  cd "$NYX_WD"
  touch push.txt errors.txt success.txt failures.txt cached.txt upstream.txt eval-failures.txt
  echo "{" > new-failures.nix

  # Warn if we don't have automated cachix
  if [ -z "$CACHIX_AUTH_TOKEN" ] && [ -z "$CACHIX_SIGNING_KEY" ]; then
    echo_warning "No key for cachix -- building anyway."
  fi

  # Download current list of cached packages
  if [ ! -e prev-cache.txt ]; then
    if [ -f prev-cache.json ]; then
      jq -r '.[]' prev-cache.json > prev-cache.txt
    elif [ -n "$CACHIX_AUTH_TOKEN" ]; then
      echo "Downloading current list of cached contents"
      curl -H "Authorization: Bearer $CACHIX_AUTH_TOKEN" \
        "https://app.cachix.org/api/v1/cache/${CACHIX_REPO}/contents" |\
          jq -r .[] > prev-cache.txt
    else
      touch prev-cache.txt
    fi
  fi

  # Creates list of what to build when only building what changed
  if [ -n "${NYX_CHANGED_ONLY:-}" ]; then
    _DIFF=$(nix build --no-link --print-out-paths --impure \
      --expr "(builtins.getFlake \"$NYX_SOURCE\").devShells.${NYX_TARGET}.comparer.passthru.any \"$NYX_CHANGED_ONLY\"" \
      || exit 13)

    ln -s "$_DIFF" filter.txt
  fi
}

# Check if $1 is known as cached
function known-cached() {
  ( grep "$1" "${NYX_HOME}/cached.txt" || grep "$1" "${NYX_WD}/prev-cache.txt" ) >/dev/null 2>/dev/null
}

# Check if $1 is in the cache
function cached() {
  nix path-info "$2" --store "$1" >/dev/null 2>/dev/null
}

# Helper to zip-merge _ALL_OUT_KEYS and _ALL_OUT_PATHS
function zip_path() {
  for (( i=0; i<${#_ALL_OUT_KEYS[*]}; ++i)); do
    echo "${NYX_PREFIX:-}${_ALL_OUT_KEYS[$i]}" "${_ALL_OUT_PATHS[$i]}"
  done
}

# Per-derivation build function
function build() {
  _WHAT="${1:- アンノーン}"
  _MAIN_OUT_PATH="${2:-/dev/null}"
  _FULL_TARGETS=("${_ALL_OUT_KEYS[@]/#/$NYX_SOURCE\#_dev.packages.${NYX_TARGET}.}")
  # If NYX_CHANGED_ONLY is set, only build changed derivations
  if [ -f filter.txt ] && ! grep -Pq "^$_WHAT\$" filter.txt; then
    return 0
  fi
  echo -n "* $_WHAT..."
  if [ -z "${NYX_REFRESH:-}" ] && known-cached "$_MAIN_OUT_PATH"; then
    echo "$_WHAT" >> cached.txt
    echo -e "${Y} CACHED${W}"
    zip_path >> full-pin.txt
    return 0
  elif [ -z "${NYX_REFRESH:-}" ] && [ -z "$CACHIX_AUTH_TOKEN" ] && cached "https://${CACHIX_REPO}.cachix.org" "$_MAIN_OUT_PATH"; then
    echo "$_WHAT" >> cached.txt
    echo "$_MAIN_OUT_PATH" >> "${NYX_HOME}/cached.txt"
    echo -e "${Y} CACHED${W}"
    zip_path >> full-pin.txt
    return 0
  elif cached 'https://cache.nixos.org' "$_MAIN_OUT_PATH"; then
    echo "$_WHAT" >> upstream.txt
    echo "$_MAIN_OUT_PATH" >> "${NYX_HOME}/cached.txt"
    echo -e "${Y} CACHED-UPSTREAM${W}"
    return 0
  else
    (while true; do echo -ne "${C} BUILDING${W}\n* $_WHAT..." && sleep 120; done) &
    _KEEPALIVE=$!
    if \
      ( nix build --json $NYX_FLAGS "${_FULL_TARGETS[@]}" |\
          jq -r '.[].outputs[]' \
      ) 2>> errors.txt >> push.txt
    then
      echo "$_WHAT" >> success.txt
      kill $_KEEPALIVE
      echo -e "${G} OK${W}"
      zip_path | tee -a to-pin.txt >> full-pin.txt
      return 0
    else
      echo "$_WHAT" >> failures.txt
      echo "  \"$_WHAT\" = \"$_MAIN_OUT_PATH\";" >> new-failures.nix
      kill $_KEEPALIVE
      echo -e "${R} ERR${W}"
      return 1
    fi
  fi
}

# Run when building finishes, before deploying
function finish() {
  # Write EOF of the artifacts
  echo "}" >> new-failures.nix
}

# When you need to exit on failures
function no-fail() {
  if [ ! $(cat failures.txt | wc -l) -eq 0 ]; then
    exit 43
  fi

  return 0
}

# Push logic
function deploy() {
  if [ -z "$CACHIX_AUTH_TOKEN" ] && [ -z "$CACHIX_SIGNING_KEY" ]; then
    echo_error "No key for cachix -- failing to deploy."
    exit 23
  elif [ -n "''${NYX_RESYNC:-}" ] || [ -s push.txt ]; then
    # Let nix digest store paths first
    sleep 10

    # Push all new deriations with compression
    cat push.txt | cachix push "$CACHIX_REPO"

    # Pin packages
    if [ -e to-pin.txt ]; then
      cat to-pin.txt | xargs -n 2 \
        cachix -v pin "$CACHIX_REPO" --keep-revisions 7
    fi

    # Locally tag everything as cached
    cat push.txt >> "${NYX_HOME}/cached.txt"
  else
    echo_error "Nothing to push."
    exit 42
  fi
}
