# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

ANTIDOTE_PATH="$HOME/.local/lib/antidote/share/antidote/antidote.zsh"
if [ -f "$ANTIDOTE_PATH" ]; then
  source "$ANTIDOTE_PATH"
  antidote load
fi

# Source anything in .zshrc.d.
for _rc in ${ZDOTDIR:-$HOME}/.zshrc.d/*.zsh; do
  # Ignore tilde files.
  if [[ $_rc:t != '~'* ]]; then
    source "$_rc"
  fi
done
unset _rc

# Set the list of directories that zsh searches for commands.
path=(
  $HOME/{,s}bin(N)
  $HOME/.local/{,s}bin(N)
  $HOME/.npm-global/bin
  $HOME/.asdf/shims
  /opt/{homebrew,local}/{,s}bin(N)
  /usr/local/{,s}bin(N)
  $path
)

# Ensure path arrays do not contain duplicates.
typeset -gU path fpath

# To customize prompt, run `p10k configure` or edit .p10k.zsh.
[[ ! -f ${ZDOTDIR:-$HOME}/.p10k.zsh ]] || source ${ZDOTDIR:-$HOME}/.p10k.zsh
