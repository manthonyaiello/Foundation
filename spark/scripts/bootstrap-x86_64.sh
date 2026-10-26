#!/usr/bin/env bash
#
# bootstrap-x86_64.sh -- from a bare Ubuntu 24.04 x86_64 machine to a green
# check-ffi.sh, in one command (issue #6, M0.5).
#
# The x86_64 instance dies 24 hours after it starts, and anything not
# scripted is lost with it. This script installs the campaign's toolchain,
# clones (or updates) the fork, and runs the build, the proof gate and the FFI
# check. Run it again at any time: every phase skips what is already in place.
#
# Each tool is used where it is when it is present and its version matches
# its pin in toolchain-pins.env, and fetched (the pinned release, sha256
# checked) only when it is not. Present means, in this order: in the
# directory its environment variable names (LLVM_LINK_DIR, for llvm-link),
# on PATH, or where an earlier run of this script fetched it. The script
# says which, per tool ("present and matching the pin" or "fetched"), as it
# goes and in the table at the end. A run with every tool present fetches
# nothing.
#
#   curl -fsSL https://raw.githubusercontent.com/manthonyaiello/Foundation/main/spark/scripts/bootstrap-x86_64.sh | bash
#
# Phases, each timed (wall-clock, printed at the end and on failure):
#   prereqs    the commands and libraries the rest needs (curl, git, python3,
#              CA certificates, libc6-dev; the shared libraries Cryptol and
#              SAW link against). The phase that may need root (as may
#              gnat-llvm, for xz-utils, when it fetches llvm-link, and a
#              fetched tool's missing shared libraries): missing packages
#              are apt-installed when running as root or with passwordless
#              sudo, and otherwise the script stops and prints the one
#              `sudo apt-get install` line to run.
#   clone      clone the fork, or fetch it and fast-forward a clean checkout.
#              The versions below are read from ITS
#              spark/scripts/toolchain-pins.env, the file CI's
#              setup-alire-spark action reads too.
#   alire      alr, the gnat_native and gprbuild toolchain, gnatprove and
#              gnatdoc_bin. Fetched: alr's release zip (sha256 checked), the
#              toolchain selected with `alr toolchain --select`, the tools
#              installed with `alr install` (into ~/.alire/bin), as CI does.
#   cryptol    Cryptol, with FFI support and a z3 for its type checker.
#              Fetched: the release build with solvers, sha256 checked.
#   saw        SAW. Fetched: the release build with solvers, sha256 checked
#              (and its .sig, when SAW_SIGNING_KEY_FILE names the signing
#              key).
#   gnat-llvm  checks GNAT Pro's LLVM back end when GNAT_LLVM_DIR names it
#              (nothing of it is ever downloaded), and llvm-link of the same
#              LLVM version. Fetched: llvm-link from LLVM's own release (a
#              2 GB tarball, sha256 checked; only bin/llvm-link extracted).
#              Writes GNAT_LLVM_DIR and LLVM_LINK_DIR to env.sh, for
#              scripts/check-saw.sh. Skipped, with a note, when GNAT_LLVM_DIR
#              is unset.
#   build      `alr -n build` in spark/.
#   proof      scripts/check-proof.sh (the slow units of proof-slow.txt are
#              skipped, and their recorded proofs checked current, as in CI),
#              retried once if it fails; the phase says "ok on retry" then.
#              Skipped with --no-proof.
#   ffi        scripts/check-ffi.sh.
#
# Usage:
#   bootstrap-x86_64.sh               everything
#   bootstrap-x86_64.sh --no-checks   tools and clone only (no build/proof/ffi)
#   bootstrap-x86_64.sh --no-proof    everything but the proof phase (build and
#                                     ffi still run). CI's bootstrap jobs use
#                                     it: the proof gate runs on arm64 only,
#                                     because x86_64's provers are slower on
#                                     some goals and miss their time limits
#                                     there (README "Bootstrapping the
#                                     x86_64 instance"). The phase table
#                                     shows proof as skipped, with why.
#
# Env:
#   FOUNDATION_TOOLS   where fetched tools go, and env.sh (default
#                      ~/foundation-tools). Alire's own state stays where alr
#                      puts it (~/.alire, ~/.config/alire,
#                      ~/.local/share/alire), as in CI.
#   FOUNDATION_REPO    the checkout (default: the checkout this script is in,
#                      if any, else ~/Foundation).
#   FOUNDATION_REMOTE  what to clone (default the fork, over https).
#   FOUNDATION_REF     a branch, tag or commit to check out (detached). Unset,
#                      a fresh clone is on the default branch, and an existing
#                      checkout keeps its branch (fast-forwarded when clean).
#   PROVE_JOBS         gnatprove -j (default nproc: the instance has no
#                      scheduler and no other user).
#   FFI_JOBS           gprbuild -j for the FFI library (default nproc).
#   FOUNDATION_SPARK_PROOF_ALLOWANCE
#                      passed through to the GPR: "ci" (the default here:
#                      CI's allowance, which never shortens a committed
#                      level, README "Levels") or "none" (the levels' own
#                      timeouts, as on the campaign machine).
#   SAW_SIGNING_KEY_FILE
#                      an armored public key; when set, SAW's .sig is verified
#                      with it (and the key must be SAW_SIGNING_KEY's).
#   GNAT_LLVM_DIR      a GNAT Pro LLVM install (holding bin/llvm-gcc), for
#                      the gnat-llvm phase; optional. When set, the phase
#                      also needs llvm-link of the same LLVM version, and
#                      fetches it (LLVM's 2 GB release tarball) unless it is
#                      present.
#   LLVM_LINK_DIR      a directory holding bin/llvm-link; used when that
#                      llvm-link is the pinned version (else PATH's, else
#                      fetched). Only read when GNAT_LLVM_DIR is set.
#
# Exit status: 0 when every phase passed; 1 when one failed (the proof and FFI
# phases both run even if the other fails, so one run reports both); 2 on a
# usage error.
#
set -euo pipefail

REMOTE_DEFAULT="https://github.com/manthonyaiello/Foundation.git"

CHECKS=1
PROOF=1
for arg in "$@"; do
  case "$arg" in
    --no-checks) CHECKS=0 ;;
    --no-proof) PROOF=0 ;;
    -h|--help) sed -n '2,/^set -euo/p' "${BASH_SOURCE[0]:-/dev/null}" | sed '$d'; exit 0 ;;
    *) echo "bootstrap-x86_64.sh: unknown argument: $arg" >&2; exit 2 ;;
  esac
done

TOOLS="${FOUNDATION_TOOLS:-$HOME/foundation-tools}"
REMOTE="${FOUNDATION_REMOTE:-$REMOTE_DEFAULT}"
REF="${FOUNDATION_REF:-}"

# The default checkout: the one this script lives in, when it is run from a
# file inside one (not through a pipe), else ~/Foundation.
if [ -z "${FOUNDATION_REPO:-}" ]; then
  FOUNDATION_REPO="$HOME/Foundation"
  src="${BASH_SOURCE[0]:-}"
  if [ -n "$src" ] && [ -f "$src" ]; then
    here="$(cd "$(dirname "$src")/../.." 2>/dev/null && pwd)" || here=""
    if [ -n "$here" ] && [ -e "$here/.git" ] && [ -d "$here/spark/scripts" ]; then
      FOUNDATION_REPO="$here"
    fi
  fi
fi
REPO="$FOUNDATION_REPO"
case "$REPO" in /*) ;; *) REPO="$PWD/$REPO" ;; esac
case "$TOOLS" in /*) ;; *) TOOLS="$PWD/$TOOLS" ;; esac

log() { printf '\n== %s\n' "$*"; }
warn() { printf '!! %s\n' "$*" >&2; }
die() { printf '!! %s\n' "$*" >&2; exit 1; }

# --- phase timing ---------------------------------------------------------------

PHASES=()
TOOL_STATES=()   # "tool version state", one per tool (tool_present, tool_fetched)
T_START="$(date +%s)"

# shellcheck disable=SC2317,SC2329  # reached through the EXIT trap
report() {
  local total=$(( $(date +%s) - T_START )) line
  {
    echo
    echo "== wall-clock per phase ($(uname -m), $(nproc) CPUs)"
    printf '%-10s %8s  %s\n' phase seconds result
    for line in "${PHASES[@]+"${PHASES[@]}"}"; do printf '%s\n' "$line"; done
    printf '%-10s %8s\n' total "$total"
    echo
    echo "== tools"
    for line in "${TOOL_STATES[@]+"${TOOL_STATES[@]}"}"; do printf '%s\n' "$line"; done
  } | tee "$TOOLS/bootstrap-times.txt"
  if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
    {
      echo "### Bootstrap wall-clock ($(uname -m), $(nproc) CPUs)"
      echo
      echo "| phase | seconds | result |"
      echo "|---|---:|---|"
      for line in "${PHASES[@]+"${PHASES[@]}"}"; do
        # shellcheck disable=SC2086  # split the padded columns on purpose
        set -- $line
        echo "| $1 | $2 | ${*:3} |"
      done
      echo "| total | $total | |"
      echo
      echo "| tool | version | state |"
      echo "|---|---|---|"
      for line in "${TOOL_STATES[@]+"${TOOL_STATES[@]}"}"; do
        # shellcheck disable=SC2086  # split the padded columns on purpose
        set -- $line
        echo "| $1 | $2 | ${*:3} |"
      done
    } >> "$GITHUB_STEP_SUMMARY"
  fi
}

# A tool phase that fails stops the run; the report is still printed.
CURRENT=""
CURRENT_T0=0
# shellcheck disable=SC2317,SC2329  # reached through the EXIT trap
on_exit() {
  local status=$?
  if [ -n "$CURRENT" ]; then
    PHASES+=("$(printf '%-10s %8s  %s' "$CURRENT" $(( $(date +%s) - CURRENT_T0 )) "FAILED (exit $status)")")
  fi
  mkdir -p "$TOOLS"
  report
  exit "$status"
}
trap on_exit EXIT
# Name the command that stopped the run: set -e alone exits silently.
set -E
trap 'echo "!! line $LINENO: \`$BASH_COMMAND\` failed (exit $?)" >&2' ERR

begin() { CURRENT="$1"; CURRENT_T0="$(date +%s)"; log "phase $1"; }
end() {
  PHASES+=("$(printf '%-10s %8s  %s' "$CURRENT" $(( $(date +%s) - CURRENT_T0 )) "${1:-ok}")")
  CURRENT=""
}

# --- helpers ------------------------------------------------------------------------

# apt-get install, as root or through passwordless sudo; otherwise stop and
# say what to run. This is the only place the script can need root.
apt_install() {
  local sudo=()
  if [ "$(id -u)" -ne 0 ]; then
    if command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
      sudo=(sudo -n)
    else
      die "missing packages; run this, then rerun the script:
     sudo apt-get update && sudo apt-get install -y --no-install-recommends $*"
    fi
  fi
  echo ">> apt-get install (needs root): $*"
  "${sudo[@]+"${sudo[@]}"}" env DEBIAN_FRONTEND=noninteractive apt-get update -qq
  "${sudo[@]+"${sudo[@]}"}" env DEBIAN_FRONTEND=noninteractive \
    apt-get install -y -qq --no-install-recommends "$@"
}

# The Ubuntu 24.04 package that provides a shared library, for the libraries
# the release binaries link against.
lib_package() {
  case "$1" in
    libgmp.so.10)     echo libgmp10 ;;
    libffi.so.8)      echo libffi8 ;;
    libz.so.1)        echo zlib1g ;;
    libtinfo.so.6)    echo libtinfo6 ;;
    libncursesw.so.6) echo libncursesw6 ;;
    libstdc++.so.6)   echo libstdc++6 ;;
    libgcc_s.so.1)    echo libgcc-s1 ;;
    libnuma.so.1)     echo libnuma1 ;;
    *)                return 1 ;;
  esac
}

# Every executable under DIR/bin must find its shared libraries; install the
# packages of the missing ones.
ensure_libs() {
  local dir="$1" f lib missing="" pkgs=() unknown=""
  for f in "$dir"/bin/*; do
    if [ ! -f "$f" ] || [ ! -x "$f" ]; then continue; fi
    file_is_elf "$f" || continue
    # ldd exits 1 on a static executable; that is not a missing library.
    missing="$missing$( { ldd "$f" 2>/dev/null || true; } | awk '/not found/ { print $1 }')"$'\n'
  done
  missing="$(printf '%s' "$missing" | sed '/^$/d' | sort -u)"
  [ -z "$missing" ] && return 0
  echo ">> $dir: missing shared libraries: $(echo "$missing" | tr '\n' ' ')"
  while IFS= read -r lib; do
    if p="$(lib_package "$lib")"; then pkgs+=("$p"); else unknown="$unknown $lib"; fi
  done <<< "$missing"
  [ -z "$unknown" ] || die "no known Ubuntu package for:$unknown"
  apt_install "${pkgs[@]}"
}

file_is_elf() { [ "$(head -c 4 "$1" 2>/dev/null | od -An -c | tr -d ' ')" = '177ELF' ]; }

# Download URL to FILE unless FILE is there with the right sha256; check it.
fetch() {
  local url="$1" file="$2" sha="$3"
  if [ -f "$file" ] && echo "$sha  $file" | sha256sum -c --status - 2>/dev/null; then
    echo ">> $(basename "$file"): already downloaded, sha256 ok"
    return 0
  fi
  echo ">> downloading $url"
  curl -fsSL --retry 3 -o "$file.part" "$url"
  mv "$file.part" "$file"
  echo "$sha  $file" | sha256sum -c - || { rm -f "$file"; die "sha256 mismatch: $file"; }
}

# Unpack a release tarball (one top directory) into DEST, recording its
# sha256 there; skip when DEST already holds that sha256's contents.
unpack() {
  local tarball="$1" dest="$2" sha="$3"
  if [ -f "$dest/.bootstrap-sha256" ] && [ "$(cat "$dest/.bootstrap-sha256")" = "$sha" ]; then
    echo ">> $dest: already installed"
    return 0
  fi
  rm -rf "$dest.new"
  mkdir -p "$dest.new"
  tar -xzf "$tarball" -C "$dest.new" --strip-components=1
  echo "$sha" > "$dest.new/.bootstrap-sha256"
  rm -rf "$dest"
  mv "$dest.new" "$dest"
}

# --- tool detection -----------------------------------------------------------------
# Present and matching the pin, or not. scripts/test-bootstrap-detect.sh
# sources the lines from here to "end of tool detection", with stub tools on
# a made-up PATH, so keep them free of side effects beyond the variables
# they document, and runnable by bash 3.2.

# The first line of a command's output, whatever its exit status
# (`gnatdoc --version` exits 1).
first_line() { local out; out="$("$@" 2>&1)" || true; printf '%s\n' "${out%%$'\n'*}"; }

# The version TOOL's executable EXE reports, in the form toolchain-pins.env
# pins it; empty when it reports none.
tool_version() {
  local tool="$1" exe="$2" line w1="" w2=""
  case "$tool" in
    llvm-link)
      # As scripts/check-saw.sh reads it.
      line="$("$exe" --version 2>&1 | sed -n 's/^ *LLVM version //p')" || true
      printf '%s\n' "${line%%$'\n'*}"
      return 0 ;;
  esac
  line="$(first_line "$exe" --version)"
  read -r w1 w2 _ <<< "$line" || true
  case "$tool" in
    alr)       [ "$w1" = alr ] && printf '%s\n' "$w2" ;;      # alr 2.1.1
    gnatprove) [ "$w1" = FSF ] && printf '%s\n' "$w2" ;;      # FSF 16.1.0
    gnatdoc)   [ "$w1" = GNATdoc ] && printf '%s\n' "$w2" ;;  # GNATdoc 26.0.0 (date)
    cryptol)   [ "$w1" = Cryptol ] && printf '%s\n' "$w2" ;;  # Cryptol 3.6.0
    saw)       # 1.6 (commit release-1.6)
               if [ "$w1" = version ]; then printf '%s\n' "$w2"; else printf '%s\n' "$w1"; fi ;;
  esac
  return 0
}

# Whether EXE is TOOL at version PIN, and usable as such. Cryptol must also
# have FFI support and a z3 beside it or on PATH (its type checker does not
# start without one). Says why when EXE runs but does not match.
tool_matches() {
  local tool="$1" exe="$2" pin="$3" v out
  [ -n "$exe" ] && [ -f "$exe" ] && [ -x "$exe" ] || return 1
  v="$(tool_version "$tool" "$exe")"
  if [ "$v" != "$pin" ]; then
    echo ">> $exe: ${v:-no $tool version}, not the pinned $pin"
    return 1
  fi
  if [ "$tool" = cryptol ]; then
    out="$("$exe" --version 2>&1)" || true
    case "$out" in
      *"FFI enabled"*) ;;
      *) echo ">> $exe: no FFI support"; return 1 ;;
    esac
    if [ ! -x "$(dirname "$exe")/z3" ] && ! command -v z3 >/dev/null 2>&1; then
      echo ">> $exe: no z3 beside it or on PATH"
      return 1
    fi
  fi
  return 0
}

# Set FOUND to the first of the CANDIDATES (executable paths; empty ones are
# skipped) that is TOOL at version PIN. Returns 1, FOUND empty, when none is.
find_tool() {
  local tool="$1" pin="$2" c
  shift 2
  FOUND=""
  for c in "$@"; do
    [ -n "$c" ] || continue
    if tool_matches "$tool" "$c" "$pin"; then FOUND="$c"; return 0; fi
  done
  return 1
}

# The executable PATH finds for NAME, or nothing.
on_path() { command -v "$1" 2>/dev/null || true; }

# PATH's llvm-link, when it sits in a bin/ directory, so that its parent can
# be LLVM_LINK_DIR (scripts/check-saw.sh runs $LLVM_LINK_DIR/bin/llvm-link);
# else nothing.
llvm_link_on_path() {
  local p
  p="$(on_path llvm-link)"
  case "$p" in */bin/llvm-link) printf '%s\n' "$p" ;; esac
  return 0
}

# Whether `alr toolchain`'s listing (LISTING) has CRATE at VERSION selected:
# its row says "Default".
toolchain_selected() {
  printf '%s\n' "$1" | awk -v c="$2" -v v="$3" \
    '$1 == c && $2 == v && $3 == "Default" { found = 1 } END { exit !found }'
}

# PATH is TOOL_PATH (the directories of the tools PATH did not already find,
# in the order added) ahead of the PATH the script started with.
BASE_PATH="$PATH"
TOOL_PATH=""
# Add DIR to TOOL_PATH, at its end, unless it is there already.
add_path() {
  case ":$TOOL_PATH:" in *":$1:"*) return 0 ;; esac
  TOOL_PATH="${TOOL_PATH:+$TOOL_PATH:}$1"
  PATH="$TOOL_PATH:$BASE_PATH"
  export PATH
}
# Make PATH find EXE as its command name: add its directory unless PATH
# already finds EXE itself.
use_tool() {
  local exe="$1"
  [ "$(on_path "$(basename "$exe")")" = "$exe" ] || add_path "$(dirname "$exe")"
}

# Record and say TOOL's state.
tool_present() {
  echo ">> $1 $2: present and matching the pin ($3)"
  TOOL_STATES+=("$(printf '%-12s %-8s %s' "$1" "$2" "present and matching the pin")")
}
tool_fetched() {
  echo ">> $1 $2: fetched ($3)"
  TOOL_STATES+=("$(printf '%-12s %-8s %s' "$1" "$2" "fetched")")
}
# --- end of tool detection ------------------------------------------------------------

# --- prereqs ------------------------------------------------------------------------

begin prereqs
if [ "$(uname -s)" != Linux ] || [ "$(uname -m)" != x86_64 ]; then
  die "this script is for x86_64 Linux, not $(uname -s) $(uname -m)"
fi
if [ -r /etc/os-release ]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  if [ "${ID:-}" != ubuntu ] || [ "${VERSION_ID:-}" != 24.04 ]; then
    warn "expected Ubuntu 24.04, found ${PRETTY_NAME:-unknown}; the release binaries are built for 24.04"
  fi
fi
need=()
for c in curl:curl git:git python3:python3 tar:tar gzip:gzip sha256sum:coreutils \
         od:coreutils ldd:libc-bin; do
  command -v "${c%%:*}" >/dev/null 2>&1 || need+=("${c#*:}")
done
# (xz, for LLVM's .tar.xz, is the gnat-llvm phase's, when it fetches.)
# curl over https needs the CA bundle; GNAT links against the C library's
# start files and libc.so, which come with libc6-dev.
[ -f /etc/ssl/certs/ca-certificates.crt ] || need+=(ca-certificates)
[ -f /usr/lib/x86_64-linux-gnu/crt1.o ] || need+=(libc6-dev)
if [ "${#need[@]}" -gt 0 ]; then
  # shellcheck disable=SC2207  # package names have no spaces
  need=($(printf '%s\n' "${need[@]}" | sort -u))
  apt_install "${need[@]}"
else
  echo ">> curl, git, python3, CA certificates and libc6-dev present"
fi
mkdir -p "$TOOLS/downloads"
end

# --- clone ----------------------------------------------------------------------------

begin clone
if [ ! -e "$REPO/.git" ]; then
  git clone "$REMOTE" "$REPO"
else
  echo ">> $REPO exists: fetching"
  git -C "$REPO" fetch --prune origin
  if [ -z "$REF" ]; then
    if git -C "$REPO" symbolic-ref -q HEAD >/dev/null \
       && git -C "$REPO" rev-parse -q --verify '@{u}' >/dev/null \
       && [ -z "$(git -C "$REPO" status --porcelain --untracked-files=no)" ]; then
      git -C "$REPO" merge --ff-only '@{u}' \
        || warn "$REPO: cannot fast-forward $(git -C "$REPO" branch --show-current); left as it is"
    else
      warn "$REPO: detached, without an upstream, or with local changes; left as it is"
    fi
  fi
fi
if [ -n "$REF" ]; then
  [ -z "$(git -C "$REPO" status --porcelain --untracked-files=no)" ] \
    || die "$REPO has local changes; not checking out $REF over them"
  git -C "$REPO" fetch origin "$REF"
  git -C "$REPO" -c advice.detachedHead=false checkout --detach FETCH_HEAD
fi
echo ">> $REPO at $(git -C "$REPO" rev-parse --short HEAD) ($(git -C "$REPO" log -1 --format=%s))"

PINS="$REPO/spark/scripts/toolchain-pins.env"
[ -f "$PINS" ] || die "$PINS missing: is $REPO a checkout of the fork at M0.5 or later?"
# shellcheck source=/dev/null  # the clone's copy, not this script's sibling
. "$PINS"
# Where a tool goes when it is fetched (and where a later run finds it).
ALR_DIR="$TOOLS/alr-$ALR_VERSION"
ALIRE_BIN="$HOME/.alire/bin"
CRYPTOL_DIR="$TOOLS/cryptol-$CRYPTOL_VERSION"
SAW_DIR="$TOOLS/saw-$SAW_VERSION"
end

# --- alire ----------------------------------------------------------------------------

begin alire
if find_tool alr "$ALR_VERSION" "$(on_path alr)" "$ALR_DIR/bin/alr"; then
  tool_present alr "$ALR_VERSION" "$FOUND"
else
  zip="$TOOLS/downloads/alr-$ALR_VERSION-bin-x86_64-linux.zip"
  fetch "https://github.com/alire-project/alire/releases/download/v$ALR_VERSION/alr-$ALR_VERSION-bin-x86_64-linux.zip" \
        "$zip" "$ALR_X86_64_LINUX_SHA256"
  rm -rf "$ALR_DIR.new"
  # python3's zipfile, not unzip: one less package on a bare image.
  python3 -I -m zipfile -e "$zip" "$ALR_DIR.new"
  chmod +x "$ALR_DIR.new/bin/alr"
  rm -rf "$ALR_DIR"
  mv "$ALR_DIR.new" "$ALR_DIR"
  tool_matches alr "$ALR_DIR/bin/alr" "$ALR_VERSION" || die "the fetched alr is not $ALR_VERSION"
  FOUND="$ALR_DIR/bin/alr"
  tool_fetched alr "$ALR_VERSION" "$FOUND"
fi
ALR="$FOUND"
use_tool "$ALR"

# As alire-project/setup-alire does for CI: select the pinned toolchain, then
# install the tools (not crate dependencies) into ~/.alire/bin; each only
# when it is not already there. From $HOME, so no crate in the current
# directory is involved.
toolchains="$(cd "$HOME" && alr -n toolchain 2>&1)" || true
if toolchain_selected "$toolchains" gnat_native "$GNAT_NATIVE_VERSION" \
   && toolchain_selected "$toolchains" gprbuild "$GPRBUILD_VERSION"; then
  tool_present gnat_native "$GNAT_NATIVE_VERSION" "alr toolchain"
  tool_present gprbuild "$GPRBUILD_VERSION" "alr toolchain"
else
  (cd "$HOME" && alr -n toolchain --select "gnat_native=$GNAT_NATIVE_VERSION" "gprbuild=$GPRBUILD_VERSION")
  toolchains="$(cd "$HOME" && alr -n toolchain 2>&1)" || true
  if ! { toolchain_selected "$toolchains" gnat_native "$GNAT_NATIVE_VERSION" \
         && toolchain_selected "$toolchains" gprbuild "$GPRBUILD_VERSION"; }; then
    die "alr toolchain did not select gnat_native $GNAT_NATIVE_VERSION and gprbuild $GPRBUILD_VERSION:
$toolchains"
  fi
  tool_fetched gnat_native "$GNAT_NATIVE_VERSION" "alr toolchain --select"
  tool_fetched gprbuild "$GPRBUILD_VERSION" "alr toolchain --select"
fi

# gnatprove and gnatdoc (crate gnatdoc_bin).
GNATPROVE=""
GNATDOC=""
to_install=()
if find_tool gnatprove "$GNATPROVE_VERSION" "$(on_path gnatprove)" "$ALIRE_BIN/gnatprove"; then
  GNATPROVE="$FOUND"
  tool_present gnatprove "$GNATPROVE_VERSION" "$GNATPROVE"
else
  to_install+=("gnatprove=$GNATPROVE_VERSION")
fi
if find_tool gnatdoc "$GNATDOC_VERSION" "$(on_path gnatdoc)" "$ALIRE_BIN/gnatdoc"; then
  GNATDOC="$FOUND"
  tool_present gnatdoc "$GNATDOC_VERSION" "$GNATDOC"
else
  to_install+=("gnatdoc_bin=$GNATDOC_VERSION")
fi
if [ "${#to_install[@]}" -gt 0 ]; then
  (cd "$HOME" && alr -n install "${to_install[@]}")
  if [ -z "$GNATPROVE" ]; then
    tool_matches gnatprove "$ALIRE_BIN/gnatprove" "$GNATPROVE_VERSION" \
      || die "alr install did not leave gnatprove $GNATPROVE_VERSION in $ALIRE_BIN"
    GNATPROVE="$ALIRE_BIN/gnatprove"
    tool_fetched gnatprove "$GNATPROVE_VERSION" "$GNATPROVE"
  fi
  if [ -z "$GNATDOC" ]; then
    tool_matches gnatdoc "$ALIRE_BIN/gnatdoc" "$GNATDOC_VERSION" \
      || die "alr install did not leave gnatdoc $GNATDOC_VERSION in $ALIRE_BIN"
    GNATDOC="$ALIRE_BIN/gnatdoc"
    tool_fetched gnatdoc "$GNATDOC_VERSION" "$GNATDOC"
  fi
fi
use_tool "$GNATPROVE"
use_tool "$GNATDOC"
# Captured, not piped into head: gnatprove dies of SIGPIPE under pipefail.
gp_version="$(gnatprove --version)"
printf '%s\n' "$gp_version"
end

# --- cryptol --------------------------------------------------------------------------

begin cryptol
if find_tool cryptol "$CRYPTOL_VERSION" "$(on_path cryptol)" "$CRYPTOL_DIR/bin/cryptol"; then
  tool_present cryptol "$CRYPTOL_VERSION" "$FOUND"
else
  fetch "https://github.com/GaloisInc/cryptol/releases/download/$CRYPTOL_VERSION/$CRYPTOL_TARBALL" \
        "$TOOLS/downloads/$CRYPTOL_TARBALL" "$CRYPTOL_SHA256"
  unpack "$TOOLS/downloads/$CRYPTOL_TARBALL" "$CRYPTOL_DIR" "$CRYPTOL_SHA256"
  ensure_libs "$CRYPTOL_DIR"
  tool_matches cryptol "$CRYPTOL_DIR/bin/cryptol" "$CRYPTOL_VERSION" \
    || die "the fetched cryptol is not a usable $CRYPTOL_VERSION"
  FOUND="$CRYPTOL_DIR/bin/cryptol"
  tool_fetched cryptol "$CRYPTOL_VERSION" "$FOUND"
fi
CRYPTOL="$FOUND"
use_tool "$CRYPTOL"
cr_version="$(cryptol --version)"
printf '%s\n' "$cr_version"
end

# --- saw ------------------------------------------------------------------------------

begin saw
if find_tool saw "$SAW_VERSION" "$(on_path saw)" "$SAW_DIR/bin/saw"; then
  tool_present saw "$SAW_VERSION" "$FOUND"
else
  fetch "https://github.com/GaloisInc/saw-script/releases/download/$SAW_TAG/$SAW_TARBALL" \
        "$TOOLS/downloads/$SAW_TARBALL" "$SAW_SHA256"
  if [ -n "${SAW_SIGNING_KEY_FILE:-}" ]; then
    command -v gpg >/dev/null 2>&1 || die "SAW_SIGNING_KEY_FILE is set but gpg is not installed"
    sig="$TOOLS/downloads/$SAW_TARBALL.sig"
    curl -fsSL --retry 3 -o "$sig" \
      "https://github.com/GaloisInc/saw-script/releases/download/$SAW_TAG/$SAW_TARBALL.sig"
    gnupg="$(mktemp -d)"
    GNUPGHOME="$gnupg" gpg --batch --quiet --import "$SAW_SIGNING_KEY_FILE"
    GNUPGHOME="$gnupg" gpg --batch --with-colons --list-keys | grep -q "^fpr:::::::::$SAW_SIGNING_KEY:" \
      || die "$SAW_SIGNING_KEY_FILE is not key $SAW_SIGNING_KEY"
    GNUPGHOME="$gnupg" gpg --batch --verify "$sig" "$TOOLS/downloads/$SAW_TARBALL" \
      || die "SAW signature does not verify"
    rm -rf "$gnupg"
  else
    echo ">> SAW .sig not verified (no SAW_SIGNING_KEY_FILE; signer $SAW_SIGNING_KEY); sha256 pinned"
  fi
  unpack "$TOOLS/downloads/$SAW_TARBALL" "$SAW_DIR" "$SAW_SHA256"
  ensure_libs "$SAW_DIR"
  tool_matches saw "$SAW_DIR/bin/saw" "$SAW_VERSION" || die "the fetched saw is not $SAW_VERSION"
  FOUND="$SAW_DIR/bin/saw"
  tool_fetched saw "$SAW_VERSION" "$FOUND"
fi
SAW="$FOUND"
# SAW's bin/ carries a cryptol of its own: Cryptol's directory goes first,
# so check-ffi.sh still gets the one chosen above.
if [ "$(on_path saw)" != "$SAW" ]; then
  add_path "$(dirname "$CRYPTOL")"
  add_path "$(dirname "$SAW")"
fi
"$SAW" --version
end

# Every chosen tool must be the one PATH finds: a directory added for one
# tool can hold another version of another (each was checked where it is).
for t in "$ALR" "$GNATPROVE" "$GNATDOC" "$CRYPTOL" "$SAW"; do
  [ "$(on_path "$(basename "$t")")" = "$t" ] \
    || die "PATH finds $(basename "$t") at $(on_path "$(basename "$t")"), not the chosen $t (PATH: $PATH)"
done

# --- gnat-llvm ------------------------------------------------------------------------

begin gnat-llvm
# The GNAT-LLVM that E4's SAW checks use is GNAT Pro's (M4.1, #22), which is
# not public: nothing of it is downloaded. When GNAT_LLVM_DIR names its
# install, check it and record it in env.sh for scripts/check-saw.sh; when it
# is unset, skip: everything but check-saw.sh works without it. It is not put
# on PATH: the crate's toolchain stays FSF GNAT (README "SAW").
#
# check-saw.sh also needs llvm-link (M4.2, #23), which GNAT Pro does not
# ship, of the same LLVM version, pinned in toolchain-pins.env. Present:
# LLVM_LINK_DIR's bin/llvm-link, else PATH's (in a bin/ directory, whose
# parent becomes LLVM_LINK_DIR), else an earlier run's. Fetched: from LLVM's
# own release; the tarball is 2 GB, and only bin/llvm-link, linked against
# libc and libz only, is extracted, to $TOOLS/llvm-<version>. Either way its
# directory is written to env.sh as LLVM_LINK_DIR. (Until #68, bin/opt and
# bin/llvm-extract were extracted too, for a GEP rewrite #68 retired.)
# Only when GNAT_LLVM_DIR is set: nothing else uses it.
GNAT_LLVM_ENV=""
LLVM_LINK_GIVEN="${LLVM_LINK_DIR:-}"
LLVM_LINK_FETCH_DIR="$TOOLS/llvm-$LLVM_LINK_VERSION"
if [ -n "${GNAT_LLVM_DIR:-}" ]; then
  [ -x "$GNAT_LLVM_DIR/bin/llvm-gcc" ] || die "GNAT_LLVM_DIR=$GNAT_LLVM_DIR has no bin/llvm-gcc"
  [ -x "$GNAT_LLVM_DIR/bin/llvm-nm" ] || die "GNAT_LLVM_DIR=$GNAT_LLVM_DIR has no bin/llvm-nm"
  # Captured, not piped into head: SIGPIPE under pipefail.
  llvm_gcc_version="$("$GNAT_LLVM_DIR/bin/llvm-gcc" --version)"
  echo ">> GNAT_LLVM_DIR=$GNAT_LLVM_DIR: ${llvm_gcc_version%%$'\n'*}"
  gnat_llvm_version="$("$GNAT_LLVM_DIR/bin/llvm-nm" --version 2>&1 | sed -n 's/^ *LLVM version //p')"
  [ "$gnat_llvm_version" = "$LLVM_LINK_VERSION" ] \
    || die "GNAT_LLVM_DIR's LLVM is ${gnat_llvm_version:-?}, but toolchain-pins.env pins llvm-link $LLVM_LINK_VERSION: they must match"

  if find_tool llvm-link "$LLVM_LINK_VERSION" \
       "${LLVM_LINK_GIVEN:+$LLVM_LINK_GIVEN/bin/llvm-link}" "$(llvm_link_on_path)" \
       "$LLVM_LINK_FETCH_DIR/bin/llvm-link"; then
    tool_present llvm-link "$LLVM_LINK_VERSION" "$FOUND"
  else
    command -v xz >/dev/null 2>&1 || apt_install xz-utils
    fetch "https://github.com/llvm/llvm-project/releases/download/$LLVM_LINK_TAG/$LLVM_LINK_TARBALL" \
          "$TOOLS/downloads/$LLVM_LINK_TARBALL" "$LLVM_LINK_SHA256"
    rm -rf "$LLVM_LINK_FETCH_DIR.new"
    mkdir -p "$LLVM_LINK_FETCH_DIR.new"
    echo ">> extracting bin/llvm-link from $LLVM_LINK_TARBALL"
    tar -xJf "$TOOLS/downloads/$LLVM_LINK_TARBALL" -C "$LLVM_LINK_FETCH_DIR.new" --strip-components=1 \
        "${LLVM_LINK_TARBALL%.tar.xz}/bin/llvm-link"
    echo "$LLVM_LINK_SHA256" > "$LLVM_LINK_FETCH_DIR.new/.bootstrap-sha256"
    rm -rf "$LLVM_LINK_FETCH_DIR"
    mv "$LLVM_LINK_FETCH_DIR.new" "$LLVM_LINK_FETCH_DIR"
    ensure_libs "$LLVM_LINK_FETCH_DIR"
    tool_matches llvm-link "$LLVM_LINK_FETCH_DIR/bin/llvm-link" "$LLVM_LINK_VERSION" \
      || die "the fetched llvm-link is not LLVM $LLVM_LINK_VERSION"
    FOUND="$LLVM_LINK_FETCH_DIR/bin/llvm-link"
    tool_fetched llvm-link "$LLVM_LINK_VERSION" "$FOUND"
  fi
  LLVM_LINK_DIR="${FOUND%/bin/llvm-link}"
  echo ">> LLVM_LINK_DIR=$LLVM_LINK_DIR"

  GNAT_LLVM_ENV="export GNAT_LLVM_DIR=\"$GNAT_LLVM_DIR\"
export LLVM_LINK_DIR=\"$LLVM_LINK_DIR\""
  end
else
  echo ">> skipped: GNAT_LLVM_DIR is unset. Only scripts/check-saw.sh (local, E4) needs it:"
  echo "   set it to a GNAT Pro LLVM install (the directory holding bin/llvm-gcc) and rerun."
  end "skipped (no GNAT_LLVM_DIR)"
fi

# Write the environment for later shells, before the checks, so a failed
# check still leaves the tools usable.
cat > "$TOOLS/env.sh" <<EOF
# Written by spark/scripts/bootstrap-x86_64.sh. Source it: . $TOOLS/env.sh
export PATH="${TOOL_PATH:+$TOOL_PATH:}\$PATH"
$GNAT_LLVM_ENV
EOF

# --- build, proof, ffi ------------------------------------------------------------------

FAILED=0
if [ "$CHECKS" -eq 1 ]; then
  begin build
  (cd "$REPO/spark" && alr -n build)
  end

  begin proof
  if [ "$PROOF" -eq 0 ]; then
    # The proof gate is arm64 only: on x86_64 the provers are slower on some
    # goals, and six AES checks run out of time (README "Bootstrapping the
    # x86_64 instance"). Build and ffi still run.
    echo ">> skipped: --no-proof (the proof gate runs on arm64 only)"
    end "skipped (--no-proof: proof gate is arm64 only)"
  else
    # CI's allowance by default: the instance's speed is unknown, and the
    # allowance never shortens a committed level (README "Levels").
    export FOUNDATION_SPARK_PROOF_ALLOWANCE="${FOUNDATION_SPARK_PROOF_ALLOWANCE:-ci}"
    echo ">> PROVE_JOBS=${PROVE_JOBS:-$(nproc)} FOUNDATION_SPARK_PROOF_ALLOWANCE=$FOUNDATION_SPARK_PROOF_ALLOWANCE"
    # A cold run proves every goal at once on every core, and a goal near its
    # time limit can miss it under that load. One retry: gnatprove replays
    # what proved from its session files, so only the unproved goals run
    # again, at the same level and limits. The phase says when it took the
    # retry, so a pass on retry is never reported as a first-time pass.
    if "$REPO/spark/scripts/check-proof.sh"; then
      end
    else
      log "proof: retrying once (proved goals replay from the session; the rest run again, same limits)"
      if "$REPO/spark/scripts/check-proof.sh"; then end "ok on retry"; else FAILED=1; end FAILED; fi
    fi
  fi

  begin ffi
  if "$REPO/spark/scripts/check-ffi.sh"; then end; else FAILED=1; end FAILED; fi
fi

log "done"
echo "Checkout in $REPO; tools as listed at the end. For a new shell:"
echo
if [ -n "$TOOL_PATH" ]; then
  echo "  export PATH=\"$TOOL_PATH:\$PATH\""
else
  echo "  (nothing to add: PATH already finds every tool)"
fi
echo
echo "(or: . $TOOLS/env.sh)"
[ "$FAILED" -eq 0 ] || { warn "a check failed (above)"; exit 1; }
exit 0
