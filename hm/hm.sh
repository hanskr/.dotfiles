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

if [ -t 1 ]; then
  BOLD=$'\033[1m' DIM=$'\033[2m' RED=$'\033[31m' YEL=$'\033[33m' GRN=$'\033[32m' OFF=$'\033[0m'
else
  BOLD='' DIM='' RED='' YEL='' GRN='' OFF=''
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
  nvd diff "$la" "$lb"
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
  nvd diff "$PROFILE" "$link" || true
  echo
  if ! confirm "Activate generation $to?" n; then
    echo "aborted."
    return 0
  fi
  "$link/activate"
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
  local target=$1 do_update=$2 attr out dry summary tobuild diff_out majors cur_path new_path

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
    diff_out=$(nvd diff "$PROFILE" "$out" 2>/dev/null || true)
    echo
    printf '%s\n' "$diff_out"
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
