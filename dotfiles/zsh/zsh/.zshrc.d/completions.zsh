if command -v vend > /dev/null; then
  eval "$(vend completion zsh)"
  eval "$(vend secret completion zsh)"
fi
source <(fzf --zsh)
