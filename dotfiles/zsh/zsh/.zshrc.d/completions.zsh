if command -v vend > /dev/null; then
  eval "$(vend completion zsh)"
fi
source <(fzf --zsh)
