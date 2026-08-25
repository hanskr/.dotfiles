#!/bin/zsh
#
# work.zsh - work-profile only shell config (see hm/work.nix).
#

# Claude Code inside the nono sandbox, with only the current directory writable.
#
# Args before an optional `--` go to nono, so ad-hoc grants are a one-liner:
#   nocl                                  # plain session
#   nocl -c                               # args go to claude
#   nocl -r ~/.config/git -- -c           # grant a read, then continue
nocl() {
  local -a nono_args
  local i=${@[(i)--]}
  if (( i <= $# )); then
    nono_args=("${@[1,i-1]}")
    shift $i
  fi
  nono run -p claude --allow-cwd "${nono_args[@]}" -- \
    claude --dangerously-skip-permissions \
    --settings '{"skipDangerousModePermissionPrompt": true}' "$@"
}
