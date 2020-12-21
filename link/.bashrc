# Where the magic happens.
export DOTFILES=~/.dotfiles

# Source all files in "source"
function src() {
  local file
  if [[ "$1" ]]; then
    source "$DOTFILES/source/$1.sh"
  else
    for file in $DOTFILES/source/*.sh; do
      # timings for load of start scripts:
      # $ __bashrc_bench=1 bash -i
      if [[ $__bashrc_bench ]]; then
        TIMEFORMAT="$file: %R"
        time . "$file"
        unset TIMEFORMAT
      else
        . "$file"
      fi

    done
  fi
}

# Run dotfiles script, then source.
function dotfiles() {
  $DOTFILES/bin/dotfiles "$@" && src
}

src

[ -f ~/.fzf.bash ] && source ~/.fzf.bash
