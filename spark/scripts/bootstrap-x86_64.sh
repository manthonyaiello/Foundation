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
#   curl -fsSL https://raw.githubusercontent.com/manthonyaiello/Foundation/main/spark/scripts/bootstrap-x86_64.sh | bash
#
# Phases, each timed (wall-clock, printed at the end and on failure):
#   prereqs    the commands and libraries the rest needs (curl, git, python3,
#              CA certificates, libc6-dev; the shared libraries Cryptol and
#              SAW link against). The ONLY phase that may need root: missing
#              packages are apt-installed when running as root or with
#              passwordless sudo, and otherwise the script stops and prints
#              the one `sudo apt-get install` line to run.
#   clone      clone the fork, or fetch it and fast-forward a clean checkout.
#              The versions below are read from ITS
#              spark/scripts/toolchain-pins.env, the file CI's
#              setup-alire-spark action reads too.
#   alire      alr (release zip, sha256 checked), the gnat_native and
#              gprbuild toolchain (`alr toolchain --select`), gnatprove and
#              gnatdoc_bin (`alr install`, into ~/.alire/bin), as CI does.
#   cryptol    Cryptol's release build with solvers, sha256 checked.
#   saw        SAW's release build with solvers, sha256 checked (and its .sig,
#              when SAW_SIGNING_KEY_FILE names the signing key).
#   gnat-llvm  a hook only: M4.1 (#22) adds GNAT-LLVM there.
#   build      `alr -n build` in spark/.
#   proof      scripts/check-proof.sh (the slow units of proof-slow.txt are
#              skipped, and their recorded proofs checked current, as in CI),
#              retried once if it fails; the phase says "ok on retry" then.
#   ffi        scripts/check-ffi.sh.
#
# Usage:
#   bootstrap-x86_64.sh               everything
#   bootstrap-x86_64.sh --no-checks   tools and clone only (no build/proof/ffi)
#
# Env:
#   FOUNDATION_TOOLS   where alr, Cryptol and SAW go (default ~/foundation-tools).
#                      Alire's own state stays where alr puts it (~/.alire,
#                      ~/.config/alire, ~/.local/share/alire), as in CI.
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
#
# Exit status: 0 when every phase passed; 1 when one failed (the proof and FFI
# phases both run even if the other fails, so one run reports both); 2 on a
# usage error.
#
set -euo pipefail

REMOTE_DEFAULT="https://github.com/manthonyaiello/Foundation.git"

CHECKS=1
case "${1:-}" in
  "") ;;
  --no-checks) CHECKS=0 ;;
  -h|--help) sed -n '2,/^set -euo/p' "${BASH_SOURCE[0]:-/dev/null}" | sed '$d'; exit 0 ;;
  *) echo "bootstrap-x86_64.sh: unknown argument: $1" >&2; exit 2 ;;
esac

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
T_START="$(date +%s)"

# shellcheck disable=SC2317  # reached through the EXIT trap
report() {
  local total=$(( $(date +%s) - T_START )) line
  {
    echo
    echo "== wall-clock per phase ($(uname -m), $(nproc) CPUs)"
    printf '%-10s %8s  %s\n' phase seconds result
    for line in "${PHASES[@]+"${PHASES[@]}"}"; do printf '%s\n' "$line"; done
    printf '%-10s %8s\n' total "$total"
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
    } >> "$GITHUB_STEP_SUMMARY"
  fi
}

# A tool phase that fails stops the run; the report is still printed.
CURRENT=""
CURRENT_T0=0
# shellcheck disable=SC2317  # reached through the EXIT trap
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
ALR_DIR="$TOOLS/alr-$ALR_VERSION"
CRYPTOL_DIR="$TOOLS/cryptol-$CRYPTOL_VERSION"
SAW_DIR="$TOOLS/saw-$SAW_VERSION"
# Cryptol before SAW: SAW's bin/ carries its own cryptol, and check-ffi.sh
# must get the pinned one.
TOOL_PATH="$ALR_DIR/bin:$HOME/.alire/bin:$CRYPTOL_DIR/bin:$SAW_DIR/bin"
export PATH="$TOOL_PATH:$PATH"
end

# --- alire ----------------------------------------------------------------------------

begin alire
if [ -x "$ALR_DIR/bin/alr" ] && [ "$("$ALR_DIR/bin/alr" --version 2>/dev/null)" = "alr $ALR_VERSION" ]; then
  echo ">> alr $ALR_VERSION already installed"
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
fi
alr --version
# As alire-project/setup-alire does for CI: select the pinned toolchain, then
# install the tools (not crate dependencies) into ~/.alire/bin. Both are
# no-ops when already done (`alr install` reinstalls only with --force).
# From $HOME, so no crate in the current directory is involved.
(cd "$HOME" && alr -n toolchain --select "gnat_native=$GNAT_NATIVE_VERSION" "gprbuild=$GPRBUILD_VERSION")
(cd "$HOME" && alr -n install "gnatprove=$GNATPROVE_VERSION" "gnatdoc_bin=$GNATDOC_VERSION")
# Captured, not piped into head: gnatprove dies of SIGPIPE under pipefail.
gp_version="$(gnatprove --version)"
printf '%s\n' "$gp_version"
case "$gp_version" in *"$GNATPROVE_VERSION"*) ;; *) die "gnatprove on PATH is not $GNATPROVE_VERSION: $(command -v gnatprove)" ;; esac
end

# --- cryptol --------------------------------------------------------------------------

begin cryptol
fetch "https://github.com/GaloisInc/cryptol/releases/download/$CRYPTOL_VERSION/$CRYPTOL_TARBALL" \
      "$TOOLS/downloads/$CRYPTOL_TARBALL" "$CRYPTOL_SHA256"
unpack "$TOOLS/downloads/$CRYPTOL_TARBALL" "$CRYPTOL_DIR" "$CRYPTOL_SHA256"
ensure_libs "$CRYPTOL_DIR"
[ "$(command -v cryptol)" = "$CRYPTOL_DIR/bin/cryptol" ] \
  || die "cryptol on PATH is $(command -v cryptol), not $CRYPTOL_DIR/bin/cryptol"
cr_version="$(cryptol --version)"
printf '%s\n' "$cr_version"
case "$cr_version" in *"FFI enabled"*) ;; *) die "cryptol lacks FFI support" ;; esac
end

# --- saw ------------------------------------------------------------------------------

begin saw
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
"$SAW_DIR/bin/saw" --version
end

# --- gnat-llvm ------------------------------------------------------------------------

begin gnat-llvm
# >>> M4.1 (#22) HOOK: install GNAT-LLVM here. <<<
# Not part of M0.5: there is no GNAT-LLVM build to pin yet. M4.1 adds its
# pins to toolchain-pins.env, installs it under "$TOOLS", puts its bin/ on
# TOOL_PATH (above) and checks its version, as the cryptol phase does.
echo ">> not installed: M4.1 (#22) adds GNAT-LLVM here"
end "hook only (M4.1)"

# Write the environment for later shells, before the checks, so a failed
# check still leaves the tools usable.
cat > "$TOOLS/env.sh" <<EOF
# Written by spark/scripts/bootstrap-x86_64.sh. Source it: . $TOOLS/env.sh
export PATH="$TOOL_PATH:\$PATH"
EOF

# --- build, proof, ffi ------------------------------------------------------------------

FAILED=0
if [ "$CHECKS" -eq 1 ]; then
  begin build
  (cd "$REPO/spark" && alr -n build)
  end

  begin proof
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

  begin ffi
  if "$REPO/spark/scripts/check-ffi.sh"; then end; else FAILED=1; end FAILED; fi
fi

log "done"
echo "Tools in $TOOLS, checkout in $REPO. For a new shell:"
echo
echo "  export PATH=\"$TOOL_PATH:\$PATH\""
echo
echo "(or: . $TOOLS/env.sh)"
[ "$FAILED" -eq 0 ] || { warn "a check failed (above)"; exit 1; }
exit 0
