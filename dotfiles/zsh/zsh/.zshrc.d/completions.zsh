if type -p vend >/dev/null 2>&1; then
  eval "$(VEND_CLI_NO_PLUGIN_NAG=1 vend completion zsh)"
  eval "$(VEND_CLI_NO_PLUGIN_NAG=1 vend secret completion zsh)"
fi
source <(fzf --zsh)
