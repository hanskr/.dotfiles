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

alias c='() { if [ -z "$1" ]; then code .; else code "$1"; fi; }'
alias hmu='(){ home-manager switch --impure --flake .$1;}'
