#!/usr/bin/env bash
#
# Build MARLEY (if needed) and generate exactly one neutrino event.
#
# Usage:  scripts/run_marley.sh [CONFIG]
#
# Environment:
#   MARLEY_SRC  MARLEY source checkout          (default: <repo>/marley)
#   SEED        RNG seed put into the config     (default: seconds since epoch)
#   OUT_DIR     where events.hepmc3 is written   (default: current directory)
#   MAKE_FLAGS  extra flags for MARLEY's Makefile (e.g. IGNORE_ROOT=1)
#
# Works the same on a laptop as in CI; nothing here is GitHub-specific.

set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
MARLEY_SRC=${MARLEY_SRC:-$REPO_ROOT/marley}
CONFIG=${1:-$REPO_ROOT/config/one_event.js}
SEED=${SEED:-$(date +%s)}
OUT_DIR=${OUT_DIR:-$PWD}
# MARLEY auto-detects ROOT/GSL/HepMC3. Pass IGNORE_ROOT=1 here to match the CI
# runner, which has no ROOT installed; nothing in this repo needs it.
MAKE_FLAGS=${MAKE_FLAGS:-}

if [[ ! -d $MARLEY_SRC ]]; then
  echo "error: no MARLEY source at $MARLEY_SRC" >&2
  echo "       clone it with: git clone https://github.com/MARLEY-MC/marley" >&2
  exit 1
fi
MARLEY_SRC=$(cd "$MARLEY_SRC" && pwd)
mkdir -p "$OUT_DIR"
OUT_DIR=$(cd "$OUT_DIR" && pwd)

# ---------------------------------------------------------------- build -----
# MARLEY's top-level Makefile drives CMake and leaves the binary at
# build/bin/marley. Skipped when a cached build tree already has it.
if [[ -x $MARLEY_SRC/build/bin/marley ]]; then
  echo "--- MARLEY already built, skipping compile"
else
  echo "--- Building MARLEY in $MARLEY_SRC"
  jobs=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 2)
  # shellcheck disable=SC2086  # MAKE_FLAGS is meant to word-split
  ( cd "$MARLEY_SRC" && make -j"$jobs" $MAKE_FLAGS )
fi

# ------------------------------------------------------------ environment ----
# setup_marley.sh exports $MARLEY (the binary refuses to start without it) plus
# PATH and the library paths. It appends to variables that may be unset, which
# trips `set -u`, so relax that for the duration of the source.
cd "$MARLEY_SRC"
set +u
# shellcheck disable=SC1091
source ./setup_marley.sh
set -u
echo "--- MARLEY=$MARLEY"

# --------------------------------------------------------------- generate ----
# The committed config carries a __SEED__ placeholder; substituting it here
# keeps the repo copy readable while making every run a different event.
RUN_CONFIG=$OUT_DIR/one_event.seed${SEED}.js
sed "s/__SEED__/${SEED}/" "$CONFIG" > "$RUN_CONFIG"
echo "--- MARLEY seed: $SEED  (config: $RUN_CONFIG)"

cd "$OUT_DIR"
marley generate "$RUN_CONFIG"

if [[ ! -s events.hepmc3 ]]; then
  echo "error: MARLEY produced no events.hepmc3" >&2
  exit 1
fi

# Human-readable dump, for the CI log and as a debugging artifact.
echo "--- marley print legacy events.hepmc3"
marley print legacy events.hepmc3 | tee events_legacy.txt
