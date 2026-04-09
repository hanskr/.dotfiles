#!/bin/zsh
#
# .aliases - Set whatever shell aliases you want.
#

setopt auto_cd
alias ls='ls --color=auto'
alias lsa='ls -lah'
alias l='ls -lah'
alias ll='ls -lh'
alias la='ls -lAh'

alias -g ...='../..'
alias -g ....='../../..'
alias -g .....='../../../..'
alias -g ......='../../../../..'
alias cd..='cd ..'

c() {
  if [ $# -eq 0 ]; then
    code .
  else
    code "$@"
  fi
}
compdef '_files' c

alias hmu='(){ home-manager switch --impure --flake .$1;}'

# Insert newline without executing
insert-newline() {
  LBUFFER+=$'\n'
}
zle -N insert-newline
bindkey '^[[13;2u' insert-newline
