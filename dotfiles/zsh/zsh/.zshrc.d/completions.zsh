if command -v vend > /dev/null; then
  eval "$(VEND_CLI_NO_PLUGIN_NAG=1 vend completion zsh)"
  eval "$(VEND_CLI_NO_PLUGIN_NAG=1 vend secret completion zsh)"
fi
source <(fzf --zsh)
