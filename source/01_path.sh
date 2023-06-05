# shellcheck shell=bash

paths=(
  ~/.local/bin
  $DOTFILES/bin
  "/Applications/IntelliJ IDEA.app/Contents/MacOS"
)

export PATH
for p in "${paths[@]}"; do
  [[ -d "$p" ]] && PATH="$p:$(path_remove "$p")"
done
unset p paths
