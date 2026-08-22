# shellcheck shell=bash
#
# hm — preview, apply and record home-manager changes.
#
#   hm #<target> [-u]  build <target>, show what changes, then offer to apply
#   hm list            recent generations, with what changed in each
#   hm diff [a] [b]    version diff between generations
#   hm rollback [n]    activate generation n (default: the previous one)
#
# The build is the expensive part, so it always happens before the prompt and
# the result is kept as a GC root — saying "no" costs nothing but the wait, and
# saying "yes" later reuses it.

FLAKE="${HM_FLAKE:-$HOME/.dotfiles}"
PROFILES="${XDG_STATE_HOME:-$HOME/.local/state}/nix/profiles"
PROFILE="$PROFILES/home-manager"
RESULTS="${XDG_STATE_HOME:-$HOME/.local/state}/hm"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/nix"
PINS="$RESULTS/pinned"

if [ -t 1 ]; then
  BOLD=$'\033[1m' DIM=$'\033[2m' RED=$'\033[31m' YEL=$'\033[33m' GRN=$'\033[32m' OFF=$'\033[0m'
  NVD_COLOUR=always ISATTY=1
else
  BOLD='' DIM='' RED='' YEL='' GRN='' OFF=''
  NVD_COLOUR=never ISATTY=0
fi

step() { printf '%s→%s %s\n' "$GRN" "$OFF" "$*"; }
warn() { printf '%s!%s %s\n' "$YEL" "$OFF" "$*" >&2; }
die() {
  printf '%serror:%s %s\n' "$RED" "$OFF" "$*" >&2
  exit 1
}

# confirm <prompt> <default y|n>
confirm() {
  local reply hint
  if [ "$2" = y ]; then hint='[Y/n]'; else hint='[y/N]'; fi
  if [ ! -t 0 ]; then
    printf '%s %s %s (no tty)\n' "$1" "$hint" "$2"
    [ "$2" = y ]
    return
  fi
  printf '%s%s%s %s ' "$BOLD" "$1" "$OFF" "$hint"
  read -r reply || reply=''
  case "${reply:-$2}" in
  [yY]*) return 0 ;;
  *) return 1 ;;
  esac
}

TARGETS=''
targets() {
  if [ -z "$TARGETS" ]; then
    TARGETS=$(
      nix eval --impure --json "$FLAKE#homeConfigurations" --apply builtins.attrNames 2>/dev/null |
        tr -d '[]"' | tr ',' ' '
    ) || TARGETS=''
  fi
  printf '%s' "$TARGETS"
}

# Same names as targets(), written the way you type them.
targets_pretty() {
  local t out=''
  for t in $(targets); do out="$out #$t"; done
  printf '%s' "${out# }"
}

usage() {
  cat <<EOF
${BOLD}hm${OFF} — preview, apply and record home-manager changes

  hm #<target> [-u]  build <target>, show what changes, then offer to apply
  hm list            recent generations, with what changed in each
  hm diff [a] [b]    version diff between generations
                     (no args: previous → current; one: a → current)
  hm rollback [n]    activate generation n (default: the previous one)
  hm purge [days]    delete generations older than days (default 30), then
                     collect garbage and optimise the store
  hm -h              this

  -u, --update       run 'nix flake update' before building

targets: $(targets_pretty)
flake:   $FLAKE (override with \$HM_FLAKE)
EOF
}

# ---------------------------------------------------------------- generations

gen_num() {
  local link
  link=$(readlink "$PROFILE") || return 1
  link=${link##*/}
  link=${link#home-manager-}
  printf '%s' "${link%-link}"
}

all_gens() {
  local link id
  for link in "$PROFILES"/home-manager-*-link; do
    [ -e "$link" ] || continue
    id=${link##*/home-manager-}
    printf '%s\n' "${id%-link}"
  done | sort -n
}

prev_gen() {
  all_gens | awk -v c="$1" '$1 + 0 < c + 0' | tail -1
}

# "~25 +4 -1" — upgraded, added, removed between two generations.
gen_summary() {
  local a=$1 b=$2 out
  if ! out=$(nvd diff "$PROFILES/home-manager-$a-link" "$PROFILES/home-manager-$b-link" 2>/dev/null); then
    printf '%s ?\n' "$b"
    return 0
  fi
  printf '%s %s\n' "$b" "$(printf '%s\n' "$out" | awk '
    /^\[U\./ { u++ } /^\[A\./ { a++ } /^\[R\./ { r++ }
    END {
      s = ""
      if (u) s = s "~" u " "
      if (a) s = s "+" a " "
      if (r) s = s "-" r
      sub(/ +$/, "", s)
      print (s == "" ? "" : s)
    }')"
}

cmd_list() {
  local cur id link when sum i ids summaries
  cur=$(gen_num) || cur=''
  mapfile -t ids < <(all_gens | tail -15)

  # ~0.7s each, so run the whole column at once rather than in sequence.
  summaries=$(
    for ((i = 1; i < ${#ids[@]}; i++)); do
      gen_summary "${ids[i - 1]}" "${ids[i]}" &
    done
    wait
  )

  for id in "${ids[@]}"; do
    link="$PROFILES/home-manager-$id-link"
    when=$(stat -c '%y' "$link" 2>/dev/null | cut -c1-16) || when='?'
    sum=$(printf '%s\n' "$summaries" | awk -v g="$id" '$1 == g { $1 = ""; sub(/^ /, ""); print; exit }')
    if [ "$id" = "$cur" ]; then
      printf '%4s  %s  %s%-12s%s %s(current)%s\n' "$id" "$when" "$DIM" "$sum" "$OFF" "$GRN" "$OFF"
    else
      printf '%4s  %s  %s%s%s\n' "$id" "$when" "$DIM" "$sum" "$OFF"
    fi
  done
}

cmd_diff() {
  local a=$1 b=$2 cur la lb
  cur=$(gen_num) || die "no current home-manager generation"
  if [ -z "$a" ]; then
    a=$(prev_gen "$cur")
    [ -n "$a" ] || die "no generation older than $cur"
  fi
  [ -n "$b" ] || b=$cur

  la="$PROFILES/home-manager-$a-link"
  lb="$PROFILES/home-manager-$b-link"
  [ -e "$la" ] || die "no such generation: $a (see 'hm list')"
  [ -e "$lb" ] || die "no such generation: $b (see 'hm list')"

  step "generation $a → $b"
  render_diff "$(nvd_diff "$la" "$lb")" "$(direct_union "$la" "$lb")"
}

cmd_rollback() {
  local want=${1:-} cur to link
  cur=$(gen_num) || die "no current home-manager generation"

  if [ -n "$want" ]; then
    to=$want
    [ "$to" != "$cur" ] || die "generation $cur is already current"
  else
    to=$(prev_gen "$cur")
    [ -n "$to" ] || die "no generation older than $cur"
  fi

  link="$PROFILES/home-manager-$to-link"
  [ -e "$link" ] || die "no such generation: $to (see 'hm list')"

  step "generation $cur → $to — this would change:"
  render_diff "$(nvd_diff "$PROFILE" "$link")" "$(direct_union "$PROFILE" "$link")"
  echo
  if ! confirm "Activate generation $to?" n; then
    echo "aborted."
    return 0
  fi
  "$link/activate"
}

# ---------------------------------------------------------------------- purge

# Every profile under $PROFILES: a bare symlink with numbered generations
# beside it. home-manager is one, nix-env's "profile" is another, and old
# generations of either pin their whole closure just the same.
profile_roots() {
  local p
  for p in "$PROFILES"/*; do
    case "$p" in *-[0-9]*-link) continue ;; esac
    if [ -L "$p" ]; then printf '%s\n' "$p"; fi
  done
}

# Generation ids of <profile>, oldest first.
prof_gens() {
  local link id
  for link in "$1"-[0-9]*-link; do
    if [ -e "$link" ]; then
      id=${link%-link}
      printf '%s\n' "${id##*-}"
    fi
  done | sort -n
}

prof_cur() {
  local t
  t=$(readlink "$1") || return 1
  t=${t%-link}
  printf '%s' "${t##*-}"
}

# Generations of <profile> older than <cutoff>, minus the two always kept: the
# live one, and the one behind it — so rollback survives a purge even on a
# machine that has not switched in months.
prof_doomed() {
  local prof=$1 cutoff=$2 cur keep id when
  cur=$(prof_cur "$prof") || return 0
  keep=$(prof_gens "$prof" | awk -v c="$cur" '$1 + 0 < c + 0' | tail -1)
  for id in $(prof_gens "$prof"); do
    if [ "$id" = "$cur" ] || [ "$id" = "$keep" ]; then continue; fi
    when=$(stat -c %Y "$prof-$id-link" 2>/dev/null) || continue
    if [ "$when" -lt "$cutoff" ]; then printf '%s\n' "$id"; fi
  done
}

# hm keeps a GC root per target so a build you declined is still there when you
# say yes. Nothing else knows to remove them, so one left behind by a build you
# never applied pins its closure forever.
stale_roots() {
  local r cur
  [ -d "$RESULTS" ] || return 0
  cur=$(readlink -f "$PROFILE" 2>/dev/null) || cur=''
  for r in "$RESULTS"/next-*; do
    if [ -L "$r" ] && [ "$(readlink -f "$r")" != "$cur" ]; then
      printf '%s\n' "$r"
    fi
  done
}

# Roots that are not ours: ./result links in projects, dev shells, whatever
# else got registered. The collector traces from these, so everything they
# reach survives — but only because they are registered, so show them and let
# the reader confirm nothing is missing from the list.
other_roots() {
  local l t
  for l in /nix/var/nix/gcroots/auto/*; do
    [ -L "$l" ] || continue
    t=$(readlink "$l") || continue
    case "$t" in
    "$PROFILES"/* | "$RESULTS"/* | /nix/var/nix/profiles/*) continue ;;
    "${XDG_STATE_HOME:-$HOME/.local/state}"/home-manager/*) continue ;;
    esac
    # Dangling ones protect nothing; nix drops them during the sweep.
    if [ -e "$t" ]; then printf '%s\n' "${t/#$HOME/\~}"; fi
  done | sort -u
}

# Store paths holding a real .app bundle. Since Sonoma, macOS App Management
# will not let anything modify a signed bundle without Full Disk Access — not
# even root, which is what the nix daemon doing the deleting runs as. nix chmods
# a path writable before unlinking it, so one dead GUI app aborts the whole
# sweep, and worse, it has already dropped the path from its database by then:
# what is left is a directory nix no longer believes in, which trips the next
# sweep in exactly the same place. So they have to be kept out of the sweep's
# way rather than tried and failed on. One level below the store root, so this
# is a directory scan, not a walk — under a second on a store of 100k paths.
app_bundles() {
  local d
  find /nix/store -maxdepth 2 -name Applications -type d 2>/dev/null |
    while IFS= read -r d; do
      if [ -n "$(find "$d" -maxdepth 2 -name '*.app' -type d -print -quit 2>/dev/null)" ]; then
        printf '%s\n' "${d%/Applications}"
      fi
    done
}

# The wreckage of an earlier sweep: on disk, but no longer a path nix knows. A
# root cannot protect one — the collector deletes store entries it has no record
# of on sight — so these have to go by hand before anything else can be swept.
orphan_bundles() {
  local p
  for p in "$@"; do
    nix-store --check-validity "$p" 2>/dev/null || printf '%s\n' "$p"
  done
}

# The grant has to be on the terminal rather than on nix: TCC attributes a
# request to whichever app owns the session, so sudo inherits what it has.
orphan_help() {
  local p
  echo
  for p in "$@"; do printf '      %s%s%s\n' "$DIM" "$p" "$OFF"; done
  cat <<EOF

      System Settings → Privacy & Security → App Management → + your terminal
      then: sudo rm -rf <the paths above>
EOF
}

# Pin a bundle as a GC root and the collector walks past it instead of dying on
# it; everything else in the store still goes. --realise on a path that is
# already valid only registers the root, but ask first anyway: on an orphan it
# would go off and fetch 60MB from a cache mid-purge.
pin_bundles() {
  local p link
  mkdir -p "$PINS"
  for p in "$@"; do
    nix-store --check-validity "$p" 2>/dev/null || continue
    link="$PINS/${p##*/}"
    if nix-store --add-root "$link" --indirect --realise "$p" >/dev/null 2>&1; then
      printf '%s\n' "$link"
    fi
  done
}

# nix-store --optimise prints nothing whatsoever until it finishes, and finishing
# can be half an hour away: most of the store passes in milliseconds, and then it
# reaches a nixpkgs checkout and hard-links a quarter of a million tiny files one
# at a time. Silence that long is indistinguishable from a hang — so ask it to
# narrate (-vv is the level at which it names what it is on) and keep the last
# one on screen. Counting the files too, because during the slow stretch the
# path alone sits unchanged for minutes and looks just as stuck.
optimise() {
  local total
  total=$(find /nix/store -maxdepth 1 -mindepth 1 -not -name '.*' | wc -l)
  nix-store --optimise -vv 2>&1 |
    awk -v total="$total" -v dim="$DIM" -v off="$OFF" -v tty="$ISATTY" '
      function clear() { if (tty) printf "\r\033[2K" }
      function show() {
        if (!tty) return
        printf "\r\033[2K    %s%d/%d paths, %d files linked   %s%s", dim, n, total, k, p, off
        fflush()
      }
      /^optimising path/ {
        n++
        p = $0
        sub(/^optimising path .\/nix\/store\/[a-z0-9]+-/, "", p)
        sub(/.\.\.\.$/, "", p)
        show()
        next
      }
      /^linking / { k++; if (k % 500 == 0) show(); next }
      /^loaded /  { next }
      { clear(); printf "    %s\n", $0; fflush() }
      END { clear() }
    '
}

cmd_purge() {
  local days=${1:-30} cutoff before prof entry ids csize total=0 rcount r
  local log swept p bsize
  local -a plan=() doomed=() roots=() others=() bundles=() orphans=() pinned=()

  case "$days" in
  '' | *[!0-9]*) die "purge takes a number of days, e.g. 'hm purge 30'" ;;
  esac

  cutoff=$(date -d "$days days ago" +%s) || die "need GNU date"
  before=$(date -d "$days days ago" '+%Y-%m-%d')

  step "purge — anything older than $days days (before $before)"
  echo
  printf '  %sdeleting%s\n' "$BOLD" "$OFF"

  while IFS= read -r prof; do
    mapfile -t doomed < <(prof_doomed "$prof" "$cutoff")
    [ "${#doomed[@]}" -gt 0 ] || continue
    total=$((total + ${#doomed[@]}))
    plan+=("$prof ${doomed[*]}")
    printf '    %-13s %-11s %sgeneration %s … %s%s\n' \
      "${prof##*/}" \
      "$(printf '%d of %d' "${#doomed[@]}" "$(prof_gens "$prof" | wc -l)")" \
      "$DIM" "${doomed[0]}" "${doomed[-1]}" "$OFF"
  done < <(profile_roots)

  mapfile -t roots < <(stale_roots)
  rcount=${#roots[@]}
  if [ "$rcount" -gt 0 ]; then
    printf '    %-13s %-11s %s(a rebuild to get back)%s\n' \
      'hm builds' "$rcount unapplied" "$DIM" "$OFF"
  fi

  csize=''
  if [ -d "$CACHE" ]; then
    csize=$(du -sh "$CACHE" 2>/dev/null | cut -f1) || csize=''
  fi
  if [ -n "$csize" ]; then
    printf '    %-13s %-11s %s(regenerates on demand)%s\n' \
      'nix cache' "$csize" "$DIM" "$OFF"
  fi

  if [ "$total" -eq 0 ] && [ "$rcount" -eq 0 ] && [ -z "$csize" ]; then
    echo "    nothing to purge"
    return 0
  fi

  # Garbage collection is a tracing collector: it walks the closure of every
  # remaining root and deletes only what nothing reaches. So the honest way to
  # answer "will this delete something I still use" is to show what stays a
  # root — the rest follows.
  printf '\n  %skeeping%s\n' "$BOLD" "$OFF"
  if [ "$total" -gt 0 ]; then
    printf '    the current generation and the one before it\n'
  fi
  mapfile -t others < <(other_roots)
  if [ "${#others[@]}" -gt 0 ]; then
    printf '    %d result link%s outside the profiles\n' \
      "${#others[@]}" "$([ "${#others[@]}" -eq 1 ] || echo s)"
    for r in "${others[@]}"; do printf '      %s%s%s\n' "$DIM" "$r" "$OFF"; done
  fi
  mapfile -t bundles < <(app_bundles)
  if [ "${#bundles[@]}" -gt 0 ]; then
    bsize=$(du -shc "${bundles[@]}" 2>/dev/null | tail -1 | cut -f1) || bsize='?'
    printf '    %d app bundle%s macOS protects from deletion (%s)\n' \
      "${#bundles[@]}" "$([ "${#bundles[@]}" -eq 1 ] || echo s)" "$bsize"
    mapfile -t orphans < <(orphan_bundles "${bundles[@]}")
  fi
  if command -v lsof >/dev/null 2>&1; then
    printf '    anything a running process holds open %s(via lsof)%s\n' "$DIM" "$OFF"
  else
    # Nix looks for open store paths by shelling out to lsof on macOS, and
    # swallows the error if it is missing — you get no warning, just less
    # protection. Say so here instead.
    warn "lsof not on PATH: nix cannot see store paths held by running"
    warn "processes. Close any 'nix develop' shells before continuing."
  fi
  # Known-broken before we start, so say it before the slow part rather than
  # after: a pin cannot save a path nix has already forgotten about.
  if [ "${#orphans[@]}" -gt 0 ]; then
    echo
    warn "an earlier sweep left ${#orphans[@]} bundle(s) on disk that nix no longer"
    warn "knows about, and it will stop on them again. Remove them first:"
    orphan_help "${orphans[@]}"
  fi

  echo
  if [ "$total" -gt 0 ]; then
    confirm "Delete $total generations, then collect garbage and optimise?" n || {
      echo "aborted."
      return 0
    }
  else
    confirm "Nothing that old — collect garbage and optimise anyway?" n || {
      echo "aborted."
      return 0
    }
  fi

  for entry in "${plan[@]}"; do
    prof=${entry%% *}
    ids=${entry#* }
    step "${prof##*/}: deleting old generations"
    # shellcheck disable=SC2086 # deliberate: one argument per generation id
    nix-env --profile "$prof" --delete-generations $ids
  done

  # Both of these hold GC roots, so they have to go before the sweep, not after.
  if [ "$rcount" -gt 0 ]; then
    step "dropping $rcount unapplied build root(s)"
    rm -f "${roots[@]}"
  fi
  if [ -n "$csize" ]; then
    step "clearing $CACHE"
    rm -rf "${CACHE:?}"/*
  fi

  if [ "${#bundles[@]}" -gt 0 ]; then
    step "pinning app bundles out of the sweep's way"
    mapfile -t pinned < <(pin_bundles "${bundles[@]}")
  fi

  step "collecting garbage — the slow part"
  log=$(mktemp) || die "cannot create a temp file"
  swept=1
  nix-store --gc 2>&1 | tee "$log" || swept=0

  # A pin is only for the duration of the sweep; leaving one behind would keep a
  # bundle's whole closure alive until the next purge noticed.
  if [ "${#pinned[@]}" -gt 0 ]; then rm -f "${pinned[@]}"; fi

  # auto-optimise-store is off by default, so this is where the duplicates go.
  # Worth doing even if the sweep died: it reclaims by hard-linking, not by
  # deleting, so it does not depend on the sweep having finished.
  step "hard-linking duplicate files — the long one, safe to interrupt"
  optimise

  if [ "$swept" -eq 0 ]; then
    echo
    warn "the sweep stopped early, so some of the garbage is still there."
    # Its own summary line says '0 store paths deleted' after an abort, which is
    # the count it never got round to tallying, not a rollback. Everything it
    # printed 'deleting' for really is gone.
    warn "what it printed 'deleting' for above is gone regardless of the 0 in"
    warn "its summary — that count is only reported by a run that finishes."
    if [ "${#orphans[@]}" -gt 0 ]; then
      warn "it stopped on the bundle(s) it no longer has a record of:"
      orphan_help "${orphans[@]}"
    fi
    rm -f "$log"
    return 1
  fi
  rm -f "$log"
}

# --------------------------------------------------------------------------- diff rendering

# Packages named in home.packages, as opposed to everything they drag in.
# home-path is a buildEnv, so its *direct* references are exactly the
# requested set — no flake evaluation needed, and it stays correct for old
# generations whose config no longer matches the working tree.
direct_names() {
  local hp
  hp=$(readlink -f "$1/home-path" 2>/dev/null) || return 0
  [ -n "$hp" ] || return 0
  nix-store -q --references "$hp" 2>/dev/null |
    sed 's|^/nix/store/[a-z0-9]*-||; s|-[0-9].*$||' | sort -u
}

# A package removed on one side is only direct on the other, so union both.
# Space-separated: package names never contain one, and a newline-separated
# awk -v assignment is not portable.
direct_union() {
  {
    direct_names "$1"
    direct_names "$2"
  } | sort -u | tr '\n' ' '
}

# nvd decides on colour by looking at its own stdout, which is a pipe here
# because we capture the output to reorder it. Tell it what we decided instead.
nvd_diff() {
  nvd --color "$NVD_COLOUR" diff "$1" "$2" 2>/dev/null || true
}

# Strip ANSI, for the commit message and for matching on package names.
uncolour() {
  sed $'s/\033\\[[0-9;]*m//g'
}

# nvd's diff, with what you asked for listed ahead of what merely came along.
# Direct packages keep nvd's colours; the rest are stripped bare and dimmed,
# so the two groups are told apart by more than just their order.
render_diff() {
  printf '%s\n' "$1" | awk -v direct="$2" -v dim="$DIM" -v off="$OFF" '
    BEGIN {
      n = split(direct, a, " ")
      for (i = 1; i <= n; i++) if (a[i] != "") D[a[i]] = 1
    }
    function plain(s) { gsub(/\033\[[0-9;]*m/, "", s); return s }
    # nvd numbers its rows; after reordering those numbers only mislead.
    function unnumber(s) { sub(/[ \t]*#[0-9]+/, "", s); return s }
    function flush(   i) {
      for (i = 1; i <= nd; i++) print dir[i]
      if (nt) {
        print dim "      · pulled in (" nt ")" off
        for (i = 1; i <= nt; i++) print dim tra[i] off
      }
      nd = 0; nt = 0
    }
    {
      bare = plain($0)
      if (bare !~ /^\[[A-Z][^]]*\][ \t]*#[0-9]+[ \t]/) { flush(); print; next }
      rest = bare
      sub(/^\[[A-Z][^]]*\][ \t]*#[0-9]+[ \t]*/, "", rest)
      split(rest, F, /[ \t]+/)
      if (F[1] in D) dir[++nd] = unnumber($0)
      else tra[++nt] = unnumber(bare)
    }
    END { flush() }
  '
}

# --------------------------------------------------------------------- switch

# Lines nvd marks as upgrades, normalised to "name old -> new".
changed_lines() {
  printf '%s\n' "$1" | awk '
    /^\[U\.\]/ {
      sub(/^\[U\.\][[:space:]]*#[0-9]+[[:space:]]*/, "")
      gsub(/[[:space:]]{2,}/, " ")
      print
    }'
}

# Upgrades where the leading version component changed — the ones worth reading
# release notes for.
major_bumps() {
  changed_lines "$1" | awk '
    function maj(v,   _) { return match(v, /^[0-9]+/) ? substr(v, RSTART, RLENGTH) : "" }
    {
      p = index($0, " -> ")
      if (!p) next
      split(substr($0, 1, p - 1), L, /[[:space:]]+/)
      split(substr($0, p + 4),     R, /[[:space:]]+/)
      old = L[2]; sub(/,$/, "", old)
      new = R[1]; sub(/,$/, "", new)
      if (maj(old) != "" && maj(new) != "" && maj(old) != maj(new))
        printf "  %s %s -> %s\n", L[1], old, new
    }'
}

commit_msg() {
  local diff_out=$1 count closure plural
  count=$(changed_lines "$diff_out" | grep -c . || true)
  closure=$(printf '%s\n' "$diff_out" | grep '^Closure size:' || true)
  if [ "$count" = 1 ]; then plural=''; else plural='s'; fi

  printf 'hm: bump %s package%s\n\n' "$count" "$plural"
  changed_lines "$diff_out"
  printf '%s\n' "$diff_out" | awk '
    /^\[[AR]\.\]/ {
      mark = substr($0, 2, 1) == "A" ? "+ " : "- "
      sub(/^\[[AR]\.\][[:space:]]*#[0-9]+[[:space:]]*/, "")
      gsub(/[[:space:]]{2,}/, " ")
      print mark $0
    }'
  [ -z "$closure" ] || printf '\n%s\n' "$closure"
}

record() {
  local diff_out=$1 msg
  if git -C "$FLAKE" diff --quiet -- flake.lock; then
    return 0
  fi
  if ! confirm "Commit + push flake.lock?" y; then
    echo "left uncommitted."
    return 0
  fi
  msg=$(commit_msg "$diff_out")
  git -C "$FLAKE" commit -q -m "$msg" -- flake.lock
  step "committed $(git -C "$FLAKE" rev-parse --short HEAD)"
  if git -C "$FLAKE" push -q; then
    step "pushed"
  else
    warn "commit created but push failed — push it yourself"
  fi
}

cmd_switch() {
  local target=$1 do_update=$2 attr out dry summary tobuild diff_out diff_colour majors cur_path new_path

  case " $(targets) " in
  *" $target "*) ;;
  *) die "no such target: #$target — expected one of: $(targets_pretty)" ;;
  esac

  cd "$FLAKE" || die "cannot enter $FLAKE"

  if [ "$do_update" = 1 ]; then
    step "nix flake update"
    nix flake update
  fi

  mkdir -p "$RESULTS"
  out="$RESULTS/next-$target"
  attr=".#homeConfigurations.\"$target\".activationPackage"

  # Cheap pass first: a 25-minute compile shouldn't be a surprise.
  if ! dry=$(nix build --dry-run --impure "$attr" 2>&1); then
    printf '%s\n' "$dry" >&2
    die "evaluation failed"
  fi
  summary=$(printf '%s\n' "$dry" | grep -E 'will be (built|fetched)' || true)
  if [ -n "$summary" ]; then
    printf '%s%s%s\n' "$DIM" "$summary" "$OFF"
    tobuild=$(printf '%s\n' "$dry" | grep -oE '/nix/store/[^ ]*\.drv' |
      sed 's|.*/||; s/^[a-z0-9]*-//; s/\.drv$//' | sort -u | tr '\n' ' ')
    if [ -n "$tobuild" ]; then
      warn "compiling from source: $tobuild"
    fi
  fi

  step "building $target"
  nix build --impure "$attr" -o "$out"

  # The store path is the only honest answer to "is there anything to do".
  # nvd compares package names and versions, so it reports no change at all
  # for edits to dotfiles, home.file sources, or hm itself — none of which
  # move a version number, all of which still need activating.
  new_path=$(readlink -f "$out")
  cur_path=$(readlink -f "$PROFILE" 2>/dev/null) || cur_path=''
  if [ "$cur_path" = "$new_path" ]; then
    step "already up to date — the running generation is this exact build"
    return 0
  fi

  if [ -z "$cur_path" ]; then
    warn "no current generation — nothing to diff against"
    diff_out=''
  else
    # Coloured for the screen, stripped for the commit message it also feeds.
    diff_colour=$(nvd_diff "$PROFILE" "$out")
    diff_out=$(printf '%s\n' "$diff_colour" | uncolour)
    echo
    render_diff "$diff_colour" "$(direct_union "$PROFILE" "$out")"
    case "$diff_out" in
    *"No version or selection state changes"*)
      printf '%s(no package changes — config files only)%s\n' "$DIM" "$OFF"
      ;;
    esac
  fi

  majors=$(major_bumps "$diff_out")
  if [ -n "$majors" ]; then
    printf '\n%s⚠ major version bumps%s\n%s\n' "$YEL" "$OFF" "$majors"
  fi

  echo
  if ! confirm "Apply?" n; then
    printf '%sbuilt, not applied:%s %s\n' "$DIM" "$OFF" "$out"
    echo "run 'hm #$target' again to apply — it will reuse this build."
    return 0
  fi

  step "activating"
  "$out/activate"
  record "$diff_out"
}

# ----------------------------------------------------------------------- main

main() {
  local target='' do_update=0
  while [ $# -gt 0 ]; do
    case "$1" in
    -h | --help)
      usage
      return 0
      ;;
    -u | --update) do_update=1 ;;
    list)
      shift
      cmd_list "$@"
      return
      ;;
    diff)
      shift
      cmd_diff "${1:-}" "${2:-}"
      return
      ;;
    rollback)
      shift
      cmd_rollback "$@"
      return
      ;;
    purge)
      shift
      cmd_purge "${1:-}"
      return
      ;;
    -*) die "unknown option: $1" ;;
    *)
      [ -z "$target" ] || die "unexpected argument: $1"
      case "$1" in
      '#'?*) target=${1#\#} ;;
      *) die "targets take a '#' prefix — did you mean: hm #$1" ;;
      esac
      ;;
    esac
    shift
  done

  if [ -z "$target" ]; then
    printf '%serror:%s specify a target\n\n' "$RED" "$OFF" >&2
    usage >&2
    return 1
  fi
  cmd_switch "$target" "$do_update"
}

main "$@"
