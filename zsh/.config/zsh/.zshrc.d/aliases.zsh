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

alias c="code ."

alias -g ...='../..'
alias -g ....='../../..'
alias -g .....='../../../..'
alias -g ......='../../../../..'
alias cd..='cd ..'
