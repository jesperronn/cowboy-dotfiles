alias cdv='cd ~/src/cancerventetid'
alias cdp='cd ~/src/nine/pplus/plus-reporter'
alias cdn='cd ~/src/nine'

#alias kk="K=$(cdk && pwd);echo $K;"
# function _kgProjects(){
#   echo "stackedit amp content-store metadata-store missing-link xml-toolbox gitifier kg-site kg-site-assets kg-pipeline"
# }
# alias karnovUpdate="C=$(pwd);cdk; pwd; for f in $(_kgProjects); do cd \$f; pwd; git fetch; cd -; done;cd \$C"


alias k='kubectl'

# EDITOR update for bundler
export BUNDLER_EDITOR=atom

# lang settings, view with `locale` or `locale -a`
# export LANG=da_DK.UTF-8
export LANG=en_US.UTF-8

# oracle instantclient via homebrew
#
export OCI_DIR="$(brew --prefix)/lib"
# see http://www.rubydoc.info/github/kubo/ruby-oci8/master/file/docs/install-on-osx.md
# AND when downloading manually the zip files into `~/Downloads`:
# `export HOMEBREW_CACHE=$HOME/Downloads/``


# for homebrew upgrade, always remove old versions:
# If --cleanup is specified or HOMEBREW_INSTALL_CLEANUP is set then remove
#     previously installed version(s) of upgraded formulae.
export HOMEBREW_INSTALL_CLEANUP=true
# The GitHub credentials in the macOS keychain may be invalid.
# Clear them with:
#   printf "protocol=https\nhost=github.com\n" | git credential-osxkeychain erase
# Or create a personal access token:
#   https://github.com/settings/tokens/new?scopes=gist,public_repo&description=Homebrew
# and then set the token as: export HOMEBREW_GITHUB_API_TOKEN="your_new_token"
# Github api for homebrew


 # bintray
 export BINTRAY_USERNAME=jesperronn
 export BINTRAY_KEY=

# homebrew API token (for `brew search` and similar commands)
